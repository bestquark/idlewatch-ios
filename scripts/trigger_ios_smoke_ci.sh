#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW_FILE="ios-smoke.yml"
BRANCH="${1:-main}"
WAIT_SECONDS="${2:-20}"
POLL_INTERVAL=2
GH_TIMEOUT_SECONDS=20

run_with_timeout() {
  local timeout_seconds="$1"
  shift

  local output_file
  output_file="$(mktemp)"

  set +e
  "$@" >"${output_file}" 2>&1 &
  local pid=$!
  local elapsed=0

  while kill -0 "${pid}" 2>/dev/null; do
    if [[ ${elapsed} -ge ${timeout_seconds} ]]; then
      kill "${pid}" 2>/dev/null || true
      wait "${pid}" 2>/dev/null || true
      cat "${output_file}" >&2
      rm -f "${output_file}"
      set -e
      return 124
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done

  wait "${pid}"
  local exit_code=$?
  set -e

  cat "${output_file}"
  rm -f "${output_file}"
  return ${exit_code}
}

gh_cmd() {
  run_with_timeout "${GH_TIMEOUT_SECONDS}" gh "$@"
}

extract_int_field() {
  local json_input="$1"
  local field="$2"
  printf '%s' "${json_input}" | python3 -c 'import json,sys
field=sys.argv[1]
raw=sys.stdin.read().strip()
if not raw:
  print(0)
  raise SystemExit
try:
  data=json.loads(raw)
except Exception:
  print(0)
  raise SystemExit
if isinstance(data, list):
  data=data[0] if data else {}
try:
  print(int(data.get(field,0)))
except Exception:
  print(0)
' "${field}"
}

select_run() {
  local runs_json="$1"
  local before_id="$2"
  printf '%s' "${runs_json}" | python3 -c 'import json,sys
rows=json.load(sys.stdin)
before=int(sys.argv[1])
for row in rows:
  try:
    if int(row.get("databaseId",0))>before:
      print(json.dumps(row))
      raise SystemExit
  except Exception:
    pass
if rows:
  print(json.dumps(rows[0]))
' "${before_id}"
}

if ! command -v gh >/dev/null 2>&1; then
  echo "[idlewatch-ios] gh CLI not found; skipping CI trigger." >&2
  exit 127
fi

if ! gh_cmd auth status >/dev/null; then
  echo "[idlewatch-ios] gh auth is not configured or timed out; skipping CI trigger." >&2
  exit 126
fi

cd "${ROOT_DIR}"

before_run_json="$(gh_cmd run list --workflow "${WORKFLOW_FILE}" --branch "${BRANCH}" --limit 1 --json databaseId || true)"
before_run_id="$(extract_int_field "${before_run_json}" "databaseId")"

dispatch_ok=true
if ! gh_cmd workflow run "${WORKFLOW_FILE}" --ref "${BRANCH}" >/dev/null; then
  dispatch_ok=false
  echo "[idlewatch-ios] Timed out triggering GitHub workflow dispatch; checking latest run metadata anyway." >&2
fi

elapsed=0
run_url=""
run_status=""
run_conclusion=""
run_id=0

while [[ ${elapsed} -le ${WAIT_SECONDS} ]]; do
  run_json="$(gh_cmd run list --workflow "${WORKFLOW_FILE}" --branch "${BRANCH}" --limit 5 --json databaseId,url,status,conclusion,createdAt || true)"

  if [[ -n "${run_json}" && "${run_json}" != "[]" ]]; then
    selected="$(select_run "${run_json}" "${before_run_id}")"

    if [[ -n "${selected}" ]]; then
      run_id="$(extract_int_field "${selected}" "databaseId")"
      run_url="$(printf '%s' "${selected}" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("url",""))')"
      run_status="$(printf '%s' "${selected}" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("status",""))')"
      run_conclusion="$(printf '%s' "${selected}" | python3 -c 'import json,sys; c=json.load(sys.stdin).get("conclusion", None); print("pending" if c in (None, "") else c)')"

      if [[ -n "${run_url}" ]]; then
        if [[ "${run_status}" == "completed" || ${elapsed} -ge ${WAIT_SECONDS} || ${run_id} -gt ${before_run_id} ]]; then
          break
        fi
      fi
    fi
  fi

  sleep ${POLL_INTERVAL}
  elapsed=$((elapsed + POLL_INTERVAL))
done

if [[ -z "${run_url}" ]]; then
  echo "[idlewatch-ios] Could not fetch workflow run metadata yet." >&2
  exit 1
fi

echo "Triggered iOS smoke CI run: ${run_url}"
echo "CI run status: ${run_status:-unknown}"
echo "CI run conclusion: ${run_conclusion:-pending}"

if [[ "${dispatch_ok}" != true ]]; then
  exit 1
fi

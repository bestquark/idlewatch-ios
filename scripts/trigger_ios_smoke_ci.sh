#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW_FILE="ios-smoke.yml"
BRANCH="${1:-main}"
WAIT_SECONDS="${2:-20}"
POLL_INTERVAL=2

if ! command -v gh >/dev/null 2>&1; then
  echo "[idlewatch-ios] gh CLI not found; skipping CI trigger." >&2
  exit 127
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "[idlewatch-ios] gh auth is not configured; skipping CI trigger." >&2
  exit 126
fi

cd "${ROOT_DIR}"

before_run_json="$(gh run list --workflow "${WORKFLOW_FILE}" --branch "${BRANCH}" --limit 1 --json databaseId 2>/dev/null || true)"
before_run_id="$(printf '%s' "${before_run_json}" | python3 -c 'import json,sys
raw=sys.stdin.read().strip()
if not raw or raw=="[]":
  print(0)
else:
  try:
    data=json.loads(raw)
    print(int(data[0].get("databaseId",0)))
  except Exception:
    print(0)
')"

# Trigger workflow dispatch on requested branch.
gh workflow run "${WORKFLOW_FILE}" --ref "${BRANCH}" >/dev/null

# Poll briefly so caller gets metadata for the freshly dispatched run (not a stale older run).
elapsed=0
run_url=""
run_status=""
run_conclusion=""
run_id=0

while [[ ${elapsed} -le ${WAIT_SECONDS} ]]; do
  run_json="$(gh run list --workflow "${WORKFLOW_FILE}" --branch "${BRANCH}" --limit 5 --json databaseId,url,status,conclusion,createdAt 2>/dev/null || true)"

  if [[ -n "${run_json}" && "${run_json}" != "[]" ]]; then
    selected="$(printf '%s' "${run_json}" | python3 -c 'import json,sys
rows=json.load(sys.stdin)
before=int(sys.argv[1])
# Prefer first run newer than the pre-dispatch snapshot.
for row in rows:
  try:
    if int(row.get("databaseId",0))>before:
      print(json.dumps(row))
      raise SystemExit
  except Exception:
    pass
# Fallback: latest row if no newer id was observed yet.
if rows:
  print(json.dumps(rows[0]))
' "${before_run_id}")"

    if [[ -n "${selected}" ]]; then
      run_id="$(printf '%s' "${selected}" | python3 -c 'import json,sys; print(int(json.load(sys.stdin).get("databaseId",0)))')"
      run_url="$(printf '%s' "${selected}" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("url", ""))')"
      run_status="$(printf '%s' "${selected}" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("status", ""))')"
      run_conclusion="$(printf '%s' "${selected}" | python3 -c 'import json,sys; c=json.load(sys.stdin).get("conclusion", None); print("pending" if c in (None, "") else c)')"

      if [[ -n "${run_url}" && ${run_id} -gt ${before_run_id} ]]; then
        if [[ "${run_status}" == "completed" || ${elapsed} -ge ${WAIT_SECONDS} ]]; then
          break
        fi
      fi
    fi
  fi

  sleep ${POLL_INTERVAL}
  elapsed=$((elapsed + POLL_INTERVAL))
done

if [[ -z "${run_url}" ]]; then
  echo "[idlewatch-ios] CI trigger sent, but could not fetch workflow run metadata yet." >&2
  exit 1
fi

echo "Triggered iOS smoke CI run: ${run_url}"
echo "CI run status: ${run_status:-unknown}"
echo "CI run conclusion: ${run_conclusion:-pending}"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW_FILE="ios-smoke.yml"
BRANCH="${1:-main}"
WAIT_SECONDS="${2:-15}"
POLL_INTERVAL=3

if ! command -v gh >/dev/null 2>&1; then
  echo "[idlewatch-ios] gh CLI not found; skipping CI trigger." >&2
  exit 127
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "[idlewatch-ios] gh auth is not configured; skipping CI trigger." >&2
  exit 126
fi

cd "${ROOT_DIR}"

# Trigger workflow dispatch on requested branch.
gh workflow run "${WORKFLOW_FILE}" --ref "${BRANCH}" >/dev/null

# Poll briefly so the caller gets fresher status than a one-shot queue check.
elapsed=0
run_url=""
run_status=""
run_conclusion=""

while [[ ${elapsed} -le ${WAIT_SECONDS} ]]; do
  run_json="$(gh run list --workflow "${WORKFLOW_FILE}" --branch "${BRANCH}" --limit 1 --json databaseId,url,status,conclusion,displayTitle,createdAt 2>/dev/null || true)"

  if [[ -n "${run_json}" && "${run_json}" != "[]" ]]; then
    run_url="$(printf '%s' "${run_json}" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d[0].get("url", ""))')"
    run_status="$(printf '%s' "${run_json}" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d[0].get("status", ""))')"
    run_conclusion="$(printf '%s' "${run_json}" | python3 -c 'import json,sys; d=json.load(sys.stdin); c=d[0].get("conclusion", None); print("pending" if c in (None, "") else c)')"

    if [[ -n "${run_url}" ]]; then
      if [[ "${run_status}" == "completed" || ${elapsed} -ge ${WAIT_SECONDS} ]]; then
        break
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

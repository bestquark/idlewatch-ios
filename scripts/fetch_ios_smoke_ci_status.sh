#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW_FILE="ios-smoke.yml"
BRANCH="${1:-main}"

if ! command -v gh >/dev/null 2>&1; then
  echo "[idlewatch-ios] gh CLI not found; cannot fetch CI status." >&2
  exit 127
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "[idlewatch-ios] gh auth missing; cannot fetch CI status." >&2
  exit 126
fi

cd "${ROOT_DIR}"

run_json="$(gh run list --workflow "${WORKFLOW_FILE}" --branch "${BRANCH}" --limit 1 --json url,status,conclusion)"

if [[ -z "${run_json}" || "${run_json}" == "[]" ]]; then
  echo "[idlewatch-ios] No iOS smoke runs found for branch ${BRANCH}." >&2
  exit 1
fi

run_url="$(printf '%s' "${run_json}" | python3 -c 'import json,sys; rows=json.load(sys.stdin); print((rows[0] if rows else {}).get("url",""))')"
run_status="$(printf '%s' "${run_json}" | python3 -c 'import json,sys; rows=json.load(sys.stdin); print((rows[0] if rows else {}).get("status","unknown"))')"
run_conclusion="$(printf '%s' "${run_json}" | python3 -c 'import json,sys; rows=json.load(sys.stdin); c=(rows[0] if rows else {}).get("conclusion",""); print("pending" if c in (None, "") else c)')"

echo "Latest iOS smoke CI run: ${run_url}"
echo "CI run status: ${run_status}"
echo "CI run conclusion: ${run_conclusion}"

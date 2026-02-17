#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKFLOW_FILE="ios-smoke.yml"
BRANCH="${1:-main}"

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

# Give GitHub a brief moment to register the new run.
sleep 3

run_json="$(gh run list --workflow "${WORKFLOW_FILE}" --branch "${BRANCH}" --limit 1 --json databaseId,url,status,conclusion,displayTitle,createdAt 2>/dev/null || true)"

if [[ -z "${run_json}" || "${run_json}" == "[]" ]]; then
  echo "[idlewatch-ios] CI trigger sent, but could not fetch workflow run metadata yet." >&2
  exit 1
fi

run_url="$(printf '%s' "${run_json}" | sed -n 's/.*"url":"\([^"]*\)".*/\1/p' | head -n1)"
run_status="$(printf '%s' "${run_json}" | sed -n 's/.*"status":"\([^"]*\)".*/\1/p' | head -n1)"
run_conclusion="$(printf '%s' "${run_json}" | sed -n 's/.*"conclusion":\("[^"]*"\|null\).*/\1/p' | head -n1 | tr -d '"')"

if [[ -z "${run_url}" ]]; then
  echo "[idlewatch-ios] CI run metadata fetched but URL missing." >&2
  exit 1
fi

echo "Triggered iOS smoke CI run: ${run_url}"
echo "CI run status: ${run_status:-unknown}"
echo "CI run conclusion: ${run_conclusion:-pending}"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${ROOT_DIR}/docs/qa/artifacts"
LOG_FILE="${LOG_DIR}/runtime-validation-$(date +%Y%m%d-%H%M%S).log"

mkdir -p "${LOG_DIR}"

if ! command -v flutter >/dev/null 2>&1; then
  echo "[idlewatch-ios] flutter CLI is not installed or not on PATH." | tee -a "${LOG_FILE}"
  echo "Install Flutter SDK and rerun: scripts/validate_runtime.sh" | tee -a "${LOG_FILE}"
  exit 127
fi

{
  echo "[idlewatch-ios] Runtime validation started: $(date)"
  echo "[idlewatch-ios] Repo: ${ROOT_DIR}"
  echo
  flutter --version
  echo
  echo "[step] flutter pub get"
  flutter pub get
  echo
  echo "[step] flutter analyze"
  flutter analyze
  echo
  echo "[step] flutter test"
  flutter test
  echo
  echo "[idlewatch-ios] Runtime validation finished: $(date)"
} | tee -a "${LOG_FILE}"

echo "Saved runtime validation log to: ${LOG_FILE}"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${ROOT_DIR}/docs/qa/artifacts"
LOG_FILE="${LOG_DIR}/runtime-validation-$(date +%Y%m%d-%H%M%S).log"
RESOLVE_SCRIPT="${ROOT_DIR}/scripts/resolve_flutter_cmd.sh"

mkdir -p "${LOG_DIR}"

FLUTTER_CMD="$(${RESOLVE_SCRIPT} 2>/dev/null || true)"

if [[ -z "${FLUTTER_CMD}" ]]; then
  echo "[idlewatch-ios] Flutter runtime not found (checked: flutter, fvm flutter)." | tee -a "${LOG_FILE}"
  echo "Install Flutter SDK or FVM and rerun: scripts/validate_runtime.sh" | tee -a "${LOG_FILE}"
  exit 127
fi

{
  echo "[idlewatch-ios] Runtime validation started: $(date)"
  echo "[idlewatch-ios] Repo: ${ROOT_DIR}"
  echo "[idlewatch-ios] Flutter command: ${FLUTTER_CMD}"
  echo
  if [[ "${IDLEWATCH_VALIDATE_REPORT_VERSION:-0}" == "1" ]]; then
    eval "${FLUTTER_CMD} --version"
    echo
  fi

  echo
  echo "[step] ${FLUTTER_CMD} pub get"
  eval "${FLUTTER_CMD} pub get"
  echo
  echo "[step] ${FLUTTER_CMD} analyze"
  eval "${FLUTTER_CMD} analyze"
  echo
  echo "[step] ${FLUTTER_CMD} test"
  eval "${FLUTTER_CMD} test"
  echo
  echo "[idlewatch-ios] Runtime validation finished: $(date)"
} | tee -a "${LOG_FILE}"

echo "Saved runtime validation log to: ${LOG_FILE}"

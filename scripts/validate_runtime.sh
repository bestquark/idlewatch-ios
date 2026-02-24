#!/usr/bin/env bash
set -euo pipefail
set -o pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${ROOT_DIR}/docs/qa/artifacts"
LOG_FILE="${LOG_DIR}/runtime-validation-$(date +%Y%m%d-%H%M%S)-$$.log"
RESOLVE_SCRIPT="${ROOT_DIR}/scripts/resolve_flutter_cmd.sh"

mkdir -p "${LOG_DIR}"

FLUTTER_CMD="$(${RESOLVE_SCRIPT} 2>/dev/null || true)"
FLUTTER_STEP_TIMEOUT_SECONDS="${IDLEWATCH_FLUTTER_STEP_TIMEOUT_SECONDS:-900}"

if [[ -z "${FLUTTER_CMD}" ]]; then
  echo "[idlewatch-ios] Flutter runtime not found (checked: flutter, fvm flutter)." | tee -a "${LOG_FILE}"
  echo "Install Flutter SDK or FVM and rerun: scripts/validate_runtime.sh" | tee -a "${LOG_FILE}"
  exit 127
fi

run_flutter_step() {
  local step_name="$1"
  shift

  local step_cmd="${FLUTTER_CMD} $*"
  local timeout_cmd=""
  local rc=0

  if [[ -n "${FLUTTER_STEP_TIMEOUT_SECONDS}" && "${FLUTTER_STEP_TIMEOUT_SECONDS}" != "0" ]] && command -v timeout >/dev/null 2>&1; then
    timeout_cmd="timeout ${FLUTTER_STEP_TIMEOUT_SECONDS}s"
  fi

  echo "[step] ${step_name}: ${timeout_cmd:+${timeout_cmd} }${step_cmd}"

  set +e
  if [[ -n "${timeout_cmd}" ]]; then
    eval "${timeout_cmd} ${step_cmd}" >>"${LOG_FILE}" 2>&1
    rc=$?
  else
    eval "${step_cmd}" >>"${LOG_FILE}" 2>&1
    rc=$?
  fi
  set -e

  if [[ ${rc} -ne 0 ]]; then
    if [[ -n "${timeout_cmd}" && ${rc} -eq 124 ]]; then
      echo "[error] ${step_name} exceeded timeout of ${FLUTTER_STEP_TIMEOUT_SECONDS}s."
    else
      echo "[error] ${step_name} failed with exit code ${rc}."
    fi
    return ${rc}
  fi
}

{
  echo "[idlewatch-ios] Runtime validation started: $(date)"
  echo "[idlewatch-ios] Repo: ${ROOT_DIR}"
  echo "[idlewatch-ios] Flutter command: ${FLUTTER_CMD}"
  echo "[idlewatch-ios] Step timeout: ${FLUTTER_STEP_TIMEOUT_SECONDS}s"
  echo
  if [[ "${IDLEWATCH_VALIDATE_REPORT_VERSION:-0}" == "1" ]]; then
    if command -v timeout >/dev/null 2>&1 && [[ -n "${FLUTTER_STEP_TIMEOUT_SECONDS}" && "${FLUTTER_STEP_TIMEOUT_SECONDS}" != "0" ]]; then
      timeout "${FLUTTER_STEP_TIMEOUT_SECONDS}"s "${FLUTTER_CMD}" --version >>"${LOG_FILE}" 2>&1 || true
    else
      eval "${FLUTTER_CMD} --version" >>"${LOG_FILE}" 2>&1 || true
    fi
    echo >>"${LOG_FILE}"
  fi

  echo
  run_flutter_step "${FLUTTER_CMD} pub get" pub get
  run_flutter_step "${FLUTTER_CMD} analyze" analyze
  run_flutter_step "${FLUTTER_CMD} test" test
  echo

  analyze_summary="$(grep -E "No issues found!?" "${LOG_FILE}" | tail -n 1 || true)"
  test_count="$(grep -E 'All tests passed' "${LOG_FILE}" | tail -n 1 | sed -E 's/.*\+([0-9]+): All tests passed!?$/\1/' | tr -d '[:space:]' || true)"

  if [[ -n "${analyze_summary}" ]]; then
    echo "[summary] flutter analyze: ${analyze_summary}"
  else
    echo "[summary] flutter analyze: unknown"
  fi

  if [[ -n "${test_count}" ]]; then
    echo "[summary] flutter test: ${test_count} tests passed."
  else
    echo "[summary] flutter test: unknown"
  fi

  echo "[idlewatch-ios] Runtime validation finished: $(date)"
} | tee -a "${LOG_FILE}"

echo "Saved runtime validation log to: ${LOG_FILE}"

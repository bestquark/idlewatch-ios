#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="${ROOT_DIR}/docs/qa/artifacts"
PREP_SCRIPT="${ROOT_DIR}/scripts/prepare_ios_smoke_report.sh"
VALIDATE_SCRIPT="${ROOT_DIR}/scripts/validate_runtime.sh"
LINK_SCRIPT="${ROOT_DIR}/scripts/link_ios_smoke_artifacts.sh"
RESOLVE_SCRIPT="${ROOT_DIR}/scripts/resolve_flutter_cmd.sh"

mkdir -p "${ARTIFACT_DIR}"

echo "[idlewatch-ios] Preparing smoke report template..."
prep_output="$(${PREP_SCRIPT})"
echo "${prep_output}"

report_path="$(printf '%s' "${prep_output}" | sed -n 's/^Created smoke report template: //p' | tail -n1)"
if [[ -z "${report_path}" ]]; then
  echo "[idlewatch-ios] Could not determine smoke report path from prepare script output." >&2
  exit 1
fi

timestamp="$(date '+%Y-%m-%d %H:%M:%S %Z')"
flutter_version="not available"
validation_status="pass"
validation_log=""
flutter_cmd="$(${RESOLVE_SCRIPT} 2>/dev/null || true)"

if [[ -n "${flutter_cmd}" ]]; then
  flutter_version="$(eval "${flutter_cmd} --version" 2>/dev/null | head -n1 | sed 's/^[[:space:]]*//')"
else
  validation_status="blocked (flutter/fvm missing)"
fi

echo "[idlewatch-ios] Running runtime validation..."
set +e
validation_output="$(${VALIDATE_SCRIPT} 2>&1)"
validation_code=$?
set -e

printf '%s\n' "${validation_output}"

if [[ ${validation_code} -ne 0 ]]; then
  if [[ "${validation_status}" == "pass" ]]; then
    validation_status="fail"
  fi
fi

validation_log="$(printf '%s' "${validation_output}" | sed -n 's/^Saved runtime validation log to: //p' | tail -n1)"
if [[ -z "${validation_log}" ]]; then
  validation_log="$(ls -t "${ARTIFACT_DIR}"/runtime-validation-*.log 2>/dev/null | head -n1 || true)"
fi

{
  echo
  echo "## Auto-captured preflight"
  echo "- Generated: ${timestamp}"
  echo "- Flutter command: ${flutter_cmd:-not available}"
  echo "- Flutter version: ${flutter_version}"
  echo "- Runtime validation status: ${validation_status}"
  if [[ -n "${validation_log}" ]]; then
    echo "- Runtime validation log: ${validation_log}"
  else
    echo "- Runtime validation log: (not found)"
  fi
  echo "- Workflow helper: scripts/run_ios_smoke_workflow.sh"
  echo
  if [[ "${validation_status}" != "pass" ]]; then
    echo "> Next step: run this same script on a Flutter-enabled macOS host with iOS simulator/device access."
  fi
} >> "${report_path}"

echo "[idlewatch-ios] Linking artifacts into QA log..."
set +e
link_output="$(${LINK_SCRIPT} "${report_path}" "${validation_status}" "${validation_log}" 2>&1)"
link_code=$?
set -e
printf '%s\n' "${link_output}"
if [[ ${link_code} -ne 0 ]]; then
  echo "[idlewatch-ios] Warning: failed to auto-link artifacts into QA log." >&2
  echo "[idlewatch-ios] Manual fallback: ${LINK_SCRIPT} \"${report_path}\" \"${validation_status}\" \"${validation_log}\"" >&2
fi

echo "[idlewatch-ios] Smoke workflow complete."
echo "[idlewatch-ios] Report: ${report_path}"
if [[ -n "${validation_log}" ]]; then
  echo "[idlewatch-ios] Validation log: ${validation_log}"
fi

if [[ ${validation_code} -ne 0 ]]; then
  exit ${validation_code}
fi

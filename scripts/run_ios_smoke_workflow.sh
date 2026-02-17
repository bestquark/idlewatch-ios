#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="${ROOT_DIR}/docs/qa/artifacts"
PREP_SCRIPT="${ROOT_DIR}/scripts/prepare_ios_smoke_report.sh"
VALIDATE_SCRIPT="${ROOT_DIR}/scripts/validate_runtime.sh"
LINK_SCRIPT="${ROOT_DIR}/scripts/link_ios_smoke_artifacts.sh"
RESOLVE_SCRIPT="${ROOT_DIR}/scripts/resolve_flutter_cmd.sh"
PREFLIGHT_SCRIPT="${ROOT_DIR}/scripts/preflight_ios_host.sh"
CI_TRIGGER_SCRIPT="${ROOT_DIR}/scripts/trigger_ios_smoke_ci.sh"
CI_STATUS_SCRIPT="${ROOT_DIR}/scripts/fetch_ios_smoke_ci_status.sh"

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
preflight_status="ready"
preflight_log=""
ci_run_url=""
ci_run_status="not triggered"
ci_run_conclusion="pending"
flutter_cmd="$(${RESOLVE_SCRIPT} 2>/dev/null || true)"

if [[ -n "${flutter_cmd}" ]]; then
  if [[ "${IDLEWATCH_WORKFLOW_CAPTURE_FLUTTER_VERSION:-0}" == "1" ]]; then
    flutter_version="$(eval "${flutter_cmd} --version" 2>/dev/null | head -n1 | sed 's/^[[:space:]]*//')"
  else
    flutter_version="not captured (skipped to reduce memory footprint)"
  fi
else
  validation_status="blocked (flutter/fvm missing)"
fi

validation_code=0
validation_output=""

echo "[idlewatch-ios] Running iOS host preflight..."
set +e
preflight_output="$(${PREFLIGHT_SCRIPT} 2>&1)"
preflight_code=$?
set -e
printf '%s\n' "${preflight_output}"
if [[ ${preflight_code} -ne 0 ]]; then
  preflight_status="blocked"
fi
preflight_log="$(printf '%s' "${preflight_output}" | sed -n 's/^Saved iOS host preflight log to: //p' | tail -n1)"
if [[ -z "${preflight_log}" ]]; then
  preflight_log="$(ls -t "${ARTIFACT_DIR}"/ios-host-preflight-*.log 2>/dev/null | head -n1 || true)"
fi

if [[ "${IDLEWATCH_SKIP_RUNTIME_VALIDATION:-0}" == "1" ]]; then
  validation_status="skipped"
  validation_output="${report_path}: runtime validation skipped by IDLEWATCH_SKIP_RUNTIME_VALIDATION=1"
  echo "[idlewatch-ios] Runtime validation skipped by request (IDLEWATCH_SKIP_RUNTIME_VALIDATION=1)."
  echo "${validation_output}"
else
  echo "[idlewatch-ios] Running runtime validation..."
  set +e
  validation_output="$(${VALIDATE_SCRIPT} 2>&1)"
  validation_code=$?
  set -e

  printf '%s\n' "${validation_output}"

  if [[ ${validation_code} -ne 0 ]]; then
    if [[ ${validation_code} -eq 127 ]]; then
      validation_status="blocked (flutter/fvm missing)"
    elif [[ "${validation_status}" == "pass" ]]; then
      validation_status="fail"
    fi
  fi

  validation_log="$(printf '%s' "${validation_output}" | sed -n 's/^Saved runtime validation log to: //p' | tail -n1)"
  if [[ -z "${validation_log}" ]]; then
    validation_log="$(ls -t "${ARTIFACT_DIR}"/runtime-validation-*.log 2>/dev/null | head -n1 || true)"
  fi
fi

echo "[idlewatch-ios] Fetching latest GitHub iOS smoke CI status..."
set +e
ci_status_output="$(${CI_STATUS_SCRIPT} main 2>&1)"
ci_status_code=$?
set -e
printf '%s\n' "${ci_status_output}"

if [[ ${ci_status_code} -eq 0 ]]; then
  ci_run_url="$(printf '%s' "${ci_status_output}" | sed -n 's/^Latest iOS smoke CI run: //p' | tail -n1)"
  ci_run_status="$(printf '%s' "${ci_status_output}" | sed -n 's/^CI run status: //p' | tail -n1)"
  ci_run_conclusion="$(printf '%s' "${ci_status_output}" | sed -n 's/^CI run conclusion: //p' | tail -n1)"
  [[ -z "${ci_run_status}" ]] && ci_run_status="unknown"
  [[ -z "${ci_run_conclusion}" ]] && ci_run_conclusion="pending"
elif [[ ${ci_status_code} -eq 126 ]]; then
  ci_run_status="status unavailable (gh auth missing)"
  ci_run_conclusion="unknown"
elif [[ ${ci_status_code} -eq 127 ]]; then
  ci_run_status="status unavailable (gh CLI missing)"
  ci_run_conclusion="unknown"
fi

if [[ "${validation_status}" == "blocked (flutter/fvm missing)" ]]; then
  echo "[idlewatch-ios] Local Flutter runtime unavailable; attempting GitHub iOS smoke CI trigger..."
  set +e
  ci_output="$(${CI_TRIGGER_SCRIPT} main 2>&1)"
  ci_code=$?
  set -e
  printf '%s\n' "${ci_output}"

  if [[ ${ci_code} -eq 0 ]]; then
    ci_run_url="$(printf '%s' "${ci_output}" | sed -n 's/^Triggered iOS smoke CI run: //p' | tail -n1)"
    ci_run_status="$(printf '%s' "${ci_output}" | sed -n 's/^CI run status: //p' | tail -n1)"
    ci_run_conclusion="$(printf '%s' "${ci_output}" | sed -n 's/^CI run conclusion: //p' | tail -n1)"
    [[ -z "${ci_run_status}" ]] && ci_run_status="queued"
    [[ -z "${ci_run_conclusion}" ]] && ci_run_conclusion="pending"
  elif [[ ${ci_code} -eq 126 ]]; then
    ci_run_status="not triggered (gh auth missing)"
    ci_run_conclusion="not triggered"
  elif [[ ${ci_code} -eq 127 ]]; then
    ci_run_status="not triggered (gh CLI missing)"
    ci_run_conclusion="not triggered"
  else
    ci_run_status="trigger failed"
    ci_run_conclusion="unknown"
  fi
fi

{
  echo
  echo "## Auto-captured preflight"
  echo "- Generated: ${timestamp}"
  echo "- Flutter command: ${flutter_cmd:-not available}"
  echo "- Flutter version: ${flutter_version}"
  echo "- iOS host preflight status: ${preflight_status}"
  if [[ -n "${preflight_log}" ]]; then
    echo "- iOS host preflight log: ${preflight_log}"
  else
    echo "- iOS host preflight log: (not found)"
  fi
  echo "- Runtime validation status: ${validation_status}"
  if [[ -n "${validation_log}" ]]; then
    echo "- Runtime validation log: ${validation_log}"
  else
    echo "- Runtime validation log: (not found)"
  fi
  echo "- GitHub iOS smoke CI trigger status: ${ci_run_status}"
  echo "- GitHub iOS smoke CI conclusion: ${ci_run_conclusion}"
  if [[ -n "${ci_run_url}" ]]; then
    echo "- GitHub iOS smoke CI run: ${ci_run_url}"
  fi
  echo "- Workflow helper: scripts/run_ios_smoke_workflow.sh"
  echo
  if [[ "${validation_status}" != "pass" ]]; then
    echo "> Next step: run this same script on a Flutter-enabled macOS host with iOS simulator/device access."
  fi
} >> "${report_path}"

echo "[idlewatch-ios] Linking artifacts into QA log..."
set +e
link_output="$(${LINK_SCRIPT} "${report_path}" "${validation_status}" "${validation_log}" "${preflight_status}" "${preflight_log}" "${ci_run_status}" "${ci_run_url}" "${ci_run_conclusion}" 2>&1)"
link_code=$?
set -e
printf '%s\n' "${link_output}"
if [[ ${link_code} -ne 0 ]]; then
  echo "[idlewatch-ios] Warning: failed to auto-link artifacts into QA log." >&2
  echo "[idlewatch-ios] Manual fallback: ${LINK_SCRIPT} \"${report_path}\" \"${validation_status}\" \"${validation_log}\" \"${preflight_status}\" \"${preflight_log}\" \"${ci_run_status}\" \"${ci_run_url}\" \"${ci_run_conclusion}\"" >&2
fi

echo "[idlewatch-ios] Smoke workflow complete."
echo "[idlewatch-ios] Report: ${report_path}"
if [[ -n "${validation_log}" ]]; then
  echo "[idlewatch-ios] Validation log: ${validation_log}"
fi

if [[ ${validation_code} -ne 0 ]]; then
  if [[ ${validation_code} -eq 127 ]]; then
    echo "[idlewatch-ios] Validation blocked by missing Flutter runtime; returning success for evidence-only cycle."
    exit 0
  fi
  exit ${validation_code}
fi

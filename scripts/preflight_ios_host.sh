#!/usr/bin/env bash
set -euo pipefail

# iOS smoke-run host readiness preflight.
# Writes a timestamped preflight log and prints summary lines to stdout.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="${ROOT_DIR}/docs/qa/artifacts"
LOG_FILE="${ARTIFACT_DIR}/ios-host-preflight-$(date +%Y%m%d-%H%M%S).log"
RESOLVE_SCRIPT="${ROOT_DIR}/scripts/resolve_flutter_cmd.sh"

mkdir -p "${ARTIFACT_DIR}"

status_ok=0

check_cmd() {
  local label="$1"
  local cmd="$2"
  if command -v "$cmd" >/dev/null 2>&1; then
    echo "[ok] ${label}: $(command -v "$cmd")" | tee -a "${LOG_FILE}"
  else
    echo "[missing] ${label}: ${cmd} not found" | tee -a "${LOG_FILE}"
    status_ok=1
  fi
}

{
  echo "[idlewatch-ios] iOS host preflight started: $(date)"
  echo "[idlewatch-ios] Repo: ${ROOT_DIR}"
  echo
} | tee -a "${LOG_FILE}"

flutter_cmd="$(${RESOLVE_SCRIPT} 2>/dev/null || true)"
if [[ -n "${flutter_cmd}" ]]; then
  echo "[ok] Flutter command: ${flutter_cmd}" | tee -a "${LOG_FILE}"
  (eval "${flutter_cmd} --version" | head -n1) 2>/dev/null | sed 's/^/[info] /' | tee -a "${LOG_FILE}" || true
else
  echo "[missing] Flutter command: neither 'flutter' nor 'fvm flutter' is available" | tee -a "${LOG_FILE}"
  status_ok=1
fi

check_cmd "Xcode CLI" xcodebuild
check_cmd "iOS simulator control" xcrun

if command -v xcrun >/dev/null 2>&1; then
  if xcrun simctl list devices available >/dev/null 2>&1; then
    echo "[ok] iOS simulator devices: available" | tee -a "${LOG_FILE}"
  else
    echo "[missing] iOS simulator devices: no available devices reported by simctl" | tee -a "${LOG_FILE}"
    status_ok=1
  fi
fi

check_cmd "CocoaPods" pod

if [[ ${status_ok} -ne 0 ]]; then
  {
    echo
    echo "[idlewatch-ios] Suggested remediation (macOS):"
    if [[ -z "${flutter_cmd}" ]]; then
      echo "- Install Flutter SDK: brew install --cask flutter"
      echo "- OR install FVM + Flutter channel: brew tap leoafarias/fvm && brew install fvm && fvm install stable && fvm global stable"
    fi
    if ! command -v pod >/dev/null 2>&1; then
      echo "- Install CocoaPods: sudo gem install cocoapods"
      echo "  (or: brew install cocoapods)"
    fi
    if ! command -v xcodebuild >/dev/null 2>&1 || ! command -v xcrun >/dev/null 2>&1; then
      echo "- Install/finish Xcode tools: xcode-select --install"
      echo "- If needed, accept Xcode license: sudo xcodebuild -license accept"
    fi
    echo "- Re-run preflight: scripts/preflight_ios_host.sh"
  } | tee -a "${LOG_FILE}"
fi

{
  echo
  echo "[idlewatch-ios] iOS host preflight finished: $(date)"
  echo "[idlewatch-ios] Readiness: $( [[ ${status_ok} -eq 0 ]] && echo ready || echo blocked )"
} | tee -a "${LOG_FILE}"

echo "Preflight readiness: $( [[ ${status_ok} -eq 0 ]] && echo ready || echo blocked )"
echo "Saved iOS host preflight log to: ${LOG_FILE}"

exit ${status_ok}

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

log_simulator_inventory() {
  if ! command -v xcrun >/dev/null 2>&1; then
    echo "[info] iOS simulator inventory: unavailable (xcrun not found)" | tee -a "${LOG_FILE}"
    return
  fi

  local simulator_block
  local line
  local selected_candidate=""
  local candidate_line=""
  local selected_rank=999
  local i=0

  # Preference list from lower-to-higher expected load profile.
  local -a preferred_models=(
    "iPhone SE"
    "iPhone 8"
    "iPhone 8 Plus"
    "iPhone X"
    "iPhone XR"
    "iPhone XS"
    "iPhone 11"
    "iPhone 12"
    "iPhone 13"
    "iPhone 14"
    "iPhone 15"
    "iPhone 16e"
    "iPhone Air"
    "iPhone 16"
    "iPhone 17"
  )

  # shellcheck disable=SC2207
  simulator_block="$(xcrun simctl list devices available | sed -n '/-- iOS /,/^-- watchOS /p')"

  while IFS= read -r line; do
    if [[ ! "$line" =~ ^[[:space:]]*iPhone ]]; then
      continue
    fi

    if [[ "$line" =~ ^[[:space:]]*(iPhone[^\(]+)\ \(([0-9A-Fa-f-]+)\)\ \(([^\)]*)\)[[:space:]]*$ ]]; then
      local name="${BASH_REMATCH[1]}"
      local udid="${BASH_REMATCH[2]}"
      local state="${BASH_REMATCH[3]}"
      echo "[sim] ${name} | ${udid} | ${state}" | tee -a "${LOG_FILE}"

      local rank=999
      local idx
      for idx in "${!preferred_models[@]}"; do
        if [[ "$name" == *"${preferred_models[$idx]}"* ]]; then
          rank=$((idx + 1))
          break
        fi
      done

      if [[ -z "$selected_candidate" && "$rank" -lt 999 ]]; then
        selected_candidate="$name"
        selected_rank=$rank
        candidate_line="$name | ${udid} | ${state}"
      elif [[ "$rank" -lt "$selected_rank" ]]; then
        selected_candidate="$name"
        selected_rank=$rank
        candidate_line="$name | ${udid} | ${state}"
      fi

      i=$((i + 1))
    fi
  done <<< "${simulator_block}"

  if [[ "$i" -gt 0 ]]; then
    echo "[info] Total available iOS simulators listed: ${i}" | tee -a "${LOG_FILE}"
  else
    echo "[missing] No iPhone simulators found in simctl output" | tee -a "${LOG_FILE}"
    status_ok=1
    return
  fi

  if [[ -n "$selected_candidate" ]]; then
    echo "[info] Lower-envelope candidate for perf capture: ${candidate_line}" | tee -a "${LOG_FILE}"
  else
    echo "[info] Lower-envelope candidate for perf capture: not detected from available models" | tee -a "${LOG_FILE}"
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
  if [[ "${IDLEWATCH_PRECHECK_FLUTTER_VERSION:-0}" == "1" ]]; then
    (eval "${flutter_cmd} --version" | head -n1) 2>/dev/null | sed 's/^/[info] /' | tee -a "${LOG_FILE}" || true
  else
    echo "[info] Flutter version capture skipped to reduce CLI memory footprint." | tee -a "${LOG_FILE}"
  fi
else
  echo "[missing] Flutter command: neither 'flutter' nor 'fvm flutter' is available" | tee -a "${LOG_FILE}"
  status_ok=1
fi

check_cmd "Xcode CLI" xcodebuild
check_cmd "iOS simulator control" xcrun

if command -v xcrun >/dev/null 2>&1; then
  if xcrun simctl list devices available >/dev/null 2>&1; then
    echo "[ok] iOS simulator devices: available" | tee -a "${LOG_FILE}"
    log_simulator_inventory
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

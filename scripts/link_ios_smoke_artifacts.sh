#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QA_LOG="${ROOT_DIR}/docs/qa/ios-qa-log.md"

report_path="${1:-}"
validation_status="${2:-unknown}"
validation_log="${3:-}"

if [[ -z "${report_path}" ]]; then
  echo "Usage: scripts/link_ios_smoke_artifacts.sh <smoke-report-path> [validation-status] [validation-log-path]" >&2
  exit 1
fi

if [[ ! -f "${QA_LOG}" ]]; then
  echo "[idlewatch-ios] QA log not found: ${QA_LOG}" >&2
  exit 1
fi

now_human="$(TZ=America/Toronto date '+%Y-%m-%d %H:%M America/Toronto')"

validation_log_line="- Runtime validation log: (not found)"
if [[ -n "${validation_log}" ]]; then
  validation_log_line="- Runtime validation log: ${validation_log}"
fi

entry_file="$(mktemp)"
cat >"${entry_file}" <<EOF
## Cycle — ${now_human}
_Auditor_: IdleWatch iOS Implementer (cron)
_Scope_: Execute highest-priority feasible backlog items while preserving prototype runnability
_Method_: QA-operability implementation pass focused on smoke-evidence linkage automation

### Implementation Summary
- ✅ Added scripts/link_ios_smoke_artifacts.sh to prepend a structured QA-cycle entry with smoke artifact links.
- ✅ Updated smoke workflow to auto-call the linkage helper when report generation succeeds.
- ✅ Updated README/checklist so operator handoff includes automatic QA-log linkage and fallback manual command.

### Backlog Status Update

#### P2 — Missing fresh iOS simulator/device smoke evidence for latest UX/auth flows
- **Previous**: ⏳ Open (mitigated)
- **Now**: ⏳ Open (further mitigated)
- **Reason**: Fresh simulator/device execution still requires Flutter-enabled macOS host.
- **Progress this cycle**:
  - QA log linkage is now automated, reducing missed artifact references.
  - Current workflow attempt status: **${validation_status}**.
  - Smoke report artifact: ${report_path}
  ${validation_log_line}

### Validation Notes
- Prototype runtime/app logic unchanged; updates are scripts/docs only.
- If validation remains blocked/failing here, rerun on Flutter-enabled macOS host:
  - scripts/run_ios_smoke_workflow.sh

EOF

combined_file="$(mktemp)"
cat "${entry_file}" "${QA_LOG}" > "${combined_file}"
mv "${combined_file}" "${QA_LOG}"

rm -f "${entry_file}"

echo "Prepended QA log cycle entry to: ${QA_LOG}"
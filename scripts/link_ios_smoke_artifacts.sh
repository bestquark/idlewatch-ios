#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QA_LOG="${ROOT_DIR}/docs/qa/ios-qa-log.md"

report_path="${1:-}"
validation_status="${2:-unknown}"
validation_log="${3:-}"
preflight_status="${4:-unknown}"
preflight_log="${5:-}"
ci_trigger_status="${6:-not triggered}"
ci_run_url="${7:-}"
ci_run_conclusion="${8:-pending}"

if [[ -z "${report_path}" ]]; then
  echo "Usage: scripts/link_ios_smoke_artifacts.sh <smoke-report-path> [validation-status] [validation-log-path] [preflight-status] [preflight-log-path] [ci-trigger-status] [ci-run-url] [ci-run-conclusion]" >&2
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

preflight_log_line="- iOS host preflight log: (not found)"
if [[ -n "${preflight_log}" ]]; then
  preflight_log_line="- iOS host preflight log: ${preflight_log}"
fi

ci_run_line="- GitHub iOS smoke CI run: (not captured)"
if [[ -n "${ci_run_url}" ]]; then
  ci_run_line="- GitHub iOS smoke CI run: ${ci_run_url}"
fi

p1_now="⏳ Open"
p1_note="First green GitHub iOS Smoke run on main is still pending."
p2_now="⏳ Open (blocked on P1 closure)"
p2_reason="Shared CI-backed UX/auth/onboarding/performance evidence is still blocked by missing green CI closure."

if [[ "${ci_run_conclusion}" == "success" ]]; then
  p1_now="✅ Closed"
  p1_note="Green GitHub iOS Smoke run on main captured; release gate restored."
  p2_now="⏳ Open (unblocked; evidence expansion pending)"
  p2_reason="CI baseline is now green; next pass should expand smoke notes for onboarding/auth retry and first-render responsiveness."
fi

entry_file="$(mktemp)"
cat >"${entry_file}" <<EOF
## Cycle — ${now_human}
_Auditor_: IdleWatch iOS Implementer (cron)
_Scope_: Execute highest-priority feasible backlog items while preserving prototype runnability
_Method_: Runtime-smoke evidence refresh pass using existing automation workflow

### Implementation Summary
- ✅ Executed iOS smoke workflow/report automation for this cycle.
- ✅ Synced latest GitHub iOS smoke CI metadata into QA evidence.
- ✅ Kept prototype runtime/app logic unchanged (ops/docs evidence pass only).

### Prioritized Issues (with Acceptance Criteria)

#### P1 — Remote iOS smoke CI closure pending after scaffolding/workflow hardening
- **Previous**: ⏳ Open
- **Now**: ${p1_now}
- **Status note**: ${p1_note}
- **Evidence this cycle**:
  - GitHub iOS smoke CI trigger/status: **${ci_trigger_status}**.
  - GitHub iOS smoke CI conclusion: **${ci_run_conclusion}**.
  ${ci_run_line}
- **Acceptance criteria**:
  - First green GitHub iOS Smoke run on main is recorded in QA log as closure evidence.

#### P2 — Missing fresh CI-backed UX/auth/onboarding/performance runtime evidence
- **Previous**: ⏳ Open
- **Now**: ${p2_now}
- **Reason**: ${p2_reason}
- **Progress this cycle**:
  - Current iOS host preflight status: **${preflight_status}**.
  - Current workflow attempt status: **${validation_status}**.
  - Smoke report artifact: ${report_path}
  ${preflight_log_line}
  ${validation_log_line}
  ${ci_run_line}

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

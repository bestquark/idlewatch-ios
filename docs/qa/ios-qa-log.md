# IdleWatch iOS QA Log

## Cycle — 2026-02-16 16:49 America/Toronto
_Auditor_: QA Lead (subagent)
_Scope_: 24h activity pie chart behavior QA (normalization to 24h, idle remainder, empty/error states, label readability)
_Method_: Static code review of `lib/main.dart` on `main` @ `17ce8b9` + repository sanity checks. Local Flutter runtime validation unavailable in this environment (`flutter` CLI missing).

### Executive Summary
The requested **24h activity pie chart implementation is not present** in the current iOS codebase. The app currently renders:
- a CPU/Memory **line chart** (`LineChart`) only,
- existing stream error state (`snapshot.hasError`), and
- existing no-data empty state (`docs.isEmpty`).

Because no pie chart code/path exists in `lib/main.dart` (the only Dart source file), the specific 24h pie-chart behaviors cannot be functionally validated yet. This cycle is therefore recorded as a **blocked QA pass** with implementation-gating acceptance criteria below.

### 24h Activity Pie QA Findings (Current Branch)

#### 1) Totals normalization to 24h
- **Status**: ❌ Not implemented / blocked
- **Finding**: No aggregation/model exists for 24h bucket totals. No code computes or enforces `active + idle == 24h`.
- **Risk**: Future pie chart may over/under-count intervals unless explicit normalization logic is added.
- **Acceptance criteria (must pass)**:
  - Build a deterministic 24h window anchored to a clear reference (e.g., `now` local/UTC, documented).
  - Sum category durations from samples/events within that window.
  - If summed non-idle exceeds 24h due to overlap/duplication, normalize with a deterministic rule and log/debug-surface the correction.
  - Final displayed total must equal exactly 24h (within small floating tolerance before formatting).

#### 2) Idle remainder behavior
- **Status**: ❌ Not implemented / blocked
- **Finding**: No pie sections or remainder logic exists.
- **Risk**: Users may see incomplete ring or misleading percentages if idle remainder is not explicitly synthesized.
- **Acceptance criteria (must pass)**:
  - Compute `idleRemainder = max(0, 24h - sum(nonIdleDurations))`.
  - Render idle slice whenever remainder > 0.
  - If `sum(nonIdleDurations) == 0`, show full 24h idle slice (not blank chart).
  - Never render negative-duration slices.

#### 3) Empty/error states for pie module
- **Status**: ⚠️ Partially covered globally; pie-specific state not implemented
- **Finding**:
  - Global states exist today:
    - `snapshot.hasError` → `_ErrorState`
    - no docs → `_EmptyState`
  - No pie-specific fallback messaging exists because pie widget/path is absent.
- **Acceptance criteria (must pass)**:
  - If 24h computation yields no valid activity samples, show explicit “No activity in last 24h” state with timestamp context.
  - If data is malformed for pie computation, show non-fatal warning and continue rendering recoverable slices.
  - Preserve existing global stream error UI for hard failures.

#### 4) Label readability
- **Status**: ❌ Not implemented / blocked
- **Finding**: No pie labels/legend for activity categories currently exist.
- **Acceptance criteria (must pass)**:
  - Labels must remain legible on compact widths (iPhone SE class) without overlap/clipping.
  - Prefer concise labels + percent (or duration), with long labels moved to legend.
  - Ensure color contrast meets dark-theme readability expectations.
  - Validate with at least: small phone width and large phone width.

### Validation Notes
- Repo search and review confirm only one Dart app source file (`lib/main.dart`) and no pie-chart activity module.
- `fl_chart` dependency is present, so implementation is technically feasible in current stack.
- Local runtime validation was limited to static review because Flutter SDK is unavailable in this execution environment.

### QA Verdict for Requested Feature
- **Result**: ❌ **Not passable yet** (feature not present on current `main`)
- **Gate**: Re-run QA immediately after the 24h activity pie implementation lands.

---

## Cycle — 2026-02-16 16:42 America/Toronto
_Auditor_: QA Lead (cron)  
_Scope_: UX, auth, onboarding, performance/readability, multi-device behavior  
_Method_: Static audit of `lib/main.dart` + `README.md` against prior QA backlog

### Executive Summary
The app materially improved since the previous pass:
- ✅ Stream error state now surfaced (`snapshot.hasError`)
- ✅ Empty state added for no-data installs
- ✅ Startup setup flow now has retry action
- ✅ Dashboard readability improved with metric chips + legend + last-update timestamp

Highest remaining risks are now:
1. **P1** Multi-device mixing still produces misleading charts (no host filter/scoping).
2. **P1** Chart still lacks touch tooltips/time axis for precise operational interpretation.
3. **P2** Loading state can spin forever without timeout/escalation/retry.
4. **P2** Runtime data quality is silently coerced to `0` for malformed fields.

---

## Prioritized Open Issues

### P1 — Metrics from multiple hosts are still mixed into one timeline
- **Area**: UX / data correctness / multi-device
- **Impact**: Interleaved host documents are plotted as a single sequence, which can imply fake spikes/drops.
- **Evidence**: Query is global (`collection('metrics').orderBy('ts').limit(120)`) with no host filter.
- **Repro**:
  1. Insert docs for `host=A` and `host=B` with overlapping timestamps.
  2. Open dashboard.
- **Current result**: One CPU line + one Memory line from combined hosts.
- **Expected result**: Host-aware view (single-host scoped query or per-host split series).
- **Acceptance criteria**:
  - Add host selector (persist last selected host).
  - Scope query to selected host **or** render distinct per-host series + legend.
  - Show active host context clearly in UI.

### P1 — Chart lacks precise reading affordances (timestamp/value at point)
- **Area**: UX / observability
- **Impact**: Users can see trends, but cannot reliably answer “what exact value/when?”.
- **Evidence**: Legend exists; left axis exists; bottom axis titles and touch tooltips are absent.
- **Repro**:
  1. Load 100+ points with known spikes.
  2. Try to identify exact spike timestamp/value.
- **Current result**: Approximate visual read only.
- **Expected result**: Fast exact read from interaction.
- **Acceptance criteria**:
  - Enable touch tooltip for CPU/memory point values.
  - Add bottom axis labeling (relative time or sampled timestamps).
  - Keep labels performant/readable on narrow iPhone widths.

### P2 — Loading state has no timeout or recovery path
- **Area**: UX / resilience
- **Impact**: Infinite spinner when data stream stalls can look like app freeze.
- **Evidence**: `!snapshot.hasData` returns bare `CircularProgressIndicator()` with no elapsed-state transition.
- **Repro**:
  1. Simulate very slow/blocked Firestore stream.
  2. Wait >30s.
- **Current result**: Continuous spinner, no guidance.
- **Expected result**: Progressive recovery messaging and retry affordance.
- **Acceptance criteria**:
  - After ~10s: show “Still connecting…” helper text.
  - After ~30s: show retry action + troubleshooting hint.

### P2 — Malformed data silently renders as `0` (masking telemetry quality issues)
- **Area**: Data integrity / UX trust
- **Impact**: Bad payloads appear as real zero usage, hiding ingestion/schema defects.
- **Evidence**: `_asDouble` returns `0` for non-`num` values.
- **Repro**:
  1. Write docs with `cpuPct: "n/a"` or missing fields.
  2. Observe chart/chips.
- **Current result**: Values plot as `0` without warning.
- **Expected result**: Invalid points are omitted/flagged.
- **Acceptance criteria**:
  - Treat invalid numeric fields as `null` and skip plotting point.
  - Surface non-blocking warning if recent samples were dropped due to invalid schema.

---

## Resolved Since Previous Cycle

### ✅ Stream error visibility (previously P0)
- `StreamBuilder` now handles `snapshot.hasError` and shows `_ErrorState` with permission guidance.
- **Follow-up**: Optional retry CTA could further improve recovery, but core visibility issue is fixed.

### ✅ Empty-state UX (previously P1)
- `_EmptyState` now provides clear onboarding hint when no metrics exist.

### ✅ Startup setup retry (previously P2)
- `SetupErrorPage` now includes `Retry setup` and `AppBootstrapPage` re-initialization path.

### ✅ Baseline chart readability improvements (partial from previous P1)
- Added legend, metric summary chips, and last-update timestamp.
- Remaining gap is precision interaction/time-axis labeling (tracked above).

---

## Recommended Next QA Pass (after fixes)
- Validate host filter behavior with 3 interleaved hosts.
- Verify tooltip readability on iPhone SE + iPhone Pro Max.
- Add widget tests for: `error`, `empty`, `loading-timeout`, and `invalid-data` branches.

---

## Cycle — 2026-02-16 16:56 America/Toronto
_Auditor_: IdleWatch iOS Implementer (cron)
_Scope_: Execute highest-priority feasible backlog items while preserving prototype runnability
_Method_: Implementation pass in `lib/main.dart` + static verification (local Flutter/Dart CLI unavailable)

### Implementation Summary
Delivered the top feasible backlog items from the previous QA cycle:

- ✅ **P1 resolved** — Added **host-scoped dashboard view** to stop multi-device metric mixing.
  - Introduced host selector (`_HostSelector`) populated from recent metric docs.
  - Dashboard now filters the plotted series to the selected host.
  - Active host context is shown in “Last update (host)” text.

- ✅ **P1 resolved** — Added **precise chart reading affordances**.
  - Enabled line-chart touch tooltips showing timestamp + CPU/MEM values.
  - Added bottom-axis time labels (start / midpoint / end) derived from sample timestamps.

- ✅ **P2 partially resolved early** — Improved malformed data handling for chart integrity.
  - Invalid CPU/MEM values are now skipped instead of coerced to zero.
  - Added non-blocking warning text indicating dropped malformed samples.

### Backlog Status Update

#### P1 — Metrics from multiple hosts are mixed into one timeline
- **Previous**: Open
- **Now**: ✅ Resolved
- **Notes**: Filtering is host-scoped in UI. Persistence of selected host across app restarts is not yet implemented.

#### P1 — Chart lacks precise reading affordances
- **Previous**: Open
- **Now**: ✅ Resolved
- **Notes**: Tooltips + time-axis labels implemented with compact formatting for narrow screens.

#### P2 — Malformed data silently renders as `0`
- **Previous**: Open
- **Now**: ✅ Resolved (for chart series)
- **Notes**: Line chart now drops invalid points and surfaces a warning count. Metric chips still read latest raw values and may show `0` for invalid latest sample fields.

#### P2 — Loading state has no timeout/recovery path
- **Previous**: Open
- **Now**: ⏳ Open
- **Reason**: Deferred to keep this cycle focused on highest-priority P1 items and maintain stability.

### Validation Notes
- Static review completed; no runtime smoke test executed because `dart`/`flutter` CLIs are unavailable in this environment.
- Prototype structure remains single-file Flutter app (`lib/main.dart`) and should remain runnable once dependencies/toolchain are available locally.

### Suggested Next Cycle
1. Add progressive loading timeout UX (10s helper, 30s retry/troubleshooting CTA).
2. Persist selected host across app restarts (e.g., shared preferences).
3. Add widget tests for host selector filtering + tooltip/time-axis rendering + invalid-point warnings.

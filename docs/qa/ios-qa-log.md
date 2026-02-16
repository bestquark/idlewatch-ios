# IdleWatch iOS QA Log

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

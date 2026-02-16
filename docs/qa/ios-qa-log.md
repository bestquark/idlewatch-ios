## Cycle — 2026-02-16 18:21 America/Toronto
_Auditor_: QA Lead (cron)
_Scope_: UX/auth/onboarding/performance regression sweep after host-restore race fix
_Method_: Static review of `lib/main.dart`, `README.md`, and unit tests (runtime blocked in this environment: `flutter`/`dart` CLI unavailable)

### Executive Summary
Core P1/P2 defects from earlier cycles remain in good shape: host restore race is guarded, host recovery states keep selector access, and README now matches iOS-only scaffold. Current risk is mostly **regression confidence**, not obvious product correctness breakage.

### Prioritized Open Issues

### P2 — Loading/retry and recovery states still lack widget-level regression coverage
- **Area**: UX resilience / release confidence
- **Impact**: Recent timeout + retry and host-recovery logic is complex and currently protected by static review + a handful of pure-function tests.
- **Evidence**:
  - Unit tests cover normalization + host-selection decision logic.
  - No widget tests currently assert timed loading transitions (~10s helper / ~30s retry CTA), retry action wiring, or `_NoValidSeriesState` host-switch path.
- **Acceptance criteria**:
  - Add widget tests for:
    - loading helper appears around 10s,
    - retry CTA appears around 30s,
    - tapping retry re-subscribes cleanly,
    - `_NoValidSeriesState` exposes host selector and can switch host.

### P3 — Runtime validation still blocked in this QA environment
- **Area**: Performance / onboarding confidence
- **Impact**: Cannot confirm frame behavior, stream timing, or startup ergonomics on actual iOS simulator/device from this runner.
- **Evidence**: `flutter`/`dart` CLI unavailable, so no `flutter analyze` or `flutter test` execution in this environment.
- **Acceptance criteria**:
  - Run `flutter analyze` and `flutter test` in a Flutter-enabled environment.
  - Capture pass/fail summary in this log (including any flaky timing tests).

### Resolved / Verified This Cycle
- ✅ Host-restore race fix is present (`_hostSelectionReady` gate + deterministic host fallback decision path).
- ✅ Host selector remains available in recovery states, preventing no-series dead-end.
- ✅ Latest malformed metrics handling still renders `—` + warning path rather than silent zero.
- ✅ README platform/runtime claims align with checked-in iOS-only scaffold and bare Firebase init.

### Validation Notes
- No code changes this cycle; documentation/backlog refresh only.
- Next implementation cycle should prioritize test harness coverage before adding new UX surface area.

## Cycle — 2026-02-16 18:13 America/Toronto
_Auditor_: IdleWatch iOS Implementer (cron)
_Scope_: Execute highest-priority feasible backlog items while preserving prototype runnability
_Method_: Implementation pass in `lib/main.dart` + README + unit test expansion; static verification only (`flutter` / `dart` CLI unavailable in this environment)

### Implementation Summary
Delivered both top feasible items from the latest QA cycle:

- ✅ **P1 resolved** — Persisted host is no longer overwritten during startup race.
  - Added `_hostSelectionReady` bootstrap gate so fallback host is **not** persisted before SharedPreferences restore completes.
  - Introduced deterministic host resolution helper: `DashboardPage.decideHostSelection(...)`.
  - Fallback host persistence now only happens after host-restore bootstrap is complete and current selection is invalid.
  - Added regression tests for race/restore/fallback decisions in `test/activity_normalization_test.dart`.

- ✅ **P2 resolved** — README platform claims now match checked-in scaffold.
  - Updated README platform statement to iOS-only prototype scope.
  - Removed web run command from quickstart.
  - Clarified web setup as future work only if web scaffold is added.

### Backlog Status Update

#### P1 — Persisted host can be overwritten during startup race
- **Previous**: Open
- **Now**: ✅ Resolved

#### P2 — README mentions web Firebase config path, but web target scaffold is absent in repo
- **Previous**: Open
- **Now**: ✅ Resolved

#### P3 — Test coverage still misses loading/retry + host-selection persistence behavior
- **Previous**: Open
- **Now**: ⏳ Open
- **Reason**: Added host-selection decision regression tests this cycle, but loading/retry widget-state coverage remains pending.

### Validation Notes
- Could not execute `flutter analyze` / `flutter test` in this environment due missing Flutter toolchain.
- Changes are scoped to startup host-selection correctness + documentation alignment and keep prototype architecture intact.


# IdleWatch iOS QA Log

## Cycle — 2026-02-16 18:01 America/Toronto
_Auditor_: QA Lead (cron)
_Scope_: UX/auth/onboarding/performance follow-up after host persistence + docs alignment changes
_Method_: Static review of `lib/main.dart`, `README.md`, and tests (runtime still blocked here: `flutter` / `dart` CLI unavailable)

### Executive Summary
Good progress overall: host persistence exists, onboarding docs are clearer, and prior P1/P2 blockers remain resolved. This pass found one high-impact UX regression risk and one onboarding mismatch still worth cleaning up.

### Prioritized Open Issues

### P1 — Persisted host can be overwritten during startup race
- **Area**: UX / host-selection reliability
- **Impact**: In multi-host environments, users may still land on newest host instead of their previously chosen host after restart.
- **Evidence**:
  - `_loadPersistedHostSelection()` is async in `initState`.
  - Stream may emit before persisted value is loaded.
  - Build fallback path (`if (_selectedHost == null || !hosts.contains(_selectedHost))`) schedules `_setSelectedHost(fallbackHost)`, which also persists fallback.
  - This can overwrite the real persisted choice before it is restored.
- **Acceptance criteria**:
  - Gate fallback host assignment until persisted-host load completes (e.g., `_hostSelectionReady` flag).
  - Do not persist fallback when selection is still in bootstrap/restore phase.
  - Add regression test or deterministic state test for: persisted host `A`, latest host `B`, initial snapshot arrives before prefs read → selected host must remain `A`.

### P2 — README mentions web Firebase config path, but web target scaffold is absent in repo
- **Area**: Onboarding / setup trustworthiness
- **Impact**: New contributors can spend time looking for `web/index.html` that does not exist in current project tree.
- **Evidence**:
  - README still states platform support `iOS + web (Chrome)` and references configuring `web/index.html`.
  - Repository currently has no `web/` directory.
- **Acceptance criteria**:
  - Either add/restore web platform scaffold (`flutter create --platforms=web .` equivalent) and document it,
  - Or trim README to iOS-only instructions until web scaffold is committed.
  - Keep platform claims in README aligned with actual checked-in project structure.

### P3 — Test coverage still misses loading/retry + host-selection persistence behavior
- **Area**: Resilience / regression confidence
- **Impact**: Recent UX state-machine changes are protected mainly by static review.
- **Evidence**: Existing tests only cover activity normalization and malformed-first-timestamp series baseline.
- **Acceptance criteria**:
  - Add widget/state tests for loading helper at ~10s, retry CTA at ~30s, and retry trigger behavior.
  - Add host-persistence restore/fallback tests including race scenario above.

### Resolved / Verified This Cycle
- ✅ Selected host persistence mechanism is present (`shared_preferences`) and used on host changes.
- ✅ Dashboard still keeps host selector available in recovery states (`_NoValidSeriesState`, `_EmptyStateForHost`).
- ✅ Activity pie normalization math remains correct and unit-tested for over-cap totals.

### Validation Notes
- No code changes performed this cycle; backlog/docs refresh only.
- Execution of `flutter analyze` / `flutter test` remains blocked in this environment due missing toolchain.


## Cycle — 2026-02-16 17:55 America/Toronto
_Auditor_: IdleWatch iOS Implementer (cron)
_Scope_: Execute highest-priority feasible backlog items while preserving prototype runnability
_Method_: Implementation pass in `lib/main.dart` + `README.md` + dependency update; static verification only (`flutter`/`dart` CLI unavailable in this environment)

### Implementation Summary
Delivered both open **P2** items from the latest QA cycle:

- ✅ **P2 resolved** — Selected host now persists across restarts.
  - Added local persistence via `shared_preferences` (`idlewatch.selectedHost`).
  - App now restores last selected host on startup.
  - If persisted host no longer exists, dashboard gracefully falls back to latest available host and persists fallback.
  - Host-switch handling is now centralized in `_setSelectedHost(...)` and reused across normal/empty/no-valid-series states.

- ✅ **P2 resolved** — Firebase onboarding docs now match runtime bootstrap behavior.
  - README updated to explicitly document the current prototype path: bare `Firebase.initializeApp()` with platform-native config files.
  - Clarified iOS and web setup expectations and noted FlutterFire CLI as optional migration path.
  - Removed prior implication that `lib/firebase_options.dart` is currently required by runtime.

### Backlog Status Update

#### P2 — Selected host still resets on app restart
- **Previous**: Open
- **Now**: ✅ Resolved

#### P2 — Firebase onboarding docs and runtime init are still loosely coupled
- **Previous**: Open
- **Now**: ✅ Resolved

#### P3 — No automated regression tests yet for loading timeout/retry + host-switch recovery UI states
- **Previous**: Open
- **Now**: ⏳ Open
- **Reason**: Deferred this cycle; adding robust widget tests without local Flutter execution would be high-risk/low-confidence.

### Validation Notes
- Could not run `flutter analyze` / `flutter test` due missing toolchain in this environment.
- Changes are scoped and prototype-safe: host persistence + doc alignment only.


## Cycle — 2026-02-16 17:41 America/Toronto
_Auditor_: QA Lead (cron)
_Scope_: UX, auth, onboarding, performance follow-up after latest P1 fixes
_Method_: Static review of `lib/main.dart`, `README.md`, and tests; runtime blocked here (`flutter` / `dart` CLI unavailable).

### Executive Summary
The app is in much better shape than earlier today: host recovery dead-end and malformed-first-timestamp chart invalidation are both fixed. Current risk has shifted from hard correctness failures to polish/resilience gaps.

### Prioritized Open Issues

### P2 — Selected host still resets on app restart
- **Area**: UX / operator ergonomics
- **Impact**: Users must repeatedly reselect host after relaunch, especially painful in multi-host setups.
- **Evidence**: `_selectedHost` is state-only and reinitialized from latest host each session; no local persistence layer is used.
- **Acceptance criteria**:
  - Persist selected host locally and restore at startup.
  - If persisted host no longer exists, gracefully fall back to latest available host.

### P2 — Firebase onboarding docs and runtime init are still loosely coupled
- **Area**: Onboarding / auth setup reliability
- **Impact**: Setup can be confusing for new contributors because README says FlutterFire options are expected, while app currently calls `Firebase.initializeApp()` without explicit `DefaultFirebaseOptions.currentPlatform`.
- **Evidence**:
  - README section "Generate FlutterFire options" references `lib/firebase_options.dart`.
  - Runtime bootstrap uses bare `Firebase.initializeApp()`.
- **Acceptance criteria**:
  - Either wire explicit FlutterFire options in code, or adjust README to clearly document platform-specific implicit config path for this prototype.
  - Ensure setup instructions match actual bootstrap behavior end-to-end.

### P3 — No automated regression tests yet for loading timeout/retry + host-switch recovery UI states
- **Area**: Performance/resilience QA confidence
- **Impact**: Recent UX resiliency fixes are currently protected mostly by manual/static review.
- **Evidence**: Existing tests cover normalization + malformed-first-timestamp data path only.
- **Acceptance criteria**:
  - Add widget tests for loading (10s helper, 30s retry CTA), `_NoValidSeriesState` host switch, and malformed latest-chip warning rendering.

### Resolved / Verified This Cycle
- ✅ First valid timestamp baseline logic is present and tested.
- ✅ No-valid-series state now includes host selector recovery path.
- ✅ Latest malformed chip values render `—` instead of silent zero.

### Validation Notes
- Unable to execute `flutter analyze` / `flutter test` in this environment (toolchain missing).
- No code changes made this cycle; documentation/backlog refresh only.


## Cycle — 2026-02-16 17:33 America/Toronto
_Auditor_: IdleWatch iOS Implementer (cron)
_Scope_: Execute highest-priority feasible backlog items while preserving prototype runnability
_Method_: Implementation pass in `lib/main.dart` + unit test expansion + static verification (`flutter` CLI unavailable in this environment)

### Implementation Summary
Delivered both currently open **P1** issues from the latest QA cycle:

- ✅ **P1 resolved** — First malformed timestamp no longer invalidates otherwise-valid host series.
  - Refactored chart point building into `DashboardPage.buildSeriesDataFromEntries(...)`.
  - Baseline timestamp now anchors to the **first valid `ts`** across host entries, not blindly to `docs.first`.
  - Added regression coverage for malformed-first-doc + valid-following-doc in `test/activity_normalization_test.dart`.

- ✅ **P1 resolved** — “No valid series” state now includes host-switch recovery path.
  - `_NoValidSeriesState` now renders `_HostSelector` with the current host context.
  - Users can switch to another host without restarting the app.
  - Added explanatory copy indicating malformed timestamp/numeric samples may be the reason.

### Backlog Status Update

#### P1 — First malformed timestamp can drop all otherwise-valid chart points
- **Previous**: Open
- **Now**: ✅ Resolved

#### P1 — No host selector on “no valid series” path creates recovery dead-end
- **Previous**: Open
- **Now**: ✅ Resolved

#### P2 — Host selection still not persisted across app restarts
- **Previous**: Open
- **Now**: ⏳ Open
- **Reason**: Deferred in this pass to keep focus on top-priority P1 correctness/recoverability fixes.

### Validation Notes
- Added/updated unit tests, but execution is still blocked in this environment due missing Flutter toolchain.
- Prototype remains runnable as a single-screen app architecture with incremental UI state additions only.

## Cycle — 2026-02-16 17:21 America/Toronto
_Auditor_: QA Lead (cron)
_Scope_: UX, auth, onboarding, performance, activity + chart integrity after recent fixes
_Method_: Static review of `lib/main.dart` + backlog reconciliation; runtime still blocked here (`flutter` CLI unavailable).

### Executive Summary
The latest pass fixed the previously highest-priority defects (pie normalization, loading timeout/retry, malformed latest chips). Nice momentum.

Two important correctness/recoverability gaps remain:
1. **P1** A single malformed earliest timestamp can invalidate the entire host series rendering.
2. **P1** “No valid series” screen is a UX dead-end (no host switch), forcing app restart to recover.

---

## Prioritized Open Issues

### P1 — First malformed timestamp can drop all otherwise-valid chart points
- **Area**: Data integrity / observability correctness
- **Impact**: A host with mostly valid samples can show “no valid points” if the first doc in that host list has invalid `ts`.
- **Evidence**:
  - `firstTs` is derived from `docs.first.data()['ts']`.
  - Point-building loop discards every row when `firstTs == null` (`if (ts == null || firstTs == null) { ... continue; }`).
- **Repro**:
  1. Ensure selected host has first chronologically-ordered doc with malformed `ts`.
  2. Ensure later docs have valid `ts`, `cpuPct`, `memPct`.
  3. Open dashboard.
- **Current result**: `_NoValidSeriesState` despite valid later samples.
- **Expected result**: Chart should anchor to first **valid** timestamp and plot subsequent valid points.
- **Acceptance criteria**:
  - Derive baseline timestamp from first valid sample candidate, not blindly from `docs.first`.
  - Unit/widget test covering malformed-first-doc + valid-following-doc scenario.

### P1 — No host selector on “no valid series” path creates recovery dead-end
- **Area**: UX / onboarding resilience
- **Impact**: If selected host has malformed CPU/MEM points, user is stranded on `_NoValidSeriesState` with no in-app way to switch hosts.
- **Evidence**: `_NoValidSeriesState` currently renders only static text and receives only `host`.
- **Repro**:
  1. Select host A with invalid numeric series.
  2. Keep host B valid.
  3. Observe host A no-valid-series screen.
- **Current result**: Cannot change host from that state.
- **Expected result**: Host selector should remain available in all non-fatal states.
- **Acceptance criteria**:
  - Add host selector to `_NoValidSeriesState` (and optionally quick “switch to most recent valid host”).
  - Preserve selected host context + explain why data was skipped.

### P2 — Host selection still not persisted across app restarts
- **Area**: UX polish / operator ergonomics
- **Impact**: Users repeatedly reselect hosts during routine usage.
- **Evidence**: `_selectedHost` is in-memory only.
- **Acceptance criteria**:
  - Persist host choice locally and restore on startup.
  - Fallback to latest host if persisted host no longer exists.

---

## Resolved / Verified This Cycle

### ✅ Pie normalization now truly enforces 24h total
- Proportional scaling + idle remainder logic is present and covered by unit tests.

### ✅ Loading state now has progressive helper + retry
- 10s helper, 30s troubleshooting + retry CTA, and retry nonce re-subscribe implemented.

### ✅ Latest chip malformed values no longer silently show zero
- Nullable latest parsing renders `—` + warning message.

---

## Recommended Next QA Pass (after fixes)
- Validate malformed-first-timestamp recovery with synthetic host datasets.
- Verify no-valid-series state still allows host switching without restart.
- Run `flutter test` for normalization and any new baseline/host-selector regression tests once toolchain is available.

## Cycle — 2026-02-16 17:13 America/Toronto
_Auditor_: IdleWatch iOS Implementer (cron)
_Scope_: Execute highest-priority feasible backlog items while keeping prototype runnable
_Method_: Implementation pass in `lib/main.dart` + unit test addition + static verification (`flutter` CLI unavailable in this environment)

### Implementation Summary
Delivered all three currently prioritized feasible items from QA:

- ✅ **P1 resolved** — 24h pie activity is now truly normalized.
  - Added proportional scaling when `cronjob + subagent > 24h`.
  - Idle remainder is now computed from normalized values so total is always 24h.
  - Added test coverage in `test/activity_normalization_test.dart` for both under-cap and over-cap scenarios.

- ✅ **P2 resolved** — Loading state now has progressive timeout + retry UX.
  - ~10s: “Still connecting…” helper text appears.
  - ~30s: troubleshooting hint + “Retry connection” action appears.
  - Retry triggers a fresh stream subscription key to avoid stale listener state.

- ✅ **P2 resolved** — Latest metric chips no longer mask malformed data as zero.
  - Latest CPU/Memory/Tokens chips now use nullable parsing.
  - Invalid latest fields render as `—`.
  - Added subtle warning message when latest sample is malformed.

### Backlog Status Update

#### P1 — 24h activity pie can exceed 24h total (normalization bug)
- **Previous**: Open
- **Now**: ✅ Resolved

#### P2 — Loading state still has no timeout or retry path
- **Previous**: Open
- **Now**: ✅ Resolved

#### P2 — Latest metric chips still mask malformed data as zero
- **Previous**: Open
- **Now**: ✅ Resolved

### Validation Notes
- Unit tests added for activity normalization math, but not executed in this environment due missing Flutter toolchain.
- Static code review confirms prototype remains single-file app + test file and should stay runnable in a proper Flutter setup.

---

## Cycle — 2026-02-16 17:01 America/Toronto
_Auditor_: QA Lead (cron)
_Scope_: UX, auth, onboarding, performance, 24h activity pie correctness
_Method_: Static review of `lib/main.dart` on `main` + backlog reconciliation; runtime validation still blocked (`flutter` CLI unavailable in this environment).

### Executive Summary
The dashboard has strong momentum (host selector, tooltips, and 24h pie are now in place), but one **high-priority correctness issue remains in the new pie chart math** and two prior resilience/data-integrity gaps are still open.

Highest risks now:
1. **P1** Pie chart is not actually normalized to 24h when cronjob+subagent totals exceed 24h.
2. **P2** Loading state can still spin forever with no timeout/recovery messaging.
3. **P2** Latest metric chips still coerce malformed values to `0`, which can hide ingestion defects.

---

## Prioritized Open Issues

### P1 — 24h activity pie can exceed 24h total (normalization bug)
- **Area**: UX correctness / telemetry trust
- **Impact**: UI text says “Pie is normalized to 24h total,” but sections can sum above 24h, producing misleading proportions.
- **Evidence**:
  - `activeSeconds` is capped to 24h, and `idleSeconds` is computed from that cap.
  - But `cronjobSeconds` and `subagentSeconds` are passed through uncapped individually.
  - If cron+subagent > 24h, pie sections become: `cron + subagent + 0 idle` (total > 24h).
- **Repro**:
  1. Provide docs in last 24h whose parsed activity durations sum to >24h (e.g., cron=20h, subagent=10h).
  2. Open activity card.
- **Current result**: Pie legend and geometry reflect >24h aggregate while claiming 24h normalization.
- **Expected result**: Section values are normalized so total equals exactly 24h.
- **Acceptance criteria**:
  - If `cron + subagent <= 24h`, keep raw values and set `idle = 24h - (cron + subagent)`.
  - If `cron + subagent > 24h`, scale both active categories proportionally so `cron + subagent == 24h` and `idle = 0`.
  - Add a unit/widget test for over-cap input verifying exact 24h total.

### P2 — Loading state still has no timeout or retry path
- **Area**: UX resilience
- **Impact**: Stream stalls appear as app freeze.
- **Evidence**: `!snapshot.hasData` path still returns only `CircularProgressIndicator()`.
- **Acceptance criteria**:
  - ~10s: show “Still connecting…” helper text.
  - ~30s: show retry action and troubleshooting hint.
  - Retry action should re-subscribe cleanly (no duplicate listeners).

### P2 — Latest metric chips still mask malformed data as zero
- **Area**: Data integrity / observability
- **Impact**: Invalid latest payloads display as `0.0%`, which looks like valid telemetry.
- **Evidence**: `_asDouble` returns `0` for non-`num`; chips use `_asDouble(latest['cpuPct'|'memPct'|'tokensPerMin'])`.
- **Acceptance criteria**:
  - Chips use nullable parsing and render `—` (or “invalid”) for malformed numeric values.
  - If latest sample is malformed, show subtle warning near chips.
  - Keep chart behavior (skip invalid points) consistent with chip behavior.

---

## Resolved / Verified This Cycle

### ✅ Multi-device host mixing
- Host selector + host-scoped series filtering are present and functioning in code path.

### ✅ Chart precision affordances
- Tooltip and bottom-axis time labels are implemented.

### ✅ Pie empty-state behavior
- When no activity telemetry is detected, card shows full-idle day + explicit explanatory note.

---

## Recommended Next QA Pass (after fixes)
- Validate pie normalization with synthetic over-cap datasets (e.g., 30h total active input).
- Verify loading timeout/retry UX on constrained network.
- Verify malformed latest sample renders `—` while historical valid points still chart.

---

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

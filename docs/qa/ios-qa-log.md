# IdleWatch iOS QA Log

_Date_: 2026-02-16  
_Auditor_: QA Lead (subagent)  
_Scope_: UX, auth flow, onboarding, chart readability, offline/error states, multi-device behavior assumptions  
_Method_: Static code audit of `lib/main.dart` + repo docs (`README.md`).

## Executive Summary

Current iOS prototype is a functional Firebase-connected chart viewer, but it lacks key product safeguards and user-facing states. Highest risk areas are:

1. **No failure state after startup for live Firestore stream errors** (permissions/network/index failure can strand users on spinner with no guidance).
2. **No empty-state UX for first-run / no metrics scenarios**.
3. **Chart readability is low (no legend, axis labels, timestamps, or value cues)**.
4. **Data is not segmented by device/host, creating misleading multi-device dashboards**.
5. **Anonymous auth lifecycle assumptions are unhandled (session churn/data access continuity risks)**.

---

## Prioritized Backlog

### P0 — Firestore stream errors are invisible after app loads
- **Area**: Offline/error states, auth/data resiliency
- **Impact**: Users may see perpetual loading or blank chart with no recovery path when Firestore query fails (rules denied, missing index, network interruption).
- **Evidence in code**: `StreamBuilder` checks only `!snapshot.hasData` and never handles `snapshot.hasError` (`DashboardPage`).
- **Repro steps**:
  1. Launch app with valid startup auth.
  2. Trigger a Firestore runtime error (e.g., deny `metrics` read in security rules, or disconnect network after launch).
  3. Observe dashboard state.
- **Current result**: No explicit error message/retry action; user is not informed what failed.
- **Expected result**: Clear, actionable error UI for stream failures with retry guidance.
- **Acceptance criteria**:
  - `snapshot.hasError` renders an error panel with readable cause category (network/permission/unknown).
  - Provide a retry action (rebuild stream) and a help CTA (e.g., “Check connection” / “Contact admin”).
  - Error state is covered by widget test for simulated stream exception.

### P1 — No empty state for no data / new install
- **Area**: Onboarding, UX
- **Impact**: First-time users with no documents in `metrics` see an uninformative empty chart area.
- **Evidence in code**: Chart always renders; `cpuSpots`/`memSpots` can be empty with no fallback message.
- **Repro steps**:
  1. Use clean Firebase project with empty `metrics` collection.
  2. Launch app successfully.
  3. Observe dashboard.
- **Current result**: Blank chart canvas; no explanation of next step.
- **Expected result**: Friendly “No metrics yet” state with onboarding hint.
- **Acceptance criteria**:
  - When docs list is empty, show empty-state card with:
    - Status text (“No metrics received yet”)
    - Suggested next step (“Start IdleWatch agent on a device”)
    - Optional refresh CTA.
  - Empty state appears within 1 second of first snapshot.

### P1 — Chart readability is insufficient for operational use
- **Area**: Chart readability, UX
- **Impact**: Users cannot reliably interpret trends or values (no axis/ticks/legend/tooltips/time context).
- **Evidence in code**: `LineChartData` has only min/max and 2 lines; no titles/legend/grid/tooltip config.
- **Repro steps**:
  1. Load app with representative metrics (>50 points).
  2. Attempt to answer: “What is current CPU and memory?” and “When was the spike?”
- **Current result**: Difficult/guess-based interpretation.
- **Expected result**: Fast interpretation of line identity, value, and recency.
- **Acceptance criteria**:
  - Add legend mapping color→metric (CPU, Memory).
  - Add axis labels (Y as %, X as relative time or timestamp).
  - Show tooltip/crosshair on touch with exact value + timestamp.
  - Ensure color contrast passes WCAG AA on dark theme.

### P1 — Multi-device data is aggregated without segmentation/filtering
- **Area**: Multi-device behavior assumptions
- **Impact**: If multiple hosts publish to `metrics`, lines merge into one sequence by index, misrepresenting per-device behavior.
- **Evidence in code**: Query reads all docs from `metrics` ordered by `ts`; ignores `host` field noted in README schema.
- **Repro steps**:
  1. Insert interleaved docs from at least two distinct `host` values.
  2. Launch dashboard.
  3. Compare chart trend to each host’s true trend.
- **Current result**: Mixed dataset plotted as one CPU and one Memory line.
- **Expected result**: Explicit single-device filter or grouped multi-series visualization.
- **Acceptance criteria**:
  - User can filter/select host (default host persisted).
  - Query scopes to selected host or chart draws separate host series with legend.
  - UI clearly indicates which host(s) are displayed.

### P2 — Startup auth/setup errors are surfaced but not recoverable in-app
- **Area**: Auth flow, onboarding
- **Impact**: `SetupErrorPage` gives error text but no remediation path except manual restart/rebuild.
- **Evidence in code**: `main()` sets `startupError`; app routes to static setup page with no retry action.
- **Repro steps**:
  1. Launch without valid Firebase config or with Anonymous auth disabled.
  2. Reach setup error screen.
- **Current result**: Informational message only.
- **Expected result**: Guided remediation with retry and setup links.
- **Acceptance criteria**:
  - Add “Retry initialization” button.
  - Add concise troubleshooting checklist (Firebase configured, anonymous auth enabled, network available).
  - Optional copy/share diagnostic details.

### P2 — Loading state lacks timeout/escalation
- **Area**: UX, offline/error states
- **Impact**: Infinite spinner without timeout degrades trust and masks upstream problems.
- **Evidence in code**: `!snapshot.hasData` always returns `CircularProgressIndicator()` with no elapsed-state transition.
- **Repro steps**:
  1. Simulate slow/blocked Firestore response.
  2. Keep app open >30s.
- **Current result**: Spinner indefinitely.
- **Expected result**: Timeout message and retry/offline guidance.
- **Acceptance criteria**:
  - After configurable threshold (e.g., 10s), display “Still connecting…” helper text.
  - After second threshold (e.g., 30s), show recovery actions.

### P3 — Onboarding context is absent once user reaches dashboard
- **Area**: Onboarding
- **Impact**: New users do not learn what metrics mean, update cadence, or data source.
- **Evidence in code**: No onboarding surfaces beyond README (developer-facing).
- **Repro steps**:
  1. Launch app as first-time non-technical user.
  2. Try to interpret dashboard with no prior context.
- **Current result**: Minimal context; likely confusion.
- **Expected result**: Lightweight in-app product guidance.
- **Acceptance criteria**:
  - First-run tooltip/sheet explains CPU%/Mem% and data freshness.
  - Dismissal persisted locally.

---

## Suggested QA Regression Matrix (iOS)

- **Auth**: anonymous enabled/disabled, token expiration, relaunch behavior.
- **Network**: online at startup, offline at startup, online→offline mid-session, captive portal.
- **Data**: empty collection, malformed fields, high volume (120 points), multi-host interleaving.
- **Accessibility**: dynamic type scaling, VoiceOver labels for chart and key states, color contrast.

## Notes for Engineering

Given current app size (single file), introducing explicit state handling (`loading`, `empty`, `error`, `ready`) and host-aware querying will resolve most high-priority UX risks quickly while preserving prototype velocity.

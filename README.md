# IdleWatch iOS Prototype (Flutter + Firebase)

Small Flutter prototype that visualizes IdleWatch metrics from Firestore.

- Platforms: iOS (prototype currently scaffolded for iOS only)
- Auth: Firebase anonymous auth
- Data source: Firestore `metrics` collection

## Quickstart

### 1) Prerequisites

- Flutter SDK (stable)
- Xcode (for iOS builds)
- A Firebase project

### 2) Install dependencies

```bash
flutter pub get
```

### 3) Configure Firebase (required)

This app expects FlutterFire configuration and anonymous auth enabled.

#### A. Create Firebase apps

In Firebase console, create an app for:
- **iOS** (`ios/Runner` bundle id)

#### B. Enable services

- **Authentication** → enable **Anonymous** provider
- **Firestore Database** → create database (test mode for prototype is fine)

#### C. Configure platform Firebase files (prototype path)

This prototype currently initializes Firebase with bare `Firebase.initializeApp()`.
That means it relies on platform-native Firebase config files (not
`DefaultFirebaseOptions.currentPlatform`).

Set up these files:

- **iOS**: add `ios/Runner/GoogleService-Info.plist`
- **Web**: not currently scaffolded in this repo. If you add web support later, generate the Flutter web platform first and then add web Firebase config.

Optional: you can still run FlutterFire CLI for future migration:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

If you later wire `lib/firebase_options.dart` into runtime bootstrap, update this README section accordingly.

### 4) Run

```bash
# iOS simulator/device
flutter run -d ios
```

If Firebase config is missing/invalid, the app shows a setup error screen instead
of crashing.

### 5) Runtime validation (recommended before merge/release)

Preferred one-command workflow:

```bash
scripts/run_ios_smoke_workflow.sh
```

This helper will:
- generate a timestamped smoke report template,
- run `flutter --version`, `flutter pub get`, `flutter analyze`, and `flutter test`,
- auto-append preflight metadata + validation artifact path into the smoke report,
- auto-link the latest smoke artifacts into `docs/qa/ios-qa-log.md`.

Manual mode is still available:

```bash
scripts/validate_runtime.sh
scripts/prepare_ios_smoke_report.sh
```

After validation, complete `docs/qa/runtime-smoke-checklist.md` and summarize results
in `docs/qa/ios-qa-log.md` (linking both the validation log and smoke report artifact paths).

If automatic linkage fails, run:

```bash
scripts/link_ios_smoke_artifacts.sh <smoke-report-path> <validation-status> <validation-log-path>
```

## Firestore Schema

Collection: `metrics`

Expected fields per document:

- `host` (`string`)
- `ts` (`number | Firestore Timestamp`) — event time (epoch seconds or epoch ms both supported)
- `cpuPct` (`number`)
- `memPct` (`number`)
- `gpuPct` (`number | null`)
- `tokensPerMin` (`number`)

### Activity telemetry (for 24h pie chart)

Dashboard computes a 24h normalized pie (`cronjob + subagent + idle = 24h`).

For each activity metric document in `metrics`, provide:

1) **Activity source** (any one of these fallback fields):

- `activitySource`
- `activity_source`
- `source`
- `runner`
- `actor`
- `kind`
- `type`

Accepted values are matched loosely:
- contains `cron` → counted as **cronjob**
- contains `subagent`, `agent`, or `worker` → counted as **subagent**

Boolean fallbacks are also accepted:
- `isCronjob: true` (or `cronjob: true`)
- `isSubagent: true` (or `subagent: true`)

2) **Activity duration** (seconds preferred, multiple fallbacks):

Seconds fields:
- `activitySeconds`
- `activity_seconds`
- `activeSeconds`
- `active_seconds`
- `durationSeconds`
- `duration_seconds`
- `activeSec`
- `durationSec`

Milliseconds fields:
- `activityMs`
- `activity_ms`
- `activeMs`
- `active_ms`
- `durationMs`
- `duration_ms`

Generic fallbacks:
- `duration`
- `active`

Duration values can be numeric or strings like `"12"`, `"12s"`, or `"1500ms"`.
If no valid activity data exists in the last 24h window, the chart renders a full **Idle** pie gracefully.

## CI

GitHub Actions workflow (`.github/workflows/flutter-ci.yml`) runs:

- `flutter pub get`
- `flutter analyze`
- `flutter test` (or a no-tests placeholder message)

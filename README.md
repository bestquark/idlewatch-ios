# IdleWatch iOS Prototype (Flutter + Firebase)

Small Flutter prototype that visualizes IdleWatch metrics from Firestore.

- Platforms: iOS + web (Chrome)
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

In Firebase console, create apps for:
- **iOS** (`ios/Runner` bundle id)
- **Web**

#### B. Enable services

- **Authentication** → enable **Anonymous** provider
- **Firestore Database** → create database (test mode for prototype is fine)

#### C. Generate FlutterFire options

Preferred approach:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This should generate `lib/firebase_options.dart`.

> If you use manual config files instead, ensure your Flutter app still provides
> Firebase options at runtime for web/iOS.

### 4) Run

```bash
# Web
flutter run -d chrome

# iOS simulator/device
flutter run -d ios
```

If Firebase config is missing/invalid, the app shows a setup error screen instead
of crashing.

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

# idlewatch-ios

Flutter + Firebase iOS/web prototype for IdleWatch metrics.

## Quick start

1. Install Flutter SDK.
2. Configure Firebase project (iOS + web app).
3. Add generated firebase options (or FlutterFire config).
4. Run:

```bash
flutter pub get
flutter run -d chrome
# or iOS simulator/device
flutter run -d ios
```

## Firestore collection

`metrics`

Fields expected:
- `host` (string)
- `ts` (number)
- `cpuPct` (number)
- `memPct` (number)
- `gpuPct` (number|null)
- `tokensPerMin` (number)

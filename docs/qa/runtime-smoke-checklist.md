# Runtime Smoke Checklist (iOS)

Use this after runtime validation passes in a Flutter-enabled environment (supports both `flutter` and `fvm flutter`).

Preferred: run `scripts/run_ios_smoke_workflow.sh` first (it generates a report template + runs host preflight + runs validation + appends metadata + links artifacts into `docs/qa/ios-qa-log.md`; when local Flutter is missing, it also attempts to trigger GitHub iOS smoke CI evidence).

Manual alternative: run `scripts/prepare_ios_smoke_report.sh`, `scripts/preflight_ios_host.sh`, and `scripts/validate_runtime.sh` separately.

## Simulator/device smoke pass

1. App launches to dashboard without crash.
2. Host selector renders and can switch hosts.
3. CPU/Memory line chart renders points for selected host.
4. Tooltip works (tap chart point, see timestamp/value).
5. Activity pie renders and totals to 24h.
6. Latest metric chips show `—` for malformed latest sample values.
7. Loading helper appears around ~10s when stream is delayed.
8. Retry CTA appears around ~30s when stream is delayed.

### Lower-envelope perf capture (P4 support)

When possible, use the lower-end iOS simulator candidate identified in preflight:

1. Run preflight and note: `Lower-envelope candidate for perf capture`.
2. Run the app on that simulator with debug defines to force helper/retry timing capture:
   - `IDLEWATCH_DASHBOARD_DELAY_MS=10000`
   - `IDLEWATCH_DASHBOARD_AUTO_RETRY=true`
3. Capture and record:
   - `loading_helper`
   - `loading_retry`
   - `dashboard_retry_recovery_ms`
4. Add measured values to the cycle artifact + QA log.

If no lower-end simulator is available, document blocker + current candidate inventory in the preflight/smoke artifacts.

## Record in QA log

Include:
- Device/simulator + iOS version
- `flutter analyze` result
- `flutter test` result
- Any flaky tests or timing caveats
- Smoke checklist pass/fail summary

If needed, you can manually link artifacts into the QA log:

```bash
scripts/link_ios_smoke_artifacts.sh <smoke-report-path> <validation-status> <validation-log-path> [preflight-status] [preflight-log-path] [ci-trigger-status] [ci-run-url] [ci-run-conclusion]
```

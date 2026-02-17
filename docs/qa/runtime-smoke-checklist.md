# Runtime Smoke Checklist (iOS)

Use this after runtime validation passes in a Flutter-enabled environment.

Preferred: run `scripts/run_ios_smoke_workflow.sh` first (it generates a report template + runs validation + appends preflight metadata).

Manual alternative: run `scripts/prepare_ios_smoke_report.sh` and `scripts/validate_runtime.sh` separately.

## Simulator/device smoke pass

1. App launches to dashboard without crash.
2. Host selector renders and can switch hosts.
3. CPU/Memory line chart renders points for selected host.
4. Tooltip works (tap chart point, see timestamp/value).
5. Activity pie renders and totals to 24h.
6. Latest metric chips show `—` for malformed latest sample values.
7. Loading helper appears around ~10s when stream is delayed.
8. Retry CTA appears around ~30s when stream is delayed.

## Record in QA log

Include:
- Device/simulator + iOS version
- `flutter analyze` result
- `flutter test` result
- Any flaky tests or timing caveats
- Smoke checklist pass/fail summary

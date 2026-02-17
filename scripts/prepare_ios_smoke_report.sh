#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="${ROOT_DIR}/docs/qa/artifacts"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_FILE="${ARTIFACT_DIR}/ios-smoke-report-${STAMP}.md"

mkdir -p "${ARTIFACT_DIR}"

cat >"${OUT_FILE}" <<EOF
# iOS Runtime Smoke Report — ${STAMP}

## Environment
- Date/time:
- Operator:
- Device/simulator:
- iOS version:
- Flutter version:

## Runtime validation artifacts
- Analyze/test log path (from scripts/validate_runtime.sh):

## Smoke checklist
- [ ] App launches to dashboard without crash
- [ ] Host selector renders and can switch hosts
- [ ] CPU/Memory line chart renders points for selected host
- [ ] Tooltip works (tap chart point, see timestamp/value)
- [ ] Activity pie renders and totals to 24h
- [ ] Latest metric chips show `—` for malformed latest sample values
- [ ] Loading helper appears around ~10s when stream is delayed
- [ ] Retry CTA appears around ~30s when stream is delayed

## Perf/timing notes
- Startup latency:
- First stream render time:
- Flaky paths observed:

## Failures / follow-ups
- 
EOF

echo "Created smoke report template: ${OUT_FILE}"

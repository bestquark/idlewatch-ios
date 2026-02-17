#!/usr/bin/env bash
set -euo pipefail

# Emits a shell-escaped command string that can run Flutter in this repo.
# Preference order:
# 1) flutter on PATH
# 2) fvm flutter (if FVM is installed)

if command -v flutter >/dev/null 2>&1; then
  printf 'flutter\n'
  exit 0
fi

if command -v fvm >/dev/null 2>&1; then
  printf 'fvm flutter\n'
  exit 0
fi

exit 127

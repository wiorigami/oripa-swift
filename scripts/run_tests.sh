#!/bin/bash
# Local verification suite: build, hermetic tests, headless UI snapshots.
#
#   bash scripts/run_tests.sh
#   SKIP_SNAPSHOTS=1 bash scripts/run_tests.sh     # faster: skip ImageRenderer pass
#
# IMPORTANT: this Mac's Command Line Tools toolchain ships no XCTest module, so the
# test suite is a plain executable target (`swift run ORIPATests`, non-zero exit on
# failure) rather than `swift test`. CI uses the same entry point.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> swift build"
swift build

echo "==> swift run ORIPATests"
swift run ORIPATests

if [ "${SKIP_SNAPSHOTS:-0}" = "1" ]; then
  echo "==> snapshots skipped (SKIP_SNAPSHOTS=1)"
else
  echo "==> swift run ORIPASnapshots build-snapshots"
  swift run ORIPASnapshots build-snapshots
  echo "    snapshots in $ROOT/build-snapshots"
fi

echo "==> all checks passed"

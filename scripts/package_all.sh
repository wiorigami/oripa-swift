#!/bin/bash
# Build every distributable artifact and collect them in dist/.
#
#   bash scripts/package_all.sh
#
# Artifacts:
#   dist/ORIPA-unsigned.ipa    iOS/iPadOS (only when a full Xcode is installed)
#   dist/ORIPA-macOS.zip       macOS .app bundle (needs only Command Line Tools)
#
# On the current CLT-only development Mac the iOS step is skipped with a note; CI
# builds the IPA on a macOS runner (see .github/workflows/ci.yml).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
DIST="$ROOT/dist"
status=0

mkdir -p "$DIST"

echo "=============================================================================="
echo " ORIPA packaging"
echo "=============================================================================="

# --- macOS app (always, SwiftPM only) ---------------------------------------
if bash "$ROOT/scripts/build_mac.sh"; then
  cp -f "$ROOT/build/macos/ORIPA-macOS.zip" "$DIST/ORIPA-macOS.zip"
else
  echo "error: macOS build failed" >&2
  status=1
fi

# --- iOS unsigned IPA (needs full Xcode) ------------------------------------
if command -v xcodebuild >/dev/null 2>&1 && xcodebuild -version >/dev/null 2>&1; then
  if [ ! -d "$ROOT/ORIPA.xcodeproj" ]; then
    if command -v xcodegen >/dev/null 2>&1; then
      echo "==> xcodegen generate"
      xcodegen generate
    else
      echo "error: ORIPA.xcodeproj missing and xcodegen not installed" >&2
      status=1
    fi
  fi
  if [ -d "$ROOT/ORIPA.xcodeproj" ]; then
    if bash "$ROOT/scripts/build_ipa.sh"; then
      cp -f "$ROOT/build/ios/ORIPA-unsigned.ipa" "$DIST/ORIPA-unsigned.ipa"
    else
      echo "error: iOS build failed" >&2
      status=1
    fi
  fi
else
  echo
  echo "note: xcodebuild is not available on this machine (Command Line Tools only)."
  echo "      Skipping the unsigned iOS IPA; build it on GitHub Actions:"
  echo "        Actions -> CI -> Run workflow  (see docs/PUBLISH.md)"
  echo
fi

echo "=============================================================================="
echo " artifacts in $DIST:"
ls -lh "$DIST" 2>/dev/null || true
echo "=============================================================================="
exit "$status"

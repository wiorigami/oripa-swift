#!/bin/bash
# Build the iOS app with xcodebuild and package it as an unsigned IPA.
#
#   bash scripts/build_ipa.sh                 # normal build
#   ADHOC_SIGN=1 bash scripts/build_ipa.sh    # additionally ad-hoc sign the .app
#
# Requires a full Xcode installation (xcodebuild); this cannot run with the Command
# Line Tools alone. CI (.github/workflows/ci.yml, macos-15 runner) does this for us.
#
# Output (git-ignored, uploaded by CI):
#   build/ios/ORIPA-unsigned.ipa
#   build/ios/xcodebuild-ios.log
#   build/ios/Payload/ORIPA.app
#
# The IPA is unsigned: install it with Sideloadly / i4Tools / TrollStore after
# appending your own signature (see docs/INSTALL.md). The bundle id stays
# com.origamitoolbox.oripa so re-signing over the previous port keeps the app
# container (Documents/project_data) intact.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT_DIR="${OUTPUT_DIR:-$ROOT/build/ios}"
DERIVED="$OUT_DIR/DerivedData"
LOG="$OUT_DIR/xcodebuild-ios.log"
IPA="$OUT_DIR/ORIPA-unsigned.ipa"
PAYLOAD="$OUT_DIR/Payload"
APP_NAME="ORIPA"

if ! command -v xcodebuild >/dev/null 2>&1 || ! xcodebuild -version >/dev/null 2>&1; then
  echo "error: xcodebuild is not available (a full Xcode installation is required)." >&2
  echo "       On this Apple-Silicon Mac with Command Line Tools only, build the IPA on" >&2
  echo "       GitHub Actions (see docs/BUILD.md) or install Xcode and run:" >&2
  echo "         sudo xcode-select -s /Applications/Xcode.app" >&2
  exit 1
fi

if [ ! -d "$ROOT/ORIPA.xcodeproj" ]; then
  echo "error: ORIPA.xcodeproj is missing; generate it first:" >&2
  echo "         /opt/homebrew/bin/xcodegen generate   (or: brew install xcodegen)" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
rm -rf "$DERIVED" "$PAYLOAD" "$IPA" "$LOG"

echo "==> xcodebuild -project ORIPA.xcodeproj -scheme ORIPA -configuration Release -sdk iphoneos"
echo "    (unsigned build: CODE_SIGNING_ALLOWED=NO; full log: $LOG)"
set +e
{
  xcodebuild \
    -project ORIPA.xcodeproj \
    -scheme ORIPA \
    -configuration Release \
    -sdk iphoneos \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$DERIVED" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    build
} 2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}
set -e

if [ "$status" -ne 0 ]; then
  echo "error: xcodebuild failed (exit $status)" >&2
  echo "--- last 150 log lines ---" >&2
  tail -n 150 "$LOG" >&2
  exit "$status"
fi

PRODUCTS_DIR="$DERIVED/Build/Products/Release-iphoneos"
APP="$(find "$PRODUCTS_DIR" -maxdepth 1 -name "$APP_NAME.app" -type d 2>/dev/null | head -n 1)"
if [ -z "$APP" ]; then
  echo "error: $APP_NAME.app not found under $PRODUCTS_DIR" >&2
  ls -la "$PRODUCTS_DIR" >&2 || true
  exit 1
fi
EXECUTABLE="$APP/$APP_NAME"
if [ ! -f "$EXECUTABLE" ]; then
  echo "error: app executable missing: $EXECUTABLE" >&2
  exit 1
fi

echo "==> validating bundle"
plutil -lint "$APP/Info.plist"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"
MARKETING_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Info.plist")"
BUILD_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Info.plist")"
echo "    CFBundleIdentifier: $BUNDLE_ID"
echo "    CFBundleShortVersionString: $MARKETING_VERSION"
echo "    CFBundleVersion: $BUILD_VERSION"
if [ "$BUNDLE_ID" != "com.origamitoolbox.oripa" ]; then
  echo "error: unexpected bundle id '$BUNDLE_ID' (must stay com.origamitoolbox.oripa" >&2
  echo "       so an upgrade keeps the user's existing Documents/project_data)" >&2
  exit 1
fi

# project.yml is the source of truth for version/build settings; the built Info.plist
# must agree (it expands $(MARKETING_VERSION) / $(CURRENT_PROJECT_VERSION)).
EXPECTED_VERSION="$(sed -n 's/^ *MARKETING_VERSION: "\([^"]*\)"/\1/p' project.yml | head -n 1)"
EXPECTED_BUILD="$(sed -n 's/^ *CURRENT_PROJECT_VERSION: "\([^"]*\)"/\1/p' project.yml | head -n 1)"
if [ -n "$EXPECTED_VERSION" ] && [ "$MARKETING_VERSION" != "$EXPECTED_VERSION" ]; then
  echo "error: CFBundleShortVersionString '$MARKETING_VERSION' != project.yml '$EXPECTED_VERSION'" >&2
  exit 1
fi
if [ -n "$EXPECTED_BUILD" ] && [ "$BUILD_VERSION" != "$EXPECTED_BUILD" ]; then
  echo "error: CFBundleVersion '$BUILD_VERSION' != project.yml '$EXPECTED_BUILD'" >&2
  exit 1
fi

# Hard user requirements that only the packaged bundle can prove: Files.app access and
# iPad upside-down orientation.
for key in UIFileSharingEnabled LSSupportsOpeningDocumentsInPlace; do
  value="$(/usr/libexec/PlistBuddy -c "Print :$key" "$APP/Info.plist" 2>/dev/null || true)"
  if [ "$value" != "true" ]; then
    echo "error: Info.plist $key must be true (got '$value')" >&2
    exit 1
  fi
done
if ! /usr/libexec/PlistBuddy -c 'Print :UISupportedInterfaceOrientations~ipad' \
      "$APP/Info.plist" 2>/dev/null | grep -q 'UIInterfaceOrientationPortraitUpsideDown'; then
  echo "error: iPad orientations must include UIInterfaceOrientationPortraitUpsideDown" >&2
  exit 1
fi
echo "    Files.app access + iPad upside-down orientation: OK"

echo "==> architecture / platform"
lipo -info "$EXECUTABLE"
if ! lipo -info "$EXECUTABLE" 2>/dev/null | grep -q 'arm64'; then
  echo "error: device build does not contain arm64 (got: $(lipo -info "$EXECUTABLE"))" >&2
  exit 1
fi
BUILD_VERSION_INFO="$(otool -l "$EXECUTABLE" | grep -A4 -m1 'LC_BUILD_VERSION' || true)"
echo "    LC_BUILD_VERSION:"
printf '%s\n' "$BUILD_VERSION_INFO" | sed 's/^/    /'
# LC_BUILD_VERSION.platform: 1 = macOS, 2 = iOS (/ newer otool prints "IOS"/"iOS").
if [ "${SKIP_LC_PLATFORM_CHECK:-0}" != "1" ]; then
  if ! printf '%s\n' "$BUILD_VERSION_INFO" | grep -qE 'platform (2|IOS|iOS)\b'; then
    echo "error: executable was not built for iOS (expected LC_BUILD_VERSION platform 2/IOS)" >&2
    exit 1
  fi
fi

if [ "${ADHOC_SIGN:-0}" = "1" ]; then
  echo "==> ad-hoc signing (ADHOC_SIGN=1)"
  codesign --force --deep --sign - "$APP"
  codesign --verify --deep --strict "$APP" || true
fi

echo "==> packaging Payload/$APP_NAME.app -> $(basename "$IPA")"
mkdir -p "$PAYLOAD"
cp -R "$APP" "$PAYLOAD/$APP_NAME.app"
(
  cd "$OUT_DIR"
  rm -f "$IPA"
  zip -qry "$IPA" Payload
)
# Validate the staged payload and the archive itself (zip -T verifies integrity).
if [ ! -f "$PAYLOAD/$APP_NAME.app/$APP_NAME" ]; then
  echo "error: staged payload is missing $PAYLOAD/$APP_NAME.app/$APP_NAME" >&2
  exit 1
fi
if ! zip -T "$IPA" >/dev/null 2>&1; then
  echo "error: $IPA failed the zip integrity test" >&2
  exit 1
fi
echo "    IPA payload: Payload/$APP_NAME.app ($(du -sh "$PAYLOAD/$APP_NAME.app" | awk '{print $1}'))"

echo "==> done"
du -sh "$APP"
ls -lh "$IPA"
echo "    sha256: $(shasum -a 256 "$IPA" | awk '{print $1}')"

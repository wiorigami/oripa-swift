#!/bin/bash
# Local iOS typecheck for ORIPAUI/ORIPACore using an iPhoneOS SDK and the CLT toolchain.
#
#   IOS_SDK=/path/to/iPhoneOS.sdk bash tools/ios_typecheck.sh
#   # with a full Xcode installation the SDK path is:
#   IOS_SDK="$(xcrun --sdk iphoneos --show-sdk-path)" bash tools/ios_typecheck.sh
#
# This is a local-only QA helper (not used by CI): it compiles the shared code for
# arm64-apple-ios16.0 so UIKit-only branches (#if canImport(UIKit) in Gestures.swift) and
# iOS availability are validated before pushing to GitHub Actions. Requires a full
# iPhoneOS SDK that was built with a matching Swift version (the CLT toolchain's Swift).
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="${IOS_SDK:?set IOS_SDK to an iPhoneOS SDK path}"
BUILD="${IOS_TYPECHECK_BUILD:-/tmp/oripa-ios-typecheck}"
mkdir -p "$BUILD"
accessor="$(find "$ROOT/.build" -name '*resource_bundle_accessor*' -path '*ORIPAUI*' | head -1)"
if [ -z "$accessor" ]; then
  echo "error: resource accessor not found; run 'swift build' first" >&2
  exit 1
fi

echo "==> ORIPACore module (arm64-apple-ios16.0)"
core_files=$(find "$ROOT/Sources/ORIPACore" -name '*.swift' | tr '\n' ' ')
# shellcheck disable=SC2086
swiftc -emit-module -parse-as-library -module-name ORIPACore \
  -emit-module-path "$BUILD/ORIPACore.swiftmodule" \
  -target arm64-apple-ios16.0 -sdk "$SDK" -swift-version 5 $core_files || exit 1

echo "==> ORIPAUI module + typecheck (arm64-apple-ios16.0)"
ui_files=$(find "$ROOT/Sources/ORIPAUI" -name '*.swift' | tr '\n' ' ')
# shellcheck disable=SC2086
swiftc -emit-module -parse-as-library -module-name ORIPAUI \
  -emit-module-path "$BUILD/ORIPAUI.swiftmodule" \
  -target arm64-apple-ios16.0 -sdk "$SDK" -swift-version 5 \
  -DSWIFT_PACKAGE -I "$BUILD" "$accessor" $ui_files || exit 1

echo "==> iOSApp typecheck"
# shellcheck disable=SC2086
swiftc -typecheck -parse-as-library \
  -target arm64-apple-ios16.0 -sdk "$SDK" -swift-version 5 \
  -I "$BUILD" "$ROOT/iOSApp/ORIPAApp.swift" || exit 1

echo "iOS typecheck OK"

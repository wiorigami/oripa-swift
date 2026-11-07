#!/bin/bash
# Build the native macOS application bundle from the SwiftPM executable target
# ORIPAMac (SwiftUI UI lives in ORIPAUI and is shared with the iOS app).
#
#   bash scripts/build_mac.sh
#
# Output (git-ignored, uploaded by CI):
#   build/macos/ORIPA.app           runnable, ad-hoc signed bundle
#   build/macos/ORIPA-macOS.zip     distribution artifact (ditto zip, keeps metadata)
#
# Notes:
#   * `swift build` needs only the Command Line Tools (no full Xcode).
#   * The SwiftPM resource bundle (`ORIPA_ORIPAUI.bundle`) is copied both to the
#     app root -- where the SwiftPM `Bundle.module` accessor looks
#     (Bundle.main.bundleURL) -- and to Contents/Resources for convention.
#   * Ad-hoc signing (`codesign --sign -`) is enough to launch locally; the zip is
#     NOT notarised, Gatekeeper will require right-click > Open (see docs/INSTALL.md).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BUILD_DIR="${BUILD_DIR:-$ROOT/build/macos}"
APP="$BUILD_DIR/ORIPA.app"
ZIP="$BUILD_DIR/ORIPA-macOS.zip"

echo "==> swift build -c release --product ORIPAMac"
swift build -c release --product ORIPAMac 2>&1 | tail -n 5

BIN_DIR="$(swift build -c release --show-bin-path)"
EXECUTABLE="$BIN_DIR/ORIPAMac"
if [ ! -x "$EXECUTABLE" ]; then
  echo "error: executable not found: $EXECUTABLE" >&2
  exit 1
fi

RESOURCE_BUNDLE=""
for candidate in "$BIN_DIR/ORIPA_ORIPAUI.bundle" "$BIN_DIR"/*ORIPAUI*.bundle; do
  if [ -d "$candidate" ]; then
    RESOURCE_BUNDLE="$candidate"
    break
  fi
done
if [ -z "$RESOURCE_BUNDLE" ]; then
  echo "error: SwiftPM resource bundle ORIPA_ORIPAUI.bundle not found in $BIN_DIR" >&2
  echo "       (did the ORIPAUI target lose its resources?)" >&2
  exit 1
fi

# Version/build: single source of truth is Sources/ORIPACore/Version.swift.
VERSION="$(sed -n 's/^.*static let version = "\([^"]*\)".*$/\1/p' Sources/ORIPACore/Version.swift | head -n 1)"
BUILD="$(sed -n 's/^.*static let build = "\([^"]*\)".*$/\1/p' Sources/ORIPACore/Version.swift | head -n 1)"
VERSION="${VERSION:-0.2.3.3}"
BUILD="${BUILD:-2}"

echo "==> assembling $APP (version $VERSION build $BUILD)"
rm -rf "$APP" "$ZIP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$EXECUTABLE" "$APP/Contents/MacOS/ORIPA"
chmod +x "$APP/Contents/MacOS/ORIPA"

# SwiftPM resource bundle.
#
# Standard macOS layout: Contents/Resources/ORIPA_ORIPAUI.bundle (this is what
# `Bundle.main.resourceURL` sees). SwiftPM's generated `Bundle.module` accessor for
# an executable target only looks at Bundle.main.bundleURL (the app ROOT), which
# would put an unsealed directory at the bundle root and break code signing. ORIPAUI
# therefore resolves resources through a BundleFinder-style candidate list that
# includes Bundle.main.resourceURL (see ORIPAUIResources in MaterialIcon.swift).
cp -R "$RESOURCE_BUNDLE" "$APP/Contents/Resources/ORIPA_ORIPAUI.bundle"

# Interim fallback for a tree where ORIPAUI still calls `Bundle.module` directly:
# copy the bundle to the app root as well. This makes the app run locally, but the
# root directory is outside `Contents/`, so codesign reports "unsealed contents"
# and downloaded copies are blocked by Gatekeeper. Never ship this layout.
ROOT_BUNDLE_COPY=0
if ! grep -rqs 'Bundle.main.resourceURL' Sources/ORIPAUI; then
  ROOT_BUNDLE_COPY=1
  cp -R "$RESOURCE_BUNDLE" "$APP/ORIPA_ORIPAUI.bundle"
  echo "warning: ORIPAUI does not yet resolve resources via Bundle.main.resourceURL;" >&2
  echo "         using the app-root fallback. The .app runs locally but its code" >&2
  echo "         signature cannot be strict-verified -- do not ship this artifact." >&2
  echo "         (see ci-release request: ORIPAUIResources in MaterialIcon.swift)" >&2
fi

# App icon: derive .icns from the committed 1024 px iOS app icon (no extra assets).
ICON_SOURCE="$ROOT/iOSApp/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
ICON_FILENAME=""
if [ -s "$ICON_SOURCE" ]; then
  ICONSET="$BUILD_DIR/AppIcon.iconset"
  rm -rf "$ICONSET"
  mkdir -p "$ICONSET"
  icon() { # <filename> <pixels>
    sips -z "$2" "$2" "$ICON_SOURCE" --out "$ICONSET/$1" >/dev/null
  }
  icon "icon_16x16.png" 16
  icon "icon_16x16@2x.png" 32
  icon "icon_32x32.png" 32
  icon "icon_32x32@2x.png" 64
  icon "icon_128x128.png" 128
  icon "icon_128x128@2x.png" 256
  icon "icon_256x256.png" 256
  icon "icon_256x256@2x.png" 512
  icon "icon_512x512.png" 512
  icon "icon_512x512@2x.png" 1024
  if iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns" 2>/dev/null; then
    ICON_FILENAME="AppIcon"
  else
    echo "warning: iconutil failed; macOS app will use the generic icon" >&2
  fi
  rm -rf "$ICONSET"
fi

# Info.plist. Bundle id deliberately differs from iOS (.mac suffix) so the two apps
# can coexist; LSMinimumSystemVersion matches Package.swift (.macOS(.v13)).
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleDisplayName</key>
	<string>ORIPA</string>
	<key>CFBundleExecutable</key>
	<string>ORIPA</string>
	<key>CFBundleIdentifier</key>
	<string>com.origamitoolbox.oripa.mac</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>ORIPA</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>${VERSION}</string>
	<key>CFBundleVersion</key>
	<string>${BUILD}</string>
	<key>LSApplicationCategoryType</key>
	<string>public.app-category.graphics-design</string>
	<key>LSMinimumSystemVersion</key>
	<string>13.0</string>
	<key>NSHighResolutionCapable</key>
	<true/>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
	<key>NSSupportsAutomaticGraphicsSwitching</key>
	<true/>
PLIST
if [ -n "$ICON_FILENAME" ]; then
  cat >> "$APP/Contents/Info.plist" <<PLIST
	<key>CFBundleIconFile</key>
	<string>${ICON_FILENAME}</string>
PLIST
fi
cat >> "$APP/Contents/Info.plist" <<'PLIST'
	<key>NSHumanReadableCopyright</key>
	<string>ORIPA (GPL-3.0): Jun Mitani, Ouchi Koji, Michelle Fung; Apple port</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$APP/Contents/PkgInfo"
plutil -lint "$APP/Contents/Info.plist" >/dev/null

# Ad-hoc signature (no Developer ID / notarisation in this project).
echo "==> ad-hoc codesigning"
codesign --force --deep --sign - "$APP"
if [ "$ROOT_BUNDLE_COPY" -eq 1 ]; then
  codesign --verify --deep "$APP" 2>&1 || true
else
  codesign --verify --deep --strict "$APP"
fi

echo "==> packaging $ZIP"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
if [ "$ROOT_BUNDLE_COPY" -eq 1 ]; then
  echo "warning: package contains the app-root resource-bundle fallback (Gatekeeper-blocked" >&2
  echo "         until ORIPAUI gets the ORIPAUIResources resolver; final QA only)" >&2
fi

echo "==> done"
du -sh "$APP" "$ZIP"
ls -lh "$ZIP"

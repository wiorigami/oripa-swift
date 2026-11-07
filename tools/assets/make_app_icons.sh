#!/bin/bash
# Generate the iOS AppIcon set + LaunchLogo imageset from the ORIPA logos in
# Sources/ORIPAUI/Resources/Logos/.
#
#   bash tools/assets/make_app_icons.sh
#
# The app icon must be *visually identical* to the previous (WKWebView) port's
# icon: the vector ORIPA mark composited on white, as Chrome/App Store would show
# it.  It is written without an alpha channel (App Store requirement) and the
# full set of legacy icon sizes is provided so every Xcode version accepts it.
# Outputs are committed so CI never needs ImageMagick.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOGOS="$ROOT/Sources/ORIPAUI/Resources/Logos"
ASSETS="$ROOT/iOSApp/Assets.xcassets"
ICONSET="$ASSETS/AppIcon.appiconset"
LAUNCHSET="$ASSETS/LaunchLogo.imageset"

if ! command -v magick >/dev/null 2>&1; then
  echo "error: ImageMagick 7 ('magick') is required: brew install imagemagick" >&2
  exit 1
fi
if [ ! -d "$ASSETS" ]; then
  echo "error: $ASSETS not found (iOSApp/Assets.xcassets must exist)" >&2
  exit 1
fi

# Prefer the crisp 1024 SVG rasterisation; fall back to the 192 px web raster.
MARK=""
for candidate in "$LOGOS/oripa_logo_v3.png" "$LOGOS/oripa_logo_v3_raster.png"; do
  if [ -s "$candidate" ]; then MARK="$candidate"; break; fi
done
if [ -z "$MARK" ]; then
  echo "error: no oripa_logo_v3 logo found in $LOGOS" >&2
  exit 1
fi

WORDMARK=""
for candidate in "$LOGOS/oripa_logo_text_v2_raster.png" "$LOGOS/oripa_logo_text_v2.png"; do
  if [ -s "$candidate" ]; then WORDMARK="$candidate"; break; fi
done

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# 8-bit keeps the icons small and avoids 16-bit PNGs in the asset catalog.
PNG_OPTS=(-depth 8 -strip -define png:exclude-chunks=date,time)

mkdir -p "$ICONSET" "$LAUNCHSET"

# Master icon: white background, no alpha channel (iOS masks the corners itself).
magick "$MARK" -background white -alpha remove -alpha off \
  -filter Lanczos -resize 1024x1024 "${PNG_OPTS[@]}" "$TMP/AppIcon-1024.png"

app_icon() { # <filename> <pixels>
  magick "$TMP/AppIcon-1024.png" -filter Lanczos -resize "$2x$2" \
    "${PNG_OPTS[@]}" "$ICONSET/$1"
}

# iPhone
app_icon 'AppIcon-20@2x.png' 40
app_icon 'AppIcon-20@3x.png' 60
app_icon 'AppIcon-29@2x.png' 58
app_icon 'AppIcon-29@3x.png' 87
app_icon 'AppIcon-40@2x.png' 80
app_icon 'AppIcon-40@3x.png' 120
app_icon 'AppIcon-60@2x.png' 120
app_icon 'AppIcon-60@3x.png' 180
# iPad
app_icon 'AppIcon-20@1x~ipad.png' 20
app_icon 'AppIcon-20@2x~ipad.png' 40
app_icon 'AppIcon-29@1x~ipad.png' 29
app_icon 'AppIcon-29@2x~ipad.png' 58
app_icon 'AppIcon-40@1x~ipad.png' 40
app_icon 'AppIcon-40@2x~ipad.png' 80
app_icon 'AppIcon-76@1x~ipad.png' 76
app_icon 'AppIcon-76@2x~ipad.png' 152
app_icon 'AppIcon-83.5@2x~ipad.png' 167
# App Store marketing icon
cp "$TMP/AppIcon-1024.png" "$ICONSET/AppIcon-1024.png"

cat > "$ICONSET/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "AppIcon-20@2x.png", "idiom" : "iphone", "scale" : "2x", "size" : "20x20" },
    { "filename" : "AppIcon-20@3x.png", "idiom" : "iphone", "scale" : "3x", "size" : "20x20" },
    { "filename" : "AppIcon-29@2x.png", "idiom" : "iphone", "scale" : "2x", "size" : "29x29" },
    { "filename" : "AppIcon-29@3x.png", "idiom" : "iphone", "scale" : "3x", "size" : "29x29" },
    { "filename" : "AppIcon-40@2x.png", "idiom" : "iphone", "scale" : "2x", "size" : "40x40" },
    { "filename" : "AppIcon-40@3x.png", "idiom" : "iphone", "scale" : "3x", "size" : "40x40" },
    { "filename" : "AppIcon-60@2x.png", "idiom" : "iphone", "scale" : "2x", "size" : "60x60" },
    { "filename" : "AppIcon-60@3x.png", "idiom" : "iphone", "scale" : "3x", "size" : "60x60" },
    { "filename" : "AppIcon-20@1x~ipad.png", "idiom" : "ipad", "scale" : "1x", "size" : "20x20" },
    { "filename" : "AppIcon-20@2x~ipad.png", "idiom" : "ipad", "scale" : "2x", "size" : "20x20" },
    { "filename" : "AppIcon-29@1x~ipad.png", "idiom" : "ipad", "scale" : "1x", "size" : "29x29" },
    { "filename" : "AppIcon-29@2x~ipad.png", "idiom" : "ipad", "scale" : "2x", "size" : "29x29" },
    { "filename" : "AppIcon-40@1x~ipad.png", "idiom" : "ipad", "scale" : "1x", "size" : "40x40" },
    { "filename" : "AppIcon-40@2x~ipad.png", "idiom" : "ipad", "scale" : "2x", "size" : "40x40" },
    { "filename" : "AppIcon-76@1x~ipad.png", "idiom" : "ipad", "scale" : "1x", "size" : "76x76" },
    { "filename" : "AppIcon-76@2x~ipad.png", "idiom" : "ipad", "scale" : "2x", "size" : "76x76" },
    { "filename" : "AppIcon-83.5@2x~ipad.png", "idiom" : "ipad", "scale" : "2x", "size" : "83.5x83.5" },
    { "filename" : "AppIcon-1024.png", "idiom" : "ios-marketing", "scale" : "1x", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON

# Launch screen wordmark (the previous port displayed it at 311x420 pt).
if [ -n "$WORDMARK" ]; then
  launch_logo() { # <filename> <max-dimension>  (bounded by a square box, keeps aspect)
    magick "$WORDMARK" -filter Lanczos -resize "$2x$2" "${PNG_OPTS[@]}" "$LAUNCHSET/$1"
  }
  launch_logo 'LaunchLogo.png' 420
  launch_logo 'LaunchLogo@2x.png' 840
  launch_logo 'LaunchLogo@3x.png' 1260
  cat > "$LAUNCHSET/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "LaunchLogo.png", "idiom" : "universal", "scale" : "1x" },
    { "filename" : "LaunchLogo@2x.png", "idiom" : "universal", "scale" : "2x" },
    { "filename" : "LaunchLogo@3x.png", "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON
else
  echo "warning: no ORIPA wordmark logo found; LaunchLogo imageset not generated" >&2
fi

echo "app icon set: $(find "$ICONSET" -maxdepth 1 -name '*.png' | wc -l | tr -d ' ') PNGs"
if [ -n "$WORDMARK" ]; then
  echo "launch logo: $(find "$LAUNCHSET" -maxdepth 1 -name '*.png' | wc -l | tr -d ' ') PNGs"
fi

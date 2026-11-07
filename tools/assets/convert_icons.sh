#!/bin/bash
# Rasterise the Android vector drawables (SVG, converted from the APK) into PNGs for
# the native app. Source of truth: oripa-port/src/assets/icons/*.svg
#
#   bash tools/assets/convert_icons.sh [path-to-oripa-port]
#
# Icons are rendered at 3x (96 px for 32 pt toolbar icons); the 160 dp help
# illustrations are rendered at 480 px. Multi-colour drawables keep their colours;
# MaterialIcon(tint:) uses them as template (alpha) masks.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="${1:-$ROOT/../oripa-port}"
ICONS="$SRC/src/assets/icons"
OUT="$ROOT/Sources/ORIPAUI/Resources/Icons"
LOGO_OUT="$ROOT/Sources/ORIPAUI/Resources/Logos"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT" "$LOGO_OUT"

fail=0
for svg in "$ICONS"/*.svg; do
  base="$(basename "$svg" .svg)"
  case "$base" in
    oripa_logo_v3)      out="$LOGO_OUT/oripa_logo_v3.png";      size=1024 ;;
    oripa_logo_text_v2) out="$LOGO_OUT/oripa_logo_text_v2.png"; size=1024 ;;
    *_help*)            out="$OUT/$base.png";                   size=480 ;;
    *)                  out="$OUT/$base.png";                   size=96 ;;
  esac
  norm="$TMP/$base.svg"
  python3 "$ROOT/tools/assets/normalize_svg.py" "$svg" "$norm"
  if magick -background none -density 384 "$norm" -resize "${size}x${size}" "$out" 2>/dev/null && [ -s "$out" ]; then
    continue
  fi
  # Fallback: QuickLook can rasterise SVG on macOS without extra tooling.
  rm -f "$out"
  qlmanage -t -s "$size" -o "$TMP" "$svg" >/dev/null 2>&1 || true
  if [ -s "$TMP/$base.svg.png" ]; then
    cp "$TMP/$base.svg.png" "$out"
  else
    echo "FAILED: $base" >&2
    fail=$((fail+1))
  fi
done
# Raster logos (already ~1024 px PNGs in the web port) override the SVG rasterisations.
cp "$SRC/src/assets/img/oripa_logo_v3_raster.png" "$LOGO_OUT/oripa_logo_v3_raster.png"
cp "$SRC/src/assets/img/oripa_logo_text_v2_raster.png" "$LOGO_OUT/oripa_logo_text_v2_raster.png"
echo "icons: $(ls "$OUT" | wc -l | tr -d ' ')  logos: $(ls "$LOGO_OUT" | wc -l | tr -d ' ')  failed: $fail"
[ "$fail" -eq 0 ]

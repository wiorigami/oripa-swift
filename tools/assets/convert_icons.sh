#!/bin/bash
# Rasterise the Android vector drawables (SVG, converted from the APK) into PNGs for
# the native app. Source of truth: oripa-port/src/assets/icons/*.svg
#
#   bash tools/assets/convert_icons.sh [path-to-oripa-port]
#
# Output (committed to git, deterministic):
#   Sources/ORIPAUI/Resources/Icons/<name>.png   96 px toolbar icons, 480 px help art
#   Sources/ORIPAUI/Resources/Logos/*.png        1024 px logos
#   iOSApp/Assets.xcassets/**                    AppIcon set + LaunchLogo (via make_app_icons.sh)
#
# Icons are rendered at 3x (96 px for 32 pt toolbar icons); the 160 dp help
# illustrations are rendered at 480 px. Multi-colour drawables keep their colours;
# MaterialIcon(tint:) uses them as template (alpha) mask, so every icon MUST have
# non-zero alpha -- checked at the end (non-zero exit on a blank icon).
#
# Transform attributes are baked into the path data by normalize_svg.py first
# (ImageMagick's internal SVG renderer ignores group transforms), with a headless
# Chrome fallback for SVGs ImageMagick still cannot handle. Only needed when the
# upstream SVG set changes; the generated PNGs are committed.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="${1:-$ROOT/../oripa-port}"
ICONS_SRC="$SRC/src/assets/icons"
IMAGES_SRC="$SRC/src/assets/img"
# Decoded APK resources: some drawables reference `@string/path_...` for their path
# data, resolved by normalize_svg.py from values/strings.xml.
export ORIPA_SVG_RES_DIR="$SRC/rev/apktool/res"
OUT="$ROOT/Sources/ORIPAUI/Resources/Icons"
LOGO_OUT="$ROOT/Sources/ORIPAUI/Resources/Logos"
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail=0
warn=0

log() { printf '%s\n' "$*"; }
err() { printf '%s\n' "$*" >&2; }

if [ ! -d "$ICONS_SRC" ]; then
  err "error: icon source directory not found: $ICONS_SRC"
  err "usage: bash tools/assets/convert_icons.sh [path-to-oripa-port]"
  exit 1
fi
if ! command -v magick >/dev/null 2>&1; then
  err "error: ImageMagick 7 ('magick') is required: brew install imagemagick"
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  err "error: python3 is required (SVG normaliser)"
  exit 1
fi

mkdir -p "$OUT" "$LOGO_OUT"

# render_svg <source.svg> <output.png> <size>
# Tries: normalised SVG -> ImageMagick, normalised SVG -> headless Chrome,
# original SVG -> QuickLook thumbnail (opaque background: last resort, warns).
render_svg() {
  local svg="$1" out="$2" size="$3" base norm
  base="$(basename "$svg" .svg)"
  norm="$TMP/$base.svg"
  rm -f "$out"

  if python3 "$ROOT/tools/assets/normalize_svg.py" "$svg" "$norm" 2>"$TMP/normalize.err"; then
    if magick -background none -density 384 "$norm" \
        -filter Lanczos -resize "${size}x${size}" -depth 8 \
        -strip -define png:exclude-chunks=date,time "$out" 2>/dev/null && [ -s "$out" ]; then
      return 0
    fi
  else
    err "  normalize_svg: $base: $(cat "$TMP/normalize.err")"
    cp "$svg" "$TMP/$base.svg" 2>/dev/null || true
    norm="$TMP/$base.svg"
  fi

  # Fallback 1: Chrome renders full SVG 1.1 (transforms, arcs) with transparency.
  if [ -x "$CHROME" ] && [ -s "$norm" ]; then
    local html="$TMP/$base.html"
    cat > "$html" <<EOF
<!doctype html><html><body style="margin:0;background:transparent">
<img src="file://$norm" style="display:block;width:${size}px;height:${size}px">
</body></html>
EOF
    rm -f "$out"
    "$CHROME" --headless=new --disable-gpu --no-sandbox --hide-scrollbars \
      --allow-file-access-from-files --default-background-color=00000000 \
      --force-device-scale-factor=1 --window-size="${size},${size}" \
      --screenshot="$out" "file://$html" >/dev/null 2>&1 || true
    if [ -s "$out" ]; then
      magick "$out" -depth 8 -strip -define png:exclude-chunks=date,time "$out" 2>/dev/null || true
      return 0
    fi
  fi

  # Fallback 2: QuickLook (opaque white background -- may break template icons).
  rm -f "$out"
  qlmanage -t -s "$size" -o "$TMP" "$svg" >/dev/null 2>&1 || true
  if [ -s "$TMP/$base.svg.png" ]; then
    cp "$TMP/$base.svg.png" "$out"
    err "  warning: $base rasterised via QuickLook (opaque background) -- check icon"
    warn=$((warn+1))
    return 0
  fi

  err "FAILED to rasterise: $base"
  return 1
}

# Non-zero alpha for every icon (template tinting would otherwise render nothing).
has_alpha() {
  local file="$1" max
  max="$(magick identify -format '%[fx:maxima.a]' "$file" 2>/dev/null || echo 0)"
  awk -v v="$max" 'BEGIN { exit !(v + 0 > 0.01) }'
}

log "rasterising SVGs from $ICONS_SRC"
for svg in "$ICONS_SRC"/*.svg; do
  [ -e "$svg" ] || continue
  base="$(basename "$svg" .svg)"
  case "$base" in
    oripa_logo_v3)      out="$LOGO_OUT/oripa_logo_v3.png";      size=1024 ;;
    oripa_logo_text_v2) out="$LOGO_OUT/oripa_logo_text_v2.png"; size=1024 ;;
    *_help*)            out="$OUT/$base.png";                   size=480 ;;
    *)                  out="$OUT/$base.png";                   size=96 ;;
  esac
  if render_svg "$svg" "$out" "$size" && has_alpha "$out"; then
    continue
  fi
  if [ -s "$out" ] && ! has_alpha "$out"; then
    err "BLANK/TRANSPARENT icon: $base"
  fi
  fail=$((fail+1))
done

# Raster logos (already ~1024 px PNGs in the web port) override the SVG rasterisations.
for logo in oripa_logo_v3_raster oripa_logo_text_v2_raster; do
  if [ -s "$IMAGES_SRC/$logo.png" ]; then
    cp "$IMAGES_SRC/$logo.png" "$LOGO_OUT/$logo.png"
  else
    err "warning: missing raster logo $IMAGES_SRC/$logo.png"
    warn=$((warn+1))
  fi
done

# Verify every committed logo has content and every icon is non-blank.
for logo in "$LOGO_OUT"/*.png; do
  [ -e "$logo" ] || continue
  if ! has_alpha "$logo"; then
    err "BLANK/TRANSPARENT logo: $(basename "$logo")"
    fail=$((fail+1))
  fi
done

icon_count="$(find "$OUT" -maxdepth 1 -name '*.png' | wc -l | tr -d ' ')"
logo_count="$(find "$LOGO_OUT" -maxdepth 1 -name '*.png' | wc -l | tr -d ' ')"
log "icons: $icon_count  logos: $logo_count  warnings: $warn  failures: $fail"
if [ "$fail" -ne 0 ]; then
  err "icon conversion failed"
  exit 1
fi

# iOS app icon set + launch logo (derived from the logos above).
if [ -f "$ROOT/tools/assets/make_app_icons.sh" ] && [ -d "$ROOT/iOSApp" ]; then
  bash "$ROOT/tools/assets/make_app_icons.sh"
fi

log "icon conversion OK"

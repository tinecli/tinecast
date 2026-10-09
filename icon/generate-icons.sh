#!/usr/bin/env bash
# Render an icon SVG into an Xcode AppIcon.appiconset with every macOS size.
# Usage: generate-icons.sh <icon.svg> [output.appiconset]
# Requires: rsvg-convert (brew install librsvg).
set -euo pipefail
cd "$(dirname "$0")"

SVG="${1:?usage: generate-icons.sh <icon.svg> [output.appiconset]}"
OUT="${2:-../TineCast/Assets.xcassets/AppIcon.appiconset}"
mkdir -p "$OUT"

images=()
for size in 16 32 128 256 512; do
  for variant in 1: 2:@2x; do
    scale="${variant%%:*}"
    px=$((size * scale))
    name="icon_${size}x${size}${variant#*:}.png"
    rsvg-convert -w "$px" -h "$px" "$SVG" -o "$OUT/$name"
    images+=("    { \"idiom\" : \"mac\", \"size\" : \"${size}x${size}\", \"scale\" : \"${scale}x\", \"filename\" : \"$name\" }")
  done
done

{
  echo '{'
  echo '  "images" : ['
  (IFS=$'\n'; echo "${images[*]}") | sed '$!s/$/,/'
  echo '  ],'
  echo '  "info" : { "version" : 1, "author" : "xcode" }'
  echo '}'
} > "$OUT/Contents.json"
echo "$OUT ($(ls "$OUT" | wc -l | tr -d ' ') files)"

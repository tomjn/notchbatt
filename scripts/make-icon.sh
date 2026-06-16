#!/usr/bin/env bash
# Regenerate Resources/AppIcon.icns from Resources/AppIcon.svg.
# Requires rsvg-convert (brew install librsvg) and iconutil (macOS). The .icns is
# committed, so make-app.sh / CI never need this — only run it when the art changes.
set -euo pipefail

cd "$(dirname "$0")/.."

SVG="Resources/AppIcon.svg"
SET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$SET"

# size:filename pairs for a standard macOS iconset
for entry in \
  16:icon_16x16 32:icon_16x16@2x 32:icon_32x32 64:icon_32x32@2x \
  128:icon_128x128 256:icon_128x128@2x 256:icon_256x256 512:icon_256x256@2x \
  512:icon_512x512 1024:icon_512x512@2x
do
  px="${entry%%:*}"
  name="${entry##*:}"
  rsvg-convert -w "$px" -h "$px" "$SVG" -o "$SET/$name.png"
done

iconutil -c icns "$SET" -o Resources/AppIcon.icns
echo "Wrote Resources/AppIcon.icns"

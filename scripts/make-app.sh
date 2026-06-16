#!/usr/bin/env bash
# Assemble NotchBatt.app from the release binary.
#
# Usage: scripts/make-app.sh [version]
#   version defaults to `git describe`; a leading "v" is stripped so a tag like
#   v1.2.0 becomes 1.2.0 in Info.plist.
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-$(git describe --tags --always 2>/dev/null || echo 0.0.0)}"
VERSION="${VERSION#v}"

APP="NotchBatt.app"
CONTENTS="$APP/Contents"

swift build -c release

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

cp .build/release/notchbatt "$CONTENTS/MacOS/notchbatt"
cp Resources/AppIcon.icns "$CONTENTS/Resources/AppIcon.icns"
sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$CONTENTS/Info.plist"

# Ad-hoc sign so the app launches locally without a "damaged / cannot be opened"
# Gatekeeper error. No Developer account or notarization involved.
codesign -s - --force --deep "$APP"

echo "Built $APP (version $VERSION)"

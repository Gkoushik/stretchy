#!/bin/bash
# Build a release DMG: universal Stretchy.app plus an Applications shortcut for drag-to-install.
# Usage: ./make-release.sh 1.0.0
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:?usage: ./make-release.sh <version>}"
DIST=dist
DMG="$DIST/Stretchy-$VERSION.dmg"

VERSION="$VERSION" ./build.sh

echo "==> Staging DMG contents"
rm -rf "$DIST" && mkdir -p "$DIST/stage"
ditto Stretchy.app "$DIST/stage/Stretchy.app"
ln -s /Applications "$DIST/stage/Applications"

echo "==> Creating $DMG"
hdiutil create -volname "Stretchy $VERSION" -srcfolder "$DIST/stage" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
rm -rf "$DIST/stage"

(cd "$DIST" && shasum -a 256 "$(basename "$DMG")" > "$(basename "$DMG").sha256")
echo "==> Done: $DMG"
cat "$DMG.sha256"

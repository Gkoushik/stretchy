#!/bin/bash
#!/bin/bash
# Build Stretchy.app from source using swiftc (no Xcode project needed).
# Produces a universal binary (Apple Silicon + Intel). Set VERSION to stamp the bundle, e.g. VERSION=1.0.0 ./build.sh
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Stretchy"
APP_DIR="${APP_NAME}.app"
BUNDLE_ID="com.gannik.stretchy"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
RES="$APP_DIR/Contents/Resources"

echo "==> Cleaning previous build"
rm -rf "$APP_DIR"

echo "==> Creating bundle layout"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$RES"

echo "==> Compiling Swift source (arm64 + x86_64)"
TMP_BIN="$(mktemp -d)"
for ARCH in arm64 x86_64; do
  swiftc \
    -swift-version 5 \
    -O \
    -target "$ARCH-apple-macos13.0" \
    -framework AppKit \
    -framework SwiftUI \
    -framework WebKit \
    -o "$TMP_BIN/$APP_NAME-$ARCH" \
    Sources/main.swift
done
lipo -create "$TMP_BIN/$APP_NAME-arm64" "$TMP_BIN/$APP_NAME-x86_64" -output "$APP_DIR/Contents/MacOS/$APP_NAME"
rm -rf "$TMP_BIN"

echo "==> Assembling player.html (template + Stretchy CSS + SVG body)"
# Replace each marker in web/player.html with the contents of a file.
inline() { # $1 marker, $2 file
  awk -v m="$1" -v f="$2" '{
    i = index($0, m)
    if (i) { printf "%s", substr($0, 1, i - 1); while ((getline l < f) > 0) print l; close(f); print substr($0, i + length(m)) }
    else print
  }'
}
inline '/*STRETCHY_CSS*/' mochi/stretchy.css < web/player.html \
  | inline '<!--MOCHI_BODY-->' mochi/stretchy-body.svg.txt > "$RES/player.html"

echo "==> Copying moves.json"
cp moves.json "$RES/moves.json"

echo "==> Copying app icon"
if [ -f Stretchy.icns ]; then cp Stretchy.icns "$RES/Stretchy.icns"; else echo "   (Stretchy.icns not found — skipping)"; fi

echo "==> Copying menu bar image"
if [ -f menubar.png ]; then cp menubar.png "$RES/menubar.png"; else echo "   (menubar.png not found — skipping)"; fi

echo "==> Writing Info.plist"
cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>Stretchy</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>Stretchy</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "==> Ad-hoc code signing"
codesign --force --deep --sign - "$APP_DIR" 2>/dev/null || echo "   (codesign skipped)"

echo "==> Done: $(pwd)/$APP_DIR"

#!/bin/bash
# Build StretchReminder.app from source using swiftc (no Xcode project needed).
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="Stretchy"
APP_DIR="${APP_NAME}.app"
BUNDLE_ID="com.gannik.stretchy"
RES="$APP_DIR/Contents/Resources"

echo "==> Cleaning previous build"
rm -rf "$APP_DIR"

echo "==> Creating bundle layout"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$RES"

echo "==> Compiling Swift source"
swiftc \
  -swift-version 5 \
  -O \
  -framework AppKit \
  -framework SwiftUI \
  -framework WebKit \
  -o "$APP_DIR/Contents/MacOS/$APP_NAME" \
  Sources/main.swift

echo "==> Assembling player.html (inlines Mochi CSS + SVG)"
{
  cat <<'HTML_HEAD'
<!doctype html><html><head><meta charset="utf-8">
<style>
html,body{margin:0;padding:0;background:transparent;overflow:hidden}
svg.mochi{width:100vw;height:100vh;display:block}
HTML_HEAD
  cat mochi/mochi.css
  cat <<'HTML_MID'
</style></head><body>
<svg class="mochi" id="m" viewBox="232 46 216 290" preserveAspectRatio="xMidYMid meet" role="img" aria-label="Mochi stretching">
HTML_MID
  cat mochi/mochi-body.svg.txt
  cat <<'HTML_TAIL'
</svg>
<script>
const GROUP_CLASS={eye:'g-eye',neck:'g-neck',sh:'g-sh',fb:''};
const GROUP={ecirc:'eye',eud:'eye',elr:'eye',turn:'neck',tilt:'neck',roll:'neck',shrug:'sh',circles:'sh',cross:'sh',reach:'fb',side:'fb',yawn:'fb'};
const svg=document.getElementById('m');
window.setMove=function(move,guides){
  svg.setAttribute('class','mochi'); void svg.getBoundingClientRect();
  svg.setAttribute('class',['mochi',move,GROUP_CLASS[GROUP[move]||''],guides?'':'no-guides'].filter(Boolean).join(' '));
};
window.setMove('roll',false);
</script></body></html>
HTML_TAIL
} > "$RES/player.html"

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
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
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

#!/bin/bash
# Regenerate the app icon (Stretchy.icns) and the menu bar image (menubar.png)
# from the Mochi SVG assets. Requires macOS (swiftc, sips, iconutil).
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Compiling offscreen SVG renderer"
swiftc -O -framework AppKit -framework WebKit -o tools/iconrender tools/iconrender.swift

echo "==> Building icon.html (squircle background + Mochi face)"
{
  echo '<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;padding:0;background:transparent}svg{display:block}</style></head><body>'
  echo '<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">'
  echo '<defs>'
  echo '<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">'
  echo '<stop offset="0" stop-color="#6E7BF2"/><stop offset="1" stop-color="#9A4FD0"/></linearGradient>'
  echo '<clipPath id="sq"><rect x="0" y="0" width="1024" height="1024" rx="230" ry="230"/></clipPath>'
  echo '</defs>'
  echo '<style>'
  cat mochi/mochi.css
  echo '.mochi .eo{opacity:1!important}.mochi .ec{opacity:0!important}'
  echo '</style>'
  echo '<g clip-path="url(#sq)">'
  echo '<rect width="1024" height="1024" fill="url(#bg)"/>'
  echo '<ellipse cx="512" cy="430" rx="360" ry="330" fill="#ffffff" opacity="0.10"/>'
  echo '<svg x="150" y="140" width="724" height="724" viewBox="254 58 172 172">'
  echo '<g class="mochi no-guides">'
  cat mochi/mochi-body.svg.txt
  echo '</g></svg>'
  echo '</g></svg>'
  echo '</body></html>'
} > icon.html

echo "==> Rendering 1024px master PNG"
./tools/iconrender "$PWD/icon.html" "$PWD/icon-1024.png" 1024

echo "==> Building Stretchy.icns"
ICS=icon.iconset
rm -rf "$ICS" && mkdir -p "$ICS"
gen(){ sips -z "$2" "$2" icon-1024.png --out "$ICS/$1" >/dev/null 2>&1; }
gen icon_16x16.png 16;      gen icon_16x16@2x.png 32
gen icon_32x32.png 32;      gen icon_32x32@2x.png 64
gen icon_128x128.png 128;   gen icon_128x128@2x.png 256
gen icon_256x256.png 256;   gen icon_256x256@2x.png 512
gen icon_512x512.png 512;   gen icon_512x512@2x.png 1024
iconutil -c icns "$ICS" -o Stretchy.icns

echo "==> Building menubar.png (face only, transparent)"
{
  echo '<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;padding:0;background:transparent}svg{display:block}</style></head><body>'
  echo '<svg xmlns="http://www.w3.org/2000/svg" width="72" height="72" viewBox="0 0 72 72">'
  echo '<style>'
  cat mochi/mochi.css
  echo '.mochi .eo{opacity:1!important}.mochi .ec{opacity:0!important}'
  echo '</style>'
  echo '<svg x="0" y="0" width="72" height="72" viewBox="278 76 124 128">'
  echo '<g class="mochi no-guides">'
  cat mochi/mochi-body.svg.txt
  echo '</g></svg>'
  echo '</svg></body></html>'
} > menubar.html
./tools/iconrender "$PWD/menubar.html" "$PWD/menubar.png" 72

echo "==> Done: Stretchy.icns, menubar.png"

#!/bin/bash
set -euo pipefail
[ "$(uname -s)" = Darwin ] || { echo 'Native macOS build required.' >&2; exit 1; }
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
cd "$ROOT"
python3 tools/prepare-macos.py
APP="$ROOT/build/macos/Rise On Air.app"
RESOURCES="$APP/Contents/Resources"
mkdir -p "$APP/Contents/MacOS" "$ROOT/dist/macos" "$ROOT/build/macos/icon.iconset"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" assets/rise-on-air-icon-v2.png --out "$ROOT/build/macos/icon.iconset/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" assets/rise-on-air-icon-v2.png --out "$ROOT/build/macos/icon.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ROOT/build/macos/icon.iconset" -o "$RESOURCES/RiseOnAir.icns"
for arch in arm64 x86_64; do
  swiftc -O -target "${arch}-apple-macosx14.0" -framework AppKit -framework WebKit macos/RiseOnAir.swift -o "$ROOT/build/macos/RiseOnAir-$arch"
done
lipo -create "$ROOT/build/macos/RiseOnAir-arm64" "$ROOT/build/macos/RiseOnAir-x86_64" -output "$APP/Contents/MacOS/RiseOnAir"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"
printf '%s\n' "$APP"

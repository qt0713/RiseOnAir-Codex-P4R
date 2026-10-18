#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
VERSION="$(tr -d '[:space:]' < "$ROOT/macos/VERSION")"
APP="$ROOT/build/macos/Rise On Air.app"
OUTPUT="$ROOT/dist/macos"
mkdir -p "$OUTPUT" "$ROOT/build/macos/dmg"
ditto "$APP" "$ROOT/build/macos/dmg/Rise On Air.app"
ln -s /Applications "$ROOT/build/macos/dmg/Applications"
cp "$ROOT/docs/MACOS.md" "$ROOT/build/macos/dmg/使用说明.md"
hdiutil create -volname 'Rise On Air' -srcfolder "$ROOT/build/macos/dmg" -ov -format UDZO "$OUTPUT/RiseOnAir-v${VERSION}-macos-universal.dmg"
ditto -c -k --keepParent "$APP" "$OUTPUT/RiseOnAir-v${VERSION}-macos-universal.zip"
(cd "$OUTPUT" && shasum -a 256 ./*.dmg ./*.zip > SHA256SUMS-macos.txt)

#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
APP="$ROOT/build/macos/Rise On Air.app"
OUT="$ROOT/build/macos-test-$(uname -m)"
mkdir -p "$OUT"
find "$APP/Contents/Resources/engine/scripts" -name '*.sh' -print0 | while IFS= read -r -d '' f; do bash -n "$f"; done
bash -n "$APP/Contents/Resources/rise-control.sh"
node --check "$APP/Contents/Resources/engine/scripts/injector.mjs"
node "$APP/Contents/Resources/engine/scripts/injector.mjs" --check-payload --theme-dir "$APP/Contents/Resources/theme" > "$OUT/payload.json"
codesign --verify --deep --strict "$APP"
lipo -verify_arch arm64 x86_64 "$APP/Contents/MacOS/RiseOnAir"
python3 "$ROOT/macos/tests/test-resources.py" "$APP" | tee "$OUT/resources.json"
RISE_TEST_OUTPUT="$OUT" "$APP/Contents/MacOS/RiseOnAir" --self-test --muted
python3 - "$OUT" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1])
result=json.loads((p/'rise-native-test.json').read_text())
assert result['pass'],result
assert (p/'preview.png').stat().st_size>10000
print(json.dumps(result,ensure_ascii=False))
PY

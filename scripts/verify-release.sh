#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_DIR="${1:-$PROJECT_DIR/dist/Universal Control Helper.app}"

codesign --verify --deep --strict --verbose=2 "$APP_DIR"
plutil -lint "$APP_DIR/Contents/Info.plist"

if [[ "${REQUIRE_UNIVERSAL:-0}" == "1" ]]; then
  ARCHS="$(lipo -archs "$APP_DIR/Contents/MacOS/UniversalControlHelper")"
  [[ "$ARCHS" == *arm64* && "$ARCHS" == *x86_64* ]]
fi

otool -L "$APP_DIR/Contents/MacOS/UniversalControlHelper" | grep -q '@rpath/Sparkle.framework'
otool -l "$APP_DIR/Contents/MacOS/UniversalControlHelper" | grep -q '@executable_path/../Frameworks'
test -d "$APP_DIR/Contents/Frameworks/Sparkle.framework"

"$APP_DIR/Contents/MacOS/UniversalControlHelper" &
APP_PID=$!
sleep 1
if ! kill -0 "$APP_PID" 2>/dev/null; then
  wait "$APP_PID"
  exit 1
fi
kill "$APP_PID"
wait "$APP_PID" 2>/dev/null || true

echo "Release verification passed: $APP_DIR"

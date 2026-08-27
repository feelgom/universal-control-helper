#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_DIR="${1:-$PROJECT_DIR/dist/UniInputFix.app}"

codesign --verify --deep --strict --verbose=2 "$APP_DIR"
plutil -lint "$APP_DIR/Contents/Info.plist"

if [[ "${REQUIRE_UNIVERSAL:-0}" == "1" ]]; then
  ARCHS="$(lipo -archs "$APP_DIR/Contents/MacOS/UniInputFix")"
  [[ "$ARCHS" == *arm64* && "$ARCHS" == *x86_64* ]]
fi

otool -L "$APP_DIR/Contents/MacOS/UniInputFix" | grep -q '@rpath/Sparkle.framework'
test -d "$APP_DIR/Contents/Frameworks/Sparkle.framework"

echo "Release verification passed: $APP_DIR"

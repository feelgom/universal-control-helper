#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_DIR="${1:-$PROJECT_DIR/dist/Universal Control Helper.app}"

codesign --verify --deep --strict --verbose=2 "$APP_DIR"
plutil -lint "$APP_DIR/Contents/Info.plist"
test -f "$APP_DIR/Contents/Resources/Assets.car"
test -f "$APP_DIR/Contents/Resources/MenuBarIcon.png"
test -f "$APP_DIR/Contents/Resources/MenuBarIcon@2x.png"

if [[ "${REQUIRE_UNIVERSAL:-0}" == "1" ]]; then
  ARCHS="$(lipo -archs "$APP_DIR/Contents/MacOS/UniversalControlHelper")"
  [[ "$ARCHS" == *arm64* && "$ARCHS" == *x86_64* ]]
fi

otool -L "$APP_DIR/Contents/MacOS/UniversalControlHelper" | grep -q '@rpath/Sparkle.framework'
otool -l "$APP_DIR/Contents/MacOS/UniversalControlHelper" | grep -q '@executable_path/../Frameworks'
test -d "$APP_DIR/Contents/Frameworks/Sparkle.framework"

if [[ "${REQUIRE_DEVELOPER_ID:-0}" == "1" ]]; then
  SIGNING_INFO="$(codesign -dvvv "$APP_DIR" 2>&1)"
  if ! echo "$SIGNING_INFO" | grep -q 'Authority=Developer ID Application:'; then
    echo "Release app is not signed with Developer ID Application" >&2
    exit 1
  fi
  if ! echo "$SIGNING_INFO" | grep -Eq 'TeamIdentifier=[A-Z0-9]+'; then
    echo "Release app does not contain a Developer Team identifier" >&2
    exit 1
  fi
  if ! echo "$SIGNING_INFO" | grep -q 'flags=.*runtime'; then
    echo "Release app does not have Hardened Runtime enabled" >&2
    exit 1
  fi

  TEAM_ID="$(echo "$SIGNING_INFO" | sed -n 's/^TeamIdentifier=//p')"
  SPARKLE_CONTENTS="$APP_DIR/Contents/Frameworks/Sparkle.framework/Versions/Current"
  SIGNED_COMPONENTS=(
    "$SPARKLE_CONTENTS/XPCServices/Installer.xpc"
    "$SPARKLE_CONTENTS/XPCServices/Downloader.xpc"
    "$SPARKLE_CONTENTS/Autoupdate"
    "$SPARKLE_CONTENTS/Updater.app"
    "$APP_DIR/Contents/Frameworks/Sparkle.framework"
  )
  for component in "${SIGNED_COMPONENTS[@]}"; do
    COMPONENT_INFO="$(codesign -dvvv "$component" 2>&1)"
    if ! echo "$COMPONENT_INFO" | grep -q "TeamIdentifier=$TEAM_ID"; then
      echo "Signing team mismatch: $component" >&2
      exit 1
    fi
    if ! echo "$COMPONENT_INFO" | grep -q 'flags=.*runtime'; then
      echo "Hardened Runtime is missing: $component" >&2
      exit 1
    fi
  done
fi

if [[ "${REQUIRE_NOTARIZED:-0}" == "1" ]]; then
  xcrun stapler validate "$APP_DIR"
  spctl --assess --type execute --verbose=4 "$APP_DIR"
fi

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

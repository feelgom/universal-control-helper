#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_DIR="$PROJECT_DIR/dist/UniInputFix.app"
SPARKLE_FRAMEWORK="$PROJECT_DIR/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
PLIST_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Resources/Info.plist")"
APP_VERSION="${APP_VERSION:-$PLIST_VERSION}"
BUILD_NUMBER="${BUILD_NUMBER:-$APP_VERSION}"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"

cd "$PROJECT_DIR"

ARCH_ARGS=()
if [[ "${BUILD_UNIVERSAL:-0}" == "1" ]]; then
  ARCH_ARGS=(--arch arm64 --arch x86_64)
fi

swift build -c release "${ARCH_ARGS[@]}"
BIN_DIR="$(swift build -c release "${ARCH_ARGS[@]}" --show-bin-path)"

if [[ ! -f "$BIN_DIR/UniInputFix" ]]; then
  echo "UniInputFix executable was not produced at $BIN_DIR" >&2
  exit 1
fi

if [[ ! -d "$SPARKLE_FRAMEWORK" ]]; then
  echo "Sparkle.framework is missing. Run 'swift package resolve' first." >&2
  exit 1
fi

if [[ -d "$APP_DIR" ]]; then
  rm -rf "$APP_DIR"
fi

mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$APP_DIR/Contents/Frameworks"
cp "$BIN_DIR/UniInputFix" "$APP_DIR/Contents/MacOS/UniInputFix"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
ditto "$SPARKLE_FRAMEWORK" "$APP_DIR/Contents/Frameworks/Sparkle.framework"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_DIR/Contents/MacOS/UniInputFix"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP_DIR/Contents/Info.plist"

codesign --force --deep --sign "$CODE_SIGN_IDENTITY" "$APP_DIR/Contents/Frameworks/Sparkle.framework"
codesign --force --deep --sign "$CODE_SIGN_IDENTITY" "$APP_DIR"

echo "$APP_DIR"

#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_DIR="$PROJECT_DIR/dist/Universal Control Helper.app"
SPARKLE_FRAMEWORK="$PROJECT_DIR/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
PLIST_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$PROJECT_DIR/Resources/Info.plist")"
APP_VERSION="${APP_VERSION:-$PLIST_VERSION}"
BUILD_NUMBER="${BUILD_NUMBER:-$APP_VERSION}"
CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
CODE_SIGN_KEYCHAIN="${CODE_SIGN_KEYCHAIN:-}"

cd "$PROJECT_DIR"

ARCH_ARGS=()
if [[ "${BUILD_UNIVERSAL:-0}" == "1" ]]; then
  ARCH_ARGS=(--arch arm64 --arch x86_64)
fi

swift build -c release "${ARCH_ARGS[@]}"
BIN_DIR="$(swift build -c release "${ARCH_ARGS[@]}" --show-bin-path)"

if [[ ! -f "$BIN_DIR/UniversalControlHelper" ]]; then
  echo "UniversalControlHelper executable was not produced at $BIN_DIR" >&2
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
cp "$BIN_DIR/UniversalControlHelper" "$APP_DIR/Contents/MacOS/UniversalControlHelper"
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$PROJECT_DIR/Resources/MenuBarIcon.png" "$APP_DIR/Contents/Resources/MenuBarIcon.png"
cp "$PROJECT_DIR/Resources/MenuBarIcon@2x.png" "$APP_DIR/Contents/Resources/MenuBarIcon@2x.png"
xcrun actool "$PROJECT_DIR/Resources/Assets.xcassets" \
  --compile "$APP_DIR/Contents/Resources" \
  --platform macosx \
  --minimum-deployment-target 13.0 \
  --app-icon AppIcon \
  --output-partial-info-plist "$PROJECT_DIR/.build/assetcatalog_generated_info.plist"
ditto "$SPARKLE_FRAMEWORK" "$APP_DIR/Contents/Frameworks/Sparkle.framework"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_DIR/Contents/MacOS/UniversalControlHelper"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $APP_VERSION" "$APP_DIR/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP_DIR/Contents/Info.plist"

SIGN_ARGS=(--force --sign "$CODE_SIGN_IDENTITY")
if [[ "$CODE_SIGN_IDENTITY" != "-" ]]; then
  SIGN_ARGS+=(--options runtime --timestamp)
fi
if [[ -n "$CODE_SIGN_KEYCHAIN" ]]; then
  SIGN_ARGS+=(--keychain "$CODE_SIGN_KEYCHAIN")
fi

# Sparkle contains nested helper apps and XPC services. Sign them from the
# inside out, preserving Downloader's entitlement as recommended by Sparkle.
SPARKLE_CONTENTS="$APP_DIR/Contents/Frameworks/Sparkle.framework/Versions/Current"
codesign "${SIGN_ARGS[@]}" "$SPARKLE_CONTENTS/XPCServices/Installer.xpc"
codesign "${SIGN_ARGS[@]}" --preserve-metadata=entitlements \
  "$SPARKLE_CONTENTS/XPCServices/Downloader.xpc"
codesign "${SIGN_ARGS[@]}" "$SPARKLE_CONTENTS/Autoupdate"
codesign "${SIGN_ARGS[@]}" "$SPARKLE_CONTENTS/Updater.app"
codesign "${SIGN_ARGS[@]}" "$APP_DIR/Contents/Frameworks/Sparkle.framework"
codesign "${SIGN_ARGS[@]}" "$APP_DIR"

echo "$APP_DIR"

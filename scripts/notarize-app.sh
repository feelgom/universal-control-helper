#!/bin/zsh
set -euo pipefail

PROJECT_DIR="${0:A:h:h}"
APP_DIR="${1:-$PROJECT_DIR/dist/Universal Control Helper.app}"

: "${APPLE_ID:?APPLE_ID is required}"
: "${APPLE_APP_SPECIFIC_PASSWORD:?APPLE_APP_SPECIFIC_PASSWORD is required}"
: "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required}"

if [[ ! -d "$APP_DIR" ]]; then
  echo "App bundle not found: $APP_DIR" >&2
  exit 1
fi

NOTARY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/universal-control-helper-notary.XXXXXX")"
NOTARY_ARCHIVE="$NOTARY_DIR/UniversalControlHelper.zip"
trap 'rm -rf "$NOTARY_DIR"' EXIT

ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$NOTARY_ARCHIVE"
xcrun notarytool submit "$NOTARY_ARCHIVE" \
  --apple-id "$APPLE_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD" \
  --team-id "$APPLE_TEAM_ID" \
  --wait
xcrun stapler staple "$APP_DIR"
xcrun stapler validate "$APP_DIR"

echo "Notarization passed and ticket stapled: $APP_DIR"

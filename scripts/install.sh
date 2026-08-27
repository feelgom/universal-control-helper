#!/usr/bin/env bash
set -euo pipefail

REPOSITORY="feelgom/universal-control-helper"
ASSET_NAME="UniversalControlHelper-macOS-universal.zip"
APP_NAME="Universal Control Helper.app"
LEGACY_APP_NAME="UniInputFix.app"
INSTALL_DIR="/Applications"
LAUNCH_APP=1
STAGING_PATH=""

usage() {
  printf '%s\n' \
    "Universal Control Helper installer" \
    "" \
    "Usage: install.sh [--install-dir PATH] [--no-launch]" \
    "" \
    "  --install-dir PATH  Install directory (default: /Applications)" \
    "  --no-launch         Do not launch the app after installation" \
    "  -h, --help          Show this help"
}

fail() {
  printf '오류: %s\n' "$1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-dir)
      [[ $# -ge 2 ]] || fail "--install-dir 뒤에 경로가 필요합니다."
      INSTALL_DIR="$2"
      shift 2
      ;;
    --no-launch)
      LAUNCH_APP=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "알 수 없는 옵션: $1"
      ;;
  esac
done

[[ "$(uname -s)" == "Darwin" ]] || fail "이 설치기는 macOS에서만 실행할 수 있습니다."

for command_name in curl ditto shasum codesign; do
  command -v "$command_name" >/dev/null 2>&1 || fail "필수 명령을 찾을 수 없습니다: $command_name"
done

mkdir -p "$INSTALL_DIR"
[[ -w "$INSTALL_DIR" ]] || fail "$INSTALL_DIR에 쓸 수 없습니다. --install-dir \"$HOME/Applications\"를 사용해 보세요."

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/UniversalControlHelper.XXXXXX")"
cleanup() {
  rm -rf "$TEMP_DIR"
  if [[ -n "$STAGING_PATH" && -e "$STAGING_PATH" ]]; then
    rm -rf "$STAGING_PATH"
  fi
}
trap cleanup EXIT

RELEASE_BASE="https://github.com/${REPOSITORY}/releases/latest/download"
printf '최신 Universal Control Helper를 내려받는 중…\n'
curl --proto '=https' --tlsv1.2 --fail --location --silent --show-error \
  --connect-timeout 15 --max-time 300 --retry 2 --retry-delay 1 \
  "$RELEASE_BASE/$ASSET_NAME" --output "$TEMP_DIR/$ASSET_NAME"
curl --proto '=https' --tlsv1.2 --fail --location --silent --show-error \
  --connect-timeout 15 --max-time 60 --retry 2 --retry-delay 1 \
  "$RELEASE_BASE/SHA256SUMS" --output "$TEMP_DIR/SHA256SUMS"

printf 'SHA-256 체크섬을 확인하는 중…\n'
(
  cd "$TEMP_DIR"
  shasum -a 256 -c SHA256SUMS
)

mkdir -p "$TEMP_DIR/unpacked"
ditto -x -k "$TEMP_DIR/$ASSET_NAME" "$TEMP_DIR/unpacked"
SOURCE_APP="$TEMP_DIR/unpacked/$APP_NAME"
[[ -d "$SOURCE_APP" ]] || fail "다운로드 파일에 $APP_NAME이 없습니다."

codesign --verify --deep --strict "$SOURCE_APP"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$SOURCE_APP/Contents/Info.plist")"

INSTALL_PATH="$INSTALL_DIR/$APP_NAME"
STAGING_PATH="$INSTALL_DIR/.UniversalControlHelper.installing.$$"
[[ ! -e "$STAGING_PATH" ]] || fail "임시 설치 경로가 이미 존재합니다: $STAGING_PATH"
ditto "$SOURCE_APP" "$STAGING_PATH"
codesign --verify --deep --strict "$STAGING_PATH"

LEGACY_INSTALL_PATH="$INSTALL_DIR/$LEGACY_APP_NAME"
CURRENT_BACKUP_PATH=""
LEGACY_BACKUP_PATH=""
if [[ -e "$INSTALL_PATH" || -e "$LEGACY_INSTALL_PATH" ]]; then
  RUNNING_PIDS="$(
    pgrep -x UniversalControlHelper 2>/dev/null || true
    pgrep -x UniInputFix 2>/dev/null || true
  )"
  if [[ -n "$RUNNING_PIDS" ]]; then
    printf '실행 중인 Universal Control Helper를 종료하는 중…\n'
    for process_id in $RUNNING_PIDS; do
      kill "$process_id" 2>/dev/null || true
    done
    sleep 1
  fi

  BACKUP_ROOT="$HOME/Library/Application Support/Universal Control Helper/Backups"
  mkdir -p "$BACKUP_ROOT"
  TIMESTAMP="$(date '+%Y%m%d-%H%M%S')"

  if [[ -e "$INSTALL_PATH" ]]; then
    CURRENT_BACKUP_PATH="$BACKUP_ROOT/Universal-Control-Helper-$TIMESTAMP.app"
    mv "$INSTALL_PATH" "$CURRENT_BACKUP_PATH"
    printf '기존 앱 백업: %s\n' "$CURRENT_BACKUP_PATH"
  fi

  if [[ -e "$LEGACY_INSTALL_PATH" ]]; then
    LEGACY_BACKUP_PATH="$BACKUP_ROOT/UniInputFix-legacy-$TIMESTAMP.app"
    mv "$LEGACY_INSTALL_PATH" "$LEGACY_BACKUP_PATH"
    printf '이전 이름 앱 백업: %s\n' "$LEGACY_BACKUP_PATH"
  fi
fi

if ! mv "$STAGING_PATH" "$INSTALL_PATH"; then
  if [[ -n "$CURRENT_BACKUP_PATH" && ! -e "$INSTALL_PATH" ]]; then
    mv "$CURRENT_BACKUP_PATH" "$INSTALL_PATH"
  fi
  if [[ -n "$LEGACY_BACKUP_PATH" && ! -e "$LEGACY_INSTALL_PATH" ]]; then
    mv "$LEGACY_BACKUP_PATH" "$LEGACY_INSTALL_PATH"
  fi
  fail "새 앱을 설치하지 못해 기존 앱을 복원했습니다."
fi
STAGING_PATH=""

printf 'Universal Control Helper %s 설치 완료: %s\n' "$VERSION" "$INSTALL_PATH"
if [[ "$LAUNCH_APP" -eq 1 ]]; then
  open "$INSTALL_PATH"
  printf '앱을 실행했습니다. Source Mac에서는 접근성과 입력 모니터링 권한을 확인해 주세요.\n'
fi

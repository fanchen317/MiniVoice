#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/Scripts/desktop-common.sh"
CONFIGURATION=release
SKIP_BUILD=false
LAUNCH=true
APP_PATH=/Applications/MiniVoice.app
while [[ $# -gt 0 ]]; do
  case "$1" in
    debug|release) CONFIGURATION="$1" ;;
    --skip-build) SKIP_BUILD=true ;;
    --no-launch) LAUNCH=false ;;
    --target)
      if [[ $# -lt 2 || "$2" != /* || "$2" != *.app ]]; then
        echo 'error: --target 需要 .app 的绝对路径' >&2; exit 2
      fi
      APP_PATH="$2"; shift ;;
    *) echo '用法：Scripts/deploy.sh [debug|release] [--skip-build] [--no-launch] [--target /absolute/MiniVoice.app]' >&2; exit 2 ;;
  esac
  shift
done
if [[ "$SKIP_BUILD" != true ]]; then "$ROOT/Scripts/build-electron-app.sh" "$CONFIGURATION"; fi
verify_desktop_app "$DESKTOP_APP_PATH"
PARENT="$(dirname "$APP_PATH")"
mkdir -p "$PARENT"
STAGING="$PARENT/.MiniVoice-staging-$$.app"
PREVIOUS="$PARENT/.MiniVoice-previous-$$.app"
trap 'rm -rf "$STAGING"' EXIT
ditto "$DESKTOP_APP_PATH" "$STAGING"
verify_desktop_app "$STAGING"
app_is_running() {
  ps -axo command= | awk -v executable="$APP_PATH/Contents/MacOS/" 'index($0, executable) == 1 {found=1} END {exit !found}'
}
# Check this exact installation, not every MiniVoice audio/helper process.
if app_is_running; then
  INSTALLED_APP_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Contents/Info.plist")"
  osascript -e "tell application id \"${INSTALLED_APP_ID}\" to quit" >/dev/null 2>&1 || true
  for ((attempt=0; attempt<20; attempt++)); do
    if ! app_is_running; then break; fi
    sleep .25
  done
fi
if app_is_running; then
  echo 'error: MiniVoice 未退出，请先完成正在进行的编辑后重试' >&2; exit 1
fi
if [[ -e "$APP_PATH" ]]; then mv "$APP_PATH" "$PREVIOUS"; fi
if ! mv "$STAGING" "$APP_PATH"; then
  if [[ -e "$PREVIOUS" ]]; then mv "$PREVIOUS" "$APP_PATH"; fi
  exit 1
fi
if [[ "$LAUNCH" == true ]] && ! open -n "$APP_PATH"; then
  rm -rf "$APP_PATH"
  if [[ -e "$PREVIOUS" ]]; then mv "$PREVIOUS" "$APP_PATH"; fi
  exit 1
fi
rm -rf "$PREVIOUS"
echo "已部署 Electron + Swift 应用：$APP_PATH"

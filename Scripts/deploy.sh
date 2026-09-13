#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MiniVoice"
APP_ID="local.fanchen.MiniVoice"
APP_PATH="/Applications/${APP_NAME}.app"
BUNDLE_PATH="$ROOT/.build/${APP_NAME}.app"
STAGING="/Applications/.${APP_NAME}-staging-$$.app"
PREVIOUS="/Applications/.${APP_NAME}-previous-$$.app"

# Build and verify before touching the installed app.
"$ROOT/Scripts/build-app.sh" "${1:-release}"
codesign --verify --deep --strict "$BUNDLE_PATH"
trap 'rm -rf "$STAGING"' EXIT
ditto "$BUNDLE_PATH" "$STAGING"
codesign --verify --deep --strict "$STAGING"

if pgrep -x "$APP_NAME" >/dev/null; then
  osascript -e "tell application id \"${APP_ID}\" to quit" >/dev/null 2>&1 || true
  osascript -e 'tell application id "com.local.minivoice" to quit' >/dev/null 2>&1 || true
  sleep 2
fi
if pgrep -x "$APP_NAME" >/dev/null; then
  echo "error: MiniVoice 未退出，请先完成正在进行的编辑后重试" >&2
  exit 1
fi

if [[ -e "$APP_PATH" ]]; then mv "$APP_PATH" "$PREVIOUS"; fi
if ! mv "$STAGING" "$APP_PATH"; then
  if [[ -e "$PREVIOUS" ]]; then mv "$PREVIOUS" "$APP_PATH"; fi
  exit 1
fi
if ! open -n "$APP_PATH"; then
  rm -rf "$APP_PATH"
  if [[ -e "$PREVIOUS" ]]; then mv "$PREVIOUS" "$APP_PATH"; fi
  exit 1
fi
rm -rf "$PREVIOUS"
sleep 2
pgrep -x "$APP_NAME"
echo "已部署并启动：$APP_PATH"

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="MiniVoice"
APP_ID="local.fanchen.MiniVoice"
APP_PATH="/Applications/${APP_NAME}.app"
BUNDLE_PATH="$ROOT/.build/${APP_NAME}.app"

echo "==> 停止旧进程..."
osascript -e "tell application id \"${APP_ID}\" to quit" >/dev/null 2>&1 || true
sleep 1

# 按 bundle ID 退出可能只命中一个实例；清理残留，避免旧版继续占用播放器资源。
if pgrep -x "$APP_NAME" >/dev/null; then
  pkill -x "$APP_NAME" || true
  sleep 1
fi
if pgrep -x "$APP_NAME" >/dev/null; then
  echo "error: ${APP_NAME} 旧进程未退出，停止部署" >&2
  exit 1
fi

echo "==> 编译..."
"$ROOT/Scripts/build-app.sh" "${1:-release}"

echo "==> 签名验证..."
codesign --verify --deep --strict "$BUNDLE_PATH"

echo "==> 替换应用..."
rm -rf "$APP_PATH"
ditto "$BUNDLE_PATH" "$APP_PATH"

echo "==> 启动应用..."
open -n "$APP_PATH"

echo "==> 完成，进程 ID:"
pgrep -x "$APP_NAME" || true

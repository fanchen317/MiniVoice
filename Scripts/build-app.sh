#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-release}"
source "$ROOT/Scripts/desktop-common.sh"
# The ZIP extraction dependency can exit with unfinished streams on Node 26.
# Prefer an installed LTS runtime for this build without changing the user's shell.
NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
if [[ "$NODE_MAJOR" -ge 26 || "$NODE_MAJOR" -lt 20 ]]; then
  for NODE_CANDIDATE in "${NVM_DIR:-$HOME/.nvm}"/versions/node/v{24,22,20}.*/bin/node; do
    if [[ -x "$NODE_CANDIDATE" ]]; then
      export PATH="$(dirname "$NODE_CANDIDATE"):$PATH"
      echo "==> 构建使用 Node $(node --version) LTS（避免当前 Node $NODE_MAJOR 的打包兼容问题）"
      break
    fi
  done
  NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
  if [[ "$NODE_MAJOR" -ge 26 || "$NODE_MAJOR" -lt 20 ]]; then
    echo 'error: 请安装 Node 20/22/24 LTS 后再构建；当前 Node 版本与打包工具不兼容' >&2
    exit 1
  fi
fi
# Build the existing Swift audio backend and its bundled FFmpeg/lyrics runtime.
"$ROOT/Scripts/build-native-engine.sh" "$CONFIGURATION"
cd "$ROOT"
node Desktop/electron/prepare-dependencies.mjs
node Desktop/electron/prepare-runtime.mjs
swift Desktop/electron/export-symbols.swift Desktop/public/symbols
npm --prefix Desktop run build
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/.build/native/MiniVoice.app/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$ROOT/.build/native/MiniVoice.app/Contents/Info.plist")"
ELECTRON_CACHE="$ROOT/.build/electron-cache" npm --prefix Desktop run package -- --app-version="$VERSION" --build-version="$BUILD"
APP="$ROOT/.build/staging/MiniVoice-darwin-arm64/MiniVoice.app"
mkdir -p "$APP/Contents/Resources/Native"
ditto "$ROOT/.build/native/MiniVoice.app" "$APP/Contents/Resources/Native/MiniVoice.app"
sign_desktop_app "$APP"
verify_desktop_app "$APP"
# There is one public artifact. The other bundles are private build inputs.
if [[ -e "$DESKTOP_APP_PATH" ]]; then rm -rf "$DESKTOP_APP_PATH"; fi
mv "$APP" "$DESKTOP_APP_PATH"
echo "$DESKTOP_APP_PATH"

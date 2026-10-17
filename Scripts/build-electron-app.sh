#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-release}"
# Build the existing Swift audio backend and its bundled FFmpeg/lyrics runtime.
"$ROOT/Scripts/build-app.sh" "$CONFIGURATION"
cd "$ROOT"
if [[ ! -d Desktop/node_modules ]]; then
  npm --prefix Desktop --cache "$ROOT/.build/npm-cache" ci
fi
node Desktop/electron/prepare-runtime.mjs
npm --prefix Desktop run build
ELECTRON_CACHE="$ROOT/.build/electron-cache" npm --prefix Desktop run package
APP="$ROOT/.build/electron/MiniVoice Electron-darwin-arm64/MiniVoice Electron.app"
mkdir -p "$APP/Contents/Resources/Native"
ditto "$ROOT/.build/MiniVoice.app" "$APP/Contents/Resources/Native/MiniVoice.app"
# Electron's Chromium/V8 executables require their JIT entitlements on Apple silicon.
codesign --force --deep --sign - --entitlements "$ROOT/Desktop/electron/entitlements.plist" "$APP"
codesign --verify --deep --strict "$APP"
echo "$APP"

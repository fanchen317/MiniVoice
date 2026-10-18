#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-release}"
source "$ROOT/Scripts/desktop-common.sh"
# Build the existing Swift audio backend and its bundled FFmpeg/lyrics runtime.
"$ROOT/Scripts/build-native-engine.sh" "$CONFIGURATION"
cd "$ROOT"
if [[ ! -d Desktop/node_modules ]]; then
  npm --prefix Desktop --cache "$ROOT/.build/npm-cache" ci
fi
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

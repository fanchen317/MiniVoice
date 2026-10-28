#!/usr/bin/env bash
# Builds the Electron + Swift desktop application.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CONFIGURATION="${1:-release}"
source "$ROOT/Scripts/common/desktop-common.sh"
case "${MINIVOICE_BUILD_CHANNEL:-release}" in
  release) export MINIVOICE_APP_NAME="MiniVoice" MINIVOICE_APP_IDENTIFIER="com.xcosmos.MiniVoice.electron" ;;
  debug) export MINIVOICE_APP_NAME="MiniVoice-debug" MINIVOICE_APP_IDENTIFIER="com.xcosmos.MiniVoice.electron.debug" ;;
  *) echo 'error: unsupported MINIVOICE_BUILD_CHANNEL' >&2; exit 2 ;;
esac
source "$ROOT/Scripts/common/node-runtime.sh"
minivoice_select_node_runtime
# Build the existing Swift audio backend and its bundled FFmpeg/lyrics runtime.
"$ROOT/Scripts/build/build-native-engine.sh" "$CONFIGURATION"
cd "$ROOT"
node MacOS/Desktop/electron/prepare-dependencies.mjs
node MacOS/Desktop/electron/prepare-runtime.mjs
swift MacOS/Desktop/electron/export-symbols.swift MacOS/Desktop/public/symbols
npm --prefix MacOS/Desktop run build
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT/.build/work/native/MiniVoice.app/Contents/Info.plist")"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$ROOT/.build/work/native/MiniVoice.app/Contents/Info.plist")"
ELECTRON_CACHE="$ROOT/.build/cache/electron" npm --prefix MacOS/Desktop run package -- --app-version="$VERSION" --build-version="$BUILD"
APP="$ROOT/.build/work/staging/$MINIVOICE_APP_NAME-darwin-arm64/$MINIVOICE_APP_NAME.app"
mkdir -p "$APP/Contents/Resources/Native"
ditto "$ROOT/.build/work/native/MiniVoice.app" "$APP/Contents/Resources/Native/MiniVoice.app"
if [[ "${MINIVOICE_BUILD_CHANNEL:-release}" == "debug" ]]; then
  echo '{"channel":"debug"}' > "$APP/Contents/Resources/build-channel.json"
  /usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.xcosmos.MiniVoice.debug' "$APP/Contents/Resources/Native/MiniVoice.app/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c 'Set :CFBundleName MiniVoice-debug' "$APP/Contents/Resources/Native/MiniVoice.app/Contents/Info.plist"
fi
sign_desktop_app "$APP"
verify_desktop_app "$APP"
# Release and debug are separate public artifacts.
if [[ -e "$DESKTOP_APP_PATH" ]]; then rm -rf "$DESKTOP_APP_PATH"; fi
mv "$APP" "$DESKTOP_APP_PATH"
echo "$DESKTOP_APP_PATH"

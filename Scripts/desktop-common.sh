#!/usr/bin/env bash
# Shared artifact contract for build, deployment and disk-image packaging.
DESKTOP_APP_PATH="$ROOT/.build/electron/MiniVoice-darwin-arm64/MiniVoice.app"
DESKTOP_ENGINE_RELATIVE="Contents/Resources/Native/MiniVoice.app/Contents/MacOS/MiniVoice"
verify_desktop_app() {
  local candidate="$1"
  if [[ ! -f "$candidate/Contents/Resources/app.asar" || ! -x "$candidate/$DESKTOP_ENGINE_RELATIVE" ]]; then
    echo "error: 不是完整的 Electron + Swift 应用：$candidate；请运行 Scripts/build-electron-app.sh" >&2
    return 1
  fi
  codesign --verify --deep --strict "$candidate"
}

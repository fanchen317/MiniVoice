#!/usr/bin/env bash
# Shared artifact contract for build, deployment and disk-image packaging.
DESKTOP_APP_PATH="$ROOT/.build/dist/MiniVoice.app"
if [[ "${MINIVOICE_BUILD_CHANNEL:-release}" == "debug" ]]; then DESKTOP_APP_PATH="$ROOT/.build/dist/MiniVoice-debug.app"; fi
DESKTOP_ENGINE_RELATIVE="Contents/Resources/Native/MiniVoice.app/Contents/MacOS/MiniVoice"
sign_desktop_app() {
  local candidate="$1"
  local identity="${MINIVOICE_CODESIGN_IDENTITY:--}"
  local identifier
  identifier="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$candidate/Contents/Info.plist")"
  # Sign nested Chromium code with its own identifiers and JIT entitlements first.
  codesign --force --deep --sign "$identity" --entitlements "$ROOT/MacOS/Desktop/electron/entitlements.plist" "$candidate"
  if [[ "$identity" == "-" ]]; then
    # Local builds have no certificate identity. Like the Swift backend, give the
    # outer app a stable DR so an update does not default to a new cdhash identity.
    # Do not pass --deep here: nested code must keep its own requirements.
    # Identifier-only requirements are for local builds, not publisher identity.
    codesign --force --sign - \
      --requirements "=designated => identifier \"$identifier\"" \
      --entitlements "$ROOT/MacOS/Desktop/electron/entitlements.plist" "$candidate"
  fi
}

verify_desktop_app() {
  local candidate="$1"
  if [[ ! -f "$candidate/Contents/Resources/app.asar" || ! -x "$candidate/$DESKTOP_ENGINE_RELATIVE" ]]; then
    echo "error: 不是完整的 Electron + Swift 应用：$candidate；请运行 Scripts/build/build-app.sh" >&2
    return 1
  fi
  codesign --verify --deep --strict "$candidate"
}

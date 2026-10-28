#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/Scripts/common/desktop-common.sh"
# Test local signing without touching the installed app or macOS privacy state.
export MINIVOICE_CODESIGN_IDENTITY=-
WORK="$(mktemp -d "${TMPDIR:-/tmp}/minivoice-signing.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
APP="$WORK/MiniVoice.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Helpers" "$APP/Contents/Resources"
cp /usr/bin/true "$APP/Contents/MacOS/MiniVoice"
cp /usr/bin/true "$APP/Contents/Helpers/SigningHelper"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.xcosmos.MiniVoice.electron</string>
<key>CFBundleExecutable</key><string>MiniVoice</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
codesign --force --sign - --identifier com.xcosmos.MiniVoice.SigningHelper "$APP/Contents/Helpers/SigningHelper"
sign_desktop_app "$APP"
codesign --verify --deep --strict "$APP"
FIRST_REQUIREMENT="$(codesign -d -r- "$APP" 2>&1 | sed -n '/^designated => /p')"
FIRST_HASH="$(codesign -dvv "$APP" 2>&1 | sed -n '/^CDHash=/p')"
FIRST_HELPER="$(codesign -d -r- "$APP/Contents/Helpers/SigningHelper" 2>&1 | sed -n '/designated => /p')"
echo update > "$APP/Contents/Resources/update.txt"
sign_desktop_app "$APP"
codesign --verify --deep --strict "$APP"
SECOND_REQUIREMENT="$(codesign -d -r- "$APP" 2>&1 | sed -n '/^designated => /p')"
SECOND_HASH="$(codesign -dvv "$APP" 2>&1 | sed -n '/^CDHash=/p')"
SECOND_HELPER="$(codesign -d -r- "$APP/Contents/Helpers/SigningHelper" 2>&1 | sed -n '/designated => /p')"
[[ "$FIRST_REQUIREMENT" == 'designated => identifier "com.xcosmos.MiniVoice.electron"' ]]
[[ "$FIRST_REQUIREMENT" == "$SECOND_REQUIREMENT" ]]
[[ -n "$FIRST_HASH" && -n "$SECOND_HASH" && "$FIRST_HASH" != "$SECOND_HASH" ]]
[[ -n "$FIRST_HELPER" && "$FIRST_HELPER" == "$SECOND_HELPER" ]]
[[ "$SECOND_HELPER" == *'com.xcosmos.MiniVoice.SigningHelper'* ]]
echo 'PASS: changed build hash, stable outer requirement, preserved helper identity, valid signatures'

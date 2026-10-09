#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$ROOT/.build/MiniVoice.app"
if [[ "${1:-}" != "--skip-build" ]]; then
  "$ROOT/Scripts/build-app.sh" release
elif [[ $# != 1 ]]; then
  echo "用法：Scripts/build-dmg.sh [--skip-build]" >&2
  exit 2
fi
codesign --verify --deep --strict "$APP_PATH"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
ARCH="$(uname -m)"
OUTPUT_DIR="$ROOT/.build/dist"
OUTPUT="$OUTPUT_DIR/MiniVoice-${VERSION}-${ARCH}.dmg"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/minivoice-dmg.XXXXXX")"
MOUNT_POINT="$WORK_DIR/volume"
cleanup() {
  if mount | grep -Fq " on $MOUNT_POINT ("; then
    hdiutil detach "$MOUNT_POINT" >/dev/null || true
  fi
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT
mkdir -p "$OUTPUT_DIR" "$WORK_DIR/content/.background" "$MOUNT_POINT"
ditto "$APP_PATH" "$WORK_DIR/content/MiniVoice.app"
ln -s /Applications "$WORK_DIR/content/Applications"
swiftc "$ROOT/Scripts/DMGBackground.swift" -o "$WORK_DIR/dmg-background" -framework AppKit
"$WORK_DIR/dmg-background" "$WORK_DIR/content/.background/install.png"

echo "==> 制作拖拽安装镜像..."
hdiutil create -quiet -srcfolder "$WORK_DIR/content" -volname "MiniVoice $VERSION" \
  -fs HFS+ -format UDRW "$WORK_DIR/installer.dmg"
hdiutil attach -quiet -nobrowse -noautoopen -mountpoint "$MOUNT_POINT" "$WORK_DIR/installer.dmg"

# Persist Finder layout in .DS_Store so opening the DMG shows both install icons.
osascript - "$MOUNT_POINT" <<'APPLESCRIPT'
on run argv
    set installFolder to POSIX file (item 1 of argv) as alias
    tell application "Finder"
        open installFolder
        set installWindow to container window of installFolder
        set current view of installWindow to icon view
        set toolbar visible of installWindow to false
        set statusbar visible of installWindow to false
        set bounds of installWindow to {200, 160, 840, 520}
        set options to icon view options of installWindow
        set arrangement of options to not arranged
        set icon size of options to 96
        set text size of options to 14
        set background picture of options to file ".background:install.png" of installFolder
        set position of item "MiniVoice.app" of installFolder to {170, 160}
        set position of item "Applications" of installFolder to {470, 160}
        update installFolder without registering applications
        delay 2
        close installWindow
    end tell
end run
APPLESCRIPT

if [[ ! -f "$MOUNT_POINT/.DS_Store" ]]; then
  echo "error: Finder 安装布局未保存，请检查 Finder 自动化权限" >&2
  exit 1
fi
hdiutil detach -quiet "$MOUNT_POINT"
hdiutil convert -quiet "$WORK_DIR/installer.dmg" -format UDZO -imagekey zlib-level=9 -o "$WORK_DIR/final.dmg"
hdiutil verify -quiet "$WORK_DIR/final.dmg"
mv -f "$WORK_DIR/final.dmg" "$OUTPUT"
echo "安装包：$OUTPUT"

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/Scripts/desktop-common.sh"
APP_PATH="$DESKTOP_APP_PATH"
SKIP_BUILD=false
REUSE_LAYOUT=false
LAYOUT_SOURCE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-build) SKIP_BUILD=true ;;
    --reuse-layout) REUSE_LAYOUT=true ;;
    --layout-from)
      if [[ $# -lt 2 || "$2" != /* || ! -f "$2" ]]; then
        echo "error: --layout-from 需要现有 DMG 的绝对路径" >&2; exit 2
      fi
      REUSE_LAYOUT=true
      LAYOUT_SOURCE="$2"
      shift ;;
    *) echo "用法：Scripts/build-dmg.sh [--skip-build] [--reuse-layout | --layout-from /absolute/previous.dmg]" >&2; exit 2 ;;
  esac
  shift
done
if [[ "$SKIP_BUILD" != true ]]; then
  "$ROOT/Scripts/build-app.sh" release
fi
verify_desktop_app "$APP_PATH"
if [[ "$REUSE_LAYOUT" != true ]]; then
  DMG_PYTHON="$ROOT/.build/dmg-tools/bin/python"
  if [[ ! -x "$DMG_PYTHON" ]]; then python3 -m venv "$ROOT/.build/dmg-tools"; fi
  if ! "$DMG_PYTHON" -c 'from importlib.metadata import version; assert version("ds-store") == "1.3.1" and version("mac-alias") == "2.2.2"' >/dev/null 2>&1; then
    "$DMG_PYTHON" -m pip install --disable-pip-version-check -r "$ROOT/Scripts/dmg-requirements.txt"
  fi
fi
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
ARCH="$(uname -m)"
OUTPUT_DIR="$ROOT/.build/dist"
OUTPUT="$OUTPUT_DIR/MiniVoice-${VERSION}-${ARCH}.dmg"
if [[ "$REUSE_LAYOUT" == true ]]; then
  LAYOUT_SOURCE="${LAYOUT_SOURCE:-$OUTPUT}"
  if [[ ! -f "$LAYOUT_SOURCE" ]]; then
    echo "error: 无现有安装包可复用布局：$LAYOUT_SOURCE" >&2; exit 1
  fi
fi
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/minivoice-dmg.XXXXXX")"
# macOS exposes TMPDIR through /var, but mount reports its /private path.
# Use the canonical path so cleanup detects and detaches our image reliably.
WORK_DIR="$(cd "$WORK_DIR" && pwd -P)"
MOUNT_POINT="$WORK_DIR/volume"
PREVIOUS_MOUNT="$WORK_DIR/previous"
cleanup() {
  if mount | grep -Fq " on $PREVIOUS_MOUNT ("; then
    hdiutil detach "$PREVIOUS_MOUNT" >/dev/null || true
  fi
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

# Persist the Finder layout without opening a Finder window.
if [[ "$REUSE_LAYOUT" == true ]]; then
  # Rebuild without UI automation, reusing a verified installation layout.
  LAYOUT_SOURCE="${LAYOUT_SOURCE:-$OUTPUT}"
  if [[ ! -f "$LAYOUT_SOURCE" ]]; then
    echo "error: 无现有安装包可复用布局：$LAYOUT_SOURCE" >&2
    exit 1
  fi
  mkdir -p "$PREVIOUS_MOUNT"
  hdiutil attach -quiet -readonly -nobrowse -noautoopen -mountpoint "$PREVIOUS_MOUNT" "$LAYOUT_SOURCE"
  cp "$PREVIOUS_MOUNT/.DS_Store" "$MOUNT_POINT/.DS_Store"
  hdiutil detach -quiet "$PREVIOUS_MOUNT"
else
  "$DMG_PYTHON" "$ROOT/Scripts/write-dmg-layout.py" "$MOUNT_POINT"
fi

if [[ ! -f "$MOUNT_POINT/.DS_Store" ]]; then
  echo "error: DMG 安装布局未保存" >&2
  exit 1
fi
hdiutil detach -quiet "$MOUNT_POINT"
hdiutil convert -quiet "$WORK_DIR/installer.dmg" -format UDZO -imagekey zlib-level=9 -o "$WORK_DIR/final.dmg"
hdiutil verify -quiet "$WORK_DIR/final.dmg"
mv -f "$WORK_DIR/final.dmg" "$OUTPUT"
echo "安装包：$OUTPUT"

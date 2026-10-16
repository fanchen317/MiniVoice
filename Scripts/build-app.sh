#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-release}"
APP_NAME="MiniVoice"
APP_PATH="$ROOT/.build/${APP_NAME}.app"
INFO_PLIST="$ROOT/AppBundle/Info.plist"
APP_IDENTIFIER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST")"

if [[ "$CONFIGURATION" != "debug" && "$CONFIGURATION" != "release" ]]; then
  echo "用法：Scripts/build-app.sh [debug|release]" >&2
  exit 2
fi

cd "$ROOT"

ARCH="$(uname -m)"
VENDORED_FFMPEG="$ROOT/Vendor/FFmpeg/$ARCH"
if [[ "$ARCH" != "arm64" ]]; then
  echo "error: 当前仅提供 arm64 的内置 FFmpeg，缺少 $ARCH 资源" >&2
  exit 1
fi
for TOOL in ffmpeg ffprobe; do
  if [[ ! -x "$VENDORED_FFMPEG/$TOOL" ]]; then
    echo "error: 缺少仓库内的 $VENDORED_FFMPEG/$TOOL" >&2
    exit 1
  fi
  EXPECTED="$(awk -v name="$TOOL" '$2 == name {print $1}' "$VENDORED_FFMPEG/SHA256SUMS")"
  ACTUAL="$(shasum -a 256 "$VENDORED_FFMPEG/$TOOL" | awk '{print $1}')"
  if [[ -z "$EXPECTED" || "$ACTUAL" != "$EXPECTED" ]]; then
    echo "error: $TOOL 校验失败，请检查 Vendor/FFmpeg" >&2
    exit 1
  fi
done

if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
export CLANG_MODULE_CACHE_PATH="$ROOT/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT/.build/ModuleCache"

CURRENT_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
BUILD_NUMBER="${BUILD_NUMBER:-$CURRENT_BUILD}"
if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "error: CFBundleVersion 必须是数字，当前为 '$BUILD_NUMBER'" >&2
  exit 1
fi

echo "==> 编译 (${CONFIGURATION})..."
swift build --disable-sandbox -c "$CONFIGURATION"
EXECUTABLE="$(swift build --disable-sandbox -c "$CONFIGURATION" --show-bin-path)/$APP_NAME"

if [[ ! -x "$EXECUTABLE" ]]; then
  echo "error: 未找到编译产物：$EXECUTABLE" >&2
  exit 1
fi

echo "==> 组装应用包..."
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources" "$APP_PATH/Contents/Helpers"
cp "$INFO_PLIST" "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP_PATH/Contents/Info.plist"
cp "$EXECUTABLE" "$APP_PATH/Contents/MacOS/$APP_NAME"
# SwiftPM Bundle.module locates its resource bundle in Contents/Resources.
RESOURCE_BUNDLE="$(dirname "$EXECUTABLE")/MiniVoice_MiniVoice.bundle"
ditto "$RESOURCE_BUNDLE" "$APP_PATH/Contents/Resources/MiniVoice_MiniVoice.bundle"
printf 'APPL????' > "$APP_PATH/Contents/PkgInfo"
chmod +x "$APP_PATH/Contents/MacOS/$APP_NAME"

echo "==> 复制应用图标..."
ICON_SOURCE="$ROOT/AppBundle/MiniVoice.icns"
if [[ ! -s "$ICON_SOURCE" ]]; then
  echo "error: 缺少应用图标，请先运行 Scripts/generate-icon.sh" >&2
  exit 1
fi
cp "$ICON_SOURCE" "$APP_PATH/Contents/Resources/MiniVoice.icns"

echo "==> 集成 FFmpeg..."
for TOOL in ffmpeg ffprobe; do
  cp "$VENDORED_FFMPEG/$TOOL" "$APP_PATH/Contents/Helpers/$TOOL"
  chmod +x "$APP_PATH/Contents/Helpers/$TOOL"
  codesign --force --sign - "$APP_PATH/Contents/Helpers/$TOOL"
done
cp "$ROOT/Vendor/FFmpeg/README.md" "$APP_PATH/Contents/Resources/FFmpeg-NOTICES.txt"
cp "$ROOT/Vendor/FFmpeg/COPYING.LGPLv2.1" "$APP_PATH/Contents/Resources/FFmpeg-LGPL-2.1.txt"

echo "==> 签名..."
codesign --force --sign - \
  --requirements "=designated => identifier \"$APP_IDENTIFIER\"" \
  "$APP_PATH"

echo "$APP_PATH"

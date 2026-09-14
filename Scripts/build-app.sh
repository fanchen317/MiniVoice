#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-release}"
APP_NAME="MiniVoice"
APP_IDENTIFIER="local.fanchen.MiniVoice"
APP_PATH="$ROOT/.build/${APP_NAME}.app"
INFO_PLIST="$ROOT/AppBundle/Info.plist"

if [[ "$CONFIGURATION" != "debug" && "$CONFIGURATION" != "release" ]]; then
  echo "用法：Scripts/build-app.sh [debug|release]" >&2
  exit 2
fi

cd "$ROOT"

for TOOL in ffmpeg ffprobe; do
  if [[ ! -x "/opt/homebrew/bin/$TOOL" && ! -x "/usr/local/bin/$TOOL" ]]; then
    echo "error: 缺少 $TOOL，请先执行 brew install ffmpeg" >&2
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
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
cp "$INFO_PLIST" "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP_PATH/Contents/Info.plist"
cp "$EXECUTABLE" "$APP_PATH/Contents/MacOS/$APP_NAME"
printf 'APPL????' > "$APP_PATH/Contents/PkgInfo"
chmod +x "$APP_PATH/Contents/MacOS/$APP_NAME"

echo "==> 生成应用图标..."
swiftc "$ROOT/Sources/MiniVoice/BrandIcon.swift" "$ROOT/Scripts/IconGenerator.swift" -o "$ROOT/.build/icon-generator" -framework AppKit
"$ROOT/.build/icon-generator" "$ROOT/.build/MiniVoice.iconset"
if ! iconutil -c icns "$ROOT/.build/MiniVoice.iconset" -o "$APP_PATH/Contents/Resources/MiniVoice.icns"; then
    # Some constrained macOS sessions reject iconutil despite a valid PNG iconset.
  # Keep deployment usable by reusing the currently installed icon in that case.
  INSTALLED_ICON="/Applications/${APP_NAME}.app/Contents/Resources/MiniVoice.icns"
  if [[ -f "$INSTALLED_ICON" ]]; then
    cp "$INSTALLED_ICON" "$APP_PATH/Contents/Resources/MiniVoice.icns"
  else
    echo "error: 未能生成应用图标，且没有可复用的已安装图标" >&2
    exit 1
  fi
fi
if [[ ! -s "$APP_PATH/Contents/Resources/MiniVoice.icns" ]]; then
  echo "error: 未能生成应用图标" >&2
  exit 1
fi

echo "==> 签名..."
codesign --force --sign - \
  --requirements "=designated => identifier \"$APP_IDENTIFIER\"" \
  "$APP_PATH"

echo "$APP_PATH"

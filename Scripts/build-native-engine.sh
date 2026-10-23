#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-release}"
APP_NAME="MiniVoice"
APP_PATH="$ROOT/.build/native/${APP_NAME}.app"
INFO_PLIST="$ROOT/MacOS/AppBundle/Info.plist"
APP_IDENTIFIER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST")"

if [[ "$CONFIGURATION" != "debug" && "$CONFIGURATION" != "release" ]]; then
  echo "内部构建：Scripts/build-native-engine.sh [debug|release]" >&2
  exit 2
fi

cd "$ROOT"

ARCH="$(uname -m)"
VENDORED_FFMPEG="$ROOT/MacOS/Vendor/FFmpeg/$ARCH"
VENDORED_AI="$ROOT/MacOS/Vendor/LyricsAI/$ARCH"
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
    echo "error: $TOOL 校验失败，请检查 MacOS/Vendor/FFmpeg" >&2
    exit 1
  fi
done
for ASSET in lyrics-worker.tar.gz small.pt; do
  if [[ ! -s "$VENDORED_AI/$ASSET" ]]; then
    echo "error: 缺少 $VENDORED_AI/$ASSET；请先安装 Git LFS 并运行 git lfs pull" >&2
    exit 1
  fi
  EXPECTED="$(awk -v name="$ASSET" '$2 == name {print $1}' "$VENDORED_AI/SHA256SUMS")"
  ACTUAL="$(shasum -a 256 "$VENDORED_AI/$ASSET" | awk '{print $1}')"
  if [[ -z "$EXPECTED" || "$ACTUAL" != "$EXPECTED" ]]; then
    echo "error: $ASSET 校验失败，请检查 Git LFS 资源是否完整" >&2
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

# Optional reproducible/offline build when the lockfile and cached checkouts exist.
# Regular builds retain their existing dependency resolution behavior.
native_swift_build() {
  if [[ "${MINIVOICE_LOCKED_BUILD:-0}" == "1" ]]; then
    swift build --skip-update --force-resolved-versions "$@"
  else
    swift build "$@"
  fi
}
echo "==> 编译 (${CONFIGURATION})..."
native_swift_build --package-path "$ROOT/MacOS" --scratch-path "$ROOT/.build" --disable-sandbox -c "$CONFIGURATION"
EXECUTABLE="$(native_swift_build --package-path "$ROOT/MacOS" --scratch-path "$ROOT/.build" --disable-sandbox -c "$CONFIGURATION" --show-bin-path)/$APP_NAME"

if [[ ! -x "$EXECUTABLE" ]]; then
  echo "error: 未找到编译产物：$EXECUTABLE" >&2
  exit 1
fi

echo "==> 组装应用包..."
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources" "$APP_PATH/Contents/Helpers"
cp "$INFO_PLIST" "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $APP_IDENTIFIER" "$APP_PATH/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP_PATH/Contents/Info.plist"
cp "$EXECUTABLE" "$APP_PATH/Contents/MacOS/$APP_NAME"
# SwiftPM Bundle.module locates its resource bundle in Contents/Resources.
RESOURCE_BUNDLE="$(dirname "$EXECUTABLE")/MiniVoice_MiniVoice.bundle"
ditto "$RESOURCE_BUNDLE" "$APP_PATH/Contents/Resources/MiniVoice_MiniVoice.bundle"
printf 'APPL????' > "$APP_PATH/Contents/PkgInfo"
chmod +x "$APP_PATH/Contents/MacOS/$APP_NAME"

echo "==> 复制应用图标..."
ICON_SOURCE="$ROOT/MacOS/AppBundle/MiniVoice.icns"
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
cp "$ROOT/MacOS/Vendor/FFmpeg/README.md" "$APP_PATH/Contents/Resources/FFmpeg-NOTICES.txt"
cp "$ROOT/MacOS/Vendor/FFmpeg/COPYING.LGPLv2.1" "$APP_PATH/Contents/Resources/FFmpeg-LGPL-2.1.txt"

echo "==> 集成离线歌词 AI..."
tar -xzf "$VENDORED_AI/lyrics-worker.tar.gz" -C "$APP_PATH/Contents/Resources"
mkdir -p "$APP_PATH/Contents/Resources/LyricsModels"
cp "$VENDORED_AI/small.pt" "$APP_PATH/Contents/Resources/LyricsModels/small.pt"
cp "$ROOT/MacOS/Vendor/LyricsAI/README.md" "$APP_PATH/Contents/Resources/LyricsAI-NOTICES.txt"
ditto "$ROOT/MacOS/Vendor/LyricsAI/licenses" "$APP_PATH/Contents/Resources/LyricsAI-Licenses"
if [[ ! -x "$APP_PATH/Contents/Resources/lyrics-worker/lyrics-worker" ]]; then
  echo "error: 歌词 AI 运行环境不完整" >&2
  exit 1
fi

echo "==> 签名..."
codesign --force --sign - \
  --requirements "=designated => identifier \"$APP_IDENTIFIER\"" \
  "$APP_PATH"

echo "$APP_PATH"

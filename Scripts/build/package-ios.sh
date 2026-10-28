#!/usr/bin/env bash
# Archives and exports the signed iOS package.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VARIANT="${1:-release}"
if [[ "$VARIANT" != release ]]; then
  echo 'error: iOS 尚未接入共享体验版宿主，不能将旧原生版重命名为体验版。可用 --platforms mac,android 打包现有体验版。' >&2
  exit 1
fi
if [[ -z "${MINIVOICE_IOS_TEAM:-}" || ! -f "${MINIVOICE_IOS_EXPORT_OPTIONS:-}" ]]; then
  echo 'error: 可安装 IPA 需要开发团队和导出签名配置。请设置 MINIVOICE_IOS_TEAM、MINIVOICE_IOS_EXPORT_OPTIONS（ExportOptions.plist 绝对路径）；不会生成伪装成安装包的未签名 IPA。' >&2
  exit 1
fi
mkdir -p "$ROOT/.build/work/ios" "$ROOT/.build/dist"
work="$(mktemp -d "$ROOT/.build/work/ios/export.XXXXXX")"
trap 'rm -rf "$work"' EXIT
xcodebuild -project "$ROOT/iOS/MiniVoice.xcodeproj" -scheme MiniVoice \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath "$work/MiniVoice.xcarchive" DEVELOPMENT_TEAM="$MINIVOICE_IOS_TEAM" archive
xcodebuild -exportArchive -archivePath "$work/MiniVoice.xcarchive" \
  -exportOptionsPlist "$MINIVOICE_IOS_EXPORT_OPTIONS" -exportPath "$work/export"
shopt -s nullglob
packages=("$work/export/"*.ipa)
[[ ${#packages[@]} == 1 ]] || { echo 'error: 导出未产生唯一 IPA' >&2; exit 1; }
unzip -tq "${packages[0]}"
mv -f "${packages[0]}" "$ROOT/.build/dist/MiniVoice-ios.ipa"
echo "IPA: $ROOT/.build/dist/MiniVoice-ios.ipa"

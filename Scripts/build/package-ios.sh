#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VARIANT="${1:-release}"
case "$VARIANT" in
  release) NAME=MiniVoice-ios; BUNDLE=com.xcosmos.MiniVoice.ios ;;
  experience) NAME=MiniVoice-ios-experience; BUNDLE=com.xcosmos.MiniVoice.ios.experience ;;
  *) echo '用法：package-ios.sh [release|experience]' >&2; exit 2 ;;
esac
# Both channels currently use the existing shared iOS host. They are isolated
# by bundle identity; channel names do not imply a second native UI framework.
TEAM="${MINIVOICE_IOS_TEAM:-}"
OPTIONS="${MINIVOICE_IOS_EXPORT_OPTIONS:-}"
if [[ "$VARIANT" == experience ]]; then
  TEAM="${MINIVOICE_IOS_EXPERIENCE_TEAM:-$TEAM}"
  OPTIONS="${MINIVOICE_IOS_EXPERIENCE_EXPORT_OPTIONS:-$OPTIONS}"
fi
if [[ -z "$TEAM" || ! -f "$OPTIONS" ]]; then
  echo 'error: 可安装 IPA 需要开发团队和导出签名配置。请设置 MINIVOICE_IOS_TEAM、MINIVOICE_IOS_EXPORT_OPTIONS（ExportOptions.plist 绝对路径）；不会生成伪装成安装包的未签名 IPA。' >&2
  exit 1
fi
plutil -lint "$OPTIONS" >/dev/null
node "$ROOT/Scripts/checks/check-ui-standards.mjs"
mkdir -p "$ROOT/.build/cache/ios/$VARIANT" "$ROOT/.build/work/ios" "$ROOT/.build/dist"
work="$(mktemp -d "$ROOT/.build/work/ios/export.XXXXXX")"
trap 'rm -rf "$work"' EXIT
xcodebuild -project "$ROOT/iOS/MiniVoice.xcodeproj" -scheme MiniVoice \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath "$ROOT/.build/cache/ios/$VARIANT/DerivedData" \
  -archivePath "$work/MiniVoice.xcarchive" DEVELOPMENT_TEAM="$TEAM" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE" archive
xcodebuild -exportArchive -archivePath "$work/MiniVoice.xcarchive" \
  -exportOptionsPlist "$OPTIONS" -exportPath "$work/export"
shopt -s nullglob
packages=("$work/export/"*.ipa)
[[ ${#packages[@]} == 1 ]] || { echo 'error: 导出未产生唯一 IPA' >&2; exit 1; }
unzip -tq "${packages[0]}"
mv -f "${packages[0]}" "$ROOT/.build/dist/${NAME}.ipa"
echo "IPA: $ROOT/.build/dist/${NAME}.ipa"

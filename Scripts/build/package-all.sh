#!/usr/bin/env bash
# Public workflows share one channel and artifact contract.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ACTION="$1"; VARIANT="$2"; shift 2
PLATFORMS=mac,android,ios
LAUNCH=true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --platforms) [[ $# -ge 2 ]] || exit 2; PLATFORMS="$2"; shift ;;
    --no-launch) LAUNCH=false ;;
    --help|-h)
      echo '用法：Scripts/{build,build-experience,deploy,deploy-experience}.sh [--platforms mac,android,ios] [--no-launch]'
      echo '默认全部平台。iOS 导出需 MINIVOICE_IOS_TEAM 与 MINIVOICE_IOS_EXPORT_OPTIONS；体验版可用 MINIVOICE_IOS_EXPERIENCE_TEAM / MINIVOICE_IOS_EXPERIENCE_EXPORT_OPTIONS 覆盖。'
      exit 0 ;;
    *) echo "未知参数：$1" >&2; exit 2 ;;
  esac
  shift
done
case "$PLATFORMS" in ''|,*|*,|*,,*) echo '平台列表不能为空' >&2; exit 2 ;; esac
IFS=, read -r -a requested <<< "$PLATFORMS"
for platform in "${requested[@]}"; do
  case "$platform" in mac|android|ios) ;; *) echo "未知平台：$platform" >&2; exit 2 ;; esac
done
export MINIVOICE_BUILD_CHANNEL=release
[[ "$VARIANT" != experience ]] || export MINIVOICE_BUILD_CHANNEL=debug
node "$ROOT/Scripts/checks/check-ui-standards.mjs"
# Prevent concurrent workflows from mutating the shared Swift/UI/native caches.
mkdir -p "$ROOT/.build/work"
LOCK="$ROOT/.build/work/package-workflow.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  echo "另一个打包流程正在运行；若之前异常退出，确认无构建进程后删除 $LOCK" >&2; exit 1
fi
trap 'rmdir "$LOCK"' EXIT
failed=0
for platform in "${requested[@]}"; do
  echo "==> $ACTION / $VARIANT / $platform"
  # Run in a separate shell so failures in child build steps cannot be masked.
  case "$platform" in
    mac) if bash "$ROOT/Scripts/build/package-mac.sh" "$ACTION" "$VARIANT" "$LAUNCH"; then :; else failed=1; fi ;;
    android) if bash "$ROOT/Scripts/build/build-android.sh" "$VARIANT"; then :; else failed=1; fi ;;
    ios) if bash "$ROOT/Scripts/build/package-ios.sh" "$VARIANT"; then :; else failed=1; fi ;;
  esac
done
python3 "$ROOT/Scripts/tools/archive-legacy-packages.py"
if [[ "$failed" != 0 ]]; then echo '部分平台打包失败；请查看上方错误。已有安装包不代表本次构建成功。' >&2; exit 1; fi
echo "完成：$ACTION / ${VARIANT}；安装包位于 $ROOT/.build/dist，Mac app 位于 $ROOT/.build/dist"

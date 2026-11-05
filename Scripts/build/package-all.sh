#!/usr/bin/env bash
# Public workflows share one channel and artifact contract.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ACTION="$1"; VARIANT="$2"; shift 2
case "$VARIANT" in release) ;; *) echo "未知版本渠道：$VARIANT" >&2; exit 2 ;; esac
source "$ROOT/Scripts/common/release-output.sh"
case "$(uname -s)" in Darwin) PLATFORMS=mac,android ;; MINGW*|MSYS*|CYGWIN*) PLATFORMS=windows ;; *) PLATFORMS=android ;; esac
LAUNCH=true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --platforms) [[ $# -ge 2 ]] || exit 2; PLATFORMS="$2"; shift ;;
    --no-launch) LAUNCH=false ;;
    --help|-h)
      echo '用法：Scripts/build.sh [--platforms mac,android,windows] [--no-launch]'
      echo 'Mac 默认构建 mac,android；Windows 默认 windows；暂不包含 iOS。跨平台原生产物需在对应主机生成。'
      exit 0 ;;
    *) echo "未知参数：$1" >&2; exit 2 ;;
  esac
  shift
done
case "$PLATFORMS" in ''|,*|*,|*,,*) echo '平台列表不能为空' >&2; exit 2 ;; esac
IFS=, read -r -a requested <<< "$PLATFORMS"
for platform in "${requested[@]}"; do
  case "$platform" in mac|android|windows) ;; *) echo "未知平台：$platform" >&2; exit 2 ;; esac
done
[[ "$ACTION" == build ]] || { mv_error "部署请直接运行 Scripts/deploy.sh"; exit 2; }
node "$ROOT/Scripts/checks/check-ui-standards.mjs"
# Prevent concurrent workflows from mutating the shared Swift/UI/native caches.
mkdir -p "$ROOT/.build/work"
LOCK="$ROOT/.build/work/package-workflow.lock"
if ! mkdir "$LOCK" 2>/dev/null; then
  echo "另一个打包流程正在运行；若之前异常退出，确认无构建进程后删除 $LOCK" >&2; exit 1
fi
trap 'rmdir "$LOCK"' EXIT
failed=0
summary=()
started=$SECONDS
mv_note "MiniVoice $MV_VERSION · 构建平台：$PLATFORMS"
for platform in "${requested[@]}"; do
  mv_note "── 开始 $platform · $MV_VERSION ──"
  platform_failed=0
  mkdir -p "$ROOT/.build/reports/build"
  log="$ROOT/.build/reports/build/${MV_VERSION}-${platform}.log"
  # Run in a separate shell so failures in child build steps cannot be masked.
  case "$platform" in
    windows) if bash "$ROOT/Scripts/build/package-windows.sh" "$ACTION" 2>&1 | tee "$log"; then :; else platform_failed=1; fi ;;
    mac) if bash "$ROOT/Scripts/build/package-mac.sh" "$ACTION" "$VARIANT" "$LAUNCH" 2>&1 | tee "$log"; then :; else platform_failed=1; fi ;;
    android) if bash "$ROOT/Scripts/build/build-android.sh" "$VARIANT" 2>&1 | tee "$log"; then :; else platform_failed=1; fi ;;
  esac
  if [[ "$platform_failed" == 0 ]]; then
    case "$platform" in
      mac) expected=("$MV_DIST/MiniVoice-${MV_VERSION}-mac.app" "$MV_DIST/MiniVoice-${MV_VERSION}-mac.dmg") ;;
      android) expected=("$MV_DIST/MiniVoice-${MV_VERSION}-android.apk") ;;
      windows) expected=("$MV_DIST/MiniVoice-${MV_VERSION}-windows-x64-setup.exe") ;;
    esac
    for artifact in "${expected[@]}"; do [[ -e "$artifact" ]] || { mv_error "缺少产物：$artifact"; platform_failed=1; }; done
    [[ "$platform_failed" != 0 ]] || printf '  → %s\n' "${expected[@]}"
  fi
  printf '  日志：%s\n' "$log"
  if [[ "$platform_failed" == 0 ]]; then mv_ok "$platform 构建完成"; summary+=("${platform}：成功"); else failed=1; mv_error "$platform 构建失败"; summary+=("${platform}：失败"); fi
done
mv_note "── 构建摘要 · 耗时 $((SECONDS-started)) 秒 ──"
printf '  %s\n' "${summary[@]}"
printf '  产物目录：%s\n' "$MV_DIST"
if [[ "$failed" != 0 ]]; then echo '部分平台打包失败；请查看上方错误。已有安装包不代表本次构建成功。' >&2; exit 1; fi
echo "完成：$ACTION / ${VARIANT}；安装包位于 $ROOT/.build/dist，Mac app 位于 $ROOT/.build/dist"

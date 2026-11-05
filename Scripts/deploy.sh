#!/usr/bin/env bash
# Build current Mac sources and install; other platforms are not rebuilt.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/Scripts/common/release-output.sh"
case "${1:-}" in --help|-h) echo '用法：Scripts/deploy.sh [debug|release] [--skip-build] [--no-launch] [--target /Applications/MiniVoice.app]'; echo "默认重新构建当前代码后安装；--skip-build 仅安装已有包。"; exit 0 ;; esac
[[ "$(uname -s)" == Darwin ]] || { mv_error 'deploy.sh 仅在 macOS 安装 Mac App'; exit 1; }
mkdir -p "$ROOT/.build/work"
LOCK="$ROOT/.build/work/package-workflow.lock"
mkdir "$LOCK" 2>/dev/null || { mv_error '另一个构建或部署流程正在运行'; exit 1; }
trap 'rmdir "$LOCK"' EXIT
mv_note "MiniVoice $MV_VERSION · 安装到应用程序目录"
node "$ROOT/Scripts/checks/check-ui-standards.mjs"
bash "$ROOT/Scripts/build/install-mac.sh" "$@"
mv_ok "MiniVoice $MV_VERSION 已安装"

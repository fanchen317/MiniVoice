#!/usr/bin/env bash
# Install the already-built current-version Mac app; never rebuild other platforms.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/Scripts/common/release-output.sh"
case "${1:-}" in --help|-h) echo '用法：Scripts/deploy.sh [--no-launch] [--target /Applications/MiniVoice.app]'; echo "安装已生成的 MiniVoice-${MV_VERSION}-mac.app；不重新构建。"; exit 0 ;; esac
[[ "$(uname -s)" == Darwin ]] || { mv_error 'deploy.sh 仅在 macOS 安装 Mac App'; exit 1; }
mkdir -p "$ROOT/.build/work"
LOCK="$ROOT/.build/work/package-workflow.lock"
mkdir "$LOCK" 2>/dev/null || { mv_error '另一个构建或部署流程正在运行'; exit 1; }
trap 'rmdir "$LOCK"' EXIT
mv_note "MiniVoice $MV_VERSION · 安装到应用程序目录"
bash "$ROOT/Scripts/build/install-mac.sh" --skip-build "$@"
mv_ok "MiniVoice $MV_VERSION 已安装"

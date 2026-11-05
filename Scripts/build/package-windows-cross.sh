#!/usr/bin/env bash
# Assemble a Windows installer using previously built Windows-native resources.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$ROOT/Scripts/common/release-output.sh"
: "${MINIVOICE_WINDOWS_RESOURCES:?请设置 MINIVOICE_WINDOWS_RESOURCES，指向含 Windows 原生核心、媒体工具和 AI 运行时的资源目录}"
command -v makensis >/dev/null || { mv_error '缺少 NSIS 3（makensis），无法生成 Windows 安装包'; exit 1; }
node "$ROOT/Windows/prepare-cross-resources.mjs" "$MINIVOICE_WINDOWS_RESOURCES"
cd "$ROOT"
node Scripts/checks/check-ui-standards.mjs
npm --prefix Shared/UI ci
node Shared/UI/node_modules/vite/bin/vite.js build --config Windows/vite.config.mjs
node Scripts/build/package-shared-notices.mjs Windows/ui Shared/UI
mkdir -p Windows/electron/shared-services "$ROOT/.build/work"
cp Shared/DesktopServices/*.cjs Windows/electron/shared-services/
ELECTRON_SKIP_BINARY_DOWNLOAD=1 npm --prefix Windows ci
npm --prefix Windows test
npm --prefix Windows run package -- --app-version="$MV_VERSION"
node Windows/generate-uninstall.mjs "$MV_DIST/MiniVoice-win32-x64" "$ROOT/.build/work/windows-uninstall.nsh"
temporary="$MV_DIST/MiniVoice-${MV_VERSION}-windows-x64-setup.pending.exe"
trap 'rm -f "$temporary"' EXIT
makensis "-DVERSION=$MV_VERSION" "-DAPP_DIR=$MV_DIST/MiniVoice-win32-x64" "-DOUTPUT=$temporary" "-DUNINSTALL_FILES=$ROOT/.build/work/windows-uninstall.nsh" Windows/installer.nsi
[[ -s "$temporary" ]] || { mv_error '未生成 Windows 安装包'; exit 1; }
mv -f "$temporary" "$MV_DIST/MiniVoice-${MV_VERSION}-windows-x64-setup.exe"
mv_ok "Windows 安装包：$MV_DIST/MiniVoice-${MV_VERSION}-windows-x64-setup.exe（待实机验收）"

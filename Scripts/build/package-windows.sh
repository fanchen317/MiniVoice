#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
case "$(uname -s)" in
 MINGW*|MSYS*|CYGWIN*) ;;
 *) echo 'Windows 构建需在 Windows x64 上运行 Scripts/build.ps1，或在 Git Bash 中运行 Scripts/build.sh --platforms windows；本机不能产出已验证的 Windows 原生核心。' >&2; exit 1 ;;
esac
command -v powershell.exe >/dev/null || { echo '缺少 Windows PowerShell' >&2; exit 1; }
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$ROOT/Windows/build.ps1")"

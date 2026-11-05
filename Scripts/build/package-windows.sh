#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
case "$(uname -s)" in
 MINGW*|MSYS*|CYGWIN*) ;;
 *) exec bash "$ROOT/Scripts/build/package-windows-cross.sh" ;;
esac
command -v powershell.exe >/dev/null || { echo '缺少 Windows PowerShell' >&2; exit 1; }
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$ROOT/Windows/build.ps1")"

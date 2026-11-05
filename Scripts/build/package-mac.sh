#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
[[ "${1:-build}" == build ]] || { echo '安装请使用 Scripts/deploy.sh' >&2; exit 2; }
bash "$ROOT/Scripts/build/build-app.sh" release
bash "$ROOT/Scripts/build/build-dmg.sh" --skip-build

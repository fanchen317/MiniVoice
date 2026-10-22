#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
[[ -f "$repo_root/MacOS/Desktop/node_modules/vite/bin/vite.js" ]] || { echo '请先在 MacOS/Desktop 安装锁定的前端依赖。' >&2; exit 1; }
node "$repo_root/MacOS/Desktop/node_modules/vite/bin/vite.js" build --config "$repo_root/Shared/UI/vite.config.mjs"

node "$repo_root/Scripts/package-shared-notices.mjs" "$repo_root/.build/Shared/UI"

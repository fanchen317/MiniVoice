#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
node "$repo_root/Scripts/check-ui-standards.mjs"
[[ -f "$repo_root/MacOS/Desktop/node_modules/vite/bin/vite.js" ]] || { echo '请先在 MacOS/Desktop 安装锁定的前端依赖。' >&2; exit 1; }
node "$repo_root/MacOS/Desktop/node_modules/vite/bin/vite.js" build --config "$repo_root/Shared/UI/vite.config.mjs"

# Keep the unprefixed blur declaration: prefix folding previously shipped a
# transparent but unblurred Android surface despite correct dev rendering.
node --input-type=module - "$repo_root/.build/Shared/UI/assets" <<'JS'
import fs from 'node:fs';import path from 'node:path';
const folder=process.argv[2],css=fs.readdirSync(folder).filter(name=>name.endsWith('.css')).map(name=>fs.readFileSync(path.join(folder,name),'utf8')).join('\n');
if(!/(?<!-)backdrop-filter:\s*blur\(var\(--mv-material-blur\)\)/.test(css))throw Error('Shared UI build lost unprefixed glass blur');
console.log('PASS packaged unprefixed glass blur');
JS

node "$repo_root/Scripts/package-shared-notices.mjs" "$repo_root/.build/Shared/UI"

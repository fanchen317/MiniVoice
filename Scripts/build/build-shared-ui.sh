#!/usr/bin/env bash
# Builds the shared React/Vite package into .build/work/shared-ui.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
output="$repo_root/.build/work/shared-ui"
source "$repo_root/Scripts/common/node-runtime.sh"
minivoice_select_node_runtime
node "$repo_root/Scripts/checks/check-ui-standards.mjs"
# Shared/UI is an independent package: it installs its own locked dependencies
# from the repository offline archive and never borrows the desktop package.
node "$repo_root/Shared/Tooling/prepare-dependencies.mjs" shared-ui
node "$repo_root/Shared/UI/node_modules/vite/bin/vite.js" build --config "$repo_root/Shared/UI/vite.config.mjs"

# Keep the unprefixed blur declaration: prefix folding previously shipped a
# transparent but unblurred Android surface despite correct dev rendering.
node --input-type=module - "$output/assets" <<'JS'
import fs from 'node:fs';import path from 'node:path';
const folder=process.argv[2],css=fs.readdirSync(folder).filter(name=>name.endsWith('.css')).map(name=>fs.readFileSync(path.join(folder,name),'utf8')).join('\n');
if(!/(?<!-)backdrop-filter:\s*blur\(var\(--mv-material-blur\)\)/.test(css))throw Error('Shared UI build lost unprefixed glass blur');
console.log('PASS packaged unprefixed glass blur');
JS

node "$repo_root/Scripts/build/package-shared-notices.mjs" "$output"
printf 'Shared UI: %s\n' "$output"

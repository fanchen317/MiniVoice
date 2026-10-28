#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"
mkdir -p .build/reports/ui
component_port="${MINIVOICE_WALL_TEST_PORT:-5190}"
node Shared/UI/node_modules/vite/bin/vite.js --config Shared/UI/vite.wall-test.config.mjs --host 127.0.0.1 --port "$component_port" --strictPort > .build/reports/ui/wall-v2-test-server.txt 2>&1 &
component_pid=$!
trap 'kill "$component_pid" 2>/dev/null || true' EXIT
ready=false
for attempt in {1..100}; do
 if ! kill -0 "$component_pid" 2>/dev/null; then cat .build/reports/ui/wall-v2-test-server.txt; exit 1; fi
 if curl --silent --fail "http://127.0.0.1:$component_port/tests/wall-mobile.html" >/dev/null; then ready=true; break; fi
 sleep .1
done
[[ "$ready" == true ]] || exit 1
MINIVOICE_WALL_TEST_URL="http://127.0.0.1:$component_port" MacOS/Desktop/node_modules/.bin/electron Scripts/tests/test-wall-version.cjs

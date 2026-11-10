#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"
mkdir -p .build/reports/ui
port="${MINIVOICE_SETTINGS_TEST_PORT:-5303}"
node Shared/UI/node_modules/vite/bin/vite.js --config Shared/UI/vite.wall-test.config.mjs --host 127.0.0.1 --port "$port" --strictPort > .build/reports/ui/wall-settings-server.log 2>&1 &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true' EXIT
for attempt in {1..100}; do
 kill -0 "$server_pid" 2>/dev/null || { cat .build/reports/ui/wall-settings-server.log; exit 1; }
 if curl --silent --fail "http://127.0.0.1:$port/tests/wall-mobile.html" >/dev/null; then break; fi
 sleep .1
done
MINIVOICE_WALL_TEST_URL="http://127.0.0.1:$port" MacOS/Desktop/node_modules/.bin/electron Scripts/tests/test-wall-settings-placement.cjs

#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"
mkdir -p .build/reports/ui/ios-wall-edges .build/work
port="${MINIVOICE_IOS_EDGE_PORT:-5301}"
if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
 echo "专用测试端口 $port 已被占用，请通过 MINIVOICE_IOS_EDGE_PORT 指定空闲端口" >&2
 exit 1
fi
node Scripts/checks/check-ui-standards.mjs
node Shared/UI/node_modules/vite/bin/vite.js --config Shared/UI/vite.wall-test.config.mjs --host 127.0.0.1 --port "$port" --strictPort > .build/reports/ui/ios-wall-edges/server.log 2>&1 &
server_pid=$!
trap 'kill "$server_pid" 2>/dev/null || true' EXIT
ready=false
for attempt in {1..100}; do
 kill -0 "$server_pid" 2>/dev/null || { cat .build/reports/ui/ios-wall-edges/server.log; exit 1; }
 if curl --silent --fail "http://127.0.0.1:$port/tests/wall-mobile.html" >/dev/null; then ready=true; break; fi
 sleep .1
done
[[ "$ready" == true ]] || exit 1
for dpr in 1 2 3; do
 MINIVOICE_WALL_TEST_URL="http://127.0.0.1:$port" MINIVOICE_TEST_DPR="$dpr" MacOS/Desktop/node_modules/.bin/electron Scripts/tests/test-ios-wall-edge-pixels.cjs
done

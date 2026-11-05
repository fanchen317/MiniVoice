#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"
mkdir -p .build/reports/ui/word-timing-ui
test_port="${MINIVOICE_WORD_TEST_PORT:-5198}"
node Shared/UI/node_modules/vite/bin/vite.js --config Shared/UI/vite.wall-test.config.mjs --host 127.0.0.1 --port "$test_port" --strictPort > .build/reports/ui/word-timing-ui/server.txt 2>&1 &
test_pid=$!
trap 'kill "$test_pid" 2>/dev/null || true' EXIT
ready=false
for attempt in {1..100}; do
  if ! kill -0 "$test_pid" 2>/dev/null; then cat .build/reports/ui/word-timing-ui/server.txt; exit 1; fi
  if curl --silent --fail "http://127.0.0.1:$test_port/tests/wall-desktop.html" >/dev/null; then ready=true; break; fi
  sleep .1
done
[[ "$ready" == true ]] || exit 1
MINIVOICE_WORD_TEST_URL="http://127.0.0.1:$test_port" MacOS/Desktop/node_modules/.bin/electron Scripts/tests/test-word-timing-ui.cjs

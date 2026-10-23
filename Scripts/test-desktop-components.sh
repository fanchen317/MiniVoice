#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
mkdir -p .build/Shared/Core
component_port="${MINIVOICE_COMPONENT_PORT:-5188}"
component_url="http://127.0.0.1:$component_port/tests/components.html"
node MacOS/Desktop/node_modules/vite/bin/vite.js --config Shared/UI/vite.config.mjs --host 127.0.0.1 --port "$component_port" --strictPort > .build/Shared/Core/component-server.log 2>&1 &
component_pid=$!
trap 'kill "$component_pid" 2>/dev/null || true' EXIT
component_ready=false
for attempt in {1..100}; do
  if ! kill -0 "$component_pid" 2>/dev/null; then cat .build/Shared/Core/component-server.log; exit 1; fi
  if curl --silent --fail "$component_url" >/dev/null; then component_ready=true; break; fi
  sleep .1
done
[[ "$component_ready" == true ]] || { echo 'Component fixture did not start' >&2; exit 1; }
MINIVOICE_COMPONENT_URL="$component_url" MacOS/Desktop/node_modules/.bin/electron Scripts/test-desktop-components.cjs

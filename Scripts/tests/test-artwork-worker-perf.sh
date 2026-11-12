#!/usr/bin/env bash
# Isolated, bundled Electron test; model inference never accesses a music library.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
source "$repo_root/Scripts/common/node-runtime.sh"
minivoice_select_node_runtime
task_dir="$(mktemp -d "${TMPDIR:-/tmp}/minivoice-worker-perf.XXXXXX")"
trap 'rm -rf "$task_dir"' EXIT
node "$repo_root/MacOS/Desktop/test/artworkSubjectsBundle.mjs" "$task_dir"
"$repo_root/MacOS/Desktop/node_modules/.bin/electron" "$repo_root/MacOS/Desktop/test/artworkWorkerPerformance.cjs" "$task_dir"

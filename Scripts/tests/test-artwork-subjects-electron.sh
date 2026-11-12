#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
source "$repo_root/Scripts/common/node-runtime.sh"
minivoice_select_node_runtime
task_dir="$(mktemp -d "${TMPDIR:-/tmp}/minivoice-artwork-models.XXXXXX")"
trap 'rm -rf "$task_dir"' EXIT
node "$repo_root/MacOS/Desktop/test/artworkSubjectsBundle.mjs" "$task_dir"
electron="$repo_root/MacOS/Desktop/node_modules/.bin/electron"
"$electron" "$repo_root/MacOS/Desktop/test/artworkSubjectsElectron.cjs" "$task_dir"

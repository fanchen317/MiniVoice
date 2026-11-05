#!/usr/bin/env bash
# Synthetic, isolated renderer regression. Does not launch the music backend.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"
node Scripts/checks/check-ui-standards.mjs
node --test Shared/UI/test/artwork-crop.test.mjs Shared/UI/test/artwork-composition.test.mjs Shared/UI/test/artwork-viewport.test.mjs
MacOS/Desktop/node_modules/.bin/electron MacOS/Desktop/test/wallArtworkLifecycle.cjs
MacOS/Desktop/node_modules/.bin/electron Scripts/tests/test-wall-artwork-mobile.cjs

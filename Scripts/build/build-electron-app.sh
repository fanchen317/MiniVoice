#!/usr/bin/env bash
# Compatibility alias: there is only one MiniVoice application build.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
exec "$ROOT/Scripts/build/build-app.sh" "$@"

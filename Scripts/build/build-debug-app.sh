#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export MINIVOICE_BUILD_CHANNEL=debug
exec bash "$ROOT/Scripts/build/build-app.sh" "${1:-release}"

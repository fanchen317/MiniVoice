#!/usr/bin/env bash
# Builds or installs the desktop application for the requested action.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ACTION="$1"; VARIANT="$2"; LAUNCH="$3"
source "$ROOT/Scripts/common/desktop-common.sh"
bash "$ROOT/Scripts/build/build-app.sh" release
if [[ "$ACTION" == build ]]; then
  bash "$ROOT/Scripts/build/build-dmg.sh" --skip-build
else
  target=/Applications/MiniVoice.app
  [[ "$VARIANT" != experience ]] || target=/Applications/MiniVoice-debug.app
  args=(--skip-build --target "$target")
  [[ "$LAUNCH" == true ]] || args+=(--no-launch)
  bash "$ROOT/Scripts/build/install-mac.sh" "${args[@]}"
fi

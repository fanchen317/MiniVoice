#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ACTION="$1"; VARIANT="$2"; LAUNCH="$3"
source "$ROOT/Scripts/desktop-common.sh"
bash "$ROOT/Scripts/build-app.sh" release
if [[ "$ACTION" == build ]]; then
  bash "$ROOT/Scripts/build-dmg.sh" --skip-build
else
  target=/Applications/MiniVoice.app
  [[ "$VARIANT" != experience ]] || target=/Applications/MiniVoice-debug.app
  args=(--skip-build --target "$target")
  [[ "$LAUNCH" == true ]] || args+=(--no-launch)
  bash "$ROOT/Scripts/install-mac.sh" "${args[@]}"
fi

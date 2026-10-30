#!/usr/bin/env bash
set -euo pipefail
export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
bash "$ROOT/Scripts/build/build-shared-ui.sh"
DESTINATION="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/SharedPlayer"
mkdir -p "$DESTINATION"
# Vite hashes assets; replace only the generated UI directory inside this build product.
rsync -a --delete "$ROOT/.build/work/shared-ui/" "$DESTINATION/"
if [[ "${CONFIGURATION:-}" == Debug ]]; then
  cp "$ROOT/iOS/Tests/shared-host-smoke.js" "$ROOT/iOS/Tests/duo-layout-smoke.js" "$ROOT/iOS/Tests/wall-smoke-helpers.js" "$ROOT/iOS/Tests/wall-stress-smoke.js" "$DESTINATION/"
  mkdir -p "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/AudioTestFixtures"
  cp "$ROOT/Android/ui-tests/assets/tags.mp3" "$ROOT/Android/ui-tests/assets/tags.flac" "$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH/AudioTestFixtures/"
fi

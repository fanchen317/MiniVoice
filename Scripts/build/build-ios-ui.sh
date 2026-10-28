#!/usr/bin/env bash
# Xcode build phase: packages the shared mobile UI into the app bundle.
set -euo pipefail
export PATH=/opt/homebrew/bin:/usr/local/bin:$PATH
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILT_PRODUCTS_DIR="${BUILT_PRODUCTS_DIR:?缺少 BUILT_PRODUCTS_DIR}"
PRODUCT_NAME="${PRODUCT_NAME:-MiniVoice}"
APP="$BUILT_PRODUCTS_DIR/$PRODUCT_NAME.app"
bash "$ROOT/Scripts/build/build-shared-ui.sh"
DESTINATION="$APP/SharedPlayer"
rm -rf "$DESTINATION"
mkdir -p "$DESTINATION"
ditto "$ROOT/.build/work/shared-ui" "$DESTINATION"
# The simulator smoke test is executed inside the real WKWebView.
cp "$ROOT/iOS/Tests/shared-host-smoke.js" "$DESTINATION/shared-host-smoke.js"
printf 'SharedPlayer: %s\n' "$DESTINATION"

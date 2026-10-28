#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/minivoice-icon.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT
if [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
swiftc "$ROOT/MacOS/Sources/MiniVoice/BrandIcon.swift" "$ROOT/Scripts/assets/IconGenerator.swift" -o "$WORK_DIR/icon-generator" -framework AppKit
"$WORK_DIR/icon-generator" "$WORK_DIR/MiniVoice.iconset"
iconutil -c icns "$WORK_DIR/MiniVoice.iconset" -o "$WORK_DIR/MiniVoice.icns"
[[ -s "$WORK_DIR/MiniVoice.icns" ]]
cp "$WORK_DIR/MiniVoice.icns" "$ROOT/MacOS/AppBundle/MiniVoice.icns"
echo "已更新：$ROOT/MacOS/AppBundle/MiniVoice.icns"

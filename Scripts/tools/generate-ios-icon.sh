#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/minivoice-ios-icon.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT
swiftc "$ROOT/MacOS/Sources/MiniVoice/BrandIcon.swift" "$ROOT/Scripts/assets/IOSIconGenerator.swift" -o "$WORK_DIR/ios-icon-generator" -framework AppKit
"$WORK_DIR/ios-icon-generator" "$ROOT/iOS/MiniVoice/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
cp "$ROOT/iOS/MiniVoice/Assets.xcassets/AppIcon.appiconset/AppIcon.png" "$ROOT/iOS/MiniVoice/Assets.xcassets/AppIconPreview.imageset/AppIconPreview.png"
echo '已更新 iOS 图标：1024×1024、不透明、背景铺满；圆角由系统裁切。'

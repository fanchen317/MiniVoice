#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DEVICE="${1:?请提供专用 MiniVoice Shared iOS 模拟器 UUID}"
xcrun simctl list devices -j | python3 -c 'import json,sys; devices=[d for rows in json.load(sys.stdin)["devices"].values() for d in rows if d["udid"]==sys.argv[1]]; assert devices and devices[0]["name"].startswith("MiniVoice Shared iOS"), "只允许专用模拟器"' "$DEVICE"
node "$ROOT/Scripts/checks/check-ui-standards.mjs"
OUTPUT="$ROOT/.build/reports/ios/layout/$DEVICE/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$OUTPUT"
xcodebuild -project "$ROOT/iOS/MiniVoice.xcodeproj" -scheme MiniVoice \
 -destination "platform=iOS Simulator,id=$DEVICE" \
 -derivedDataPath "$ROOT/.build/cache/ios/DerivedData" \
 -resultBundlePath "$OUTPUT/results.xcresult" -parallel-testing-enabled NO \
 -collect-test-diagnostics never ARCHS="$(uname -m)" ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO test
xcrun xcresulttool export attachments --path "$OUTPUT/results.xcresult" --output-path "$OUTPUT/attachments"
echo "系统点按与旋转报告：$OUTPUT"

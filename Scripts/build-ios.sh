#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DESTINATION="${1:-simulator}"
CONFIGURATION="${2:-Debug}"
case "$DESTINATION" in
  simulator) SDK=iphonesimulator; TARGET='generic/platform=iOS Simulator' ;;
  device) SDK=iphoneos; TARGET='generic/platform=iOS' ;;
  *) echo '用法：Scripts/build-ios.sh [simulator|device] [Debug|Release]' >&2; exit 2 ;;
esac
case "$CONFIGURATION" in
  Debug|Release) ;;
  *) echo '配置须为 Debug 或 Release' >&2; exit 2 ;;
esac

xcodebuild -project "$ROOT/iOS/MiniVoice.xcodeproj" \
  -scheme MiniVoice -configuration "$CONFIGURATION" \
  -sdk "$SDK" -destination "$TARGET" \
  -derivedDataPath "$ROOT/.build/iOS/DerivedData" \
  CODE_SIGNING_ALLOWED=NO build

echo "应用：$ROOT/.build/iOS/DerivedData/Build/Products/$CONFIGURATION-$SDK/MiniVoice.app"

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUTPUT="$ROOT/.build/reports/ios/tests"
mkdir -p "$OUTPUT"
swift build --package-path "$ROOT/Shared/Core" --scratch-path "$ROOT/.build/cache/swift-shared-core"
SHARED_BIN="$(swift build --package-path "$ROOT/Shared/Core" --scratch-path "$ROOT/.build/cache/swift-shared-core" --show-bin-path)"
if [[ -d "$SHARED_BIN/Modules" ]]; then
  SHARED_FLAGS=(-I "$SHARED_BIN/Modules" -Xcc "-fmodule-map-file=$SHARED_BIN/MiniVoiceCore.build/module.modulemap" "$SHARED_BIN/MiniVoiceShared.build/SharedEngine.swift.o" "$SHARED_BIN/MiniVoiceCore.build/core.cpp.o" "$SHARED_BIN/MiniVoiceCore.build/vendor/utf8proc.c.o")
else
  SHARED_FLAGS=(-I "$SHARED_BIN" -Xcc "-fmodule-map-file=$SHARED_BIN/../../Intermediates.noindex/GeneratedModuleMaps/MiniVoiceCore.modulemap" "$SHARED_BIN/MiniVoiceShared.o" "$SHARED_BIN/MiniVoiceCore.o")
fi
swiftc "${SHARED_FLAGS[@]}" -lc++ "$ROOT/iOS/MiniVoice/Models.swift" "$ROOT/iOS/Tests/LRCParserTests.swift" -o "$OUTPUT/lrc-tests"
"$OUTPUT/lrc-tests"
swiftc "$ROOT/iOS/MiniVoice/WeightedWallScene.swift" "$ROOT/iOS/Tests/WeightedWallSceneTests.swift" -o "$OUTPUT/wall-tests"
"$OUTPUT/wall-tests"

swiftc "${SHARED_FLAGS[@]}" -lc++ "$ROOT/iOS/MiniVoice/Models.swift" "$ROOT/iOS/MiniVoice/ParitySupport.swift" "$ROOT/iOS/Tests/ParitySupportTests.swift" -o "$OUTPUT/parity-tests"
"$OUTPUT/parity-tests" "$OUTPUT/diagnostics-test.zip"
python3 - "$OUTPUT/diagnostics-test.zip" <<'ZIPTEST'
import sys,zipfile,json
with zipfile.ZipFile(sys.argv[1]) as z:
    assert z.testzip() is None
    assert json.loads(z.read('diagnostics.json')) == {'ok':True}
print('PASS: diagnostic ZIP extracted and CRC validated')
ZIPTEST

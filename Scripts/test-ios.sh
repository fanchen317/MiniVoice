#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="$ROOT/.build/iOS/tests"
mkdir -p "$OUTPUT"
swiftc "$ROOT/iOS/MiniVoice/Models.swift" "$ROOT/iOS/Tests/LRCParserTests.swift" -o "$OUTPUT/lrc-tests"
"$OUTPUT/lrc-tests"
swiftc "$ROOT/iOS/MiniVoice/WeightedWallScene.swift" "$ROOT/iOS/Tests/WeightedWallSceneTests.swift" -o "$OUTPUT/wall-tests"
"$OUTPUT/wall-tests"

#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
SOURCE="$ROOT/.build/whisper-lite-source"
DEST="$ROOT/.build/lyrics-lite"
COMMIT=0c7be696371069e0baa2515ed7aa08d5a5473aa6
MODEL_SHA=ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb
if [[ ! -d "$SOURCE/.git" || "$(git -C "$SOURCE" rev-parse HEAD)" != "$COMMIT" ]]; then
  echo "准备 whisper.cpp 源码到 $SOURCE，并检出 $COMMIT 后重试" >&2; exit 1
fi
MODEL="$DEST/models/ggml-small-q5_1.bin"
if [[ ! -f "$MODEL" || "$(shasum -a 256 "$MODEL" | awk '{print $1}')" != "$MODEL_SHA" ]]; then
  echo "缺少正确的 small-q5_1 模型，见 Experiments/LyricsLite/README.md" >&2; exit 1
fi
CMAKE="${CMAKE_BIN:-$ROOT/.build/lyrics-lite-tools/bin/cmake}"
"$CMAKE" -S "$SOURCE" -B "$DEST/build" -DCMAKE_BUILD_TYPE=Release -DWHISPER_BUILD_TESTS=OFF -DGGML_METAL=ON -DGGML_NATIVE=OFF
"$CMAKE" --build "$DEST/build" --config Release --target whisper-cli -j 4
mkdir -p "$DEST/bin" "$DEST/package/bin" "$DEST/package/models"
swiftc -O "$ROOT/Experiments/LyricsLite/main.swift" -o "$DEST/bin/lyrics-lite"
clang++ -std=c++17 -O3 -Wno-deprecated-literal-operator \
  "$ROOT/Experiments/LyricsLite/forced.cpp" \
  -I"$SOURCE/include" -I"$SOURCE/ggml/include" -I"$SOURCE/examples" \
  -L"$DEST/build/bin" -lwhisper -Wl,-rpath,"$DEST/build/bin" \
  -o "$DEST/bin/lyrics-force"
"$DEST/bin/lyrics-lite" --self-test
cp "$DEST/bin/lyrics-lite" "$DEST/package/bin/"
cp "$DEST/bin/lyrics-force" "$DEST/package/bin/"
cp "$DEST/build/bin/whisper-cli" "$DEST/package/bin/"
for library in "$DEST/build/bin"/libwhisper*.dylib "$DEST/build/bin"/libggml*.dylib; do
  cp -P "$library" "$DEST/package/bin/"
done
# Make the experimental bundle portable rather than resolving build-tree libraries.
for binary in "$DEST/package/bin"/*; do
  if [[ ! -L "$binary" ]]; then
    if otool -l "$binary" | grep -q "$DEST/build/bin"; then
      install_name_tool -rpath "$DEST/build/bin" @loader_path "$binary"
    fi
    codesign --force --sign - "$binary"
  fi
done
cp "$MODEL" "$DEST/package/models/"
cp "$SOURCE/LICENSE" "$DEST/package/WHISPER-CPP-LICENSE"
cp "$SOURCE/examples/json.hpp" "$DEST/package/NLOHMANN-JSON-NOTICES.hpp"
echo "Experimental package: $DEST/package"
du -sh "$DEST/package"

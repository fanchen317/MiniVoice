#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODEL_SOURCE="${1:-}"
RUNTIME_PYTHON="${LYRICS_PYTHON:-$HOME/Library/Application Support/MiniVoice/LyricsAI/venv/bin/python3}"
OUTPUT="$ROOT/Vendor/LyricsAI/arm64"
DIST="$ROOT/.build/offline-ai/optimized-dist"
WORK="$ROOT/.build/offline-ai/optimized-work"
MODEL_SHA="9ecf779972d90ba49c06d968637d720dd632c55bbf19d441fb42bf17a411e794"

if [[ "$(uname -m)" != "arm64" || -z "$MODEL_SOURCE" || ! -f "$MODEL_SOURCE" || ! -x "$RUNTIME_PYTHON" ]]; then
  echo "用法：Scripts/refresh-lyrics-assets.sh /absolute/path/to/small.pt（需要 arm64 和已安装依赖的 LYRICS_PYTHON）" >&2
  exit 2
fi
if [[ "$(shasum -a 256 "$MODEL_SOURCE" | awk '{print $1}')" != "$MODEL_SHA" ]]; then
  echo "error: small.pt 不是原版 OpenAI Whisper small 模型" >&2
  exit 1
fi
"$RUNTIME_PYTHON" - <<'PY'
from importlib.metadata import version
required = {
    "stable-ts": "2.19.1", "torch": "2.8.0", "torchaudio": "2.8.0",
    "openai-whisper": "20250625", "pyinstaller": "6.16.0",
}
for package, expected in required.items():
    actual = version(package)
    if actual != expected:
        raise SystemExit(f"{package}: expected {expected}, found {actual}")
PY

cd "$ROOT"
"$RUNTIME_PYTHON" -m PyInstaller --noconfirm --clean \
  --distpath "$DIST" --workpath "$WORK" Scripts/lyrics-worker.spec
WORKER="$DIST/lyrics-worker"
for LIBRARY in "$WORKER/_internal/torch/lib/libtorch_cpu.dylib" \
               "$WORKER/_internal/llvmlite/binding/libllvmlite.dylib"; do
  strip -x "$LIBRARY"
  codesign --force --sign - "$LIBRARY"
done
"$WORKER/lyrics-worker" --self-test "$MODEL_SOURCE"
mkdir -p "$OUTPUT"
cp "$MODEL_SOURCE" "$OUTPUT/small.pt"
tar -C "$DIST" -czf "$OUTPUT/lyrics-worker.tar.gz" lyrics-worker
(
  cd "$OUTPUT"
  shasum -a 256 lyrics-worker.tar.gz small.pt > SHA256SUMS
)
echo "已更新 $OUTPUT；请检查并提交 Git LFS 资源。"

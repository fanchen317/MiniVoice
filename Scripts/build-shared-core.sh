#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source_root="$repo_root/Shared/Core/Sources/MiniVoiceCore"
output="$repo_root/.build/Shared/Core"
mkdir -p "$output"
# Sources and flags are shared with the Android NDK build; these are host test/preview artifacts.
clang -O2 -fPIC -DUTF8PROC_STATIC -c "$source_root/vendor/utf8proc.c" -o "$output/utf8proc.o"
clang++ -std=c++17 -O2 -fPIC -DUTF8PROC_STATIC -I "$source_root" -c "$source_root/core.cpp" -o "$output/core.o"
java_home="$(/usr/libexec/java_home)"
clang++ -std=c++17 -O2 -fPIC -DUTF8PROC_STATIC -I "$source_root" -I "$java_home/include" -I "$java_home/include/darwin" -dynamiclib "$repo_root/Shared/Core/Adapters/android_jni.cpp" "$output/core.o" "$output/utf8proc.o" -o "$output/libminivoice_core.dylib"
clang++ -std=c++17 -O2 -I "$source_root" "$repo_root/Shared/Core/Tests/cli.cpp" "$output/core.o" "$output/utf8proc.o" -o "$output/minivoice-core"
printf 'Shared core: %s\n' "$output"

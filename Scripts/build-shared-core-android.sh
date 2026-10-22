#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/Scripts/android-sdk.sh"
sdk_root="$(minivoice_find_sdk build)"
ndk="${ANDROID_NDK_HOME:-$sdk_root/ndk/27.2.12479018}"
toolchain="$ndk/toolchains/llvm/prebuilt/darwin-x86_64/bin"
[[ -x "$toolchain/clang++" ]] || { echo "缺少 NDK 27.2.12479018，请使用 sdkmanager 安装 ndk;27.2.12479018" >&2; exit 1; }
source_root="$repo_root/Shared/Core/Sources/MiniVoiceCore"
output="$repo_root/.build/Android/native"
for pair in arm64-v8a:aarch64-linux-android x86_64:x86_64-linux-android armeabi-v7a:armv7a-linux-androideabi x86:i686-linux-android; do
  abi="${pair%%:*}"; target="${pair#*:}29"; folder="$output/lib/$abi"; mkdir -p "$folder"
  stamp="$(cat "$source_root/core.cpp" "$source_root/include/minivoice_core.h" "$source_root/core.hpp" "$repo_root/Shared/Core/Adapters/android_jni.cpp" "$source_root/vendor/SOURCES.json" "$0" | shasum -a 256 | cut -d ' ' -f 1)"
  if [[ -f "$folder/build.stamp" && "$(cat "$folder/build.stamp")" == "$stamp" && -f "$folder/libminivoice_core.so" ]]; then continue; fi
  "$toolchain/clang" --target="$target" -O2 -fPIC -DUTF8PROC_STATIC -c "$source_root/vendor/utf8proc.c" -o "$folder/utf8proc.o"
  "$toolchain/clang++" --target="$target" -std=c++17 -O2 -fPIC -fvisibility=hidden -fvisibility-inlines-hidden -DUTF8PROC_STATIC -I "$source_root" -shared -static-libstdc++ -Wl,-z,max-page-size=16384 -Wl,--gc-sections "$source_root/core.cpp" "$repo_root/Shared/Core/Adapters/android_jni.cpp" "$folder/utf8proc.o" -o "$folder/libminivoice_core.so"
  "$toolchain/llvm-strip" --strip-unneeded "$folder/libminivoice_core.so"
  printf '%s' "$stamp" > "$folder/build.stamp"
done

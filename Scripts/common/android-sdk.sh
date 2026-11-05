#!/usr/bin/env bash
# Shared SDK discovery. Source this file after setting repo_root.
minivoice_find_platform() {
  local sdk="$1" version
  # Prefer the project's original platform, then any newer installed platform.
  for version in 35 $(
    for dir in "$sdk"/platforms/android-*; do
      [[ -d "$dir" ]] || continue
      basename "$dir" | sed 's/^android-//'
    done | LC_ALL=C sort -t . -k1,1nr -k2,2nr -k3,3nr
  ); do
    if [[ -f "$sdk/platforms/android-$version/android.jar" ]]; then
      printf '%s\n' "$sdk/platforms/android-$version/android.jar"
      return 0
    fi
  done
  printf '缺少 Android Platform（需要 android-35 或更新稳定版本）：%s/platforms\n' "$sdk" >&2
  return 1
}

minivoice_sdk_valid() {
  local candidate="$1" mode="${2:-build}"
  minivoice_find_platform "$candidate" >/dev/null 2>&1 || return 1
  if [[ "$mode" == build ]]; then
    minivoice_find_build_tools "$candidate" >/dev/null 2>&1 || return 1
  fi
}

minivoice_find_build_tools() {
  local sdk="$1" version tool complete
  # Prefer the project's original version, then a newer stable installation.
  for version in 35.0.0 $(
    for tool in "$sdk"/build-tools/*; do
      [[ -d "$tool" ]] || continue
      basename "$tool"
    done | LC_ALL=C sort -t . -k1,1nr -k2,2nr -k3,3nr
  ); do
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue
    [[ "${version%%.*}" -ge 35 ]] || continue
    complete=true
    for tool in aapt2 d8 zipalign apksigner; do
      [[ -x "$sdk/build-tools/$version/$tool" ]] || complete=false
    done
    if [[ "$complete" == true ]]; then
      printf '%s\n' "$sdk/build-tools/$version"
      return 0
    fi
  done
  printf '缺少完整的 Android Build Tools（35.0.0 或更新稳定版本）：%s/build-tools\n' "$sdk" >&2
  return 1
}

minivoice_find_sdk() {
  local mode="${1:-build}" configured="" candidate
  if [[ -n "${ANDROID_HOME:-}" ]]; then
    configured="$ANDROID_HOME"
  elif [[ -n "${ANDROID_SDK_ROOT:-}" ]]; then
    configured="$ANDROID_SDK_ROOT"
  elif [[ -f "$repo_root/Android/local.properties" ]]; then
    configured="$(sed -n 's/^[[:space:]]*sdk\.dir[[:space:]]*=[[:space:]]*//p' "$repo_root/Android/local.properties" | head -n 1 | sed 's/\\:/:/g; s/\\ / /g; s/\\\\/\\/g')"
  fi
  if [[ -n "$configured" ]]; then
    if minivoice_sdk_valid "$configured" "$mode"; then
      printf '%s\n' "$configured"
      return 0
    fi
    printf '配置的 Android SDK 不完整：%s\n需要 platforms/android-35/android.jar（android-35 或更新稳定版本）' "$configured" >&2
    [[ "$mode" != build ]] || printf ' 和 Build Tools 35.0.0 或更新稳定版本' >&2
    printf '。请检查 ANDROID_HOME、ANDROID_SDK_ROOT 或 Android/local.properties。\n' >&2
    return 1
  fi
  for candidate in \
    "$HOME/Library/Android/sdk" \
    "$HOME/Android/Sdk" \
    /opt/homebrew/share/android-commandlinetools \
    /usr/local/share/android-commandlinetools \
    "$repo_root/.build/android-sdk"; do
    if minivoice_sdk_valid "$candidate" "$mode"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  printf '未找到可用的 Android SDK。请安装 Android SDK Platform 35（或更新稳定版本）' >&2
  [[ "$mode" != build ]] || printf ' 和 Build Tools 35.0.0（或更新稳定版本）' >&2
  printf '，并设置 ANDROID_HOME=/你的/Android/sdk。\n' >&2
  return 1
}

# SDK tools and the pinned NDK may be installed under different SDK roots.
minivoice_ndk_valid() {
  local ndk="$1" revision
  [[ -f "$ndk/source.properties" ]] || return 1
  revision="$(sed -n 's/^[[:space:]]*Pkg.Revision[[:space:]]*=[[:space:]]*//p' "$ndk/source.properties" | tr -d '\r' | sed 's/[[:space:]]*$//')"
  [[ "$revision" == 27.2.12479018 ]] || return 1
  local tool
  for tool in clang clang++ llvm-strip; do
    [[ -x "$ndk/toolchains/llvm/prebuilt/darwin-x86_64/bin/$tool" ]] || return 1
  done
}

minivoice_find_ndk() {
  local sdk="$1" candidate
  # An explicit setting is authoritative; never silently replace a broken one.
  if [[ -n "${ANDROID_NDK_HOME:-}" ]]; then
    if minivoice_ndk_valid "$ANDROID_NDK_HOME"; then
      printf '%s\n' "$ANDROID_NDK_HOME"; return 0
    fi
    printf '配置的 ANDROID_NDK_HOME 无效或版本不符：%s\n需要完整的 NDK 27.2.12479018，请检查 source.properties 与 LLVM 工具。\n' "$ANDROID_NDK_HOME" >&2
    return 1
  fi
  for candidate in \
    "$sdk/ndk/27.2.12479018" \
    "$HOME/Library/Android/sdk/ndk/27.2.12479018" \
    "$HOME/Android/Sdk/ndk/27.2.12479018" \
    /opt/homebrew/share/android-commandlinetools/ndk/27.2.12479018 \
    /usr/local/share/android-commandlinetools/ndk/27.2.12479018 \
    "$repo_root/.build/android-sdk/ndk/27.2.12479018"; do
    if minivoice_ndk_valid "$candidate"; then printf '%s\n' "$candidate"; return 0; fi
  done
  printf '未找到完整的 NDK 27.2.12479018（当前 SDK：%s）。\n请运行 sdkmanager --sdk_root="%s" "ndk;27.2.12479018"，或设置 ANDROID_NDK_HOME 指向已安装的该版本。\n' "$sdk" "$sdk" >&2
  return 1
}

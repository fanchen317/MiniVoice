#!/usr/bin/env bash
# Shared SDK discovery. Source this file after setting repo_root.
minivoice_sdk_valid() {
  local candidate="$1" mode="${2:-build}"
  [[ -f "$candidate/platforms/android-35/android.jar" ]] || return 1
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
    printf '配置的 Android SDK 不完整：%s\n需要 platforms/android-35/android.jar' "$configured" >&2
    [[ "$mode" != build ]] || printf ' 和 Build Tools 35.0.0 或更新稳定版本' >&2
    printf '。请检查 ANDROID_HOME、ANDROID_SDK_ROOT 或 Android/local.properties。\n' >&2
    return 1
  fi
  for candidate in \
    "$HOME/Library/Android/sdk" \
    "$HOME/Android/Sdk" \
    /opt/homebrew/share/android-commandlinetools \
    /usr/local/share/android-commandlinetools \
    "$repo_root/.build/cache/android-sdk"; do
    if minivoice_sdk_valid "$candidate" "$mode"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  printf '未找到可用的 Android SDK。请安装 Android SDK Platform 35' >&2
  [[ "$mode" != build ]] || printf ' 和 Build Tools 35.0.0（或更新稳定版本）' >&2
  printf '，并设置 ANDROID_HOME=/你的/Android/sdk。\n' >&2
  return 1
}

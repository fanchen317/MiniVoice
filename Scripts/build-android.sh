#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/Scripts/android-sdk.sh"
sdk_root="$(minivoice_find_sdk build)"
build_tools="$(minivoice_find_build_tools "$sdk_root")"
android_jar="$sdk_root/platforms/android-35/android.jar"
printf 'Android SDK: %s\nBuild Tools: %s\n' "$sdk_root" "$build_tools"
output="$repo_root/.build/Android"
# Keep signing identity outside disposable build output. An explicit old key wins.
keystore="${MINIVOICE_KEYSTORE:-$repo_root/Android/signing/debug.keystore}"
key_alias="${MINIVOICE_KEY_ALIAS:-androiddebugkey}"
export MINIVOICE_STORE_PASSWORD="${MINIVOICE_STORE_PASSWORD:-android}"
export MINIVOICE_KEY_PASSWORD="${MINIVOICE_KEY_PASSWORD:-$MINIVOICE_STORE_PASSWORD}"
if [[ ! -f "$keystore" ]]; then
  if [[ -n "${MINIVOICE_KEYSTORE:-}" ]]; then
    printf '指定的签名密钥不存在：%s\n' "$keystore" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$keystore")"
  if [[ -f "$output/debug.keystore" ]]; then
    cp -p "$output/debug.keystore" "$keystore"
  elif [[ -f "$HOME/.android/debug.keystore" ]]; then
    cp -p "$HOME/.android/debug.keystore" "$keystore"
  else
    keytool -genkeypair -keystore "$keystore" -storepass:env MINIVOICE_STORE_PASSWORD -keypass:env MINIVOICE_KEY_PASSWORD -alias "$key_alias" -dname 'CN=MiniVoice Debug,O=MiniVoice,C=CN' -keyalg RSA -keysize 2048 -validity 10000 >/dev/null 2>&1
  fi
fi
printf 'Signing key: %s\n' "$keystore"
keytool -list -keystore "$keystore" -storepass:env MINIVOICE_STORE_PASSWORD -alias "$key_alias" >/dev/null
mkdir -p "$output/classes" "$output/dex" "$output/generated"
rm -f "$output/MiniVoice-unsigned.apk" "$output/MiniVoice-unaligned.apk" "$output/MiniVoice-debug.apk"
"$build_tools/aapt2" compile --dir "$repo_root/Android/app/src/main/res" -o "$output/resources.zip"
"$build_tools/aapt2" link -o "$output/MiniVoice-unsigned.apk" -I "$android_jar" --manifest "$repo_root/Android/app/src/main/AndroidManifest.xml" -R "$output/resources.zip" --java "$output/generated" --auto-add-overlay
javac -source 17 -target 17 -cp "$android_jar" -d "$output/classes" "$output/generated/com/xcosmos/minivoice/R.java" "$repo_root"/Android/app/src/main/java/com/xcosmos/minivoice/*.java
"$build_tools/d8" --lib "$android_jar" --min-api 29 --output "$output/dex" "$output"/classes/com/xcosmos/minivoice/*.class
(cd "$output/dex" && zip -q "$output/MiniVoice-unsigned.apk" classes.dex)
"$build_tools/zipalign" -f 4 "$output/MiniVoice-unsigned.apk" "$output/MiniVoice-unaligned.apk"
"$build_tools/apksigner" sign --ks "$keystore" --ks-key-alias "$key_alias" --ks-pass env:MINIVOICE_STORE_PASSWORD --key-pass env:MINIVOICE_KEY_PASSWORD --out "$output/MiniVoice-debug.apk" "$output/MiniVoice-unaligned.apk"
"$build_tools/apksigner" verify "$output/MiniVoice-debug.apk"
printf 'APK: %s\n' "$output/MiniVoice-debug.apk"

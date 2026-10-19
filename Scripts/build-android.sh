#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
sdk_root="${ANDROID_HOME:-/opt/homebrew/share/android-commandlinetools}"
build_tools="$sdk_root/build-tools/35.0.0"
android_jar="$sdk_root/platforms/android-35/android.jar"
output="$repo_root/.build/Android"
mkdir -p "$output/classes" "$output/dex"
rm -f "$output/MiniVoice-unsigned.apk" "$output/MiniVoice-unaligned.apk" "$output/MiniVoice-debug.apk"
javac -source 17 -target 17 -cp "$android_jar" -d "$output/classes" "$repo_root"/Android/app/src/main/java/com/xcosmos/minivoice/*.java
"$build_tools/d8" --lib "$android_jar" --min-api 29 --output "$output/dex" "$output"/classes/com/xcosmos/minivoice/*.class
"$build_tools/aapt2" link -o "$output/MiniVoice-unsigned.apk" -I "$android_jar" --manifest "$repo_root/Android/app/src/main/AndroidManifest.xml" --auto-add-overlay
(cd "$output/dex" && zip -q "$output/MiniVoice-unsigned.apk" classes.dex)
"$build_tools/zipalign" -f 4 "$output/MiniVoice-unsigned.apk" "$output/MiniVoice-unaligned.apk"
if [[ ! -f "$output/debug.keystore" ]]; then
  keytool -genkeypair -keystore "$output/debug.keystore" -storepass android -keypass android -alias androiddebugkey -dname 'CN=MiniVoice Debug,O=MiniVoice,C=CN' -keyalg RSA -keysize 2048 -validity 10000 >/dev/null 2>&1
fi
"$build_tools/apksigner" sign --ks "$output/debug.keystore" --ks-key-alias androiddebugkey --ks-pass pass:android --key-pass pass:android --out "$output/MiniVoice-debug.apk" "$output/MiniVoice-unaligned.apk"
"$build_tools/apksigner" verify "$output/MiniVoice-debug.apk"
printf 'APK: %s\n' "$output/MiniVoice-debug.apk"

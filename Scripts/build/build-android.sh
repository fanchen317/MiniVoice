#!/usr/bin/env bash
# Assembles the Android package from the shared UI and the shared C++ core.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
VARIANT="${1:-experience}"
case "$VARIANT" in release|experience) ;; *) echo '用法：build-android.sh [release|experience]' >&2; exit 2 ;; esac
node "$repo_root/Scripts/checks/check-ui-standards.mjs"
source "$repo_root/Scripts/common/android-sdk.sh"
sdk_root="$(minivoice_find_sdk build)"
build_tools="$(minivoice_find_build_tools "$sdk_root")"
android_jar="$(minivoice_find_platform "$sdk_root")"
printf 'Android SDK: %s\nBuild Tools: %s\n' "$sdk_root" "$build_tools"
output="$repo_root/.build/work/android"
source "$repo_root/Scripts/common/android-signing.sh"
minivoice_check_signing "$repo_root"
printf 'Signing key: %s\nCertificate SHA-256: %s\n' "$keystore" "$signing_fingerprint"
bash "$repo_root/Scripts/build/build-shared-core-android.sh"
bash "$repo_root/Scripts/build/build-shared-ui.sh"
# Private assembly files never appear beside installable packages.
work="$(mktemp -d "$output/package.XXXXXX")"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/classes" "$work/dex" "$work/generated" "$repo_root/.build/dist"
cp "$repo_root/Android/app/src/main/AndroidManifest.xml" "$work/AndroidManifest.xml"
if [[ "$VARIANT" == release ]]; then
  python3 - "$work/AndroidManifest.xml" <<'MANIFEST'
import sys
import xml.etree.ElementTree as ET
p=sys.argv[1]; ET.register_namespace('android','http://schemas.android.com/apk/res/android')
t=ET.parse(p); ns='{http://schemas.android.com/apk/res/android}'; app=t.getroot().find('application')
a={v.get(ns+'name'):v for v in app.findall('activity')}
old=a['.PortablePlayerActivity']; new=a['.MainActivity']
for f in list(old.findall('intent-filter')): old.remove(f); new.append(f)
old.set(ns+'exported','false'); new.set(ns+'exported','true'); t.write(p,encoding='utf-8',xml_declaration=True)
MANIFEST
fi
artifact="$repo_root/.build/dist/MiniVoice-android.apk"
[[ "$VARIANT" != experience ]] || artifact="$repo_root/.build/dist/MiniVoice-android-experience.apk"
"$build_tools/aapt2" compile --dir "$repo_root/Android/app/src/main/res" -o "$work/resources.zip"
"$build_tools/aapt2" link -o "$work/MiniVoice-unsigned.apk" -I "$android_jar" --manifest "$work/AndroidManifest.xml" -R "$work/resources.zip" --java "$work/generated" --auto-add-overlay -A "$repo_root/.build/work/shared-ui"
javac -source 17 -target 17 -cp "$android_jar" -d "$work/classes" "$work/generated/com/xcosmos/minivoice/R.java" "$repo_root"/Android/app/src/main/java/com/xcosmos/minivoice/*.java
"$build_tools/d8" --lib "$android_jar" --min-api 29 --output "$work/dex" "$work"/classes/com/xcosmos/minivoice/*.class
(cd "$work/dex" && zip -q "$work/MiniVoice-unsigned.apk" classes.dex)
(cd "$output/native" && zip -q "$work/MiniVoice-unsigned.apk" lib/*/libminivoice_core.so)
"$build_tools/zipalign" -f 4 "$work/MiniVoice-unsigned.apk" "$work/MiniVoice-unaligned.apk"
"$build_tools/apksigner" sign --ks "$keystore" --ks-key-alias "$key_alias" --ks-pass env:MINIVOICE_STORE_PASSWORD --key-pass env:MINIVOICE_KEY_PASSWORD --out "$work/signed.apk" "$work/MiniVoice-unaligned.apk"
"$build_tools/apksigner" verify "$work/signed.apk"
mv -f "$work/signed.apk" "$artifact"
# Internal compatibility for instrumentation, not an extra public package.
rm -rf "$output/classes"; mv "$work/classes" "$output/classes"
if [[ "$VARIANT" == experience ]]; then ln -sfn ../../dist/MiniVoice-android-experience.apk "$output/MiniVoice-debug.apk"; fi
printf 'APK: %s\n' "$artifact"

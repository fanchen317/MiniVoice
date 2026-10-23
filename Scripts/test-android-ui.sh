#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/Scripts/android-sdk.sh"
sdk_root="$(minivoice_find_sdk build)"
build_tools="$(minivoice_find_build_tools "$sdk_root")"
output="$repo_root/.build/Android/ui-tests"
mkdir -p "$output/classes" "$output/dex"
# Test fixture replaces library state: only permit a dedicated emulator, never a user's phone.
serial="${1:-}"
if [[ -n "$serial" && "$serial" != emulator-* ]]; then
  echo 'UI 回归使用合成音乐库，只允许专用 emulator-* 设备。' >&2; exit 2
fi
bash "$repo_root/Scripts/build-android.sh"
"$build_tools/aapt2" link -o "$output/unsigned.apk" -I "$sdk_root/platforms/android-35/android.jar" --manifest "$repo_root/Android/ui-tests/AndroidManifest.xml" -A "$repo_root/Android/ui-tests/assets"
javac -source 17 -target 17 -cp "$sdk_root/platforms/android-35/android.jar:$repo_root/.build/Android/classes" -d "$output/classes" "$repo_root"/Android/ui-tests/com/xcosmos/minivoice/*.java
"$build_tools/d8" --lib "$sdk_root/platforms/android-35/android.jar" --min-api 29 --output "$output/dex" "$output"/classes/com/xcosmos/minivoice/*.class
(cd "$output/dex" && zip -q "$output/unsigned.apk" classes.dex)
"$build_tools/zipalign" -f 4 "$output/unsigned.apk" "$output/aligned.apk"
source "$repo_root/Scripts/android-signing.sh"
minivoice_check_signing "$repo_root"
"$build_tools/apksigner" sign --ks "$keystore" --ks-key-alias "$key_alias" --ks-pass env:MINIVOICE_STORE_PASSWORD --key-pass env:MINIVOICE_KEY_PASSWORD --out "$output/MiniVoice-ui-tests.apk" "$output/aligned.apk"
if [[ -z "$serial" ]]; then echo "已构建界面测试 APK。传入专用模拟器 serial 可执行：bash Scripts/test-android-ui.sh emulator-5554"; exit 0; fi
adb="$sdk_root/platform-tools/adb"
"$adb" -s "$serial" install -r "$repo_root/.build/Android/MiniVoice-debug.apk"
"$adb" -s "$serial" install -r "$output/MiniVoice-ui-tests.apk"
"$adb" -s "$serial" shell pm clear com.xcosmos.minivoice
"$adb" -s "$serial" shell pm grant com.xcosmos.minivoice android.permission.POST_NOTIFICATIONS
"$adb" -s "$serial" shell am instrument -w com.xcosmos.minivoice.uitests/com.xcosmos.minivoice.UiRegressionInstrumentation | tee "$output/results.txt"
"$adb" -s "$serial" pull /sdcard/Android/data/com.xcosmos.minivoice/files/ui-regression "$output/screenshots" >/dev/null
rg -q '^UI_REGRESSION_PASS' "$output/results.txt"

"$adb" -s "$serial" shell am force-stop com.xcosmos.minivoice
# This phase deliberately crashes the disposable test process to exercise the real handler.
"$adb" -s "$serial" shell am instrument -w -e mode crash com.xcosmos.minivoice.uitests/com.xcosmos.minivoice.UiRegressionInstrumentation > "$output/crash-probe.txt" 2>&1 || true
"$adb" -s "$serial" shell am instrument -w -e mode restart com.xcosmos.minivoice.uitests/com.xcosmos.minivoice.UiRegressionInstrumentation | tee "$output/restart-results.txt"
rg -q '^UI_PROCESS_RESTART_PASS' "$output/restart-results.txt"

"$adb" -s "$serial" shell am instrument -w -e mode portable com.xcosmos.minivoice.uitests/com.xcosmos.minivoice.UiRegressionInstrumentation | tee "$output/portable-results.txt"
rg -q '^UI_PORTABLE_PASS' "$output/portable-results.txt"

"$adb" -s "$serial" shell am instrument -w -e mode modals com.xcosmos.minivoice.uitests/com.xcosmos.minivoice.UiRegressionInstrumentation | tee "$output/modal-results.txt"
rg -q '^UI_MODALS_PASS' "$output/modal-results.txt"

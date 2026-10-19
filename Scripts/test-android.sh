#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/Scripts/android-sdk.sh"
sdk_root="$(minivoice_find_sdk test)"
android_jar="$sdk_root/platforms/android-35/android.jar"
output="$repo_root/.build/Android/tests"
source_root="$repo_root/Android/app/src/main/java/com/xcosmos/minivoice"
mkdir -p "$output"
javac -cp "$android_jar" -d "$output" "$source_root/Lyrics.java" "$source_root/AudioTags.java" "$repo_root/Android/tests/com/xcosmos/minivoice/ParsingTests.java"
java -cp "$output:$android_jar" com.xcosmos.minivoice.ParsingTests "$@"

javac -d "$output" "$source_root/FocusCardMetrics.java" "$repo_root/Android/tests/com/xcosmos/minivoice/FocusCardTests.java"
java -cp "$output" com.xcosmos.minivoice.FocusCardTests

javac -d "$output" "$source_root/WallReflow.java" "$repo_root/Android/tests/com/xcosmos/minivoice/WallReflowTests.java"
java -cp "$output" com.xcosmos.minivoice.WallReflowTests

javac -d "$output" "$source_root/LyricIndex.java" "$source_root/LyricsLoadState.java" "$source_root/CoverPreviewBudget.java" "$repo_root/Android/tests/com/xcosmos/minivoice/LibraryResourceTests.java"
java -cp "$output" com.xcosmos.minivoice.LibraryResourceTests

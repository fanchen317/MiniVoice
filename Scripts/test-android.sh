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

javac -d "$output" "$source_root/FocusCardPresentation.java" "$source_root/PlaybackModes.java" "$source_root/FocusCardMetrics.java" "$repo_root/Android/tests/com/xcosmos/minivoice/FocusCardTests.java"
java -cp "$output" com.xcosmos.minivoice.FocusCardTests

javac -d "$output" "$source_root/WallReflow.java" "$repo_root/Android/tests/com/xcosmos/minivoice/WallReflowTests.java"
java -cp "$output" com.xcosmos.minivoice.WallReflowTests

javac -d "$output" "$source_root/LyricIndex.java" "$source_root/LyricsLoadState.java" "$source_root/CoverPreviewBudget.java" "$repo_root/Android/tests/com/xcosmos/minivoice/LibraryResourceTests.java"
java -cp "$output" com.xcosmos.minivoice.LibraryResourceTests

javac -d "$output" "$source_root/WallFocusMotion.java" "$repo_root/Android/tests/com/xcosmos/minivoice/WallFocusMotionTests.java"
java -cp "$output" com.xcosmos.minivoice.WallFocusMotionTests

javac -cp "$android_jar:$output" -d "$output" "$source_root/Song.java" "$source_root/EmbeddedLyrics.java" "$source_root/LibraryCache.java" "$source_root/LyricsRepository.java" "$source_root/ScanProgress.java" "$repo_root/Android/tests/com/xcosmos/minivoice/EmbeddedLyricsTests.java"
java -cp "$output:$android_jar" com.xcosmos.minivoice.EmbeddedLyricsTests

javac -d "$output" "$source_root/WallZoom.java" "$source_root/WallSearchDismiss.java" "$repo_root/Android/tests/com/xcosmos/minivoice/WallControlsTests.java"
java -cp "$output" com.xcosmos.minivoice.WallControlsTests

javac -d "$output" "$source_root/WallViewport.java" "$repo_root/Android/tests/com/xcosmos/minivoice/WallViewportTests.java"
java -cp "$output" com.xcosmos.minivoice.WallViewportTests

javac -cp "$output" -d "$output" "$source_root/PlayerExpansion.java" "$repo_root/Android/tests/com/xcosmos/minivoice/PlayerExpansionTests.java"
java -cp "$output" com.xcosmos.minivoice.PlayerExpansionTests

javac -d "$output" "$source_root/PanelDismiss.java" "$repo_root/Android/tests/com/xcosmos/minivoice/PanelDismissTests.java"
java -cp "$output" com.xcosmos.minivoice.PanelDismissTests

#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/Scripts/android-sdk.sh"
sdk_root="$(minivoice_find_sdk test)"
android_jar="$sdk_root/platforms/android-35/android.jar"
output="$repo_root/.build/Android/tests"
source_root="$repo_root/Android/app/src/main/java/com/xcosmos/minivoice"
mkdir -p "$output"
bash "$repo_root/Scripts/build-shared-core.sh"
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:-} -Djava.library.path=$repo_root/.build/Shared/Core"
javac -cp "$output" -d "$output" "$source_root/SharedCore.java"
javac -cp "$android_jar:$output" -d "$output" "$source_root/Lyrics.java" "$source_root/LyricSweep.java" "$source_root/AudioTags.java" "$repo_root/Android/tests/com/xcosmos/minivoice/ParsingTests.java"
java -cp "$output:$android_jar" com.xcosmos.minivoice.ParsingTests "$@"

javac -cp "$output" -d "$output" "$source_root/FocusCardPresentation.java" "$source_root/PlaybackModes.java" "$source_root/FocusCardMetrics.java" "$repo_root/Android/tests/com/xcosmos/minivoice/FocusCardTests.java"
java -cp "$output" com.xcosmos.minivoice.FocusCardTests

javac -cp "$output" -d "$output" "$source_root/WallReflow.java" "$repo_root/Android/tests/com/xcosmos/minivoice/WallReflowTests.java"
java -cp "$output" com.xcosmos.minivoice.WallReflowTests

javac -cp "$output" -d "$output" "$source_root/LyricIndex.java" "$source_root/LyricsLoadState.java" "$source_root/CoverPreviewBudget.java" "$repo_root/Android/tests/com/xcosmos/minivoice/LibraryResourceTests.java"
java -cp "$output" com.xcosmos.minivoice.LibraryResourceTests

javac -cp "$output" -d "$output" "$source_root/WallFocusMotion.java" "$repo_root/Android/tests/com/xcosmos/minivoice/WallFocusMotionTests.java"
java -cp "$output" com.xcosmos.minivoice.WallFocusMotionTests

javac -cp "$android_jar:$output" -d "$output" "$source_root/Song.java" "$source_root/EmbeddedLyrics.java" "$source_root/AppStorage.java" "$source_root/CacheMigration.java" "$source_root/LibraryCache.java" "$source_root/LyricsRepository.java" "$source_root/ScanProgress.java" "$repo_root/Android/tests/com/xcosmos/minivoice/EmbeddedLyricsTests.java"
java -cp "$output:$android_jar" com.xcosmos.minivoice.EmbeddedLyricsTests

javac -cp "$output" -d "$output" "$source_root/WallZoom.java" "$source_root/WallSearchDismiss.java" "$repo_root/Android/tests/com/xcosmos/minivoice/WallControlsTests.java"
java -cp "$output" com.xcosmos.minivoice.WallControlsTests

javac -cp "$output" -d "$output" "$source_root/WallViewport.java" "$repo_root/Android/tests/com/xcosmos/minivoice/WallViewportTests.java"
java -cp "$output" com.xcosmos.minivoice.WallViewportTests

javac -cp "$output" -d "$output" "$source_root/PlayerExpansion.java" "$repo_root/Android/tests/com/xcosmos/minivoice/PlayerExpansionTests.java"
java -cp "$output" com.xcosmos.minivoice.PlayerExpansionTests

javac -cp "$output" -d "$output" "$source_root/PanelDismiss.java" "$repo_root/Android/tests/com/xcosmos/minivoice/PanelDismissTests.java"
java -cp "$output" com.xcosmos.minivoice.PanelDismissTests

javac -cp "$android_jar:$output" -d "$output" "$source_root/AppAppearance.java" "$repo_root/Android/tests/com/xcosmos/minivoice/AppearanceTests.java"
java -cp "$output:$android_jar" com.xcosmos.minivoice.AppearanceTests

javac -cp "$android_jar:$output" -d "$output" "$source_root/Song.java" "$source_root/LibraryOrdering.java" "$repo_root/Android/tests/com/xcosmos/minivoice/LibraryOrderingTests.java"
java -cp "$output:$android_jar" com.xcosmos.minivoice.LibraryOrderingTests

javac -cp "$output" -d "$output" "$source_root/SheetPosition.java" "$repo_root/Android/tests/com/xcosmos/minivoice/SheetPositionTests.java"
java -cp "$output" com.xcosmos.minivoice.SheetPositionTests

javac -cp "$android_jar:$output" -d "$output" "$source_root/CacheMigration.java" "$repo_root/Android/tests/com/xcosmos/minivoice/CacheMigrationTests.java"
java -cp "$output:$android_jar" com.xcosmos.minivoice.CacheMigrationTests

javac -cp "$output" -d "$output" "$source_root/CacheFiles.java" "$repo_root/Android/tests/com/xcosmos/minivoice/CacheFilesTests.java"
java -cp "$output" com.xcosmos.minivoice.CacheFilesTests

javac -cp "$output" -d "$output" "$source_root/PlaybackBars.java" "$repo_root/Android/tests/com/xcosmos/minivoice/PlaybackBarsTests.java"
java -cp "$output" com.xcosmos.minivoice.PlaybackBarsTests

javac -cp "$output" -d "$output" "$source_root/CoverQuality.java" "$repo_root/Android/tests/com/xcosmos/minivoice/CoverQualityTests.java"
java -cp "$output" com.xcosmos.minivoice.CoverQualityTests

javac -cp "$output" -d "$output" "$source_root/ArtworkFraming.java" "$repo_root/Android/tests/com/xcosmos/minivoice/ArtworkFramingTests.java"
java -cp "$output" com.xcosmos.minivoice.ArtworkFramingTests

javac -cp "$output" -d "$output" "$source_root/CoverWorkingSet.java" "$repo_root/Android/tests/com/xcosmos/minivoice/CoverWorkingSetTests.java"
java -cp "$output" com.xcosmos.minivoice.CoverWorkingSetTests

javac -cp "$output" -d "$output" "$source_root/PlayerWorkspaceMetrics.java" "$repo_root/Android/tests/com/xcosmos/minivoice/PlayerWorkspaceTests.java"
java -cp "$output" com.xcosmos.minivoice.PlayerWorkspaceTests

javac -cp "$output" -d "$output" "$source_root/SongSelection.java" "$repo_root/Android/tests/com/xcosmos/minivoice/SongSelectionTests.java"
java -cp "$output" com.xcosmos.minivoice.SongSelectionTests

javac -cp "$output" -d "$output" "$source_root/LibraryColumns.java" "$repo_root/Android/tests/com/xcosmos/minivoice/LibraryColumnsTests.java"
java -cp "$output" com.xcosmos.minivoice.LibraryColumnsTests

javac -cp "$output" -d "$output" "$source_root/StyleFragmentMotion.java" "$repo_root/Android/tests/com/xcosmos/minivoice/StyleFragmentMotionTests.java"
java -cp "$output" com.xcosmos.minivoice.StyleFragmentMotionTests

javac -cp "$output" -d "$output" "$source_root/CoverAtmosphereColors.java" "$repo_root/Android/tests/com/xcosmos/minivoice/CoverAtmosphereTests.java"
java -cp "$output" com.xcosmos.minivoice.CoverAtmosphereTests

javac -cp "$output" -d "$output" "$source_root/ScanRequestQueue.java" "$source_root/ScanStatusText.java" "$repo_root/Android/tests/com/xcosmos/minivoice/ScanServiceTests.java"
java -cp "$output" com.xcosmos.minivoice.ScanServiceTests

javac -cp "$output" -d "$output" "$source_root/GlassGaussian.java" "$repo_root/Android/tests/com/xcosmos/minivoice/GlassGaussianTests.java"
java -cp "$output" com.xcosmos.minivoice.GlassGaussianTests

javac -cp "$output" -d "$output" "$source_root/DrawerMaterialState.java" "$repo_root/Android/tests/com/xcosmos/minivoice/DrawerMaterialTests.java"
java -cp "$output" com.xcosmos.minivoice.DrawerMaterialTests

javac -cp "$output" -d "$output" "$source_root/PageScrollMemory.java" "$repo_root/Android/tests/com/xcosmos/minivoice/PageScrollMemoryTests.java"
java -cp "$output" com.xcosmos.minivoice.PageScrollMemoryTests

javac -cp "$output" -d "$output" "$source_root/IncrementalScan.java" "$source_root/ArtistNames.java" "$repo_root/Android/tests/com/xcosmos/minivoice/LibraryCapabilityTests.java"
java -cp "$output" com.xcosmos.minivoice.LibraryCapabilityTests
javac -cp "$android_jar:$output" -d "$output" "$repo_root/Android/tests/com/xcosmos/minivoice/BilingualLyricsTests.java"
java -cp "$output:$android_jar" com.xcosmos.minivoice.BilingualLyricsTests

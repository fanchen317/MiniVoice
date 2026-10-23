#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/Scripts/android-sdk.sh"
sdk_root="$(minivoice_find_sdk test)"
ffmpeg_bin="$(command -v ffmpeg)"
ffprobe_bin="$(command -v ffprobe)"
output="$repo_root/.build/Android/tag-tests"
source_root="$repo_root/Android/app/src/main/java/com/xcosmos/minivoice"
mkdir -p "$output/classes" "$output/fixtures"
for version in 3 4; do
 "$ffmpeg_bin" -v error -f lavfi -i 'sine=frequency=440:duration=1' -metadata comment='preserve me' -id3v2_version "$version" -y "$output/fixtures/mp3$version.mp3"
 "$ffmpeg_bin" -v error -f lavfi -i 'sine=frequency=440:duration=1' -metadata comment='preserve me' -y "$output/fixtures/flac$version.flac"
 if [[ "$version" == 4 ]]; then
  "$ffmpeg_bin" -v error -f lavfi -i 'sine=frequency=440:duration=1' -metadata comment='preserve me' -movflags +faststart -y "$output/fixtures/m4a$version.m4a"
 else
  "$ffmpeg_bin" -v error -f lavfi -i 'sine=frequency=440:duration=1' -metadata comment='preserve me' -y "$output/fixtures/m4a$version.m4a"
 fi
done
android_jar="$sdk_root/platforms/android-35/android.jar"
javac -cp "$android_jar" -d "$output/classes" "$source_root/AudioTags.java" "$source_root/PortableTagCodec.java" "$source_root/PortableM4aTags.java" "$repo_root/Android/tests/com/xcosmos/minivoice/PortableTagCodecTests.java"
java -cp "$output/classes:$android_jar" com.xcosmos.minivoice.PortableTagCodecTests "$output/fixtures" "$ffmpeg_bin" "$ffprobe_bin"

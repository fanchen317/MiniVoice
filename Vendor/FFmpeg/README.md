# Bundled FFmpeg (macOS arm64)

MiniVoice includes `ffmpeg` and `ffprobe` from the pinned [FFmpeg 8.0.3 arm64 static release](https://github.com/AtlasYang/ffmpeg-static-builds/releases/tag/ffmpeg-8.0.3-build4). The upstream archive is `ffmpeg-8.0.3-macos-arm64.tar.gz` (SHA-256 `26f6269b117a51c5fdfd3a870c4e0a62b99f0575740a3933fc3d852f0a3f80b1`). The two executables were extracted without modification. Their individual hashes are in `arm64/SHA256SUMS`; `arm64/configure.txt` is the release's build configuration.

The build disables GPL and nonfree components. FFmpeg is licensed under LGPL 2.1 or later; see `COPYING.LGPLv2.1`. FFmpeg source is available from the [FFmpeg 8.0.3 release](https://ffmpeg.org/releases/ffmpeg-8.0.3.tar.xz). The binary build and its linked libraries remain subject to their respective upstream notices. Review the [FFmpeg distribution guidance](https://ffmpeg.org/legal.html) before publishing a DMG.

These checked-in binaries are arm64 only. An Intel build requires a separately pinned and verified x86_64 resource.

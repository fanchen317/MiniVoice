# MiniVoice

轻量 macOS 本地音乐播放器，支持导入 MP3、FLAC、M4A、AAC、WAV 与 AIFF，播放与 Apple Music 风格的逐行歌词显示（不自动滚动）。

## 功能

- 导入和播放本地通用音频格式
- 显示、编辑和写入歌曲名称、多个歌手（用 `/` 分隔）、专辑、LRC 歌词和自定义封面
- 保存时使用 `ffmpeg` 重封装写回原歌曲文件，保留音频码流，不重新编码

## 运行

```sh
brew install ffmpeg
swift run
```

编辑后选择“保存到歌曲文件”即可写回。macOS 的安全文件选择器会为用户选取的文件授予访问权限；请确保歌曲文件不是只读。

生成可双击打开的 App：

```sh
chmod +x Scripts/build-app.sh
Scripts/build-app.sh
open build/MiniVoice.app
```

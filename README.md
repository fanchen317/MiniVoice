# MiniVoice

轻量原生 macOS 本地音乐播放器，基于 SwiftUI 与 AVFoundation，macOS 13 及以上。

## 已实现

- 导入、播放 MP3、FLAC、M4A、AAC、WAV、AIFF；进度跳转、音量、上一首/下一首。
- 重启恢复音乐库；从 Finder 使用“打开方式”导入歌曲。
- 参考提供的绿色 MV 音符，以原生矢量绘制应用图标，构建时生成全尺寸 ICNS。
- 状态栏图标可选隐藏、彩色、纯色（随系统明暗外观变化），设置自动保存；可在 MiniVoice → 设置（⌘,）或状态栏菜单切换。
- 状态栏菜单支持打开主窗口、播放/暂停和退出。
- 编辑歌曲名称、专辑，逐个添加/移除歌手；文件内以 ` / ` 保存多个歌手，保留名称内部的 `/`（例如 AC/DC）。不同播放器对多歌手的结构化识别可能不同。
- 读取内嵌歌词与封面；没有内嵌歌词时自动读取同名 `.lrc`。
- 导入 UTF-8 LRC/TXT、编辑歌词，支持多时间标签与 `[offset:...]`。
- Apple Music 风格的大字号逐行歌词，当前句高亮，点击带时间标签的歌词跳转；手动滚动，不自动滚动。
- 为 MP3、FLAC、M4A 写入名称、歌手、专辑、歌词，以及自定义封面的添加、替换、删除；音频码流复制，不重新编码。
- 写入成功才更新界面；每次保存会在歌曲旁保留 `原文件名.minivoice-backup-UUID` 原文件备份，需要恢复时将备份复制回原文件名。备份会累积，可在确认编辑正确后手动删除。

## 运行与部署

```sh
brew install ffmpeg
swift run
```

```sh
swift test
Scripts/deploy.sh
```

部署脚本先构建 release、验证签名，再退出旧版并替换 `/Applications/MiniVoice.app`，最后启动。依赖通过绝对路径查找，Finder 启动不依赖终端 PATH。当前部署面向本机，ffmpeg/ffprobe 需要保留在 Homebrew 安装位置。

单独构建：`Scripts/build-app.sh [debug|release]`，产物在 `.build/MiniVoice.app`。

## 当前边界

- AAC、WAV、AIFF 支持播放，暂不提供完整标签/封面写入，编辑窗口会明确提示。
- 暂无封面裁剪、歌词在线搜索、自动时间对齐、逐字卡拉 OK、播放队列管理。
- 歌曲路径移动后需重新导入；歌词文件暂要求 UTF-8。
- 本机使用 ad-hoc 签名；分发给其他 Mac 还需处理 ffmpeg 依赖、开发者签名与公证。

## 验证

`swift test` 包含歌词解析及 MP3/FLAC/M4A 实际文件往返测试：中文标签、多歌手、歌词、封面添加和删除、备份、AVAudioPlayer 可读取，以及保存前后音频码流 SHA-256 一致。

# MiniVoice iOS

原生 SwiftUI 本地音乐播放器，支持 iPhone 和 iPad，最低 iOS 17。界面参考 Android 版：深色音乐墙、侧栏分类、搜索、聚焦卡片、底部播放条和展开歌词页。

## 当前功能

- 从系统“文件”选择一个或多个音乐目录，保存访问书签；支持子文件夹扫描、重新扫描和移除目录。读取 MP3、M4A、AAC、FLAC、WAV、AIFF、CAF。音乐文件保持在原位置。
- 读取常见音频标签与内嵌封面；无标签时按文件名回退。读取内嵌歌词或同目录 `lrc/` 下的同名 LRC，也可在播放页手动导入 LRC；支持 UTF-8、UTF-16、GB18030、时间偏移和增强 LRC 时间标记。
- 歌曲、歌手、专辑、最近播放、收藏、歌单、搜索、播放队列、五种播放模式及进度拖动。收藏、歌单和音乐库索引保存在应用数据中，封面缩略图保存在应用缓存中。
- 后台音频、锁屏与控制中心媒体信息、播放/暂停、切歌及进度控制。

## 构建

在仓库根目录运行：

```sh
Scripts/build/build-ios.sh simulator Debug
```

脚本生成未签名的模拟器应用，位于 `.build/cache/ios/DerivedData/Build/Products/Debug-iphonesimulator/MiniVoice.app`。也可以在 Xcode 中打开 `iOS/MiniVoice.xcodeproj`，选择自己的开发团队后安装到 iPhone。使用 `Scripts/build/build-ios.sh device Release` 可检查未签名的设备 Release 编译；安装与分发需要开发团队签名。

运行 `Scripts/tests/test-ios.sh` 检查 LRC 时间轴和加权音乐墙布局。

iOS 的“文件”目录访问受系统授权及文件提供方状态限制。云端文件应先下载到设备；目录被移动或授权失效后，需要在设置中重新选择。音乐墙支持双向拖动、双指缩放、周期重复和墙内聚焦卡片。聚焦时可播放、收藏、切歌并展开歌词页；Android 版的周边封面回流动画尚待移植。

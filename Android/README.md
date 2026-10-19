# MiniVoice 安卓版

这是独立的 Android 本地播放器工程，复用 MiniVoice 的产品名称与播放模式。当前包含系统音乐库扫描、搜索、歌手与专辑浏览、后台播放及通知栏控制、五种播放模式、收藏、歌单和 LRC 文件导入。收藏、歌单及导入的歌词保存在应用本地数据中；音乐文件不会复制或修改。

在 Android Studio 打开 `Android/`，安装 Android SDK 35 和 Build Tools 35.0.0，运行 `:app:assembleDebug`。APK 位于 `app/build/outputs/apk/debug/`。支持 Android 10 及以上。

当前版本还没有迁移 Mac 专用的桌面歌词、音乐墙、标签编辑、在线歌词和离线 AI 歌词匹配。安卓系统通过媒体库授权读取本机歌曲，不直接读取 Mac 的音乐目录；需将音频文件传到手机。

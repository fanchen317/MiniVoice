# MiniVoice Windows 桌面开发版

Windows 直接构建 `MacOS/Desktop/src/main.jsx`，复用 Mac 正式 App、OwnPanels、OwnDesktopLyrics 及 Shared/UI 基础组件和 CSS，不维护页面副本。平台能力在 Windows/electron 内适配，现有 Mac 代码未为 Windows 分叉。

Windows x64 安装 Node.js 22+、CMake 3.22+、Visual Studio C++ Build Tools、NSIS 3（makensis.exe 加入 PATH），执行：

```powershell
./Scripts/build.ps1 -Platforms windows
```

Git Bash 也可执行 `bash Scripts/build.sh --platforms windows`。产物 `.build/dist/MiniVoice-3.0.0-windows-x64-setup.exe` 为 NSIS 安装包（文件名自动随版本变化），尚无签名。目录包为中间产物。构建使用网络安装固定版本 npm 依赖；版本检查对照 Shared/version.json，带共享许可。其他平台默认构建集合保留。macOS 上显式请求 Windows 会失败，不把 Mac 核心当 Windows exe。

## 大体版本已接线

- Mac 同源音乐库、简易、音乐墙，歌手/专辑、收藏、最近播放、歌单、搜索、排序、多选、右键、队列及歌词页面。
- 同源独立设置、歌曲信息/封面/歌词编辑面板、歌词导入/试听/打点/偏移与桌面歌词。界面存在不代表所有平台能力完成，见下方限制。
- Electron Audio 播放、暂停、跳转、切歌、五种模式基础行为、三秒上一曲规则；音量与系统默认输出。
- 文件夹授权、递归开关、目录去重、排除 backup/符号链接、重新扫描；批量收藏、歌单生命周期和批量加入/移除；仅移除索引或显式移至回收站。
- 同目录 LRC 读取、导入、保存与原文/翻译存储；覆盖前备份，临时文件原子替换；写入和删除复核当前真实路径授权。
- 托盘打开/播放/退出，关闭时后台/暂停/退出，主窗口位置大小保存，显示器断开回退；桌面歌词独立浮窗与解锁菜单；Ctrl 方向键播放映射和自定义播放键。

## 尚未达成 Mac 完整能力

- 已接入内嵌标题、歌手、专辑、时长、歌词和封面读取（music-metadata 12.0.0），按内容哈希缓存封面，未变化文件复用索引。具体格式覆盖、损坏文件和大型曲库仍待实机；同目录 LRC 在没有内嵌歌词时回退。
- FLAC/M4A 标签写回、在线歌词/封面搜索、AI 对齐/模型、系统输出枚举与切换、全局窗口快捷键未接入，命令明确失败。MP3 已允许标签与 PNG/JPEG 封面写回，其他格式标签字段仍只读；当前歌曲先切换后才能写回，单文件上限 256 MB。
- 随机模式已接入一轮无重复与上一曲/下一曲历史返回；资源失效重建、扫描取消、桌面歌词窗口恢复/拖动与完整系统集成待完善。
- 仍有 Finder、Command 等 Mac 文案待平台化；GPU 材质、原生窗口边框、全部交互动画和状态恢复待 Windows 对照验收。
- 音频解码依赖 Chromium，扩展名不代表实机格式支持。preload 当前 contextIsolation 开启、Node 禁止于页面，但音频 preload 的进程 sandbox 尚未启用。

## 验证边界

本机已构建同源桌面 renderer（110 模块），用 clang 构建并运行真实共享核心 JSON-lines 程序，执行 Windows 后台扫描/集合/桌面 DTO 测试与组件门禁。此处核心是 macOS 宿主验证产物，不是 Windows exe。MSVC/PowerShell/Windows 音频、所有窗口与三种样式×深浅的实际验收仍待 Windows 主机，不能宣称 1:1 验收完成。


新增依赖使用 package-lock.json 固定完整依赖树，Windows 构建执行 npm ci。2026-11-04 本机 npm audit 报告 7 项问题（4 moderate / 3 high），涉及 electron、@electron/packager 及其传递依赖；未放宽检查或自动跨主版本升级，发行前须处理。解析库本身未列入本轮审计结果。


MP3 写回使用固定 node-id3 0.2.9，保持音频 payload 不变，原有已解析标签逐项检查，校验失败拒绝提交；备份位于歌曲同级 backup/。临时文件同目录写入并回读校验，替换前检测外部修改。未知/无法解析的原始 ID3 帧完整保留、断电恢复、Windows 文件占用及多软件兼容性仍需专项验收；不能以合成数据测试替代真实格式验收。

### 最新续接（覆盖上方历史缺口中对应条目）

封面复制/粘贴/向外拖出已接共用服务，支持 Electron 44 异步剪贴板；媒体键/系统媒体面板已编写 MediaSession 适配；设备列表与输出切换已接 audio RPC，失败不写偏好；窗口全局快捷键已接注册与冲突回退。这些系统能力仍无 Windows 实机证据。只检测指定 sink 消失暂停，默认输出耳机断开与系统主音量联动仍未接入。

### 流式写回续接

已新增共用FFmpeg事务，内置工具存在时启用MP3/FLAC/M4A及流式大文件处理；原MP3内存回退仍有256MB限制。Windows构建需设置MINIVOICE_WINDOWS_MEDIA_TOOLS，目录包含ffmpeg.exe、ffprobe.exe和LICENSE.txt；仓库尚无固定来源/版本/哈希的Windows工具包，须补齐发行资源。已用本机真实工具测试合成FLAC/M4A，不代表Windows占用、大文件和封面组合验收。当前播放歌曲的直接保存尚未完成。

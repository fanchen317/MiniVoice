# MiniVoice Windows 桌面开发版

Windows 直接构建 `MacOS/Desktop/src/main.jsx`，复用 Mac 正式 App、OwnPanels、OwnDesktopLyrics 和 Shared/UI，不维护页面副本。版本由 `Shared/version.json` 统一约束。

## 在 Mac 上生成 Windows x64 安装包

需要 Node.js 22.12+、Python 3、Homebrew。首次安装构建工具：

```sh
brew install mingw-w64 nsis
bash Scripts/build.sh --platforms windows
```

未设置 `MINIVOICE_WINDOWS_RESOURCES` 时，构建自动运行 `Windows/prepare-runtime.py`：编译真正的 Windows x64 核心，准备 Windows Python 3.11.9、PyTorch/torchaudio 2.8.0、stable-ts 2.19.1、Whisper 20250625、small 模型、FFmpeg 8.1.2、MSVC 本地 DLL 和许可。模型复用仓库中的原版模型并校验 SHA256；不复用 Mac 原生运行时。首次需要联网并下载较大的资源，后续复用缓存。PyPI 镜像可通过标准 `PIP_INDEX_URL` 配置。

下载、编译缓存位于 `.build/cache/windows-downloads`、`.build/cache/windows-bootstrap`；组装结果在 `.build/cache/windows-x64-resources`。`resource-manifest.json` 记录归档和组装文件 SHA256，打包前再次核对。Python、FFmpeg、Electron 和模型使用固定 SHA256；AI 源包使用 PyPI 固定版本及 SHA256，全部传递 wheel 由 runtime-requirements.txt 和 runtime-wheels.lock.json 锁定版本与哈希。FFmpeg 发布者的 README、GPLv3 许可和依赖许可随资源一起打包。离线资源的归档哈希和依赖版本另记在清单中。推理不需要的静态链接库、调试符号及 Torch C++ 头文件不进入发行包，避免超过 NSIS 数据块限制；DLL、PYD、模型与许可保留。

已有完整资源包时，可设置 `MINIVOICE_WINDOWS_RESOURCES=/absolute/path`。所需布局：

```text
minivoice-core.exe
ffmpeg.exe
ffprobe.exe
LICENSE.txt
LyricsAI/
  python.exe
  python311.dll
  python311.zip
  python311._pth
  Lib/site-packages/...
  models/small.pt
  LICENSES/...
```

仅有 `python.exe` 或模型不构成完整 AI 环境。资源中的 Windows 程序须为 x64 PE；不会把本机 Mach-O 当作 Windows exe。

## 在 Windows 上构建

Windows x64 安装 Node.js 22.12+、CMake 3.22+、Visual Studio C++ Build Tools 和 NSIS 3，将 makensis.exe 加入 PATH。设置 `MINIVOICE_WINDOWS_MEDIA_TOOLS`（含 ffmpeg.exe、ffprobe.exe、LICENSE.txt）及 `MINIVOICE_WINDOWS_AI_RUNTIME`（完整 LyricsAI 目录），执行：

```powershell
./Scripts/build.ps1 -Platforms windows
```

Windows 原生构建会运行 worker `--self-test`，包含 small 模型编码器推理检查。Mac 交叉打包无法执行该检查，不会把资源存在或 PE 检查当作 Windows 推理验证。

安装包输出：`.build/dist/MiniVoice-3.0.0-windows-x64-setup.exe`（版本随 Shared/version.json 变化）；未签名。安装到当前用户目录，卸载仅删除包内文件，保留用户音乐与偏好。

## 已接入与剩余差距

- 同源音乐库、简易、音乐墙，歌手/专辑、收藏、最近播放、歌单、搜索、排序、多选、右键和队列。
- 设置、编辑器、歌词导入/试听/打点/偏移、双语歌词及桌面歌词；封面复制/粘贴/向外拖出。
- Electron Audio 播放、暂停、跳转、五种模式和随机历史；托盘、关闭行为、主窗口位置大小保存、多屏回退。
- 元数据和内嵌封面读取、增量扫描、扫描取消、缓存重建；文件授权与回收站操作。
- 内置 FFmpeg 时启用 MP3/FLAC/M4A 流式安全写回，包含备份、音频流校验和并发修改检测；当前播放歌曲接释放音频源、保存、恢复进度与状态。无工具时仅 MP3 内存回退（256 MB 上限）。
- 在线歌词部分来源、Apple Music 封面来源已接；网易/QQ/酷狗等完整来源和繁简转换尚未追平 Mac。
- 原 Mac AI worker、任务取消/重试、Small/Medium 模型管理和逐字缓存已接；Windows 实际推理、模型下载及取消仍待实机。
- 媒体键/系统媒体面板、输出切换和全局快捷键已有适配；系统主音量联动及默认输出耳机断开仍有缺口。
- Windows 无同等 Apple Vision 语义检测器，共用像素显著性和几何构图器。

## 验证边界

Mac 上的逻辑测试、同源前端构建、PE 与哈希检查、NSIS 组装，均不代表 Windows 安装/运行验收。三种样式×深浅、键鼠焦点、真实解码、多屏窗口、文件占用和音频恢复、大曲库性能、AI 推理仍须 Windows 主机验证。当前进度与证据以 `Docs/ACCEPTANCE_STATUS.md` 的最新续接为准，不宣称与 Mac 1:1 验收完成。

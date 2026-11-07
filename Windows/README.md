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

## 安装选项与更新方式

- 首次可选择安装位置、桌面快捷方式、开始菜单快捷方式；完成页可取消“安装完成后启动”。仅为当前用户安装，不要求管理员权限。
- 当前使用完整安装包覆盖升级，不自动联网检查或下载更新。运行新版 setup.exe 后读取原安装目录和上次快捷方式选择；同版本可修复安装，禁止降级到较旧版本。升级期间固定原目录，避免产生两个安装副本。
- 安装器在临时目录展开应用文件；已有small模型按SHA256匹配时跳过模型解压。随后按清单校验将保留或将替换的文件，再检查文件占用。请通过托盘退出应用；安装器不会强制结束播放或编辑。未变化的模型和运行库不备份、不覆盖；更新前仅备份会被修改的程序文件，成功后清理备份；写入失败尝试恢复，无法恢复时保留备份并显示位置。
- 仅清理上一版清单登记、但新版已不再需要的程序文件。首次从没有清单的旧简版安装器升级时，保留未知旧文件；此后按安装清单管理。未登记的用户文件、音乐目录、AppData 内的音乐库、收藏、歌单和偏好不参与清理。
- 更新时临时解包和回退备份需要额外磁盘空间；请保留足够空间。Windows 文件占用、安装页交互、注册表、快捷方式及实际回退仍需 Windows 实机验收。

Windows 安装器、卸载程序和主程序共用 `Windows/assets/MiniVoice.ico`；桌面/开始菜单快捷方式与“已安装的应用”条目指定主程序的第0枚图标。ICO含16/20/24/32/40/48/64/128/256像素的32位透明帧，直接由既有BrandIcon矢量生成。修改品牌图后执行 `Scripts/tools/generate-icon.sh` 可同时刷新Mac ICNS与Windows ICO；Windows打包使用已提交的ICO，不依赖Swift工具链。

主窗口使用Windows原生caption overlay与共享32/34px顶部布局；所有应用窗口均移除原生菜单，Alt不会重新显示菜单行。设置通过托盘右键、任务栏右键的“打开设置”或Ctrl+,访问。图标明确指定品牌ICO，字体使用Windows UI/CJK字体栈。三种样式维持同一桌面布局基准；Windows实际caption、字体、缩放与窗口贴靠效果仍待实机回验。

Windows详情DTO现已提供与Mac相同公式的封面背景配色，按封面哈希缓存，不要求重扫曲库。三样式同尺寸参考对照可运行 `MacOS/Desktop/node_modules/.bin/electron Scripts/tests/test-desktop-platform-parity.cjs`（先构建Windows renderer）；此测试使用合成数据验证共享布局，并不替代Windows字体、DPI、GPU材质和原生窗口实机验收。

## Windows 滚动与后台开销

- 列表请求192px浏览图，音乐墙/分类请求512px浏览图，详情与编辑继续读取原图；按封面哈希持久缓存并合并并发解码，内存PNG缓存限制32MiB。缓存仅用于显示，不改音乐标签或原始封面。
- 曲库目录使用轻量行DTO；播放进度与页面状态分离，不把整份歌曲/歌词数组重复塞入每秒状态。未变页面不重复发送，歌词解析按歌曲/原文缓存。
- 播放进度单独写入小检查点，主状态写入合并排队；暂停、跳转、退出保留恢复语义。任务栏设置入口复用运行中的单实例，二次启动不写默认空状态。
- 已通过真实大图管线及合成千首曲库的结构性检查，不据此宣称Windows实际FPS或所有GPU上的卡顿已消除。

安装包使用按文件独立的zlib压缩，优先解压速度，完整包相对旧solid-LZMA包较大。覆盖升级时，small.pt只有在缺失、内容不同或校验失败时才解压安装；依据内容SHA256，而非版本号、文件名或大小。完整包仍携带模型供首次安装/修复，因此不是省略模型的轻量下载包。

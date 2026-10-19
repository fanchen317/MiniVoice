# MiniVoice 主窗口

主窗口由 Electron + React + Chromium 渲染，不嵌入 SwiftUI 主界面。现有 Swift 可执行文件以 `--desktop-engine` 模式启动，只负责音频、曲库、标签和歌词服务。

## 构建与运行

在仓库根目录执行：

```sh
Scripts/build-app.sh release
```

唯一主应用产物：`.build/MiniVoice.app`。

运行该应用即可；无需 Node、Homebrew 或终端常驻。FFmpeg、歌词模型和 Swift 后台已打包。主窗口只有这一套正式入口，Swift 可执行文件仅作为内置服务启动，不会再打开独立 SwiftUI 播放器。旧 `build-electron-app.sh` 只保留为构建别名。

开发流程：

```sh
node Desktop/electron/prepare-dependencies.mjs
node Desktop/electron/prepare-runtime.mjs
npm --prefix Desktop run build
MINIVOICE_ENGINE=/absolute/path/to/MiniVoice npm --prefix Desktop start
```

Electron 分发包保存在 `Vendor/Electron/arm64`，npm 离线依赖缓存保存在 `Vendor/NodeDependencies`，均使用 Git LFS。首次检出后执行 `git lfs pull`；部署只使用本地资源，不再自动下载。Electron 按 npm 官方包的 SHA-256 校验；npm 缓存同时校验归档和 `package-lock.json` 的哈希，安装使用 `npm ci --offline` 并校验锁文件中的包完整性。Node 20/22/24 LTS 和 Xcode 命令行工具仍需预先安装。Swift 首次解析 Yams 或 DMG 首次安装 Python 工具仍可能联网，此处固定的是 Electron 和前端部署依赖。

## 本轮迁移范围

- 三种主界面：音乐墙、音乐库、简易样式；样式切换使用 Chromium View Transitions。
- 音乐墙：原 MiniVoice 权重分割布局、重复边缘、空间索引和可见区域挂载；触控板、鼠标滚轮、二维拖拽与惯性、聚焦、缩放、定位歌曲。
- 虚拟化歌曲列表和歌手/专辑卡片；搜索、排序、最近播放、收藏、歌单创建/加入/移除。
- Swift 音频播放、队列快照、播放模式、音量、输出设备、进度拖动。
- 歌词展示、逐字高亮、点击歌词定位、独立歌词视图；React 歌曲信息/歌词编辑器、在线歌词搜索、AI 同步入口。
- 音乐文件夹管理、扫描、主题和减弱动态效果设置。桌面歌词沿用原有原生浮窗服务。

macOS 上关闭主窗口遵循设置中的关闭行为，Command + Q 退出并保存进度。设置、歌曲编辑、在线封面与歌词工具复用原生窗口；歌单管理、多选删除、任务面板与排序偏好接通同一后台。渲染材质、跨行逐字及动画中间帧仍需原版同场景视觉验收，不能以构建成功宣称逐像素 1:1。

新版使用相同 MiniVoice 曲库、缓存和收藏/歌单数据；不复制音乐文件。界面外观/样式偏好独立保存在 Electron 应用数据中。macOS 可能要求新窗口进程重新获准访问原曲库文件夹；文件夹访问提示需在解锁状态处理。

## 渲染路径

相机位置存在 ref 中，以 `requestAnimationFrame` 写入单个 `translate3d + scale`。React 不订阅逐帧相机位置，只有越过可见区域边界时更新海报集合。虚拟列表/卡片按行挂载。播放状态、曲库和时钟分开发布，重复状态通知去重；歌词高频绘制只更新当前歌词的样式。

进度拖动在等待后台时间回传时保留手指释放的位置，避免先跳回旧进度。停止交互、卸载视图后取消动画帧。

## 进程边界

- Renderer：`Desktop/src/`，没有 Node/文件系统权限。
- Preload：仅暴露命令调用和后台事件订阅。
- Electron main：命令白名单、主 frame 校验、文件夹选择、窗口、受限本地封面协议。
- Swift：`Sources/MiniVoice/DesktopEngine.swift`，有界 JSON 行输入与请求 ID，后台串行输出；不创建 SwiftUI 主窗口。
- 禁止外部页面导航和新窗口。封面请求只接受缓存根目录中的 64 位十六进制 key。

## 验证

```sh
MINIVOICE_ENGINE="$(pwd)/.build/MiniVoice.app/Contents/Resources/Native/MiniVoice.app/Contents/MacOS/MiniVoice" npm --prefix Desktop test
swift test --disable-sandbox
```

桌面测试使用独立偏好设置域和临时静音 WAV / LRC，覆盖启动、请求/事件分离、错误命令、歌单创建、真实音频解码、时间推进、seek、暂停、定时歌词、空间查询和 60/120Hz 运动一致性。它们不会播放用户曲库或修改用户音乐。

当前自动化：6 项桌面测试全部通过；Swift 全量 246 项中 235 项通过、10 项跳过，1 项基线已有的歌词缓存测试失败（见 `Docs/ScrollingPerformance-2026-10-17.md`）。界面已验证实际 1,040 首曲库载入、封面显示、中文搜索、音乐墙滚动与样式切换。没有采集实际显示帧耗时，不能据此宣称已经追平 Folia。

## 外观约束

以原 SwiftUI MiniVoice 为视觉基准：保留三种样式的布局、封面背景、绿色点缀、浮动音乐墙工具和胶囊播放器。Folia 仅作为滑动体验参考，不沿用其界面设计。侧栏左上品牌图标循环切换样式，系统“显示”菜单可直接选择样式。Chromium 材质与原生玻璃仍有细节差异，当前属于第一轮还原。

后续验收标准已提升为原版 1:1，包含动效和交互状态。当前恢复记录与未完成项见 `Docs/InterfaceRestoration-2026-10-17.md`；不应将本轮主界面恢复描述为全应用复刻完成。

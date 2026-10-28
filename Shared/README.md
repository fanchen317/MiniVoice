# MiniVoice 自有组件重写（当前：Mac + Android）

当前实施范围：先重写 Mac 和 Android，其他平台保留已有代码，待这两端完成后再考虑 iOS、Windows。未来可扩展不等于当前实施。

目标：歌词、音乐库规则、状态模型和可共享的界面能力复用；电脑以 Mac 页面为准，手机以现有手机页面为准；文件授权、音频输出、系统媒体会话、窗口和持久化由小型平台适配器负责。Android 自绘组件并不等于跨平台组件，因此新增共享渲染层，而不是继续增加 Java 控件。

## 已接入的路径

| 层 | 共享实现 | 实际调用方 |
| --- | --- | --- |
| 歌词解析/逐字进度 | Core C++17，LRC、增强 LRC、YRC、同时间双语 | Android 主播放器；iOS 歌词解析；新版共享界面 |
| 歌手归并/扫描复用/滚动锚点 | Core C++17 | Android 主播放器 JNI |
| 页面状态变更 | Core `state.reduce` | Android BrowseStateStore；新版共享界面 |
| 手机界面与交互 | Shared/UI React/CSS，触控/抽屉/底部卡片 | Android WebView 预览；本地开发浏览器的手机演示 |
| 电脑界面与交互 | 复用 MacOS/Desktop 的现有 Mac 页面 | macOS Electron 正式页与桌面预览，窄窗口也保持电脑基准 |
| 音频与媒体通知 | 平台适配 | Android PlaybackService；macOS 现有 Swift 引擎 |

这是渐进式迁移。原播放器默认界面保留，共享预览已有可拖动、缩放的重复封面墙和聚焦播放卡片，并接入真实封面、收藏、最近播放、歌单创建、播放队列与五种播放模式。手机批量操作与歌单管理已补齐，设置中的文件夹、扫描与诊断已接入；完整缓存/检查设置和元数据写入编辑尚未迁移；具体差异见 UI/PARITY.md。iOS 已消费共享核心，尚未接共享 React 页面。macOS 原歌词解析与页面保留其已有能力；手机预览歌词走 Core。

## 使用

Android 设置 → 实验功能 → 跨平台界面试用。使用当前已授权文件夹的索引，直接连接现有后台播放服务，不另建音频播放器；也可在试用界面的设置里添加文件夹并扫描；“返回当前播放器”退出预览。

macOS 菜单“显示 → 桌面界面预览（Mac 布局）”。复用现有 Mac 页面与 Swift 引擎；不会加载手机布局。手机试用的状态与原页面单独持久化。

开发浏览器（明确使用合成音乐库与模拟播放时钟，无音频）：

```sh
bash Scripts/build/build-shared-core.sh
bash Scripts/build/build-shared-ui.sh
node Scripts/tools/preview-shared-ui.mjs
```

共享 UI 拥有独立锁文件，可执行 `npm --prefix Shared/UI ci` 后 `npm --prefix Shared/UI run build`。打包脚本自动通过 `Shared/Tooling/prepare-dependencies.mjs shared-ui` 离线准备依赖，无需安装 Mac 前端。两个前端固定使用一致的 React/Vite 版本，每个页面只解析一份 React。Android 仍需 Android SDK/NDK 27.2.12479018；新增库包含 arm64、armv7、x86_64、x86 四种架构，16KB 链接页对齐。

## 边界与后续迁移顺序

1. Core 不接收 Context、Uri、Parcelable、SwiftUI、View、文件句柄、时钟或播放器对象。平台读文件后传 UTF-8 文本/元数据，核心返回不可变 DTO。不要在平台层再复制解析算法。
2. UI 不调用 Android/iOS API，只依赖 `core/snapshot/play/toggle/seek/skip/read/write/exit`。`platform.js` 是唯一宿主入口，Android 与 Swift 转换毫秒/系统类型。
3. 原 Android 列表的 Parcelable 仅作为宿主临时优化，稳定歌曲 ID + 像素偏移才是共享恢复依据。新 UI 串行执行状态修改/持久化；轮询时保留未变化歌曲数组的引用，避免意外重置虚拟列表。
4. 下一阶段优先迁移完整缓存/检查设置与编辑，再接 iOS WKWebView adapter。媒体通知、系统音频焦点与目录授权仍分别保留系统实现。

## 验证

```sh
bash Scripts/tests/test-shared-core.sh  # C ABI / JNI / Swift 同一组协议金样 + Swift/JS 测试
bash Scripts/tests/test-android.sh
bash Scripts/tests/test-ios.sh
bash Scripts/tests/test-android-ui.sh emulator-5554
# 专用模拟器，测试会替换音乐库及页面状态，不允许实体手机
adb -s emulator-5554 shell am instrument -w -e mode portable \
  com.xcosmos.minivoice.uitests/com.xcosmos.minivoice.UiRegressionInstrumentation
npm --prefix MacOS/Desktop test
npm --prefix MacOS/Desktop run build
```

Core vendor 的固定版本、来源、SHA256 和许可证见 Sources/MiniVoiceCore/vendor/SOURCES.json 与 LICENSE 文件。UI 使用 CSS backdrop-filter；宿主 WebView 不支持该能力时明确退化成可读背景，不宣称在所有系统版本上完全一致。新界面须经过真机材质、触摸与性能验证再替换默认界面。

材质验证补充：Android WebView 某些合成路径中，侧边栏的 `backdrop-filter` 声明存在但实际采样仍可能丢失。共享页面打开侧边栏时对背景 scene 显式施加 CSS blur，并将背景设为 inert；侧边栏保持独立半透明材质和描边。关闭时撤销滤镜，避免依靠点击/滚动触发偶然重绘。模拟器截图已验证文本背景实际模糊，不仅检查 CSS 属性。

自有组件的两端边界与迁移标准见 [UI/COMPONENTS.md](UI/COMPONENTS.md)：手机和平板同属触控移动端，以 Android 为设计/操作基准；电脑属键鼠桌面端，以 Mac 为基准。首组共享按钮语义、弹窗焦点边界和尺寸策略已实际接入两端，仍非全量组件迁移完成。

## iOS 用户授权接入更新（2026-10-28）

本节更新上文 iOS 尚未接入页面的历史状态：用户已明确要求继续 iOS，并按 Android 体验版/开发手册复用共享组件。iOS 默认现已通过 WKWebView 加载同一份 Shared/UI；Swift 仅适配本地资源、目录授权、音乐库/音频、集合操作和页面状态保存。iPhone/iPad 均使用 mobile / Android 触控家族。具体构建、专用模拟器验证与未接入能力见 `../iOS/README.md` 和 `../Docs/ACCEPTANCE_STATUS.md`。这不扩大其他未授权平台的实施范围。

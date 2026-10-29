# MiniVoice iOS 体验版

最低 iOS 17，支持 iPhone / iPad。用户已明确要求继续 iOS 并以 Android 体验版为布局和交互基准。

## 当前默认架构

- `SharedPlayerView.swift` 用 WKWebView 加载打包在 App 内的 **同一份 Shared/UI**。音乐墙、侧栏、三种样式、设置/队列/歌单弹窗、图标、ActionButton、Slider、ScrollRail、聚焦回流和空闲播放条均来自 Android 使用的 React/CSS 组件。
- `platform.js` 为 iOS 选择 mobile / Android 参考 / touch；宽 iPad 仍是触控家族。Swift 不重新实现内容组件。
- Swift 负责系统文件目录授权、扫描、标签与封面读取、AVPlayer、后台音频、锁屏媒体控制和持久化；C++ Shared Core 继续负责歌词与共享状态 reducer。
- `HomeView.swift` 是此前的原生实现参考，默认入口不调用它，也不会用它作内容回退。

## 已接入能力

目录授权及增删、子目录扫描、读取 MP3/M4A/AAC/FLAC/WAV/AIFF/CAF；音乐原文件保留原位。读取内嵌封面与歌词、同名 LRC。歌曲/歌手/专辑/最近/收藏/歌单、批量收藏和歌单操作、搜索排序、播放队列、五种播放模式、进度提交、三种样式与系统/深/浅主题。

共享内容通过版本化宿主桥访问数据；播放与队列请求校验音乐库身份。只加载 App 内的界面资源，封面仅按当前库歌曲 ID 提供，阻止外部导航。页面状态独立保存在 `Application Support/MiniVoice/shared-mobile-workspace-v1.json`，不覆盖既有音乐索引。

## 构建与运行

用 Xcode 打开 `iOS/MiniVoice.xcodeproj`，选择 iPhone/iPad 模拟器后按 ⌘R。构建阶段自动打包 Shared/UI，无需单独启动前端服务；需要本机 Node.js 与仓库工具依赖。真机安装需要配置开发团队签名。

```sh
bash Scripts/build/build-ios.sh simulator Debug
bash Scripts/build/build-ios.sh device Release
bash Scripts/tests/test-ios.sh
node --test Shared/UI/test/*.test.mjs
```

模拟器应用位于 `.build/cache/ios/DerivedData/Build/Products/Debug-iphonesimulator/MiniVoice.app`。

## 运行集成检查

创建名字以 `MiniVoice Shared iOS` 开头的专用模拟器，再运行：

```sh
bash Scripts/tests/test-ios-shared-ui.sh <专用模拟器UUID>
```

脚本拒绝普通模拟器。测试启动参数 `--mv-ui-fixture --mv-ui-smoke` 只在模拟器生效，生成 12 张合成封面与静音 WAV，通过实际 WKWebView/宿主桥验证共享页面，并把 JSON 报告与截图复制到 `.build/reports/ios/shared-ui/<UUID>/<runID>/`。不读取真实音乐库；DOM 自动操作不能替代真机触控/手势测试。

系统点按、横竖屏和三样式深浅截图：

```sh
bash Scripts/tests/test-ios-layout.sh <专用模拟器UUID>
```

该脚本使用 XCUITest，包含诊断系统导出面板的打开与取消，截图使用 XCUIScreen，报告位于 `.build/reports/ios/layout/<UUID>/<runID>/`。仅用专用模拟器，不能替代真机音频和多指手势检查。

## 当前边界

已接入诊断 ZIP 系统导出、共享缓存维护/文件巡检/歌手归并、原图封面、扫描日期及进度、LRC/YRC 发现、五模式策略和系统音频/导航信号。完整逐项结果见 `Docs/iOS-AndroidExperience-Parity-Implementation-2026-10-29.md`。已继续接入 MetricKit 延迟崩溃报告和本地诊断历史，并修复真实软键盘遮挡、补队列触摸测试，见 `Docs/iOS-AndroidExperience-Followup-2026-10-29.md`。OGG 解码、大库性能及后台长期扫描仍未完整对齐；系统目录选择器、iCloud、电话/蓝牙/锁屏、VoiceOver 与实体 GPU 仍需真机验收。AVFoundation 同步标签读取的弃用警告尚在。

iOS 图标由 `bash Scripts/tools/generate-ios-icon.sh` 从共享矢量导出，不透明背景铺满，主屏圆角由系统裁切。完整验收状态见 `Docs/ACCEPTANCE_STATUS.md`，后续开发遵守 `Docs/PRODUCT_STANDARD.md`、`Docs/COMPONENT_STANDARD.md` 与 `Shared/UI/COMPONENTS.md`。

用户最新竖屏定位要求：展开播放长条在左右安全区内居中，收起圆形保持原左下角位置。通过共享组件的 `portraitDock` 配置实现，横屏和 Android 的现有规则保持不变。

iPad 的设置按钮按播放条与原右下位置的实际碰撞决定是否上移，未遮挡时位置不变。移动端圆形播放条只响应点击展开；模拟器鼠标悬停不会展开。Mac 的键鼠行为由同一收起组件的独立参数保留。

## 统一打包入口

`bash Scripts/build.sh --platforms ios` / `bash Scripts/build-experience.sh --platforms ios` 分别生成正式/体验签名IPA；deploy对应命令同样生成IPA，只有Mac执行本机应用替换，不自动安装iPhone。两条iOS通道目前都使用本目录现有共享宿主，区别为包标识、缓存及产物隔离，不代表恢复旧原生UI。

设置 `MINIVOICE_IOS_TEAM` 和 `MINIVOICE_IOS_EXPORT_OPTIONS`（有效ExportOptions.plist绝对路径）；体验版可用 `MINIVOICE_IOS_EXPERIENCE_TEAM` / `MINIVOICE_IOS_EXPERIENCE_EXPORT_OPTIONS` 覆盖。证书/描述文件需支持正式 `com.xcosmos.MiniVoice.ios` 或体验 `com.xcosmos.MiniVoice.ios.experience`。输出 `.build/dist/MiniVoice-ios.ipa` / `MiniVoice-ios-experience.ipa`，缓存 `.build/cache/ios/{release,experience}/DerivedData`。缺签名时明确失败，旧IPA不代表本次成功。

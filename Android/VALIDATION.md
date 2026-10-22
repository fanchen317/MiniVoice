# Android 功能验证 · 2026-10-22

本次版本恢复原有 PNG 图标，并加入本地诊断、统一浏览状态、增量扫描与库检查、歌手名称归并、双语及逐字歌词。

## 已执行

- `bash Scripts/test-android.sh`：全部通过，包括增量失效策略、歌手归并/循环映射、疑似重复判定、双语时间合并、增强 LRC 结束时间和 YRC 停顿。
- `bash Scripts/test-android-ui.sh emulator-5554`：Android 15 / API 35、ARM64 专用模拟器，完整通过。
  - 音乐库、简易、音乐墙三种样式 × light/dark。
  - 歌手、专辑卡片的真实点击进入/返回，网格重复三次并另测第一行部分滚动，行号和像素偏移恢复。
  - 父页搜索过滤及文本恢复、侧边栏重复打开/关闭、侧边栏打开期间切换样式。
  - Activity 重建、排序/搜索持久化、播放器与歌词展开状态、双语行的实际控件显示。
  - 完全停止进程后重启，检查行号与像素偏移。
  - 故意抛出未捕获异常使测试进程退出；重启后确认崩溃文件及导出 ZIP 中的异常堆栈。
  - 测试 ContentProvider 按 DocumentsContract 协议提供实际 WAV 文件：未变化扫描不重新打开音频，修改仅重读一个文件，删除产生未找到文件提示。
- APK 签名校验与 `git diff --check`：通过。

完整运行结果：`.build/Android/ui-tests/results.txt`、`restart-results.txt`；界面截图：`.build/Android/ui-tests/screenshots/`。普通逻辑测试结果：`.build/Android/capability-test-results.txt`。

## 修复中发现的实际问题

原生网格保存状态不保留首行部分像素偏移，现于显示前补齐偏移。异步偏好写盘在进程立即终止时可能尚未完成，现于导航保存及退出时写入统一检查点；最终强停/重启回归通过。

## 范围与限制

- 模拟器回归不能代替小米/HyperOS 的 GPU、背屏和系统省电策略验证。
- 增量扫描仍需枚举目录；首次升级后缺少文件版本的旧索引、未知修改时间/大小、读取失败的文件会重新读取。更改扫描范围不把排除的文件标为丢失。
- 重复项依据歌名、歌手和相近时长提示“疑似重复”，不是音频内容指纹；不会自动删除原文件。歌手归并只影响应用分组及搜索，不修改标签。
- 双语翻译必须由歌词提供；支持同时间戳双语、增强 LRC 和 YRC，不宣称支持所有厂商的加密歌词格式。
- 崩溃记录针对 Java 未捕获异常，不能保证记录操作系统强杀、原生进程崩溃或所有内存耗尽场景。报告本地保存，经用户选择导出，不自动上传。

## 2026-10-22 共享核心与界面迁移

新增 `Shared/Core`（C++17/C ABI，Android JNI + Swift Package）和 `Shared/UI`（React/CSS）。Android 主播放器的歌词解析、逐字进度、歌手规范化、扫描版本复用、锚点恢复已走共享核心。设置新增“新版播放器预览”，仅作为逐步迁移入口。

本轮验证记录在 `.build/Shared/Core/`：

- `parity-tests.txt`：同一组 10 个协议用例经 C CLI、Java JNI、Swift CLI 输出一致；Swift 核心测试、JS 并发状态/桥接/轮询稳定性测试通过。
- `android-tests.txt`：现有 Java 单元回归经 JNI 路径通过，包括双语/YRC/滚动锚点/增量扫描规则。
- `ui-regression.txt`：三种样式 × 深浅模式的实际 Android 导航、像素锚点、侧边栏重开，Activity 重建、force-stop 后恢复、崩溃导出、ContentProvider WAV 增量扫描均通过。首次隔离测试时先清空专用模拟器应用数据，避免此前临时音乐库影响 fixture。
- `ui-portable.txt`：共享 WebView 界面测试结果；覆盖真实 WAV 播放、双语、三种材质切换、深色恢复、轮询不重置滚动、歌手卡片多次进入返回、返回音乐库与 Activity 重开锚点。WebView 设备像素比会产生小数 scrollTop，锚点存储取整，误差容许 1 CSS px。
- `ios-build.txt` / `ios-tests.txt`：共享包接入后的 iOS Simulator 编译和模型回归通过。
- `macos-build.txt` / `desktop-build.txt` / `desktop-tests.txt`：Swift 引擎与共享 React 预览构建通过；桌面测试 50 通过、3 跳过。

APK 包含四个 CPU ABI 与共享页面，体积约 2.5 MiB；仍使用系统 WebView，不捆绑独立 Chromium。共享材质尚需小米真机验证；原无限音乐墙与完整设置没有宣称已移植到共享预览。

共享预览首次专项回归暴露了卸载后读取 scrollTop=0 覆盖父页锚点的问题；已改为保留离开前的有效位置，最终 `ui-portable.txt` 为 UI_PORTABLE_PASS。材质截图 `shared-player-drawer-dark.png` 已人工检查；共享侧边栏使用独立 scene 模糊，避免 WebView backdrop 采样失效时透出清晰底层内容。较早 `ui-regression.txt` 中末尾预览失败来自修复前的专项，原界面与进程重启阶段已通过；最终共享专项以 `ui-portable.txt` 为准。

## 2026-10-22 应用内弹窗统一

确认、输入、单选、菜单、歌词详情、文件检查、缓存删除等入口已从系统 AlertDialog 转到 AppDialog 自定义内容。AppDialog 与 BottomSheet 共用 DialogSurface 的深浅色背景、描边、文字与强调色；统一底部弹出和遮罩。短操作菜单按内容收缩，长列表仍保留滚动和面板拖动。

模拟器 `-e mode modals` 检查记录见 `.build/Shared/Core/ui-modals.txt`：深浅模式输入文字颜色、空名称保留弹窗、成功回调只执行一次、单选菜单、长内容与底部操作列表均通过。截图 `modal-choice-light/dark.png`、`modal-actions-light/dark.png`；构建与原有单元回归记录见 `modal-ui-build.txt` 和 `modal-unit-tests.txt`。

“新版播放器预览”更名为“实验功能 → 跨平台界面试用”，明确部分功能未迁移，并保留返回当前播放器的说明。

## 2026-10-22 共享主界面复刻推进

以现有 Android 主界面为参照，共用原 PNG 图标和应用图标；共享界面补齐简易/音乐库布局、可缩放拖动封面墙与聚焦、真实封面与缺失占位、收藏/最近/歌单创建、歌手专辑网格、当前列表播放顺序、五种模式与队列、统一共享弹窗、主题与状态栏颜色。设置入口仍可打开原设置的文件夹/扫描/缓存/诊断功能。完整差异清单见 `Shared/UI/PARITY.md`，未将本阶段宣称为 100% 复刻。

- `.build/Shared/Core/parity-ui-tests.txt`：专用 Android 35 模拟器真实 WebView + PlaybackService。验证授权封面实际解码、真实 WAV、双语、收藏落盘、模式值、队列/创建歌单弹窗、三种样式 × 深浅截图、隐藏列表/重开/网格返回锚点、封面墙缩放聚焦。封面为测试程序生成的合成图片。
- `.build/Shared/Core/parity-unit-tests.txt`：7 个共享 JS 测试通过，包含长 ID、页面过滤和排序、墙可见单元、串行状态、桥接、版本化快照复用。
- `.build/Shared/Core/parity-desktop-build.txt` / `parity-macos-build.txt`：共享前端与 Swift 引擎构建通过。
- `.build/Shared/Core/parity-desktop-tests.txt`：现有桌面测试 50 通过、3 跳过。

Android 使用 catalogRevision 增量传输：音乐库未变化时进度轮询不再重复发完整歌曲数组；只传媒体状态/队列等动态字段。平台封面接口按当前已授权索引的字符串 ID 查找，不暴露任意文件路径。播放上下文中的队列 ID 逐个验证授权后才交给服务。

## 2026-10-22 电脑与手机呈现分离、手机集合操作

电脑端直接沿用现有 Mac App 页面，窄窗口仍保持电脑交互；不再将手机 PortablePlayer 作为桌面预览。Android/iOS/鸿蒙按手机呈现规范规划，当前仅 Android 完成共享界面宿主接入。平台分类独立于视口宽度。

手机共享界面增加歌曲长按、批量收藏/加入/移出歌单、歌单创建/重命名/删除、歌曲信息与歌词详情；共享设置连接目录授权、扫描和诊断导出入口。集合修改由串行宿主适配层校验并落盘，批量含未知 ID 时整体拒绝；删除歌单不删除音乐文件。重命名迁移原页面搜索、滚动和展开状态。

验证记录：

- `mobile-actions-unit.txt`：10 个共享 JS 测试通过，包含设备类型与歌单状态迁移。
- `desktop-profile-tests.txt`：桌面 50 个测试通过、3 个跳过；`desktop-profile-build.txt` 构建通过。
- `mobile-actions-build.txt`：Android APK 构建通过。
- `mobile-actions-ui-tests.txt`：Android 模拟器真实 WebView 回归，覆盖集合操作、批量原子校验、重命名锚点、信息/双语歌词、共享设置，以及真实 WAV 播放、封面、三种样式与主题、重开恢复。共享设置截图已检查。

目录选择与诊断导出使用系统文件选择器；本轮 UI 回归验证共享入口与设置数据，未自动操作系统文件选择器完成导出。高级缓存、文件检查、元数据写入仍未完整迁移到共享界面。

## 音乐墙共享试用版专项修正

加权封面拼墙、周期重复、墙内方形聚焦和邻卡让位复用原几何算法。手机单击仅聚焦、双击/播放按钮播放，缩放限制 60%～120%，拖动有惯性。聚焦内容使用屏幕像素排版，歌词展开占据墙视口；歌词居中使用容器相对坐标，上下留白按实际高度计算，避免宽卡的百分比 padding 导致裁切。

`wall-unit.txt`：12 个共享测试通过；`wall-desktop-tests.txt`：50 个通过、3 个跳过；`wall-build.txt`、`wall-android-build.txt`：桌面及 Android 构建通过。`wall-ui-tests.txt` 检查实际 WebView 的不同封面尺寸、墙内聚焦、当前歌词居中，以及单击其他封面不改变播放歌曲。`wall-focus.png` 为合成音乐库截图，已人工检查。缩放中的紧凑卡片分级和完整液态折射仍待对齐，不能将本轮视为音乐墙完全复刻。

## 自有组件基础与移动/桌面输入边界

首组 ActionButton、DialogBoundary、Presentation 接入共享移动界面和现有 Mac 桌面界面；两端皮肤保持独立。移动端包含手机和平板，最小按钮触控区 44 CSS px；平板弹窗居中，手机默认底部弹出。桌面保持键鼠与现有 Mac 布局，窄窗口不切换产品家族。修复旧桌面 Tab 输入导航抢占弹窗的冲突，弹窗内按钮也能参与焦点循环。

- `components-unit.txt`：13 个共享测试通过，覆盖手机/平板横竖屏及窄桌面窗口的产品家族规则。
- `components-desktop-tests.txt`：51 个通过、3 个跳过，含旧 Tab 逻辑让出弹窗控制权的回归。
- `components-desktop-build.txt` / `components-android-build.txt`：构建通过。
- `components-ui-tests.txt`：手机模拟器真实 WebView 验证最小触控区、动态尺寸分类、Tab 包含按钮并循环、Escape 关闭及原有音乐库/歌单/音乐墙回归。
- `components-tablet-ui-tests.txt`：同一 Android 模拟器覆盖 2560×1920、420dpi 横屏平板配置下的同组回归，未以实体平板替代描述。`components-tablet-settings.png` 已检查居中弹窗和背景。

组件规范见 `Shared/UI/COMPONENTS.md`。列表、侧边栏、滚动条、播放栏、歌词及音乐墙尚需继续迁移和对齐，不宣称组件库完整或 iOS/鸿蒙宿主已支持。

## Mac + Android 重写范围与自绘滚动条

当前实施范围收敛为 Mac 与 Android；iOS、Windows 等保留已有代码，待两端重写验收后再考虑，不新增这些平台的宿主或适配。本轮将桌面的浏览器滚动条与移动试用版的独立滚动条逻辑替换为共用自绘组件。列表、分组和歌词通过同一 mountScrollbar 管理滑块几何、拖动捕获、失焦/取消、闲置隐藏、Home/End/Page/方向键；两端保留不同尺寸、色彩和隐藏等待时间。

- `rewrite-unit.txt`：16 个共享测试通过，新增长列表/短视口/空内容、拖拽边界、键盘端点测试。
- `rewrite-desktop-tests.txt`：51 个通过、3 个跳过；`rewrite-desktop-build.txt` 构建通过。
- `rewrite-android-build.txt`：Android 与测试 APK 构建通过。
- `rewrite-ui-tests.txt`：真实 Android WebView 检查浏览器滚动条已隐藏、自绘滑块滚动后显示/闲置隐藏、实际触摸拖拽移动内容、键盘端点；原有组件、歌单、三种样式、歌词与重开恢复回归通过。

首轮专项断言读取 `scrollbarWidth`，模拟器 WebView 未暴露该计算属性，虽然自绘滑块已正常显示；最终改为检查实际生效的 `::-webkit-scrollbar` 隐藏规则，并完成真实拖动检查。Mac 当前验证为构建、单元回归及共用逻辑，未宣称桌面实际鼠标拖动已由 UI 自动化验证。验收清单见 `Shared/REWRITE.md`。

## Mac + Android 自绘 Slider

Mac 的进度、音量、音乐墙显示比例，以及 Android 共享试用版进度条改用 MiniVoice Slider，不再由浏览器 range 控件渲染。共用命中计算、步长、键盘、拖动预览、提交和取消；拖动期间保留本地草稿，轮询不覆盖手势。进度只在松手或键盘确认时调用平台 seek，取消不提交。Mac 的快捷键和墙点击判断已识别自绘滑块；弹窗普通按键保留给内容控件，Tab/Escape 仍由弹窗边界负责。

- `slider-unit.txt`：18 个共享测试通过，含命中边界、小数步长和键盘端点。
- `slider-desktop-tests.txt`：51 个通过、3 个跳过；`slider-desktop-build.txt` 构建通过。
- `slider-android-build.txt`：Android 与测试 APK 构建通过。
- `slider-ui-tests.txt`：真实 WebView/PlaybackService 验证拖动保持 700ms 跨轮询不回跳、松手前不 seek、松手后实际播放器位置改变、取消不 seek、键盘 Home 提交；自绘滚动条、弹窗普通键/Tab/Escape、歌单和原有三样式回归通过。截图 `shared-custom-slider.png` 已人工检查。

Mac 滑块的鼠标实机操作仍未由本轮 UI 自动化验证；Android 测试仅涉及共享试用界面，原默认原生界面没有宣称完成替换。其他平台未新增适配。

# Android / Mac 体验版验收台账

本文件反映已有证据，不是整体完成声明。其他平台暂停接入。

| 项目 | Android 体验版 | Mac 体验版 | 证据或缺口 |
| --- | --- | --- | --- |
| 自有内容组件入口 | 默认启动器/媒体/扫描入口已接入 | MiniVoice-debug 主界面与辅助面板已接入 | 原正式 Mac 辅助窗口不在体验版替换结论内 |
| 按钮/图标/滑块/菜单/弹窗 | 自动化通过 | 自动化通过 | 所有真实设备尺寸与操作仍需持续验收 |
| 三种样式、深浅主题 | 模拟器回归通过 | Electron 实际页面回归通过 | 真机对比度与材质专项待验收 |
| 播放按钮绘制中心 | 自动化通过 | 窄窗口 SVG/path 中心通过 | 报告 mobile-play-button-*、dock-button-center-* |
| 返回/分组/滚动/重启 | 模拟器回归通过 | 已有逻辑与页面回归 | 完整实体设备矩阵尚未全部签收 |
| 音乐墙重排与可见区 | 新逆变换逻辑与 1037 首规模校验通过 | 独立桌面实现已有回归 | Android 用户视频同场景真机回验待完成，不能保证全部空白原因均已排除 |
| 搜索圆形/长条动画 | 渲染、焦点、关闭/返回与模拟器通过 | 未同步改动；保持桌面设计 | 本轮为 Android 定向修复 |
| 原文件写入 | MP3/FLAC/M4A 格式测试及保存/恢复测试通过 | 实际后台保存路径已接入 | 特殊 ID3、分片 M4A 等明确限制；不扩称所有格式 |
| 在线来源与 AI 能力 | 尚未与 Mac 对齐 | 搜索/模型/后台任务已接入 | 接口可用不等于所有在线来源实时可用 |
| 组件契约 v1 | 规则已建立，存量逐项收敛 | 规则已建立，存量逐项收敛 | 组件直接依赖门禁及正反例通过；CSS token、作用域、disclosure 和完整契约用例仍待收敛 |
| 全量产品标准 v1 | 未整体验收 | 未整体验收 | 新标准执行边界已建立；对比度、材质、连续操作及实体设备矩阵是后续重点 |

当前报告目录：`.build/reports/ui/`。重点报告 `experience-search-*`、`full-controls-*`。历史报告证明当时对应改动，不自动视作未来改动仍通过。

## 当前交付

Android 定向体验包：`.build/work/android/MiniVoice-android-experience.apk`。包含音乐墙可见区修正和搜索变形动画；实体手机视频场景仍需回验。

Mac 体验包：`.build/dist/MiniVoice-debug.app`，继续与正式版隔离。

产品标准执行入口：组件静态边界检查通过（85 个源文件）；规则正反例测试 2 项通过；Android/桌面前端经新增构建门禁均构建通过。此结果不改变上表真机与全量视觉验收的待验收状态。

组件标准本轮验证：85 个生产源文件静态检查通过；4 项规则测试通过（含组件平台依赖、网络/存储反例）。未改运行界面，未重复全量界面测试；不新增真机通过结论。

本轮交互框架接入：Mac 歌曲编辑入口明确包含信息、歌词与插图；Android 歌曲编辑入口暂撤，保留查看和底层恢复实现。共享 ActionButton 增加可配置按下/精确指针悬浮/焦点反馈，支持专用动画退出通用反馈与减弱动态。Electron 实际鼠标按下、悬浮、busy 不提交、reduce-motion 检查通过；实际页面搜索变形、音乐墙、Mac 编辑器等回归通过（component-feedback-pages.txt）。两端前端构建及 4 项规则测试通过。尚未以此宣称全部页面动画完成或真机流畅度通过。

连续切卡专项：新增测试先复现“已有封面节点未被下一段过渡保留”，修复后 Electron 多帧保留检查通过；封面关闭通用按钮缩放，移除重复过渡图片。播放条左下锚定、三样式主题从设置切换、横竖屏与 Mac 页面回归通过；共享模型 29 项通过。报告 wall-flash-unit.txt、wall-flash-render.txt。用户 Android 真机同场景闪屏仍待回验，不能标记全量修复验收完成。

Android 专用模拟器本轮 portable 回归已通过（UI_PORTABLE_PASS，wall-flash-android-tests.txt），包括设置切主题、手机只读歌词信息、左下播放条锚点、音乐墙缩放/展开/旋转/返回。体验 APK 已更新；Mac 本轮确认侧栏无主题入口，未另改桌面运行代码或重打包。

专辑图/播放条/共享材质回归修复：Android 当前播放和预览卡片都增加显式专辑图层，原加载封面继续作为过渡底层；此前仅依赖模糊背景/底层透出的实现未满足专辑图要求。Mac 时间文字的后代 span 选择器改为直接子元素，进度轨道分配剩余宽度；移除旧桌面椭圆滑块规则，改为等宽等高圆形滑块。两端工具按钮和播放条共用 materials.css。

Electron 实际页面验证通过：手机当前卡片图片加载、Mac 轨道完整与滑块圆形、手机/桌面按钮计算背景颜色/渐变/模糊参数一致，以及连续切卡、旋转、三样式主题与编辑面板回归（cover-dock-material-render.txt）。截图已查看；这些证据不替代 Android 真机 GPU/连续触控验收。

本轮 Android WebView 专用模拟器 portable 已通过（UI_PORTABLE_PASS，cover-dock-material-android-tests.txt），包含真实授权封面加载与音乐墙卡片图片检查。Android 体验 APK 与 Mac-debug 体验包均已重新构建，Mac 签名校验通过。

空闲/闪屏专项：Mac 补接共享 useIdleCollapse，空闲收圆、悬浮展开、配置按钮下沉；Android 配置按钮从原短位移改为下沉至底部安全区。Electron 逐帧验证两端下沉中间位置、Mac 收起中间宽度与悬浮展开通过；连续切卡节点保留与专辑图显示、Mac 窄窗实际 SVG 中心及播放动作回归通过（idle-flash-render.txt）。共享逻辑 29 项与门禁 4 项测试通过。

图片交接补充：Android 显式封面等 decode 完成才显示；Mac 高清图升级先解码，保留缩略图直到可替换。尚未有用户真实设备的 GPU 录屏验证，不宣称所有闪屏原因均已消除。

本轮 Android 专用模拟器 portable 通过（UI_PORTABLE_PASS，idle-flash-android-tests.txt）。Mac 与 Android 已重打体验包，Mac 签名校验通过。另增加人为延迟 decode 的图片交接测试，防止仅检查图片节点存在而漏掉未解码瞬间。

延迟解码专项最终通过：Android 新图未就绪时隐藏新图层并保留原已解码封面；Mac 人为阻塞高清 decode 时继续显示原缩略图，放行后正常聚焦与展开。最终 idle-flash-render.txt 全部通过，包含两端空闲下沉中间帧、Mac 悬浮展开和窄窗播放动作。所有通过项仍不替代用户设备同场景录屏。

Mac 音乐墙播放条位置更正：移除底部居中的 left/translateX 规则，圆形与展开长条统一距左侧 18px、底部 18px。收起/展开不再改变左侧锚点；逐帧回归增加左侧位置断言。Android 继续保持原左下角位置，本轮未修改安卓包。

左下角更正验证通过：mac-dock-left-render.txt 全部页面回归通过，新增逐帧左侧锚点检查通过；Mac 体验包已重新构建并通过签名校验。

## 2026-10-23 正式页面对照续修

以 PRODUCT_STANDARD / COMPONENT_STANDARD 及既有正式版还原记录为基准继续 Android、Mac 体验版；本轮未完成同曲目、同时间、同尺寸的正式版/体验版逐像素比对，不能称为全应用 1:1 通过。

已整改：设置重复候选/读取问题、后台扫描问题、歌词打点共用 Disclosure，替换浏览器 details/summary；ActionButton + 应用 SVG 提供统一折叠标题、禁用、键盘 Enter/Space、展开语义和深浅主题继承；折叠保留草稿挂载。Mac 设置及关于移除面向开发者的组件/适配层说明，保留版本及体验版身份。

验证通过：87 个生产源文件组件边界；共享逻辑 29 项；桌面测试 54 项通过、3 项跳过；Electron 组件键盘开合/禁用/草稿保留及既有菜单、滑块、按钮反馈；两端实际页面回归（音乐墙、三样式主题、连续切卡、搜索、横竖布局、Mac 设置/编辑器和歌词打点），已查看设置、编辑器和组件截图。报告 parity-disclosure-components.txt、parity-updated-render.txt。Android 与 Mac-debug 已重新构建，Mac 深度严格签名校验通过。真机材质、对比度、连续动画和正式版同步视觉比对仍待验收。

本轮 Android 专用 MiniVoiceRegression 模拟器 portable 回归通过（UI_PORTABLE_PASS，parity-android-portable.txt）：真实 WAV 播放、三样式主题、歌词、触控滑块/滚动条、长按取消、横竖屏、设置及重启锚点。测试仅使用合成音乐库；截图已拉取至 .build/reports/android/ui-tests/parity-screenshots。实体手机/GPU 与正式版 1:1 对照继续待验收。

## 2026-10-23 用户截图按钮 / Android 整墙闪屏专项

输入证据：用户 Screenrecorder-2026-10-23-14-42-19-67.mp4（约 6.78 秒）及四张标注截图。抽帧显示切卡过程中整片墙面短暂消失，悬浮工具仍在，不能归结为单张封面解码。原视频抽帧 contact.png 位于 .build/reports/ui/user-flash/。本机未稳定复现用户实体 GPU 的相同故障，唯一根因仍待真机诊断。

已修正：Mac 音乐墙收起播放按钮外径 38px，与菜单/搜索/设置工具一致；去除内层白圆。桌面 SVG 从旧位图尺寸隔离，缩小工具栏、播放副控件、顶部与输出设备绘制框；简化侧栏图形，修复搜索绝对定位导致的中心偏移。Android 将世界平面公共 translate3d/scale 提升改为视口内逐卡投影，保留已加载图片、相机和可见区；画布/聚焦区使用不可滚动裁切，增加焦点滚动检查。

通过证据：共享逻辑 29 项；桌面 54 项通过、3 项跳过；组件门禁 87 源文件；Electron 页面回归、1037 首连续切卡画面采样、拖动打断、深浅主题/横竖布局、Mac 收圆同径和简易/音乐库窄窗 SVG 检查。已查看对应桌面截图。报告 user-flash-render.txt、user-flash-components.txt。先前 Android WebView portable 与新增 12 次连续切卡画面采样通过；追加不可滚动裁切后的最终回归结果另记。

待验收：用户原手机/同曲库连续点击录屏、实体 GPU 合成稳定性和滚动性能。不得将这些定向测试写成全部闪屏已修复。

最终验证：追加 overflow:clip 与主动焦点检查后，Android 专用模拟器 portable 再次通过（UI_PORTABLE_PASS，user-flash-android-portable.txt），包含连续切卡 UiAutomation 画面采样；Electron 完整页面回归通过，组件交互通过。最终 Android 体验 APK / Mac-debug 已重新构建，Mac 深度严格签名校验通过。最终 Android 截图 user-flash-android-final.png。以上不替代用户原手机的同场景回验。

## 2026-10-26 手机滑动与 Mac 正式播放栏续修

参考用户 Screenrecorder-2026-10-23-17-51-19-961.mp4（约 12.26 秒）及原版 MusicWallDock.swift / MusicWallCamera.swift。手机上一轮逐卡 left/top/width/height 更新增加布局工作，本轮改为每卡二维平移，只在尺寸变化时写宽高，比例不变不重复刷新继承字号变量；保留不可滚动画布、独立卡片、已加载图片和打断保护。

同一 1037 首合成曲库 / 60 步拖动 CDP 诊断：修改前 LayoutCount 125、修改后 23（mobile-pan-before.json / mobile-pan-after.json）；这是本机 Chromium 单次同条件布局次数，不代表 Android 实机 FPS，不能单凭此宣称恢复原版流畅度。

按用户要求，Mac 音乐墙按钮和播放栏恢复正式页面参考的独立薄玻璃皮肤，背景采样/折射在伪元素，前景文本清晰；与手机基础皮肤明确区分。持续播放栏根同步过渡宽、高、内边距、播放按钮与内容，保留展开内容几何和渐隐裁切，使用原版 .42/.88 弹簧参数；上一曲/下一曲采用正式播放条的左右箭头。保留此前用户要求的左下锚点和同径收起圆。

通过：组件边界 87 源文件，共享测试 29 项，桌面 54 项通过/3 项跳过；Electron 实际页面、Mac 薄玻璃采样层、同步宽高变形中间帧、内容几何保留、中途反向展开与减弱动态验证通过（scroll-dock-render.txt），已查看中间帧；Android 专用模拟器 portable 通过（scroll-android-portable.txt，含整墙画面采样、焦点、滑块与旋转/重启）。Android 体验 APK 与 Mac-debug 均已重打，Mac 深度严格签名校验通过。

待验收：用户真实手机上的连续触控流畅度、GPU 闪屏与原版同场景对照；Mac 与原生系统玻璃仍是自有实现的视觉参考，不宣称像素/材质完全相同。

## 2026-10-26 自有动画与 Android 系统触觉

按用户本轮澄清：按钮、悬浮、轮廓、样式切换、侧栏与弹窗视觉全部继续使用自有组件实现；仅手机震动调用 Android 系统能力。未接回原生内容面板、按钮或系统弹窗皮肤。

本轮接入：ActionButton 通过页面注入的 FeedbackContext 发出可信激活反馈，Android 主线程 performHapticFeedback(CONTEXT_CLICK) 尊重系统触感设置、45ms 去重；Wall 自管选卡只反馈一次，禁用/busy/程序性 click 和滑动取消不反馈。触控点按与品牌图标有独立按压效果，避免专用效果叠加通用缩放；减弱动态取消位移/旋转。

自有动画续修：手机侧栏打开/退出复用 DrawerLayer/useSurfaceMotion；设置类弹窗关闭从当前视觉状态退场，退出副本惯性不可交互、主题参数与原层级保留，重开清理旧副本；运行时减弱动态结束现有过渡。Mac 侧栏使用 chrome 弹簧。手机样式切换记录最新连续点击意图，Mac 排队不再清空最新请求；Mac 无快照时也有自有进入过渡。音乐墙增加当前曲目独立轮廓与一次性进入提示，手机区分播放/暂停强度，不做无限光晕。

验证通过：89 源文件组件边界；共享逻辑 29 项、桌面 54 项（另 3 项跳过）；实际鼠标激活回调计数、busy 抑制与点按/悬浮/减弱动态；Electron 两端页面回归、手机侧栏/设置开关中间帧、关闭副本 inert、快速重开与最终清理，报告 activation-components.txt / activation-motion-render.txt。已查看设置进入截图。Android portable 首轮 UI_PORTABLE_PASS，真实触摸注入验证主线程系统触觉调用与禁用抑制，其他墙面/横竖/返回/重启继续通过。

待验收：实体手机实际震感、系统关闭触感时的物理效果与用户 GPU 动画流畅度。模拟器验证的是调用链，不能等同实机手感。最终包验证另记。

最终验证：activation-android-final-portable.txt 记录 UI_PORTABLE_PASS，包含真实触摸注入触发 Android 系统触觉与禁用抑制；activation-motion-render.txt 全部页面及新增侧栏/设置动画检查通过。Android 体验包与 Mac-debug 已重打，Mac 深度严格签名校验通过。最终组件标记和文档检查通过；实体震感和用户手机 GPU 流畅度继续待验收。

## Mac 展开播放栏居中与配置按钮避让纠正

按用户最新截图纠正：展开播放栏在可用墙面水平居中，收起圆仍在左下；同一持续根同步动画 left/宽高/内边距。配置按钮默认底距 18px，仅与播放栏安全间距发生冲突时抬高，设置面板跟随同一锚点。此前固定左下展开和无条件抬高的 Mac 规则已被本次要求覆盖，Android 不改动。

验证通过：桌面 55 项（3 项跳过），新增窗口/侧栏预留及碰撞临界测试；Electron 420/580/600/1280px 实际窗口居中、配置按钮条件避让、不重叠、收放及中途反向动画回归全部通过（dock-center-tests.txt / dock-center-render.txt）。已查看 1280px 截图；Mac-debug 已重打并通过深度严格签名校验。

## 2026-10-26 手机系统安全区与弹窗拖动条

音乐库、简易样式统一使用 edge-to-edge 视口，由 Android 发布真实系统栏/挖孔四边 inset，共享页面按安全区添加留白，底部播放栏避开导航区；旧系统底部 inset 限定稳定导航栏高度。弹窗也按四边安全区布局。

弹窗顶部自有拖动条提供 44px 触摸区域，支持跟手下拉、距离/速度判定关闭、短拉回弹、取消复位；仅手柄接管手势，正文保留滚动。关闭仍走原页面回调。使用 window 捕获跟踪，动画帧合并写入位移，减弱动态时直接复位；拖动后的键盘激活仍可关闭。

验证：组件边界 91 源文件通过，共享逻辑 30 项通过，git diff --check 通过。Electron 页面全套回归通过，包含四边安全区、拖动跟手/回弹/取消/关闭及拖动后 Enter 激活（insets-sheet-render.txt）。专用 MiniVoiceRegression 模拟器分别在手势导航、三键导航执行完整 portable 回归，均 UI_PORTABLE_PASS；真实 Activity 横竖屏系统 inset 与页面比较、真实触摸注入拖动/取消均通过（insets-sheet-android-gesture.txt、insets-sheet-android-threebutton.txt）。已恢复模拟器手势导航。最终键盘兼容修正后重新构建 Android 体验 APK，路径 .build/work/android/MiniVoice-android-experience.apk。实体手机触感、用户设备 GPU 流畅度仍待实机验收；本轮没有修改 Mac。

## 2026-10-26 手机侧栏宽度和可见动画纠正

用户反馈手机侧栏过宽、开关和样式切换看不到动画。本轮收窄为 80vw、最大 340px；侧栏由仅 28px 位移改为从屏幕左侧完整滑入，关闭滑出时保留退出层直到 280ms 动画结束（原遮罩提前移除会截断退出），退出层继承 mobile 布局。样式切换改为持续页面根的自有 WAAPI 收束/进入及图标标记旋转，不依赖 WebView 整页快照；保留最新连续点击意图和减弱动态规则。

已通过：组件边界 91 源文件、共享逻辑 30 项、Electron 页面回归，包括侧栏实际宽度/中间位移、退出保留/清理/快速重开、三种样式根节点的运行中动画，以及原系统安全区和弹窗拖动条。专用 MiniVoiceRegression Android 模拟器 portable 完整回归 UI_PORTABLE_PASS（drawer-slide-android.txt），通过 requestAnimationFrame 采样验证侧栏从屏外到最终位置的多个中间帧、样式切换存在多个不同的非单位变换，包含真实系统栏横竖屏及其他原功能回归。最终退出副本布局修正后重新构建并复测结果另记。实体手机 GPU 流畅度继续待实机体验确认，未将模拟器采样称为实机 FPS。

最终复核：drawer-slide-android-final.txt 再次 UI_PORTABLE_PASS；drawer-slide-render-final.txt 增加连续三次切换以最新意图落位、结束后 transform 归零、减弱动态直接更新状态的页面验证通过，原 Mac 页面回归通过。已查看 drawer-narrow-final.png 确认收窄后标题与按钮可容纳、右侧页面留白可见。Android 最终 APK 已更新至 .build/work/android/MiniVoice-android-experience.apk。

## 2026-10-26 手机侧栏前后与上下分区层次

按用户“弹出后有上下层次、三种样式都优化”的要求：音乐墙、音乐库、简易共用前景侧栏/后景主页面关系。侧栏弹出时主页面仅视觉缩小至 .96、下沉 8px、圆角及边缘阴影，关闭恢复原几何；侧栏浮层阴影强化，顶部品牌/操作区与下方导航用分隔线组织，简易样式歌曲区再分层。没有增加整页模糊、重新排版或改变墙面相机尺寸；正文继续 inert，系统减弱动态取消过渡。

页面验证通过（drawer-depth-render.txt）：三种样式/深浅主题/横竖屏原回归、侧栏前后层次参数、关闭恢复 transform 与交互、快速重开、连续样式切换、安全区、弹窗拖动，以及原 Mac 页面回归。已查看新的 drawer-narrow-final.png 确认前后圆角边缘、标题分隔与层次。组件门禁 91 源文件及 git diff --check 通过。Android 首轮新增层次检查通过，宿主固定延时检查退出层时已错过短动画，改为浏览器 requestAnimationFrame 记录真实退出中间帧后复测，最终结果另记。实体设备 GPU 流畅度仍待实机确认。

补充复核过程：初始固定时长的滚动断言在歌手页异步 page.restore 返回前读取了 0；随后返回音乐库的断言也早于恢复完成。SongList 增加 aria-busy 恢复标记和卸载帧保护，可见性回调不再在恢复请求未完成时提前标记就绪；原始像素锚点断言保留，测试等待明确就绪。动画检查同样从宿主固定时间点轮询改为页面 RAF 记录开始至结束，仍要求多个不同的中间变换，未放宽为“存在动画对象即通过”。

最终 Android 完整 portable 回归 UI_PORTABLE_PASS（drawer-depth-android-complete.txt）：三种样式层次及复位、侧栏真实进出中间帧、样式切换、原像素滚动锚点/分组返回/重启、系统安全区、触控等全部通过。共享逻辑 30 项通过；最终组件边界及差异空白检查通过。体验 APK 已更新为 .build/work/android/MiniVoice-android-experience.apk。

## 2026-10-26 手机样式切换对齐 Mac 碎片扩散

用户明确指出手机仍未实现与 Mac 一样的切换。本次核对：此前手机是淡入/缩放，Mac 是当前页面快照从品牌图标向外碎片扩散，前轮不能称为已对齐。本轮抽取 Mac 原 fragmentCells/fragmentProgress 与绘制公式为共享 fragmentMotion.js，Mac 和手机都调用同一 paintFragments，保留 200ms 距离延迟、480ms 运动、680ms 总扫动、旋转/卷曲/缩小/140px 散开的原效果。

Android 增加自身 Activity WebView 区域 PixelCopy 快照能力（不录屏、不读取其他应用），经适配器注入；手机先以旧页面画布覆盖再提交新样式，随后碎片散开揭示新样式。获取或解码失败仍有短进入兜底，但验收要求快照碎片路径，不能用兜底冒充对齐。连续切换按最新意图；旋转、运行时减弱动态和完成均清理画布/帧/监听器，状态更新失败不吞错。

已通过：组件边界 92 源文件，共享逻辑 30 项，Mac 逻辑 55 项（3 项跳过）。Electron 实际页面回归通过（fragment-render-final.txt），包含真实页面截图作为碎片纹理、多个碎片中间帧、连续切换最终状态、运行时减弱动态、动画中 resize 清理，以及三种样式、深浅、侧栏层次/安全区/弹窗拖动和原 Mac 页面回归。已查看 phone-mac-style-fragments.png 确认旧画面碎片实际旋转散开。Android 最终结果另记；实体手机 GPU 流畅度仍待实机验收。

Android 最终完整 portable 回归 UI_PORTABLE_PASS（fragment-android.txt）：三种样式切换经真实 PixelCopy 宿主链路，RAF 要求多个不同碎片时间帧且绘制纹理具有多个非透明颜色，确认没有走无快照兜底；原安全区、层次/侧栏开关、实际触摸、滚动锚点/重启等回归通过。最终组件边界与 git diff --check 通过，Android 体验 APK 已更新至 .build/work/android/MiniVoice-android-experience.apk。

## 2026-10-26 双端缩放刻度、手机材质/回弹/译文优化

用户反馈碎片不清晰、手机点按缺乏回弹、切换侧栏变纯色、音乐库缺少玻璃、缩放数字行与 Mac 配置不一致、Mac 模式/队列图标相同及手机译文显示问题。本轮实施：手机快照由 1280 长边提高为 2560/300万像素上限，碎片画布由 CSS 一倍改为随设备像素密度（2.5/250万像素上限），并将两端碎片网格/角度/延迟预计算移出每帧；不以此宣称实体设备 FPS。手机标准按钮释放加入自有回弹，保留禁用/取消/减弱动态及一次系统触感路径。

DrawerMaterial 跨样式保持同一实例、有效封面与采样，等待墙面首轮布局且校正滑入采样原点，不再因重建空采样只剩纯色 tint；音乐库列表/简易歌词区明确玻璃表面。双端 Slider 刻度点在轨道上，去掉底部数字行，点按选档、滑动仍支持 62%；手机音乐墙配置按 Mac 收敛为比例、±、恢复及排序，时间排序补真实字段；模式及应用设置仍从播放器/侧栏进入。Mac 列表播放独立图标，和队列区分。手机原本支持同时间戳双语解析，本轮移除紧凑卡片直接隐藏译文的条件，增加各歌词样式译文开关及持久状态。

已通过：共享逻辑 30 项、Mac 逻辑 55 项（3 项跳过）、组件边界 92 源文件、git diff --check。polish-render-final.txt 页面回归通过，包括实际点击缩放档位、两端拖动至约 62%、手机译文隐藏/恢复、回弹缩放值先压下后超出 1、连续换样式保留已解码玻璃采样、原深浅/横竖/状态/动画打断及 Mac 页面。已查看 wall-v3-simple-light.png 和 phone-mac-style-fragments.png。Mac-debug 已重打，深度严格签名检查通过；Android 最终回归结果另记。

补充回归发现并修复：晚返回的异步 page.restore 仍可能覆盖较新的滚动，不能仅通过延长测试等待处理。SongList 现区分自身恢复写入与外部滚动，记录滚动版本；新滚动更新锚点后，旧恢复结果失效。手机音乐墙播放条补模式入口，精简配置不减少可用功能。

Android 最终 polish-android-verified.txt 完整 UI_PORTABLE_PASS：真实触摸选刻度点、连续拖动 62%、译文开关、回弹缩放超调、三种样式保留解码采样、真实快照片段、原横竖/系统栏/手势/收藏歌单迁移/分组返回/重启锚点/快速墙面选择全部通过。已拉取并查看 polish-android-drawer.png 和 polish-android-lyrics.png，确认模拟器译文实际可见、侧栏有封面采样色彩。polish-components.txt 自有组件鼠标/键盘/禁用/忙碌/减弱动态及 slider/menu 契约通过。Android 最终体验包已更新，Mac-debug 深度严格签名再次通过。实体手机清晰度/手感及 GPU 流畅度仍需实机体验确认。

最终 polish-render-complete.txt 全部页面回归通过，新增故意挂起 page.restore、先滚动再释放旧结果的确定性用例通过（PASS delayed restore respects newer list scroll），保留精确滚动值断言。两端刻度/62%/独立模式队列图标、手机玻璃采样/译文/回弹、原 Mac 页面回归均通过。

## 2026-10-26 源封面、编辑预览与双端歌词统一

展开封面改走源图详情链路：Android 优先音频内嵌图，再读取关联封面，原字节传输且使用真实 MIME；Mac 首次详情请求从注册音频提取原始编码并缓存 Original，保留列表缩略图。兼容格式不重压缩，不支持的浏览器格式转为原尺寸 PNG；源文件本身低清不能恢复不存在的细节。本地封面选择和在线封面下载移除 1400px/JPEG 重编码，编辑保存允许 20MiB。

Mac 编辑器补完整本地双语歌词预览、逐句定位与显式试听，在线结果先预览再应用草稿，搜索使用当前草稿标题/歌手；本地和在线封面均可全图 contain 预览及查看尺寸，可恢复歌曲封面。异步搜索/文件选择按当前歌曲版本防止串入其他歌曲草稿。桌面歌词缩小工具区，按窗口实际宽高完整拟合原文/译文，深色背景同步；锁定保留独立可点击解锁按钮。手机/Mac 音乐墙复用同一自然行高、逐词进度和双语组件；手机音乐库/简易歌词同步 Mac 常规字号与居中规则。

验证：source-all-android-final.txt 完整 UI_PORTABLE_PASS，Android 源图字节一致并在展开图片读取到 2048×1536；source-engine-save-final.txt 四项真实打包后端测试全部通过，其中嵌图 FLAC 提取的 2200×1800 PNG 与源字节一致，保存完整封面和双语歌词后重新读取尺寸/标题/译文通过。source-all-final-render.txt 页面回归全部通过，覆盖搜索候选预览/应用、本地草稿与完整封面预览和既有三样式交互。在线搜索页面流程使用受控结果验证，未据此宣称外部服务实时可用。

source-desktop-lyrics-final.txt 验证 580×140、360×110、1050×200 长韩文/中文完整边界、深浅主题、锁定工具区收起及实际解锁按钮事件；已查看 desktop-lyrics-fit-dark.png，原文换行和完整译文均在窗口内。邻句允许边缘渐隐，当前句不可截断。共享单元 33 项通过，Mac 单元 58 项通过、4 项需打包后端的用例独立运行；组件门禁覆盖 96 源文件。实体手机 GPU 流畅度、物理震感和 macOS 多空间实际交互仍待实机体验。

## 2026-10-26 Mac 侧栏展开后的收起播放按钮定位

修复收起播放圆固定 left=18 导致被并排侧栏遮住的问题，改用与顶部侧栏按钮相同的 headerLeading：并排侧栏打开时移至右侧，关闭或窄窗口覆盖布局时位于左下 12px，底距仍为 18px。展开播放栏的可用区域居中与设置按钮碰撞规则不变，Android 不变。

组件门禁 96 源文件、Mac 单元 58 项通过（4 项后端条件用例跳过）、git diff --check 通过。dock-sidebar-render.txt 完整页面回归通过，新增真实 DOM 验证侧栏展开后播放圆在侧栏右侧且与上方按钮横向误差小于 1px、600/1280 宽度切换保持对齐、关闭返回左下，原变形中间帧/打断/展开居中回归通过。已查看 mac-collapsed-dock-sidebar-aligned.png 确认不被遮挡。Mac-debug 体验包重新构建并通过深度严格签名校验；未据此宣称实体设备流畅度通过。

## 2026-10-26 Mac 设置与歌曲编辑重新设计

按用户要求重设计设置页及编辑页：设置分为四分类侧栏、标题说明、分组卡片和行末操作，添加文件夹/清空历史不再贴着分隔线堆叠；统一按钮、间距和自有滑动开关，保留原设置及危险操作确认。快捷键录入的 Esc 先取消录入，不关闭页面。歌曲编辑有独立信息/歌词/插图页，默认插图，原图直接完整展示，更换标签置于图片外，点击图片选本地文件，下方在线查找。

在线插图及歌词改为专用双栏工作区：左候选列表、右完整详情，各自滚动，底部固定应用。支持修改关键词/歌手、连续选择、返回/Escape、焦点限制及恢复；仅应用进入草稿，保存仍显式确认。搜索失败在工作区显示并可重试；修复 command 全局报告造成第二个错误弹窗打断搜索的问题，局部处理仍保留 reject，其他命令默认错误报告不变。

editor-redesign-render-final.txt 完整页面回归通过，覆盖四设置页深浅主题、360/600/1040 窗口、默认插图、本地 2400px 图片 contain、候选更换/预览/应用、未保存关闭保护、只读格式、原双端音乐墙交互。editor-panels-behavior-complete.txt 定向验证通过：开关点按与 Space 提交、快捷键 Esc 取消录入、搜索错误/重试、360/600/1100 搜索双栏及图像边界、Tab 焦点归属、Escape 返回及触发按钮焦点恢复、更换标签不遮盖原图。已查看 settings-redesign-light-library.png、editor-online-artwork-split.png、editor-online-lyrics-split.png、editor-artwork-default.png。初轮预览返回断言误计退出动画保留的不可交互副本，修正为等待退出结束；同时发现并修复搜索错误的重复全局弹窗，未放宽焦点和边界断言。

共享逻辑 33 项通过；Mac 逻辑 59 项通过、4 项打包后端条件用例跳过（本轮未修改后端写入）。editor-redesign-components.txt 自有组件交互通过，组件门禁 98 源文件及 git diff --check 通过。Mac-debug 重新构建并通过深度严格签名检查。搜索结果使用受控服务验证，未宣称外部服务实时可用；未替代实机视觉/流畅度验收。本轮布局作用于 Mac，PanelFrame 可选图标只被 Mac 页面使用，未修改 Android 页面。

## 2026-10-27 手机音乐墙拖动、点击、明暗与播放栏

修复播放/收藏/歌词按钮区域不能平移墙面：8px 阈值区分点按与拖动，触控沿用原目标隐式捕获，鼠标拖动才转移到墙面；清理松手/取消/失焦/隐藏/弹层中的指针状态。工具栏按下阶段停止惯性，打开侧栏后相机不继续运动。拖动后的兼容 click 只在墙面内部拦截，下一次侧栏点按不被吞掉。滑块继续独占进度拖动。

普通卡片增加静态 34% 黑色遮罩（不创建逐卡片的透明度动画），选中预览去遮罩、方形重排并保持高分原图交接；当前歌曲保留歌词阅读渐变，3px 顶层独立轮廓覆盖图片和歌词，移除明暗脉冲。卡片右上移除关闭及重复收放按钮，保留译文和底部展开/收起，系统返回仍先收起全屏再退出聚焦。音乐墙配置标题改为“音乐墙”。播放栏歌名/歌手独立整行，控制另占一行、进度保留底部，不再挤窄元数据。

手机反馈按下 .88、释放峰值 1.16，对齐 Mac 墙面主要按钮幅度，保留系统触感与减弱动态。合法 TouchEnd 触发一次语义点击，并取消该 TouchEnd 的兼容 click；不是在 PointerUp 提前执行业务后放任浏览器再次点击。拖动/取消/多指/移出/禁用/忙碌不激活，触控按压缩小不削减布局命中区。鼠标、键盘、辅助激活和 submit 原语义保留。

验证通过：mobile-wall-final-touch-android.txt 完整 UI_PORTABLE_PASS（包含真实 WAV 播放、双语歌词、三样式/主题/系统栏、原图、触觉调用、侧栏真实进出帧、滑条/拖动取消、歌单与分组返回/重启锚点）；mobile-wall-edge-android.txt UI_WALL_PASS，额外覆盖边缘有效点按和真实手指在播放/收藏/歌词上拖动后单次打开侧栏、不触发业务/触感、相机冻结、图片节点逐帧保留、60/100/120 缩放、62% 连续值、展开/系统返回、横竖屏和快速切卡画面。mobile-wall-final-touch-render.txt 页面与原 Mac 页面回归通过，mobile-wall-final-touch-components.txt 自有组件交互通过；共享单元 33 项通过，Mac 单元 59 项通过、4 项后端条件用例跳过，组件边界 98 源文件及 git diff --check 通过。

过程与限制：仪器输入已修正为 SOURCE_TOUCHSCREEN/TOOL_TYPE_FINGER 和实际 Down/Up 间隔；之前未知工具类型会产生空 pointerType 而没有 click，不能作为真实手指的通过证据。长时运行模拟器曾出现旧图块，冷启动 host/OpenGL 后端（本轮关闭 Vulkan）并按真实手指事件重新完整验证；已查看 mobile-wall-final-android.png 和 mobile-wall-native-touchend.png，未再见早轮残留块。常驻整页合成、全墙 Canvas、强制 WebView 硬件层等未改善的实验均已撤销，交付不包含这些尝试。实体手机的 GPU 流畅度、偶发闪屏和物理震感仍需实机体验，不宣称所有设备均已消除闪屏。Android 体验 APK 已更新至 .build/work/android/MiniVoice-android-experience.apk。

### 2026-10-27 手机实机截图反馈：侧栏背景边线、露底和响应
已实现：后方卡片/播放栏边框与阴影在侧栏打开期间隐藏并恢复；导航与歌曲列表增加分层材质；音乐墙增加冻结封面的全幅背景，保留前景内容后退而不露出纯色底。打开侧栏不再连续读取墙面，前景平移与遮罩渐入分开合成。切换按钮立即提供工作中反馈，截图准备不再等待状态 flush，提交仍序列保存。Android 维持截图分辨率上限，独立线程编码 JPEG 95，减少无损 PNG 的体积与编码负担。
验证：mobile-drawer-layer-android.txt 完整 UI_PORTABLE_PASS；含实际手指输入、侧栏真实进入/退出帧、背景边框隐藏/导航层次/墙面全幅背景、三样式与主题、系统栏、横竖屏、滑动取消和返回还原。mobile-drawer-layer-render.txt 原三样式与 Mac 页面回归通过；共享单元 mobile-drawer-layer-unit.txt 33 项通过。截图与日志位于 .build/reports/ui。
待验收：用户实体手机的帧稳定性与截图链路时延；本次未测量实机 FPS，不以模拟器或静态截图宣称所有设备均无卡顿。截图编码已改变格式但未降低原有分辨率上限，需要实机确认细字与碎片边缘观感。
补充验证：mobile-drawer-layer-touch.txt 覆盖简易/音乐墙分层、全幅背景、关闭动画过程中保留背景且完成后释放、延迟 700ms 返回截图时按钮立即出现工作动画、切换完成后清理碎片画布；mobile-drawer-layer-components.txt 自有组件键鼠/忙碌/减弱动态回归通过。最终 Android 包的 targeted mobile-drawer-layer-final-android.txt 为 UI_WALL_PASS。

### 2026-10-27 手机音乐库列表左右留白
已调整主音乐库普通歌曲行：去除滚动容器右侧 28px 预留与行内 26px 预留的叠加，改为左右各 8px 行外间距；封面与收藏图形到面板的可见边距均为 20px。标题栏左侧对齐封面，歌曲信息使用释放出的宽度；收藏按钮维持 44px 触摸区域，时长不压缩。分组卡片、侧栏列表及 Mac 页面未调整。
验证通过：mobile-library-spacing.txt 中 360/390/430px 竖屏及 844px 横屏的两侧可见边距均为 20px、收藏命中区 44px、封面/文字/时长/收藏无重叠；已查看 mobile-library-balanced.png。组件边界及 git diff --check 通过，Android 体验 APK 已重建。实体手机观感待验收。

### 2026-10-27 双端普通歌词滚动与边缘渐隐
已实现：手机普通歌词补齐与 Mac 相同的上下渐隐（各为视口 7%，最多 28px），当前行及邻行使用一致的距离强调；手机去掉歌词 shell 顶部 40px 保留区，Mac 简易歌词控制条改为浮动，去掉独占顶部行。手机首尾留白改按实际歌词视口高度计算，Mac 末尾补齐对称留白，最后一句亦可居中；Mac 用行/视口实际坐标定位，尺寸变化尊重手动滚动保护。音乐墙自己的歌词呈现保持原逻辑。
验证通过：Scripts/tests/test-lyrics-viewport.cjs，日志 lyrics-viewport-geometry.txt，检查手机/Mac 首、中、尾行可居中、渐隐存在、顶部控制条浮动、歌词视口不超出卡片；过程发现手机默认 50vh 留白导致内层撑高，已改为初始零留白、测量后设置像素值，并重新检查实际 436px 视口。lyrics-viewport-final-android.txt 完整 UI_PORTABLE_PASS；lyrics-viewport-render.txt 现有双端页面回归通过；lyrics-viewport-unit.txt 共享 33 项通过。截图已查看，组件边界、diff 空白检查及 Mac codesign --verify --deep --strict 通过。Android 体验 APK 和 .build/dist/MiniVoice-debug.app 已重建。实机滚动观感待用户验收。

### 2026-10-27 Mac 搜索栏边界与信息按钮材质
已实现：音乐库搜索栏从窗口固定宽度改为在 workspace-header 可用宽度内收缩，browse-tools/input 允许 flex 收缩，搜索图标保持尺寸；侧栏覆盖/并排、窄窗口不再把搜索框挤出右边界。简易样式右上角歌曲信息按钮纳入与侧栏按钮相同的共享玻璃材质，沿用统一的圆形 38px 布局与图标组件。
验证通过：mac-search-layout-geometry.txt，304/486/770/1100px 窗口侧栏开/关全部检查搜索框在标题栏和窗口边界内、输入区宽度为正；信息/侧栏按钮计算背景、尺寸、圆角一致。mac-search-layout-render.txt 原双端页面回归通过；已查看 mac-search-layout.png。组件边界、diff 空白及 Mac 体验包签名验证通过。新包为 .build/dist/MiniVoice-debug.app；实机外观待验收。

### 2026-10-27 Mac 桌面歌词按钮、横竖布局与焦点轮廓
按用户明确要求，Mac 非输入控件取消 focus-visible 轮廓（保留焦点、Tab 与 Enter/Space 操作），仅输入框/文本编辑区域保留轮廓；这是本轮对原通用键盘轮廓规范的用户指定外观例外，不改变手机组件默认规则。桌面歌词移除显示播放器/播放暂停两个按钮，新增横竖切换；保留窗口内锁定与关闭，移除设置里的锁定开关。解锁悬浮按钮默认透明无边框，悬浮出现材质与轮廓，歌词窗口内按钮亦只在悬浮显示轮廓。横竖布局经专用配置协议保存，按显示器可用范围调整窗口与独立尺寸限制，竖排原文/译文继续自适应字号。音乐墙收起状态在播放时复用 NowPlayingIndicator 持续四音柱律动，展开后的暂停控制保持原语义。
验证通过：mac-lyrics-actions-geometry.txt 覆盖三按钮/移除旧控件、横竖切换命令和竖向 writing-mode、解锁默认透明、键盘聚焦图标无轮廓、设置锁定项移除及收起播放音柱在两个采样时刻确实变化；mac-lyrics-actions-render.txt 原双端页面回归通过。mac-lyrics-actions-unit.txt 60 项通过、4 项后端条件跳过，含新增竖向配置持久化尺寸约束；组件边界、main.cjs 语法、diff 空白和体验包签名校验通过。新包 .build/dist/MiniVoice-debug.app。窗口在实际多显示器间的旋转、竖排长歌词观感待实机验收。

### 2026-10-27 双端图标与手机队列、主题切换
已实现：Mac 音乐库定位/排序/清除搜索改用共享 SVG，手机设置的主题选中与添加文件夹也使用共享图标，保持 24 点画布与既有语义映射；静态审计两端 103 处 Icon/icon 引用均能解析到共享真实路径。手机三样式的队列统一行边距、10px 间隔、44px 收藏操作与选中态，取消音乐墙对队列行的玻璃卡片/背景模糊污染。手机主题选择立即显示并保存，失败恢复原状态并显示错误，后续写入不会清除更新的选择；缺少偏好时跟随系统。弹窗独立按选定主题取色，避免墙面样式覆盖设置/队列配色。
验证通过：theme-queue-matrix.txt 覆盖三样式×浅深主题六组合、设置选中语义、队列背景/行材质/间距/图标画布及重载后持久化；已查看 theme-queue-light.png / theme-queue-dark.png。theme-queue-android.txt 完整 UI_PORTABLE_PASS；theme-queue-render.txt 原双端页面回归通过；theme-queue-unit.txt 共享 33 项通过。theme-queue-icons.txt 静态图标审计、组件边界、diff 空白及 Mac 签名校验通过。双端体验包已更新，实体设备切换响应仍待用户验收。

### 2026-10-27 用户录屏与七张截图定向修复（本轮）

已实现：手机展开卡片隐藏轮廓，移除只在动画端点更新的全墙黑遮罩；侧栏背后使用实际页面缩放，删除外侧静态封面拼接层，恢复后相机不变。侧栏内部保留独立模糊采样并复用按钮材质色罩/模糊参数。播放栏恢复原歌曲信息与控制同排、进度在下的紧凑布局；缩放滑块去掉圆点刻度并缩小圆形手柄。原生 Android configuration 的 systemDark 进入快照，修复 WebView media query 与系统主题不一致；手机设置弹层不再将整层玻璃祖先与面板同时淡入。

Mac：解锁命中区闲置时包括图标与底框均透明，悬浮/焦点可见；竖置的歌名/歌手及控制区同步纵向布局，目标至少 28px。歌词默认窗口压缩至横 600×112、竖 110×600，仅迁移旧默认预设，自定义尺寸保留。Mac 音乐墙配置映射共享 wallSettings，设置齿轮改为两端共用的中心对称路径。

通过：组件边界；共享逻辑 33 项；桌面逻辑 61 项、4 项宿主测试在普通运行跳过；打包后台以独立 MiniVoice.Test.* 偏好域额外运行 4 项全部通过；Mac codesign --verify --deep --strict；自有组件交互、test-wall-version 实际页面回归（1037 首、三种样式/深浅、打断、缩放/拖动、展开返回、窗口边界）；test-mobile-wall-touch（真实播放/收藏/歌词区域拖动、不误触、侧栏相机与实际页面缩放、原紧凑播放栏、展开无轮廓、收缩中间帧无黑遮罩）；test-desktop-lyrics（600×112/360×88 长句和译文拟合、110×600 竖向元信息、默认透明解锁及真实点击）。上述截图已检查。

Android 专用 emulator-5554：portable 完整回归通过 UI_PORTABLE_PASS；新增系统主题用例在设置页保持打开时通过 cmd uimode night yes/no，原生 configuration 驱动 WebView 分别到 dark/light，结束恢复模拟器原夜间设置。覆盖横竖屏、安全区域、三种样式深浅、播放/队列/设置/返回、缩放与歌词。日志 `.build/review/`，定向包 `.build/work/android/MiniVoice-android-experience.apk` 和 `.build/MiniVoice-mac-experience.zip`；Mac 体验版身份/数据域隔离保留。

待实体设备验收：用户手机 GPU 上的设置闪烁、玻璃采样与快速连续展开/收缩观感，真实封面下的两端材质一致性及对比度；本轮没有实机 FPS 或对比度测量。此为定向体验包，不代表整个产品矩阵全部签收。先前要求存在静态拼接层、手机七个圆点的断言已改为验证本次明确要求的实际场景缩放和连续滑块，未放宽组件标准。

### 2026-10-27 手机样式切换后音乐墙配置按钮被播放栏遮挡
根因：WallDock 卸载前已收起，外层 dockCompact 保留 true；切回音乐墙时新实例默认展开，却只在下一次收起/展开事件通知外层，造成配置按钮仍在底行。现由 WallDock 在 layout effect 中同步首次挂载与后续 compact 状态，首帧前更新配置按钮位置，保留原有收起/展开过渡。
通过：组件边界、diff 检查；新增 test-mobile-wall-touch 场景（空闲收起→切换简易/音乐库→返回音乐墙，播放栏展开，配置按钮底边距播放栏顶边至少 12px），截图 mobile-wall-style-reentry-settings.png 已检查；test-wall-version 全页面回归；重建 APK 后 emulator-5554 完整 portable 回归 UI_PORTABLE_PASS。日志 .build/review/style-reentry-*，Android 体验 APK 已更新。实体手机的连续切换动画仍待用户回验；本次未修改 Mac 播放栏。

### 2026-10-27 Mac 解锁图标常显、悬浮才显示轮廓
用户澄清：需要默认看见锁图标，只隐藏外框；上一轮将整个按钮透明不符合要求，现已纠正。图标保持显示，默认背景/边框/阴影透明；悬浮底色显式与对应深浅桌面歌词匹配，图标浅色为深绿、深色为浅白，避免深色模式使用浅色回退底色。
通过：组件边界、diff 检查；test-desktop-lyrics 覆盖浅/深×默认/悬浮的图标、背景、边框、实际点击解锁，以及原有长句、译文和竖向适配；四张 desktop-unlock-{idle,hover}-{light,dark}.png 已逐张查看。Mac 体验包重建且 codesign --verify --deep --strict 通过。用户实际桌面背景下的最终观感待回验。

### 2026-10-27 Mac 解锁按钮独立窗口阴影与错位整改
上轮仅覆盖 CSS 透明/悬浮，没有关闭原生透明窗口的系统阴影；独立按钮尺寸/悬浮底色/横竖位置也与原锁按钮不一致。本轮关闭宿主 hasShadow 和 roundedCorners，透明 backgroundColor，保留首击解锁；可见按钮复用原锁按钮 28px 尺寸与 6px 圆角，宿主不绘制悬浮底板或阴影，按钮只作轻色高亮和轮廓。横竖坐标对齐原锁按钮，避免锁定后位置横跳。
通过：边界与 diff 检查；桌面 63 项通过（普通运行 4 项后台用例跳过），打包后台以隔离测试域另跑 4 项通过；test-desktop-components；test-desktop-lyrics 新增真实 Electron BrowserWindow.hasShadow()==false 检查，横竖锁/解锁中心≤1px，浅深默认与悬浮外观、实际点击解锁。四张按钮截图及 desktop-unlock-composite-light/dark 完整窗口组合预览已查看；组合预览用于检查按钮与歌词的布局，不能视为用户实际桌面的系统合成截图。Mac 体验包重建、codesign --verify --deep --strict 通过。
待验收：用户当前桌面上的最终原生合成观感；当前未获取到用户本次实际问题截图，未宣称实机问题已完全复现。产物 .build/MiniVoice-mac-experience.zip，日志 .build/review/native-unlock-*。

### 2026-10-27 手机音乐墙真实缩放、材质打包问题与可上拉队列
按用户新截图重新核查并修正：恢复七个 Mac 同款缩放刻度；墙面侧栏景深从“缩小/裁切整个页面”改为完整屏幕内临时相机缩放，边缘显示真实已解码封面、关闭恢复持久相机；清除普通页背后内容的面板材质，并将 atmosphere 移出缩放内容容器，去掉大圆角底板；取消样式 badge 旋转。音乐墙侧栏和所有手机 Modal 直接采样当前内容，用按钮同款色罩/模糊；队列可上拉到安全区域内接近全屏，下拉回半屏，取消不改变档位，保留单一歌曲列表滚动区。
重要根因：此前 dev 预览通过不代表 APK 正常。模拟器实测已安装包的墙面侧栏 backdropFilter=none；生成 CSS 经 minifier 后只剩部分 WebKit 前缀声明。现关闭共享 UI 的 CSS minify，保留双声明并添加产物门禁。修复后安装 APK 的真实 filter 检查通过。此为渲染修正，JS 平台目标与身份/数据隔离不变。
通过证据：组件边界、diff 检查、共享逻辑 33 项；自有组件回归、实际双端页面 test-wall-version；新增 test-mobile-wall-surfaces（完整画布、各边缘≥75%真实封面覆盖且保留自然间隙、原相机恢复、七刻度、共享单层材质、无 badge 旋转、队列上拉/下拉/取消、深浅截图、普通页无嵌套底框）。开发页面 1037 首规模；Android 专用 emulator-5554 安装最终 APK，portable 测试包含实际玻璃 filter、三种样式深浅、横竖与安全区域、返回和系统主题、真手指队列展开/收起/取消和单滚动条；首次完整 UI_PORTABLE_PASS 后补充 atmosphere 外移检查并重跑最终包，最终日志见 .build/review/mobile-rework-android-final.txt。
截图：mobile-full-wall-drawer-light/dark、mobile-wall-scale-marks、mobile-queue-half/full-dark、mobile-queue-full-light、mobile-simple-drawer-unframed 已检查；实际 APK 截图保存于 .build/review/mobile-rework-android-shots，已检查墙面浅色侧栏、简易浅色侧栏和真实手指展开队列。最终包 .build/work/android/MiniVoice-android-wall-glass-20261027.apk（同时更新 experience.apk）。
待验收：用户实体手机的实际 GPU 合成、连续操作流畅度与真实封面下的对比度；未测量 FPS，不把模拟器通过称为整体验收完成。本轮未修改 Mac 页面实现。
最终补充：atmosphere 外移后的最终 APK 也已重跑得到 UI_PORTABLE_PASS；最后一轮真实截图位于 `.build/review/mobile-rework-android-shots/ui-regression/`，已重新查看简易浅色侧栏，背后不再有页面大小的圆角底板。最终体验 APK 两个交付文件均从此轮构建复制。

### 2026-10-27 Mac 桌面歌词与在线歌词/插图编辑优化
桌面歌词字号上限从 64 调整为 44，保留 18 起点并细化为 1px、显示当前 px。以整首歌长句/译文及可用窗口测量稳定字号，最小横竖窗将歌词与控制区分离；同歌长短句切换不跳字号。保留既有独立解锁按钮与原生透明窗口行为。
在线歌词显示歌名、歌手、专辑、时长、来源与明确的纯文本/逐行/逐字标签，详情预览行时间及真实逐字进度。在线插图和编辑插图扩大预览，显示像素尺寸与实际文件字节。两个搜索页面进入即查询，居中加载、失败可重试，返回忽略迟到请求；搜索弹层使用明确深浅主题，修复截图中浅色面板白字和整体发灰。搜索呈现抽入共享 SearchWorkspace，平台命令留在 Mac 适配层；未新增 Windows 宿主。
通过：组件边界 100 源文件；共享逻辑 36 项；桌面逻辑 63 项（普通运行另有 4 项后台测试跳过）；test-desktop-components、test-editor-panels、test-editor-search-workspace、test-desktop-lyrics、test-wall-version。桌面歌词矩阵覆盖浅深×横竖×18/32/44、最小窗口、长短句字号稳定和控制区不重叠。在线页覆盖自动查询、等待/错误/选择、元数据、逐字不拆行、大图像素/字节；浅深搜索/加载/插图截图已检查。最终构建、签名和隔离后台验证见 .build/review/mac-editor-*。
待用户回验：真实桌面背景的窗口合成观感、真实在线源的网络速度与元数据完整性；未知字段如实显示未提供。本轮未测量整套动态背景对比度或 FPS，不代表全部产品矩阵验收完成。Mac 体验版身份和数据隔离保留。

本轮最终产物验证：打包后台以独立 MiniVoice.Test.* 域运行 4 项全部通过（含原图源字节不缩略），codesign --verify --deep --strict 及 git diff --check 通过。体验包 `.build/MiniVoice-mac-experience.zip` 已由最终构建更新。

### 2026-10-27 手机切换样式动画、薄透明音乐墙与状态标签
发现的开销：原切换每帧 clearRect 并从完整截图裁切/旋转绘制全部碎片，同时更新每帧 DOM 标记。已改为截图碎片一次绘制，后续仅由 Web Animations 变换与透明度呈现；总纹理像素预算降至 120 万、倍率最多 1.5，保留原碎片形态/原点/时序，打断和减弱动态可清理。此为明确去除的重复绘制工作，不将其称为真机 FPS 测量结果。
材质问题原因：手机音乐墙沿用普通页 .58/.60 色罩与 24px 模糊，虽透明采样有效，观感仍偏磨砂。本次为音乐墙按钮/播放栏/侧栏提供相同的 .18/.24 色罩和 10px 薄玻璃；普通弹窗材质保持原参数。播放卡片左上角改为截图所示 Mac 同款薄荷绿胶囊+三音柱，暂停静止、播放跳动，紧凑卡片也保留。
通过：组件门禁、共享逻辑 37 项、test-wall-version 实际双端页面、test-mobile-wall-surfaces、test-mobile-wall-touch；新增 test-mobile-style-glass 覆盖真实浅深设置、状态语义、同材质、72 碎片单次绘制与动画期间无新增 drawImage、快速连续切换及无残留。截图 mobile-thin-status-paused/playing、mobile-thin-drawer-light/dark、mobile-thin-fragments 已检查。Android 最终打包与专用 emulator-5554 portable 结果见 .build/review/mobile-thin-android-final.txt。
待验收：用户实体手机 GPU 的连续切换流畅度，以及真实封面组合下薄透明侧栏的文字对比；未测量真机 FPS 或整套动态封面对比度，不宣称所有手机均无卡顿。Mac 页面未改动。

最终补充：最终 APK 在 emulator-5554 得到 UI_PORTABLE_PASS，含实际截图纹理、碎片变换中间值、三样式深浅、横竖/返回、原生系统主题和真实手指队列手势。最终 Android 截图保存在 `.build/review/mobile-thin-android-shots/`；交付 `.build/work/android/MiniVoice-android-thin-glass-20261027.apk`，并更新 experience.apk。

### 2026-10-28 Mac 独立设置/编辑窗口与大图操作
按用户截图调整：设置、歌曲编辑从主窗口内覆盖层改为独立原生窗口，主窗口缩放不影响其内容区域；设置复用一个窗口，编辑按歌曲复用以保留草稿。仍由自有组件绘制内容，窗口关闭、搜索层返回、忙碌与未保存确认保持一致。设置各分类标题下概述移除。
插图只保留“歌曲插图”标题及复制/更换/查找操作，去掉截图标记的说明与图片信息。大图完整铺满剩余预览区域、保留比例；点击图片不打开文件选择器，仅“更换”按钮选文件。支持图片复制、Command/Ctrl+C/V、单图拖入成为草稿和原尺寸 PNG 拖出，明确保存后才改歌曲。同步处理所属窗口授权、图片格式/大小验证、临时导出清理和迟到读取。
验证：组件门禁；共享逻辑 37 项；Mac 逻辑 64 项、常规运行 4 项后台用例另行验证；test-editor-panels、test-editor-search-workspace、test-wall-version、自有组件交互回归通过。test-panel-windows 使用真实 Electron BrowserWindow 和生产 renderer/preload：设置单实例、父窗口改为 400×650 后子窗尺寸不变、原生关闭/草稿保护、深浅主题、大图区域、点击图片不选图/更换按钮选图、1600×1200 图片复制和 PNG 导出尺寸、File drop 和键盘粘贴验证通过。原图测试为合成图，剪贴板与 startDrag 注入测试替身，不写用户剪贴板或伪称 Finder 实际落点已验证。截图 independent-settings-light、independent-editor-light/dark 与更新后的 editor-large-source-light 已检查。构建和签名、隔离后台结果见 .build/review/panel-window-*。
待回验：用户 macOS 桌面上的拖出到 Finder/其他软件、其他软件图片粘贴和多显示器窗口观感；本轮没有更改手机端。

本轮最终产物：`.build/MiniVoice-mac-experience.zip` 已由最终构建更新；打包后台在独立 MiniVoice.Test.* 偏好域运行 4 项全部通过，codesign --verify --deep --strict、组件门禁及 git diff --check 通过。

### 2026-10-28 手机缩放节点反馈、侧栏字体和横屏布局
缩放节点的方框反馈修正：移动 Slider 及内部节点取消 WebView tap highlight，触摸只保留圆形滑块反馈；键盘焦点也改为圆形光环，桌面规则不变。侧栏调整字号/字重/行距、14px 圆角选中细框与 aria-current，浅色文字加强层级，保留上一轮薄透明玻璃，不给每个未选中项新增底板。
对照非体验版原生 PlayerStylePage、HomeScreen、WallViewport 的布局代码，普通横屏采用左侧封面/元信息/进度/控制与右侧歌词，列表保留全宽目录和底部播放栏；歌词展开改为全幅歌词和底部横排控制，墙面聚焦左侧、播放栏右下。保留当前自有按钮和玻璃皮肤，不切回旧原生内容界面。Android 横屏三种样式全部隐藏状态栏/导航栏，竖屏恢复；保留刘海与临时轻扫系统栏。
通过：组件门禁、共享逻辑 37 项、test-wall-version 双端实际页面、自有组件测试、test-mobile-wall-surfaces；新增 test-mobile-landscape 覆盖深浅、横屏普通/目录/墙面与歌词展开、侧栏选中/文字、圆形缩放反馈及恢复。实际截图 mobile-native-landscape-simple-light/wall-dark、mobile-sidebar-type-light 等已检查。最终 APK 的 emulator-5554 portable 验证及日志见 .build/review/landscape-android-final.txt；包含实际 systemBars 方向可见性、手指按住刻度的无方块反馈、横竖/返回/系统主题、队列手势与真实音频。
待用户回验：实体手机切口/系统导航模式、透明封面下字体观感与横屏操作舒适度；本轮按原生分区对齐，未宣称所有屏幕逐像素一致或真机 GPU 流畅度已测量。Mac 源码与打包不在本轮修改范围（工作区仍保留上一轮 Mac 独立窗口改动）。

本轮最终补充：重新打包后的最终 APK 在 emulator-5554 再次通过 UI_PORTABLE_PASS；真手指按住节点截图和横屏截图位于 `.build/review/landscape-android-final-shots/`。交付 `.build/work/android/MiniVoice-android-landscape-20261028.apk`，同步更新 experience.apk。测试会关闭首次沉浸系统说明以检查实际页面，不将系统引导当作应用内容。

## 2026-10-28 打包入口整理

- 已实现：`build.sh` / `build-experience.sh` 统一构建安装包；`deploy.sh` / `deploy-experience.sh` 生成移动安装包并事务式替换对应 Mac 应用，不制作 DMG。正式、体验 Mac 身份和数据隔离保持不变。
- 已验证：两种 Android APK 实际构建、签名校验通过；aapt2 确认正式启动 MainActivity、体验启动 PortablePlayerActivity。媒体/扫描通知改为跟随当前包的启动器入口。四入口路由、单平台失败继续处理且整体非零、未知平台拒绝、工作锁释放的隔离测试通过；Shell 语法和 101 源文件组件边界通过。
- 产物规范：`.build/dist` 固定文件名覆盖；历史 APK/DMG 转移到 `.build/archive/installers`，不删除。临时 APK 和签名伴随文件在组装目录退出时清理。
- 版本边界已由用户确认：保留原生设置等窗口的现有 Mac 正式实现为正式版，自有组件窗口实现为体验版；继续共用已有底层及组件，不恢复历史纯 SwiftUI 主窗口。
- 未接入：iOS 体验版宿主；入口会明确失败，不能用正式 IPA 冒充。iOS 正式 archive/export 流程已编写，缺少团队/导出配置时拒绝生成，尚未验证签名 IPA。
- 待验收：本轮未执行真实 Applications 替换或设备安装回归；Android 两版沿用相同包名和开发证书，互相覆盖，不能宣称可并行安装或商店发行已配置。

打包实测补充：正式、体验 Mac `.app` 均通过新入口完成重建和 codesign 深度严格校验；两个固定名称 DMG 均完成生成与 hdiutil verify。发布目录现有两 APK、两 DMG；没有生成 IPA。未执行 `/Applications` 实际替换或真机安装，iOS 导出配置缺失拒绝路径已验证。

## 2026-10-28 项目目录与前端构建依赖整理

- 已实现：`.build` 顶层只保留 cache、work、reports、archive、dist；既有安装包、历史项目副本、实验资源和验收证据保留并迁移。App 及安装包统一在 dist；迁移清单保存在 reports/build-layout-migration.json。旧 Clang/Swift 编译缓存与需要重建的实验 Python 环境保留在 legacy 目录，新路径不复用包含旧绝对路径的编译模块。
- 已实现：Scripts 只保留 build、build-experience、deploy、deploy-experience 四个公开脚本；内部实现按 build/common/checks/tests/tools/assets 分类，仓库引用和说明同步更新。正式原生窗口与体验自有组件身份边界未改变。
- 已实现：9 个 Shared/UI Vite 缓存文件移出 Git 跟踪；所有层级 node_modules 与 Vite 缓存加入忽略规则。共享 UI 有独立锁文件和构建入口，两个前端共用 Shared/Tooling 下的离线依赖工具与 LFS 归档，桌面仍显式使用自身 React，避免页面双实例。
- 验证通过：临时隔离项目不含 MacOS/Desktop/node_modules，从不同工作目录离线安装 19 个包并完成共享 UI 构建；npm Shared/UI 构建入口通过。共享 UI 37 项测试、桌面 64 项测试通过（另 4 项按环境跳过）；核心 Swift 2 项和 C/JNI/Swift 10 组协议金样通过；Android JVM 测试通过。
- 验证通过：四入口路由及失败传播、迁移预览/重名归档/重复执行/构建锁保护，组件边界及脚本语法。Electron 自有组件交互、音乐墙页面回归通过。两版 Android APK、两版 Mac App 与 DMG 已在新目录完成构建、签名或镜像校验。
- 环境记录：Mac 首次验证发现搬迁 Clang 缓存包含旧绝对路径，已归入 legacy 并重新生成；GitHub 依赖更新网络失败，最终使用本地依赖与 MINIVOICE_LOCKED_BUILD=1 完成构建，不修改依赖版本。
- 未执行：缓存清空、用户 Applications 替换、真实设备安装或全量视觉矩阵。本轮整理不增加 iOS 体验宿主或 IPA 签名配置，不改变此前未接入结论。

## 2026-10-28 Android 缩放条与中性玻璃面板

- 已实现：手机显示比例滑块使用 4px 实色轨道、无晕圈刻度与 18px 圆形滑块头/2px 分离描边；保留七刻度、连续 1% 调节和原手势/键盘行为。三种手机样式的侧栏、设置与各 Modal 共用中性深浅皮肤，保留原透明底色 alpha，降低背景饱和度；墙面侧栏用 22px 真实背景采样与独立深浅亮度，不再叠导航内部的灰绿色底板。
- 已实现：暗化遮罩移至面板外部，避免先压暗背景再采样造成浅色玻璃发灰；按钮/关闭控件、选中行、输入框统一采用对应深浅面板变量。所有新规则限定 mobile，不改变 Mac 正式版/体验版皮肤与身份。
- 通过：组件边界 101 源文件；共享逻辑 37 项；Electron 三样式 × 深浅设置和侧栏、刻度/62%键盘调节、薄玻璃采样/切样式、队列伸缩/取消，以及原音乐墙/Mac 页面回归。截图与日志位于 `.build/reports/ui/neutral-*`、`mobile-neutral-surfaces-test.log`、`mobile-style-glass-test.log`、`mobile-wall-surfaces-test.log`。
- 通过：最终体验 APK 构建及签名；专用 Android 35 模拟器 `mode=surfaces` 返回 UI_SURFACES_PASS，覆盖实际 WebView 三样式 × 深浅侧栏/设置、真实背景采样、七刻度、无晕圈、44px CSS 布局目标，以及手指点选 90%。原生弹窗基准 mode=modals 返回 UI_MODALS_PASS。实际 WebView 截图位于 `.build/reports/android/neutral-surfaces-final-screenshots/neutral-native-*`。
- 失败/待定位：完整 portable 回归在 Shared play did not reach real service 断言处崩溃，两次复现；音乐墙完整 mode=wall 在 Phone wall did not show bilingual lyrics 断言失败。使用隔离目录以 Git HEAD 的改前 PortablePlayer/player.css/materials.css 构建对照 APK，portable 同样在 Shared play 断言失败，日志见 android-neutral-surfaces-baseline-*。未放宽原断言或声称完整播放/歌词回归通过。基准测试后模拟器已恢复最终体验 APK；对照包仅保存在 reports/android。
- 待验收：用户实体手机、真实封面组合、厂商 WebView/GPU 的清晰度、对比度与连续动画。本轮不宣称实体设备矩阵或全产品验收通过。

## 2026-10-28 Android 播放页与横屏体验优化

- 已实现：普通手机页面（音乐库/简易）的图标工具与传输按钮移除常态圆底、描边、阴影；保留按压、选中颜色、禁用和键盘焦点。专辑图容器不再绘制宽色底，保留原图比例。
- 已实现：展开墙面卡片跟随播放身份变化，下一首与外部换曲后更新聚焦；主动浏览非当前卡片不强制跟随。切入音乐库时清除继承的播放页展开状态、进入全部歌曲列表并定位当前歌。歌词解析按歌曲 ID+原文归属，译文入口仅在当前解析结果存在非空译文时显示。
- 已实现：手机展开音乐墙新增大字歌词模式，复用 Mac 原有纯排版/逐字着色算法（桌面旧导出兼容）；控制受页面 wallKinetic 状态管理，支持双语、换曲、暂停/定位与减弱动态。横屏按可用高度控制后续行数量，避免半行裁切。展开内容四边使用安全区；横屏墙面设置按钮移到左下，与侧栏按钮共用左边线。
- 已实现/优化待实体机验收：临时风格截图由最多 300 万像素、JPEG95 调整为最多 120 万像素/长边1600、JPEG85，后台编码不变，封面原件不受影响；碎片每8块让出一帧，轨迹与连续意图保留。上一轮100vmax外扩阴影改为独立裁切遮罩，降低首次侧栏绘制面积；退出幽灵保留移动皮肤，仍不可交互。
- 通过：103源文件边界、38项共享测试、桌面64项通过/4项按条件跳过；Electron 定向流程覆盖下一首、大字/减弱动态、无译文入口、模拟左右安全区、横屏设置位置、无按钮/封面底板、切入音乐库定位远处第901首；原组件交互、三样式深浅面板与音乐墙/Mac页面回归通过。
- 通过：最终 APK 构建与签名；专用 Android35 模拟器 playerFlow 模式返回 UI_PLAYER_FLOW_PASS，连接真实 PlaybackService 验证下一首跟随、歌词模式、横屏安全区、设置位置和列表入口。截图在 `.build/reports/android/player-flow-final-screenshots/android-flow-native-*`，Electron 图在 `.build/reports/ui/android-*`。
- 性能实测：最终模拟器流程某次切换记录 capture41ms/decode23ms/prepare151ms/total959ms（total含动画等待），报告 android-player-flow-native-final.log；Electron 合成曲库定向流程记录 capture7ms/decode0ms/prepare73ms/total792ms，当前观测窗口 Long Task 列表为空。无设备/前后对照基准，不把这些数字推广为帧率、所有冷启动表现或用户手机流畅度结论。
- 待验收/边界：用户实体手机首次打开、真实大曲库、厂商GPU/WebView、挖孔/刘海与导航栏组合仍待回验。此前完整 portable/歌词回归失败仍保留，未放宽或删除原断言；本轮新增定向流程不等同完整回归通过。

## 2026-10-28 Android 录屏反馈修正

- 修正上一轮过大的去底板范围：仅音乐库/简易的列表工具、播放控制、歌词区等次级图标按钮保持简洁，顶部侧栏、搜索及返回恢复原玻璃圆形/胶囊。歌曲行取消 WebView 默认蓝色点击高亮，保留圆角选中、触控反馈与键盘焦点。
- 展开音乐墙换歌不再重跑小卡片聚焦入场；新封面解码前保留上一张已解码大图，同一展开根节点持续存在。大字歌词切换与收起按钮交换位置。
- 去除侧栏/弹窗遮罩的矩形空洞裁切，改为连续单层遮罩；设置页补充窄屏、横屏、长路径换行、按钮与标题布局。此条替代上一节的空洞遮罩方案。
- 移动端样式碎片上限24，减少合成图层；捕获等待上限180ms、解码等待250ms，超时走既有降级，保留动画取消及连续切换意图。桌面碎片预算不变。
- 通过：103源文件静态门禁、39项共享模型测试；增强 Electron 流程逐帧检查延迟900ms解码下展开换歌不露出小卡片、按钮位置、主按钮圆底恢复；320px竖屏/844px横屏设置无横向溢出；三样式×深浅侧栏/弹窗及样式连续切换测试；现有音乐墙和实际 Mac 页面回归。报告 android-regression-{flow,neutral,style,wall-full,unit-tests}.log。
- 性能记录：本轮 Electron 合成截图流程 capture10/decode0/prepare17/total736ms（包含动画），观测窗口无 Long Task；碎片专测实际20个一次栅格化图层。仅代表测试环境，不能推断用户手机帧率或首次切换体验。
- 构建通过：当前体验 APK 已生成并签名。原生 playerFlow 本轮未通过：首次 WebView callback timed out，重试时 emulator-5554 掉线；保留 android-regression-native-flow*.log，不算原生验收通过。用户实体手机录屏场景、设置页真实内容及厂商 GPU 合成仍待回验；此前完整 portable/歌词失败仍未关闭。

## iOS 音乐墙首轮移植（2026-10-28，用户明确要求）

本次用户明确要求开发 iOS，并优先音乐墙、侧栏及设置弹窗，因此仅对本轮 iOS 实现适用平台范围例外；Android/Mac 原有标准不变。

- 已实现：音乐墙改为背景全屏画布，顶部工具/底部播放条与设置按钮叠放；选中歌曲详情浮在画布上，关闭不移动墙面布局。双向拖动、周期重复沿用原实现，缩放及相机位置存入 iOS 专用偏好。工具反馈尊重减弱动态效果。
- 已实现：实际 SwiftUI regularMaterial 侧栏，导航/歌单可滚动，遮罩关闭；设置为自有材质弹窗，文件夹增删、递归扫描开关、忙碌禁用、重新扫描/清理封面接入原业务。外观支持系统/浅色/深色并持久化。音乐墙设置使用自有按钮选项和比例步进。
- 通过：`node Scripts/checks/check-ui-standards.mjs`；`bash Scripts/tests/test-ios.sh`（LRC 与加权墙几何）；`bash Scripts/build/build-ios.sh simulator Debug`。门禁现有扫描范围不覆盖 SwiftUI，不能据此宣称 iOS 控件全部符合共享组件契约。
- 运行证据：新建专用 `MiniVoice iOS UI Check` iPhone 18 Pro / iOS 27.0 模拟器，安装并启动 `com.xcosmos.MiniVoice.ios`，截图检查空库首页布局；未操作真实音乐库。当前可用 UI 自动化接口无法绑定 Simulator，未完成侧栏/弹窗点击流程验收。
- 待验收：有封面音乐库的墙面视觉、弹窗/侧栏连续开关、浅色实际截图、文件目录授权/扫描、播放器窄屏碰撞、横屏/iPad、重启相机恢复和真机触控/材质效果。
- 尚未移植：Android 周边封面聚焦回流、圆形播放条空闲变形，以及共享自有图标路径。现有队列/歌词页与系统新建歌单提示仍保留原 SwiftUI 实现。此次为定向首版，不代表 Android 完整复刻或整体验收通过。

## 2026-10-28 简易样式默认播放页

- 简易样式启动恢复时清除当前页旧 catalog/lyrics 展开状态；通过侧栏切换或设置切入简易也显示播放信息及歌词页。主动打开歌曲目录不受影响。未选择歌曲时主标题与底部播放栏统一显示“选择歌曲”。
- 验证：定向 Electron 测试覆盖设置切入、未选歌标题、旧目录状态重启恢复；Android 构建及签名检查。实体设备回验待完成。

### iOS 主屏图标黑边修正（2026-10-28）

- 原因：AppIcon 源图采用桌面图标的内缩圆角背景，背景外圈在 iOS 上成为黑边。
- 修正：共享 BrandIcon 新增默认关闭的 fullBleed 导出选项；iOS 专用生成器输出铺满画布、无 alpha 的 1024×1024 PNG，主屏圆角交给系统裁切。同步应用内预览；Mac 默认绘制路径保持不变。
- 通过：生成图视觉检查（四角和边缘为绿色，无黑色留边）、图像尺寸/alpha 属性检查及 iOS 模拟器 Debug 构建。系统主屏刷新后的效果待验收，不能将源图检查写成主屏截图验收。
- 可复现导出：`bash Scripts/tools/generate-ios-icon.sh`。

## 2026-10-28 展开播放器安全区与控制间距

- 手机展开音乐墙去除控制行额外44px内边距；收起按钮回归同一控制行，播放/上一首/下一首/收藏靠左，大字及收起靠右；按钮44px触控区域、弹性间距与中间留白避免互相挤压。
- 横屏左右统一使用 max(16px, safe-left, safe-right)，按头部最大安全宽度对称避让，标题、歌词、控制行和完整进度行共用边界；底部取实际安全区与12px较大值。竖屏左右分别按安全区与16px较大值处理。
- 通过：静态门禁、Android体验包构建/签名；定向Electron逐帧播放流程及新增320/390竖屏、844横屏左右挖孔模拟，断言按钮44px、不重叠、不越界、首末按钮和进度行共边、横屏安全边距对称。报告 android-player-spacing-flow.log；用户实体设备安全区/GPU观感待回验。

## iOS 默认接入 Android 共享界面（2026-10-28）

按用户本轮明确要求，继续 iOS 并按 Android 体验版布局/交互与开发手册接入。这一条替代前文 iOS“原生首轮”的当前默认实现描述，其他平台规则不变。

**已接入**

- 默认 WKWebView 承载 App Bundle 内同一份 Shared/UI，复用三种样式、音乐墙聚焦/回流、侧栏、搜索、设置/队列/歌单弹窗、自有按钮/图标/滑块/滚动条与空闲收起规则。SwiftUI 旧 HomeView 保留参考，不是默认或回退入口。
- 宿主桥接现有 iOS 音乐库、文件授权、后台/锁屏音频、毫秒 DTO、Shared Core、收藏/批量收藏、歌单创建/改名/删除/成员操作、播放模式与队列选择。页面状态独立 JSON 原子保存；目录移除后撤销未授权队列/当前音频。
- 只加载本地打包页面和按当前库身份提供的封面；拒绝外部导航、未知命令和未授权歌曲。模拟器合成夹具需显式参数；集成测试脚本只接受专用模拟器名称。
- 用户澄清的竖屏定位：**展开长条左右居中；收起圆形仍在原左下角**。使用共享组件的显式宿主布局配置，Android 定位不变。过渡期间同一材质节点移动/缩放，未另建 iOS 播放条。

**已执行的验证**

- `node Scripts/checks/check-ui-standards.mjs` 通过；`node --test Shared/UI/test/*.test.mjs` 45 项通过，新增 iOS 手机家族、DTO 命令/毫秒、目录 revision 与错误/迟到回复测试。
- `bash Scripts/tests/test-ios.sh` 通过（LRC 与旧原生墙几何；后者不等于当前共享音乐墙交互验收）。
- 模拟器 Debug 与未签名设备 Release 编译通过；AVFoundation 原有同步标签读取仍有弃用警告。
- 专用 iPhone 18 Pro（402×874）与 iPad mini（744×1133）的 WKWebView 合成音乐库集成流程：共享页面/封面、侧栏、设置重开、深浅主题保存回读、歌单协议、AVPlayer 切歌与进度、五模式、拒绝未授权歌曲/无效模式、队列共用虚拟列表、墙比例保存、三种样式切换。自动报告/截图位于 `.build/reports/ios/shared-ui/<UUID>/`。
- 竖屏定位追加检查：展开长条中心、闲置收起、圆形左下角位置、同一 DOM 材质节点、动画中间帧不出屏、再次展开后居中，以及非对称左右安全区后的展开长条中心。最终结果以本条对应专用模拟器报告为准。

**待验收 / 未接入**

- 集成流程使用 DOM 激活，未证明真实手指拖动、双指缩放、取消/长按、旋转、键盘、VoiceOver 或真机 GPU/材质流畅度达标。系统目录选择/iCloud 下载和授权续期、音频打断及锁屏入口定位仍待实机验证。
- 诊断导出、歌手别名、完整缓存维护和原生版手动导入 LRC 入口未接入共享 iOS 宿主。设置按已支持能力呈现，未实现命令明确拒绝；本轮不能称全量 Android 功能对齐。
- 未覆盖用户真实音乐库，没有发布、签名安装到实体设备或提交应用商店。

### iOS/iPad 播放栏后续澄清与优化（2026-10-28）

- 按用户澄清：仅展开长条竖屏居中；圆形仍左下。额外优化通过共用碰撞模型和布局观察器实现：设置按钮只在长条实际侵犯 12px 安全间距时上移，iPad 不遮挡则保留右下；初次布局直接落在正确位置，避免启动滑动。
- 已修复模拟器鼠标悬停使圆形自动展开：共用 useIdleCollapse 提供显式 hoverExpand，移动端关闭悬停展开，点击才展开；Mac 默认为 true。
- 专用 iPhone/iPad 最新报告通过：展开中心/收起左下/中间帧不出屏/同一材质节点、不对称安全区、手机遮挡避让、iPad 无遮挡不移动、mouse pointerover 不展开。iPad 实测原位底距 34pt，展开/收起后相同；仅为该专用模拟器尺寸，不是通用硬编码。
- 共享单测新增碰撞模型边界，合计 45 项通过；共享内容组件测试通过。整版墙回归第一次因 Vite 服务连接中断超时，使用独立端口重跑，最终状态见本轮报告补记。

本轮回归补记：独立端口 `MINIVOICE_WALL_TEST_PORT=5297 bash Scripts/tests/test-wall-version.sh` 完整通过，覆盖移动音乐墙/侧栏/进度/样式/安全区域与 Mac 墙面、播放栏、设置和窗口几何；`bash Scripts/tests/test-desktop-components.sh` 通过。首次 Vite 连接中断的超时已通过独立端口重跑解决，未修改或屏蔽回归断言。

## 2026-10-28 横屏墙面位置与侧栏连续性

- 横屏播放栏恢复左下、配置右下；聚焦卡片按左侧播放栏和右侧工具列之间剩余区域居中，宽高根据安全区及可用空间约束。覆盖844×390、1024×600、1366×768，不依赖固定屏幕坐标。
- 侧栏关闭幽灵继承安全区，并固定关闭前实测面板位置及尺寸，避免脱离祖先布局后跳位；定向测试修复前x54跳0，修复后x54保持54。
- 展开卡片大字/收起按钮去常态底框，保留按压反馈；选中收藏使用红色实心爱心。换歌新封面解码完成后以520ms轻缩放过渡，遵守减弱动态；仅时长和缓动风格向Mac靠齐，不宣称两端完整切歌实现相同。播放栏进度条按用户更正保持粗细，长度两端各内收8px。
- 通过：静态门禁、42项模型测试、横屏可用区域及侧栏关闭几何专测、增强播放流程、原墙面及实际Mac页面回归；APK构建签名。真机材质、连续快速开合及切歌观感仍需用户设备回验。日志android-wall-{placement,centering-flow,centering-ui,centering-unit}.log。


### 2026-10-28 Android 音乐墙展开边缘、预览动作对齐

- 修正：Wall 测量保留小数 CSS 宽高；先前 clientWidth/clientHeight 在 density 2.625 模拟器将 915.0476px 高度取整为 915px。预览卡片的展开/收起按钮新增明确右侧锚点，避免 expanded 通用 margin 清零后落入左侧按钮组；当前播放卡片继续保留右侧歌词切换/收起组。
- 通过：自有组件静态门禁；45 项共享测试；test-wall-version.sh 全部通过，新增真实 WallPlayer 八种当前/预览×展开/收起×普通/紧凑组合的右边界检查，以及横竖小数尺寸下四边差值 < .02 CSS px 检查。完整页面第一次运行在样式切换动画断言失败，复跑通过；未放宽断言。
- 实际 APK：已构建 .build/dist/MiniVoice-android-experience.apk；专用 Android 35 模拟器测量确认 WebView 与窗口均为 1080×2400，旋转后交换宽高；更新后卡片使用小数边界。竖屏截图 wall-fractional-portrait.png 已检查。
- 失败：portable 原先依赖音乐库初始样式，现显式初始化测试 workspace 后可加载测试库，但在“Shared play did not reach real service”断言终止；wall 专项在“Style switch lacks composited fragment motion or actual nonblank app snapshot”断言终止。因此本次不宣称 Android 完整原生回归通过。报告 .build/reports/android/wall-fractional-{portable,native-wall}.txt。
- 待验收：用户实体手机中红框整条底部区域是否消失；当前已确认的不足一个物理像素缝隙不能解释所有可能的导航区/合成差异，仍需同设备新版截图复核。真机横竖屏、系统导航方式和材质均未签收。

补充实包核对：更新 APK 的预览展开卡片控制行与收起按钮 right 均为 396.18454 CSS px，已查看 wall-fractional-preview-right.png；卡片底边与墙面同为 915.04761 CSS px。

## iOS 对齐 Android 体验版全面审计（2026-10-28）

本轮以体验版 PortablePlayerActivity 为唯一 Android 基准，未以正式版 MainActivity 功能作为对齐目标。完整结果见 `Docs/iOS-AndroidExperience-ParityAudit-2026-10-28.md`。

- 已定向复现：真实路径歌曲 ID 经封面 URL 只还原末段，无法命中授权库；缺失日期 DTO 导致添加/更新时间排序不生效。旧短 ID 夹具通过不覆盖这些问题。
- 已确认能力缺口：共享设置的缓存/检查/归并与诊断导出、高清原封面、部分歌词/格式发现、上一首/随机策略、系统音频/导航、扫描进度与后台恢复、默认主题和部分集合规则。
- 已确认包版本差异：当前 Android 体验版包比现有 iOS Debug 包多四项视觉规则与侧栏/弹窗退出几何更新。源码共用不代表两份旧包的资源一致。
- 既有用户定制保留：iOS 展开长条竖屏居中、圆形左下、iPad 无碰撞时设置按钮不移动；不列为应回退的偏差。
- 本轮静态门禁、45 项共享 JS 单测、iOS LRC/旧墙几何测试通过。未重跑双平台完整 UI/真机矩阵，不把尚未验证的横屏、键盘、触控或 GPU 效果写成通过；未修改产品运行逻辑。

## 2026-10-28 打包脚本层恢复（iOS 构建失败修复）

- 原因：`.gitignore` 的 `build/` 规则匹配任意层级同名目录，重构后的 `Scripts/build/` 整个目录被静默忽略、从未入库。Xcode 构建阶段 `Package shared mobile UI` 引用的 `Scripts/build/build-ios-ui.sh` 因此不存在，iOS 编译在脚本阶段即失败（`No such file or directory`）。Android `build.gradle` 与四个公开打包部署入口引用同一目录，同样失效。
- 修正：`build/` 改为 `/build/`，只忽略仓库根构建输出；按 `Scripts/README.md` 与 `Docs/PROJECT_STRUCTURE.md` 的目录职责恢复 `Scripts/build/` 的 15 个脚本，适配新目录层级与 `.build/{cache,work,reports,dist}` 布局（`.build/work/shared-ui`、`.build/work/android`、`.build/work/native`、`.build/cache/ios/DerivedData`）；新增 `Scripts/build/build-ios-ui.sh`（把共享 UI 打包进 App bundle 的 `SharedPlayer/`，并附带模拟器冒烟脚本）与 `Scripts/common/node-runtime.sh`（Xcode 构建阶段的最小 PATH 只解析到 `/usr/local/bin/node` v16，缺少 `node:util` 的 `styleText`，统一按仓库既有规则选择 Node 20/22/24 LTS）。
- 通过：`bash Scripts/build/build-ios.sh simulator Debug`（Debug 模拟器构建成功，产物含 `SharedPlayer/index.html`、assets 与 `shared-host-smoke.js`）；`bash Scripts/tests/test-ios.sh`；`node --test Shared/UI/test/*.test.mjs`（45 项）；`python3 Scripts/tests/test-package-workflows.py`；`python3 Scripts/tests/test-shared-ui-independent.py`（异目录、无 `MacOS/Desktop/node_modules` 的离线构建）；`bash Scripts/build/build-app.sh release`（Mac 正式包重建到 `.build/dist/MiniVoice.app`，`codesign --verify --deep --strict` 通过）。
- 未验证：Android 打包缺本机 Android SDK 与 `Android/signing-certificate.sha256`，脚本已运行到 SDK 发现步骤即按预期拒绝；`package-ios.sh` 的签名 IPA 导出仍缺开发团队与导出配置；iOS 专用模拟器的 WKWebView 集成冒烟本轮未运行。

## 2026-10-28 统一入口接入 iOS 打包

- 按用户明确要求维护iOS打包：移除旧“iOS体验宿主未接入”拦截。build/build-experience/deploy/deploy-experience均默认包含iOS，支持--platforms ios定向导出。iOS deploy仅产出IPA，不安装手机。
- 正式/体验均使用当前iOS共享宿主，不更换业务UI。正式bundle com.xcosmos.MiniVoice.ios，体验bundle com.xcosmos.MiniVoice.ios.experience；缓存和固定IPA名按通道隔离。通用团队/ExportOptions配置保留，体验可独立覆盖。先校验plist，再archive/export；失败明确返回非零，不把旧IPA当本次成功。此项取代此前体验宿主未接入的打包限制。
- 通过：四公开入口路由测试、模拟Xcode的iOS双通道archive/export/产物命名/身份/配置继承/缺签名失败/临时目录清理测试；bash语法及diff检查；实际 build-ios.sh device Release 无签名构建通过，报告 .build/reports/ios/package-device-build.log。模拟导出仅验证脚本，不代表Apple签名验收。
- 未完成真实签名导出：本机security find-identity报告0个可用签名身份，开发团队/ExportOptions未配置；公开体验入口正确失败，报告package-signing-check.log。没有生成或宣称生成可安装IPA，实体设备安装仍待有效证书及描述文件。


## 2026-10-29 iOS 全面补齐 Android 体验版主体能力

- 基准固定为 PortablePlayerActivity + Shared/UI，按用户明确授权开展 iOS 开发；保留竖屏长条居中、圆形左下、iPad 按实际碰撞避让和禁止悬停展开。
- 已实施：特殊路径封面身份、原图和缓存重建、日期/大小、LRC/YRC 发现、共享维护工具/诊断 ZIP 导出、五模式策略、音频打断/路由与状态观察、导航定位、扫描进度/增量/中断标记、默认系统主题、集合排序、当前元数据刷新、沉浸与横屏安全区。状态后台串行保存避免旧请求覆盖新状态。
- 通过：组件门禁、45 项共享 JS；iOS 解析/策略/路径/缓存/旧索引/ZIP；iPhone 88、iPad 89 项 WKWebView 桥接；两设备三样式×深浅×横竖的 XCUITest 点按/旋转与系统截图；iPhone 系统导出面板打开/取消；Debug 模拟器和无签名 device Release。两包实际共享 JS/CSS 指纹一致。最终状态串行保存后重新通过双设备桥接和 device Release。
- 测试修正记录：原 Button 查询不能匹配 WKWebView 的 aria-pressed Switch，以及系统取消 Other；修正实际辅助功能查询。app.screenshot 横屏附件裁切异常，改用 XCUIScreen 系统截图并重新跑矩阵，未把黑边旧截图作为通过证据。
- 尚未完整对齐：OGG/Vorbis 解码、崩溃捕获/完整诊断历史、长期后台扫描、大库主线程开销。待验：真实文件提供方/iCloud、电话/耳机/蓝牙/锁屏、软键盘/IME/VoiceOver/分屏、多指及取消手势、实体 GPU。不可宣称完整实机签收。
- 逐项实现与证据见 `Docs/iOS-AndroidExperience-Parity-Implementation-2026-10-29.md`，历史审计保留修复前结论。


## 2026-10-29 iOS 按标准继续补充：诊断、键盘与真实手势

- 已实施：MetricKit 系统报告接入、有界本地事件/错误/崩溃历史、跨启动读取、投递去重、路径/URI 清理和诊断 ZIP；替代上一阶段“崩溃捕获未接入”，但系统延迟报告不等同即时全量捕获。截图 JPEG 编码转后台。
- 已修复：真实 iPhone 创建歌单被键盘遮挡及文本框聚焦自动放大；Shared Modal 复用可视区域测量，保留原无键盘高度/平板间距和播放条位置。实际 Android 35 不缩小 visualViewport，补宿主 IME 与 WebView 实际交集，避免重复扣除。
- 通过：门禁、46 项共享 JS、iOS 诊断持久化/边界/清理/损坏/失败/ZIP；iPhone 89、iPad 90 项宿主；两设备各 4 个 XCUITest（含三样式×深浅×横竖、实际搜索/歌单软键盘、队列上拉下拉、系统导出/取消）；实际 Android 35 `UI_KEYBOARD_PASS`；test-wall-version 全部页面/Mac 回归。Debug 模拟器与无签名 device Release、Android 体验 APK 构建通过，共享 JS/CSS 指纹一致。
- 失败及修正：初始 iPhone 键盘遮挡断言、Android 关闭点按落到键盘均真实失败，已修复；iPad 导出自动化需滚动到弹窗真实可见矩形，修正测试可见性判断后通过。
- 待验收：MetricKit 真机投递、API 29 回退、浮动/分离/横屏键盘及完整 IME；OGG、长期后台扫描、大库性能和此前真机边界仍在。未执行完整 Android portable 历史用例，不扩大宣称。
- 完整实现、证据与已知限制见 `Docs/iOS-AndroidExperience-Followup-2026-10-29.md`。


## 2026-10-29 合并 origin/version2.8.1-repair

- 已合入 28c9948、dc7f0a9、38c6c02、c3a7903：修正 `.gitignore` 的 build 作用域、入库构建脚本、Node 兼容处理和共享资源根路径规范化。
- 冲突整合保留当前 iOS 体验/正式双通道、测试和 MetricKit 引用、Debug 冒烟打包及严格许可校验；保留双方验收记录。当前开发源码随整合提交，个人 Xcode 状态单独保留。
- 通过：Git index 干净导出 + 精简 PATH 离线共享 UI 构建；公开入口/iOS 打包模拟/独立 UI 构建测试；门禁、46 项 JS、iOS 基础与诊断/ZIP；Debug 模拟器与无签名 device Release；专用 iPhone/iPad 宿主；语法/diff 检查。
- 未执行真实 Apple 签名和手机部署、完整 Android/Mac 原生回归。日志 `.build/reports/merge-repair/`；详见 `Docs/MERGE_VERSION2_8_1_REPAIR_2026-10-29.md`。

## 2026-10-29 移动侧栏字体与可读性

- 按Android截图反馈调整共享mobile侧栏排版：导航16px/500、选中600、品牌21px/600、副标题12px/400、分组12px/500，取消合成字重与不必要字距。文字使用独立导航深浅配色，副标题和分组不降低透明度；选中项使用更明确的深绿/薄荷文字及底色。
- 侧栏采样保留，增加中性玻璃wash对真实封面明暗的缓冲，降低背景造成文字忽明忽暗；作用域为mobile侧栏，不改Mac及其他面板。共享mobile皮肤也适用于当前iOS宿主。
- 通过：107源文件静态门禁、Android体验APK构建签名、三样式×深浅设置/侧栏与滑块定向回归；人工查看neutral-wall-drawer-light/dark截图确认文本层次。报告android-drawer-typography-{build,ui}.log。没有进行实体设备字体栅格化与全封面动态对比度测量，真机观感待用户回验。


## 2026-10-29 iOS 本地音频、FLAC 封面、缩放与 Xcode 构建修复

- 只读核对用户设备索引：1037 首中 964 首 FLAC、73 首 MP3，已有封面缓存恰为 73 份；FLAC 原生 PICTURE/VORBIS 元数据未被原 commonMetadata 路径覆盖。未复制音乐文件或修改真机曲库。新增有界 FLAC 元数据解析，读取封面、标题、歌手、专辑、歌词与时长；缓存版本升级，重新扫描补建旧封面。
- 本地播放改用 AVAudioPlayer，协调文件读取并持续保留目录授权；支持同目录重新选择以更新失效书签；错误呈现包含实际域和代码。共享模块拒绝原因也改为可读文案。模拟器 MP3、FLAC 均真实解码、进入 playing 且时钟推进；这不等同用户所有真机文件已逐首验证。
- iOS 宿主限制整页缩放，音乐墙保留自身相机缩放。iPhone/iPad 均通过原生双指手势：简易/音乐库布局位置和宽度不变，音乐墙显示比例发生变化。
- Xcode 默认缓存目录原样复现失败：App Debug 同时编译 x86_64/arm64，但 Swift 包仅生成活动 arm64 模块，报 Unable to resolve module dependency: MiniVoiceShared。项目 Debug 设置 ONLY_ACTIVE_ARCH=YES 后，同目录、同目标、不附加架构或关闭签名参数构建成功；未删除缓存、未硬编码为 arm64，Release 保留原架构策略。
- 通过：静态门禁；iOS 单元/诊断/ZIP 与 FLAC STREAMINFO、VORBIS、PICTURE、截断边界；iPhone/iPad 宿主含真实 MP3/FLAC 播放及 FLAC 封面扫描；两设备原生双指测试；无签名 device Release；Xcode 默认 Debug 构建。日志 `.build/reports/ios/local-audio-fix/`，手势结果 `pinch-flac-final.xcresult`、`pinch-flac-ipad.xcresult`，宿主报告 `shared-ui/*/20261029T035*`。
- 待验收：用户在真机安装新版后重扫曲库并播放；真实文件提供方失效/重新授权、iCloud 下载、后台/耳机/锁屏与全部编码组合。没有安装覆盖真机 App，没有宣称 OGG 解码已接入。

## 2026-10-29 侧栏底色回调及播放栏文字

- 按用户反馈撤回上次新增的侧栏中性wash，选中行恢复原轻透明底色；保留导航字号、字重及文字颜色优化。此条替代上一节增强wash方案。
- 音乐墙mobile播放栏元信息：歌名14px/600、歌手12px/400、两行3px间隔、歌手不透明度.8，封面与文字10px间距；长文本省略并限制在弹性槽内，避免侵入传输按钮。深浅使用已有材质文字变量，不新增色块。
- 验证：静态门禁、Android体验包构建、三样式深浅侧栏面板及原音乐墙/实际Mac页面回归；实体手机字体和真实长标题观感待回验。报告android-drawer-dock-type-*.log。


## 2026-10-29 iOS 扫描内存超限闪退

- 原因已从 Xcode 保留的真机暂停调用栈确认：`EXC_RESOURCE (RESOURCE_TYPE_MEMORY: high watermark memory limit exceeded) (limit=3376 MB)`；扫描线程停在 `LibraryScanner.prepareArtwork → AVAsset.availableMetadataFormats`，系统线程在 CoreMedia 解析封面元数据的二进制属性列表。应用诊断连续记录扫描开始和进程重启，未完成扫描。未将此次问题误报为 EXC_BAD_ACCESS 或歌曲数量限制。
- 修复：FLAC 元数据每首只经有界原生块读取，不进入 AVFoundation common/全部格式元数据；每首 readSong 和按需封面重建使用 autoreleasepool；ImageIO 直接按 640px 降采样，避免先解码原尺寸以及 UIKit 默认屏幕倍率放大；压缩图输入上限 32MiB。原图仍保留。重复重扫等待前轮协作取消并释放后再启动，防止读取叠加。
- 定向压力验证：专用模拟器合成 964 FLAC + 73 MP3，共 1037 首，4096px 封面；实际 LibraryScanner 完整扫描与增量重扫均 1037 首，无错误，所有缩略图最长边不超过 640px。iPhone 进度点采样 RSS 从 384942080 到 461930496 字节，增长约 73.4MiB；这是采样结果，不宣称全时峰值或真机同等内存。宿主回归同时验证 MP3/FLAC 实际播放、封面缓存重建和目录原文件保留。
- 通过：静态门禁、iOS 单元/FLAC 元数据/诊断/ZIP；iPhone/iPad 宿主含压力验证、Debug 模拟器与无签名 device Release 构建。iPad 同样扫描 1037 首、增量重扫 1037 首，采样内存增长约 57.0MiB；证据 `.build/reports/ios/shared-ui/CA6853B6-D675-4B5C-BF93-E5A7002EC070/20261029T041900Z-62945/`。iPhone 证据 `.build/reports/ios/shared-ui/E4D86FE2-4A02-463B-BB0E-AF9961F67ABF/20261029T041707Z-61202/`。
- 待验收：用户安装新版后真实曲库扫描，后台/文件提供方边界仍未签收。没有安装或重扫用户真机曲库；旧真机崩溃现场保持暂停，没有执行继续/结束调试命令。

## 2026-10-29 侧栏选中底色与播放栏字体修正

- 用户截图仍显示突兀的侧栏选中亮底：现明确令选中行background透明、无背景图与阴影，仅保留文字及轻边框强调；不新增面板底色。
- 按用户明确更正，只调整音乐墙播放栏文字，撤回临时尝试的空间重分配；保留原84px展开播放栏和原按钮位置。歌名中等500字重，歌手400，歌手取消透明衰减、统一使用深浅材质文字色；不以布局变化解决字体显示问题。
- 通过：109源文件门禁、最终APK构建、320/390竖屏与844横屏定向检查原84px高度/歌名字重/歌手不透明/44px传输按钮/侧栏透明选中；共享模型测试及已有墙面Mac回归通过。报告android-dock-metadata-*.log。实体手机字体观感仍待回验。

## 2026-10-29 Android 状态栏背景模糊

- Android平台适配显式声明statusBarBlur；PortablePlayer添加aria-hidden、pointer-events:none的statusbar-backdrop，位于系统图标下方的应用内容上方。高度取宿主--mv-safe-top，blur18px及深浅渐变透明色；不重复增加安全区padding。iOS不启用此新增层，保留原宿主行为。
- 横屏及音乐墙全屏展开时隐藏，顶部安全区0时高度0，避免隐藏状态栏后多余模糊条。
- 通过：109源文件门禁、Android体验APK构建签名、Electron定向检查34px安全区高度/真实backdrop-filter/无触摸拦截/横屏与零安全区清理。报告android-statusbar-blur-{build,ui}.log，截图ui/android-statusbar-blur-portrait.png。模拟页面未包含系统状态图标，厂商WebView及实际系统图标合成效果待用户真机回验。


## 2026-10-29 移动扫描可见性、后台执行与横屏安全区

- iOS 移除简易/音乐库横屏强行对称化左右安全区的逻辑，按系统真实各边 inset 布局；音乐墙保持相同安全区来源。侧栏补语义区域名称，测试直接测量面板边缘，不用宽度不同的关闭按钮坐标代替面板边缘。
- Shared/UI 新增 ScanStatus（ActionButton 查看入口与同源详情）：三种移动样式、已有曲库重扫、发现文件、已知总数、暂停/完成均有明确状态。发现阶段不编造百分比；处理阶段显示数量与进度；结束卸载；暂停保留查看入口。iOS 桥接补 completed/total/execution，Android 体验宿主接通已有服务的 completed/total。
- Android 沿用 LibraryScanService 独立后台扫描、真实进度和通知点击 SHOW_SCAN；Android 12+ 设置 FGS_IMMEDIATE，修复系统延迟显示扫描通知；体验宿主在有来源及新授权来源时申请既有通知权限。
- iOS 26+ 对用户主动触发扫描注册并提交 BGContinuedProcessingTask，系统提供实时活动/支持设备上的灵动岛进度与取消；进度每0.5秒节流，发现阶段使用不定进度，完成关闭任务。提交被拒/旧系统保留有界 UIApplication 后台时间，系统到期暂停，原子保存每100首检查点并在取消时保存尾批，返回时复用元数据继续；不是无限后台。通知授权从设置明确发起，授权后可收到受限后台阶段的进度替换通知及结束通知，点击查看设置详情。自动恢复扫描不冒充用户新触发的持续任务。
- 通过：109 文件组件门禁、47 项共享 JS、iOS 单元/FLAC/诊断/ZIP；iPhone/iPad WKWebView 宿主回归，含1037首混合格式与4096px封面完整/增量扫描和真实 MP3/FLAC播放；Debug 模拟器和无签名 device Release。Android 体验 APK与测试 APK构建；专用 MiniVoiceRegression 上真实后台服务、已有库常驻指示、ongoing通知、切后台继续及点击通知详情均通过 `UI_SCAN_PROGRESS_PASS`。首轮通知缺失是真实的系统 FGS 延迟，已改即时策略后通过，没有放宽通知断言。
- 后台系统 UI 待验：模拟器真实返回“BGTaskScheduler is not available on this platform”，只通过了受限后台回退/返回查看，不宣称灵动岛或长期持续执行已在模拟器/真机验收。未部署用户手机；iOS17–25没有自定义 ActivityKit 小组件，不能宣称这些版本有灵动岛扫描展示。
- Duo 环境失败：初轮 XCUIDevice 旋转并未将折叠 Duo 展开，不能算展开横屏通过；补实际宽高断言后真实失败。手动展开的27.1专用Duo随后反复发生系统 PosterBoard `PRPosterDescriptor _initWithPath:` 断言(SIGTRAP)，崩溃 coalition 确认属于专用 DD2B3C31 模拟器，已关闭该设备止住重启循环；没有擦除模拟器数据或禁用崩溃提醒。Xcode 另有SDK/runtime build解析 invalidDigitCount，影响测试结果包收尾；保留失败日志，未伪造 xcresult 完成。展开Duo专用布局脚本保留用于系统恢复后验证。
- iPad宿主首轮受旧持久化样式影响在等待音乐墙阶段失败；测试改为通过真实侧栏/设置初始化目标样式后重新通过，未改产品默认样式。最终报告 `shared-ui/CA6853B6-D675-4B5C-BF93-E5A7002EC070/20261029T045028Z-82207/`，iPhone `shared-ui/E4D86FE2-4A02-463B-BB0E-AF9961F67ABF/20261029T044432Z-78645/`。本轮集中日志 `.build/reports/mobile-scan-progress/`。

- 补充通过：普通 iPhone 专用模拟器严格断言 App 宽大于高后，左右横屏×三样式直接测量“侧边栏面板”区域左边缘一致，原生测试 testLandscapeDrawerLeadingEdge 通过（phone-panel.log）；该通过不代替 Duo 展开屏验收。早先关闭按钮坐标相差20px源于样式面板宽度不同，测试已改测语义面板本体。

## 2026-10-29 两端旋转露白底修正

- 扫描确认iOS WKWebView原为透明/systemBackground、scrollView透明；Android只设置WebView色而未覆盖window/decor/content；HTML根文档无明确背景。这些层在旋转过渡/尺寸更新时可能露出白色底。
- iOS改为不透明WebView，并同步WebView/scrollView/underPage/window及根控制器背景至当前三样式/深浅色；SwiftUI补非白启动背板，布局和safe变化时更新宿主背景。Android同时设置window/decor/content/WebView底色；不禁止旋转或用固定截图遮挡。共享文档在useLayoutEffect同步--bg，根层背景匹配应用，支持100dvh动态高度。
- 通过：109源文件门禁；Android体验APK构建签名；iOS device Release无签名构建；Electron三样式×深浅×四尺寸方向变化逐帧断言根背景匹配、页面覆盖视口及无纯白底；已有墙面和实际Mac页面回归。报告rotation-backing-{android-build,ui,wall}.log、ios/rotation-backing-build.log。
- 边界：Electron窗口变化不等于系统旋转合成动画，当前没有启动的专用iOS模拟器；厂商GPU/WebView及iOS系统旋转录屏仍需真机回验，不能宣称所有旋转中间帧已实机消除露底。iOS签名IPA条件仍未满足。

## 2026-10-29 Android 状态栏模糊硬边修正

- 按真机截图反馈，撤回状态栏等高矩形滤镜的硬截断。滤镜移入伪元素，向下延伸最多24px，以多段mask渐变将模糊本身淡出；浅色/深色覆盖降低，不再绘制原灰色整条。安全区0时伪元素也为0；横屏/展开隐藏和不拦截触摸规则保留。
- 通过：111源文件门禁、Android体验包构建签名、定向检查34px安全区/58px羽化层/16px实际blur/mask/无触摸拦截/横屏及0安全区清理。日志android-statusbar-feather-{build,ui}.log。实体Android WebView下mask合成与最终观感待用户回验，不宣称与iOS系统材质完全相同。

## 2026-10-29 iOS 触控与播放性能修正、移动搜索遮挡

- 移动音乐库工具移除未开放的歌手归并表单；既有规则与桌面入口保留。移动内容禁止系统文本选择/长按呼出，输入框保留原生编辑；歌词后续行取消裁剪边界上的 blur 滤镜，保留透明度层级。
- iOS 文件协调、音频会话初始激活和 AVAudioPlayer 准备移至串行后台队列，连续切歌使用取消票据和代次校验；加载期间暂停、定位保留到最终目标。歌曲索引避免队列验证重复遍历整库。展开封面使用2048px上限显示缓存，原图读取保留；iOS纯平移复用墙面容器合成，缩放/聚焦沿用逐卡投影。
- 搜索输入使用临时同步草稿等待宿主保存，修复快速中文输入丢首字。移动搜索根据动画期间真实相交区域隐藏各工具栏动作并禁用其命中，空间足够时保留侧栏入口，关闭后恢复。iOS横屏顶部控制及侧栏上下留白按较大的垂直安全区平衡，原生左右安全区和满幅墙面不变。
- 已通过：共享47项 JS、iOS单元、墙面回归、iPhone/iPad WKWebView宿主播放（MP3/FLAC）和连续切歌/暂停/定位；独立Touch模拟器1037首扫描、4096原图到2048显示缓存及原图字节保留；原生长按无系统菜单与“山海”完整输入用例通过。device Release无签名构建通过。原生XCTest用例通过后Xcode runtime元数据解析导致收尾挂起，保留日志，不宣称完整xcresult生成。
- 验证边界：Electron容器平移验证只证明投影连续与封面保持，不代表真机FPS；用户截图歌词彩线具体GPU成因及真机连续播放/滑动体感仍需回验。无用户真实库写入或真机部署。


### 2026-10-29 iOS / Android 音乐墙入口移出与返回

- 本次用户明确包含 iOS、Android，按该范围修正共享音乐墙，未新增移动歌曲编辑功能。“编辑”位置沿用现有音乐墙设置入口。
- 已修正：侧栏向左、搜索向右、设置/播放栏向下退场；隐藏入口保留节点，立即 inert / aria-hidden，动画结束后不可见。插图缩回后延迟到卡片动画完成再返回；快速反向清理旧回调，减少动态效果直接到终态。
- 已修正：WallDock 不再以 enabled=false 清空 idle 状态。隐藏和返回期间暂停空闲倒计时，保留离开时的横条或圆形；返回后再继续正常空闲规则。iOS 居中皮肤保留自身位置变形并叠加退场 translate。设置避让读取底部锚定的静止几何，避免屏外旋转时误判。
- 通过：组件门禁；47 项共享测试；mobile-wall-chrome.txt 中两端皮肤×横竖屏×横条/圆形八组合通过中间帧、屏外停留、保持节点和形态、屏外旋转、延迟返回、快速反向、减少动态效果。八张 chrome-{android,ios}-{portrait,landscape}-{bar,circle}.png 已生成，已查看 iOS 横屏圆形返回截图。
- 实际宿主：iPhone WKWebView 最终 smoke 全部通过（mobile-wall-chrome-smoke-final.txt），包含四入口中间帧、隐藏超过3秒、两种形态返回。早期 iPhone / iPad smoke 曾在后续缓存检查失败，原始报告保留。Android 实包竖屏两种形态专项通过（mobile-wall-chrome-native-portrait.txt）；横屏固定100ms中间帧探针未捕获到运动，保留失败报告，不冒充原生横屏通过。
- 未通过：Android portable 仍在 Shared play did not reach real service 断言结束；完整页面脚本复跑曾在 Mac Dock did not start a new idle collapse 断言失败。均未修改或放宽断言。
- 构建：Android 体验 APK 与 iOS Debug 模拟器应用均已更新。实体 iPhone / Android 的手势、GPU 材质、系统导航和最终观感待用户验收；未宣称 iOS 真机签名包已交付。

## 2026-10-29 系统图标配色与横屏导航边

- Android此前用!dark设置LIGHT_STATUS_BAR，浅色音乐墙因此请求黑色图标；现在音乐墙按封面背景场景统一请求白色，音乐库/简易保持浅色深图标、深色白图标。兼容旧systemUiVisibility及API30+显式setSystemBarsAppearance，音乐墙羽化层使用轻暗渐变，不恢复硬边条。
- 横屏隐藏导航栏不再丢失原底边余量：读取忽略可见性的导航insets，保存竖屏导航底边；按实际90/270旋转映射到右/左，至少16dp。三样式共用，普通页面原有对称避让保留；封面墙仍可铺满，工具和聚焦区域沿安全变量避让。
- 通过：111源文件门禁、最终体验APK及instrumentation测试包构建。新增chrome定向模式覆盖三样式深浅原生系统图标配置和两方向导航安全边；此次安装执行前专用emulator-5554掉线，未跑成，不记原生通过。报告android-status-icons-navigation-build.log、android-chrome-test-build.log、android-native-chrome.log。实体设备系统通知图标及隐藏栏侧边需回验。

最终补充：iPad WKWebView 完整 smoke 同样通过，见 mobile-wall-chrome-ipad-final.txt；与 iPhone 最终报告一起覆盖两种设备的真实宿主桥与入口动画。

最终补充：test-wall-version.sh 最后完整复跑通过，见 mobile-wall-chrome-full.txt；保留上文前次 Mac idle 断言失败的事实。Android portable 的播放服务断言仍未通过。
- 补充通过：`test-mobile-search-overlap.cjs` 的iOS/Android宽横屏入口保留、窄工具栏真实重叠隐藏及关闭恢复；iOS 21px底部/0px顶部安全区下，顶部控制外边距35px，侧栏上下边距相等。这是合成安全区的渲染验证，实体设备最终观感待回验。最终iOS Release再次构建通过。
- 最终共享墙面回归、47项JS、Android体验APK构建通过；日志 `/tmp/mv-touch-wall-layout.log`、`/tmp/mv-touch-js-layout.log`、`/tmp/mv-touch-android-layout.log`。本轮没有声称Android实体触摸或iOS GPU实机验收。


### 2026-10-29 侧栏打开后背景组件轮廓丢失

- 根因：共享 player.css 的两条 is-drawer-behind 后代规则将背景组件的填充、描边、阴影和模糊清空，iOS / Android 共用因此同时出现。按本次用户要求移除这两条规则；仍保留后景后退、遮罩和输入隔离。
- 通过：16种两端皮肤×简易/音乐库×深浅×横竖的开关侧栏材质逐项一致检查（drawer-surface-preservation.txt）；原 surface 测试、完整音乐墙/桌面页面回归（drawer-wall-surfaces.txt、drawer-surface-wall-full.txt）；47项共享单测与组件门禁。已查看 drawer-surface-android-simple.png，截图右侧搜索圆形、歌词板块、播放栏轮廓保留。
- 实际 iOS WKWebView：simple / library 的侧栏前后材质与轮廓一致、后景 inert 检查通过；完整 smoke 随后在“缓存清理结果回读”断言失败（drawer-surface-smoke.txt），不宣称整套通过。
- Android：已构建体验 APK 和测试 APK；portable 运行出现 Process crashed，日志为仍未通过的完整原生回归（drawer-surface-portable.txt）。本次界面属性专项已通过，但不宣称完整 Android 原生回归通过。
- 产物：.build/dist/MiniVoice-android-experience.apk 与 iOS Debug 模拟器应用已更新；两端实体设备 GPU / 玻璃采样及最终观感待验收。本条取代旧“侧栏后景无框”记录中的视觉要求。

## 2026-10-29 iOS录屏横线与滑动专项

- 录屏可见两条跨全屏细线和快速滑动封面空底；完成抽帧和代码路径排查，详细记录见 `Docs/IOS_RENDERING_INVESTIGATION.md`。未把录屏60fps标记当成应用FPS。
- iOS采用单页面实时opacity样式过渡，移除生产切换链路中的WK截图/编码/分片；墙面提前挂载360px，修正100px提前范围小于140px换窗口阈值；稳定封面节点与投影，iOS增加可回收的32MiB成本预算图片缓存及版本化响应缓存。
- 通过：111文件组件门禁、47项共享逻辑、共享墙面/实际Mac页面回归、iOS定向渲染检查（连续切换/旋转/减弱动态、零capture、轮询零海报style写入、18次正反平移可见节点覆盖）、容器平移与解码连续性；iOS模拟器Debug与device Release无签名构建、Android体验APK构建。
- 真机待验：横线消失与长时间滑动体感/系统GPU压力。没有用户设备上的Instruments采样，不能宣称横线根因已被系统级证明或帧率达到固定数值。
- 真实WKWebView完整回归通过：`ios/shared-ui/A1A82D8E-910C-4068-8FC1-1D8D5F21A010/20261029T091341Z-21611/`，含三样式零截图、往返滑动封面、缓存清理/重建、1037首完整/增量扫描、MP3/FLAC时钟和连续切歌。保留两次初轮失败日志：前置新增探测超过播放栏闲置时限；缓存清点时新目录封面仍在生成。分别显式初始化展开态、等待新目录全部显示资源完成后重跑通过，没有放宽原断言。

## 2026-10-29 保留碎片动画与iOS原生墙面滑动

- 根据用户明确反馈撤回上一轮live淡入淡出策略，恢复碎片卷曲/散开效果。iOS使用共享17点运动采样和原480ms+径向延迟，通过原生UIView区域快照/Core Animation合成；没有WK整屏takeSnapshot、JPEG/base64和JS图片解码链路。取消/旋转/减弱动态/超时按token清理。
- iOS一指平移/惯性由WebKit原生双轴overflow滚动承载；仅同步相机与更新有限窗口，空坐标空间靠边重定位保留无限墙；避免重写相同scroll偏移打断惯性。双指开始才安装阻塞move监听，保留锚点缩放及整页scale=1。封面touch-action原先阻断原生滚动，已修正；展开/弹窗禁止背景滚动，滚动背板避免整片海报强制大纹理。
- 通过：112文件门禁、47项JS、共享墙面/Mac实际页面回归；可信touch输入的一指滚动、双指墙缩放、19次往返/边界重定位与完整可见ID；真实WK三次native prepare/animate、滚动相机和全部宿主回归（最终报告 `ios/shared-ui/A1A82D8E-910C-4068-8FC1-1D8D5F21A010/20261029T094538Z-38222/`）；iOS Debug/device Release无签名与Android体验构建。
- 原生XCTest实际系统手指拖动及三次品牌按钮切换通过，两轮23秒用例且完整xcresult生成；录制专用模拟器并抽帧确认碎片中间态存在、结束不残留。初轮测试错误地按Button查找具有Switch语义的自有选择项，查找失败后修正定位重跑，没有绕过产品交互。
- 待真机：用户设备GPU帧率/长期快速滑动体感、横线在原系统上的复验。模拟器录屏不能证明真机达到特定FPS或已等同Android流畅度。详见 IOS_RENDERING_INVESTIGATION.md 后续纠正段。

## 2026-10-29 iOS聚焦、双击播放、侧栏卡顿专项

- 用户确认原生滑动改善，继续优化其余三个交互。iOS聚焦改为固定盒子预采样合成动画，图片与文本反向缩放保持比例，高清图延后交接；动画中断/续接、最终正方形和原生相机保存保留。侧栏改为保留表面的整体深度变换，不逐帧改写海报宽高。碎片样式切换保持。
- 修复播放recent变化引发无关音乐库重排，复用中文数字排序器并跳过空查询全文处理。相同1037首合成ID顺序不变，48项JS通过。
- 通过：113源文件门禁、完整共享墙面/Mac实际页面回归、聚焦比例/双击播放/侧栏中断续接定向检查；本机相同采样段尺寸写入1036→0（聚焦）、2142→0（侧栏），本机Node排序18.28–21.02ms→0.84–1.08ms。全部是合成负载的开销记录，不能当作真机FPS。
- 专用iPhone真实XCTest系统手指拖动、单击、双击播放、侧栏两次往返与三样式切换通过30.10秒，完整xcresult已生成；最终WK宿主报告 `ios/shared-ui/A1A82D8E-910C-4068-8FC1-1D8D5F21A010/20261029T101251Z-50966/` 通过，含扫描/缓存与音频原回归。iOS Debug/device Release无签名、Android体验构建通过。
- 实机待验：这三个动作的连续操作体感、GPU压力和低内存场景；没有安装/写入用户实体设备或真实音乐库。

## 2026-10-29 iOS 音乐墙连续性修复（流畅/稳定优先）

- 已实现：聚焦图片状态按歌曲身份隔离，快速换卡不携带上一首已解码图片；同曲高清接管保留旧层，移除额外520ms图片缩放。原封面底层、ActionButton和共享聚焦行为保留。
- 已实现：iOS同版本同质量资源请求合并，独立消费者停止不取消共享任务，任务票据防止旧失败清除新任务；缓存命中仍不等于WebKit纹理常驻。原生scroll相机同步合并到每帧一次，卸载清理挂起帧。
- 通过：113源文件组件门禁、48项共享单测、iOS模拟器Debug构建；增强后的焦点专项（跨歌曲图片隔离、无升级二次缩放、图片比例、双击播放、侧栏打断恢复、动画清理），报告 `.build/reports/ios/focus-motion/optimized.json`。专项聚焦/侧栏采样段卡片宽高写入均为0，不代表真机FPS。
- 完整页面回归初轮失败于聚焦渐入时序断言，第二轮失败于Mac碎片过渡时序断言；原断言未放宽，保留 `/tmp/mv-ios-wall-stability.log`、`/tmp/mv-ios-wall-stability-rerun.log`；最终回归结果另记下方。
- 失败/待排查：真实WK完整宿主首轮失败“WK 四个入口完全退场 false”，复跑失败“WK 原生双轴滚动承载墙面”；日志 `/tmp/mv-ios-wk-stability.log`、`/tmp/mv-ios-wk-stability-rerun.log`。不能宣称完整iOS集成通过。
- 未接入：全局图片并发预算、方向预取及解码工作集；本轮仅在途请求合并，未宣称完整资源调度已完成。待验收：实体设备长时间滑动、低内存、GPU闪烁，以及三样式深浅主题完整真机矩阵。没有操作用户真实音乐库或实体设备。
- 最终完整页面回归：手机墙面、旋转/恢复、共享弹窗及多项Mac检查通过，但最终在Mac播放栏打断后展开布局断言失败；完整回归仍标失败，日志 `/tmp/mv-ios-wall-stability-final.log`。未修改Mac播放栏实现或放宽断言。

## 2026-10-29 录屏反馈：iOS墙面封面驻留与缩略图分级

- 用户实机反馈上一批无体感改善，保留此事实；录屏抽帧可见多处标题仍在而封面暂空。此证据不能单独区分读取、解码和GPU纹理回收。
- 已实现：普通iOS小卡片（最长边≤220 CSS px）使用独立版本化256px资源，大卡片保留640px，聚焦高清独立；缩放换资源先解码后更新同一img。分组透传资源身份。保留近期离屏卡片，160实例目标软上限；可见必需集合不驱逐，歌曲身份变更清理。24MiB解码预热池、最多4个预解码任务，丢弃过时未启动预热，卸载释放。离屏保留实例不参加聚焦动画。
- 边界：这是DOM实例驻留与浏览器Image强引用，不是原生Bitmap/GPU纹理锁定，也不是全局img网络并发限制；未将聚焦播放器完全移入原卡片，仍保留共享聚焦覆盖层。Android/Mac未切换到新的iOS驻留策略。
- 通过：114源文件门禁、50项共享测试（新增工作集上限/必需集合、排队过期/解码预算/卸载）、20次往返滚动专项（可见图片解码、重叠实例不重建、保留窗口有界、返回节点仍连接）、增强焦点专项、完整共享墙面/实际Mac页面回归；模拟器Debug及device Release无签名构建。日志 `/tmp/mv-wall-residency-unit.log`、`/tmp/mv-wall-residency-probe-final.log`、`/tmp/mv-wall-residency-focus-final.log`、`/tmp/mv-wall-residency-pages-final.log`、`/tmp/mv-wall-residency-build-final.log`、`/tmp/mv-wall-residency-device.log`。
- WK测试前置修正：隔离模拟器重新安装后合成歌曲ID中的容器路径变化，旧展开焦点不再有效；测试通过实际点选和收起恢复可滚动前置状态，再等待侧栏真实退场，不放宽滚动断言。小样本墙卡片可能全大于220px，缩略图验证直接解码宿主提供的wall资源，单独断言像素上限。最终宿主结果另记。
- 待验收：用户设备相同手势录屏复验、持续快速滚动和低内存、三样式深浅实体GPU表现；没有真实设备FPS/内存峰值数据，不宣称已达到Android流畅度。测试只使用专用模拟器与合成音乐库。

### Mac 扫描缺失封面恢复（2026-10-29）
- 已修改：显式扫描不再复用无封面键、缩略图丢失或损坏的旧条目，重新读取源音频并保存封面。保留正常封面的增量扫描。
- 待验收：合成音频扫描、重启回读及三种样式深浅主题实际显示；未操作用户真实音乐库。
- 最终真实WK完整宿主回归通过：`.build/reports/ios/shared-ui/E5B44004-715E-4830-AD53-09130017798A/20261029T130855Z-19967/`；包含独立wall资源真实解码及≤256px预算、原生滚动、样式切换、聚焦/播放和扫描/缓存/音频原回归。前置失败日志仍保留，不将此前失败改写为通过。

## 2026-10-29 用户要求撤回本轮iOS流畅度优化

- 用户再次反馈仍不好用，优先恢复此前定位、点击切换正常的基线。将本次对话修改的墙面/滚动/图片宿主/资源处理/配套测试与组件说明恢复到 `3007679`（本次对话开始前HEAD）；移除本轮新增驻留池及专项文件，未回退其他工作区改动，未清除音乐库或偏好数据。
- 上述“iOS音乐墙连续性修复”“录屏反馈：iOS墙面封面驻留与缩略图分级”实现均已撤回。原自动化通过只代表当时测试结果，用户实机效果不通过，不再作为有效交付方案。
- 撤回前文件备份：`.build/rollback-backups/20261029-211242/`。后续以功能正确为基线，先复现定位/点击和加载问题、再单点验证，不在此轮继续添加性能策略。
- 已通过：113源文件组件门禁、48项共享单测。构建及页面回归结果另记下方；实体设备体感仍待用户回验，不宣称回退消除了既有卡顿。
- 部署验证：Mac release 构建成功，体验版已替换至 `/Applications/MiniVoice-debug.app` 并启动，`codesign --verify --deep --strict` 通过。缺失封面实际扫描显示仍待验收。
- 回退验证补充通过：iOS模拟器Debug与device Release无签名构建、聚焦/图片比例/双击播放/侧栏打断恢复专项；日志 `/tmp/mv-ios-rollback-build.log`、`/tmp/mv-ios-rollback-release.log`、`/tmp/mv-ios-rollback-focus.log`。已确认相关源文件与基线一致；未安装到用户实体设备。
- 完整共享墙面/实际Mac页面回归通过：`/tmp/mv-ios-rollback-pages.log`，原断言未放宽。此前实机卡顿保留待排查，不把回退视为性能修复。

### Mac 缺失歌词联网下载（2026-10-29）
- 已接入：歌曲编辑歌词页在草稿无歌词时提供联网下载，复用多源搜索，按歌名、歌手、专辑、时长排序，可靠匹配中优先原生逐字；写入现有 `lrc/<歌曲文件名>.lrc` 目录规则。
- 防覆盖：下载前及保存前检查现有歌词；无可靠匹配显示错误并引导候选预览。
- 已通过：组件静态门禁；桌面测试 64 通过、4 跳过。
- 待验收：Swift 构建、网络真实来源、保存回读与重启、三样式深浅及键盘交互。尚未替换安装包。

## 2026-10-29 回退目标纠正：原生滑动引入前

- 用户明确指出上一轮3007679仍太晚；实际目标为 `151c549`，即 `a8300b8`“原生墙面滑动”提交之前。
- 已将这两次提交涉及的源代码、Xcode项目接入及配套测试恢复到151c549：撤回WebKit overflow原生平移、原生碎片会话和其后的聚焦合成优化；恢复原共享手势/惯性相机及当时样式切换策略。删除当时尚未存在的useNativeWallPan、wallReflowMotion及对应新增测试/宿主文件。
- 保留Mac编辑/歌词等不相关工作区改动、用户Xcode配置和音乐库数据；组件说明仅恢复相关基线，保留其他新增说明。旧验收记录留作历史，不代表撤回后仍启用原生滑动。撤回前备份 `.build/rollback-backups/20261029-211626/`。
- 已通过111源文件组件门禁；构建/行为回归另记。不在本轮继续实施性能优化，也不宣称消除旧版卡顿。
- 回退后通过：47项共享单测、iOS模拟器Debug和device Release无签名构建；核对iOS源文件/项目接入/测试与151c549一致。日志 `/tmp/mv-pre-native-unit.log`、`/tmp/mv-pre-native-build.log`、`/tmp/mv-pre-native-release.log`。实体设备未安装，既有卡顿仍待后续分析。
- 完整共享墙面/实际Mac页面回归通过：`/tmp/mv-pre-native-pages.log`；覆盖点击、聚焦、展开收起、旋转及恢复。未以模拟器/浏览器结果替代用户实机验收。

## 2026-10-29 以151c549功能基线定向优化共享相机平移

- 用户确认151c549完成度高，仅继续处理滑动；本轮保留该版手势/惯性、定位、点击切换、聚焦及图片链路，不重新引入原生overflow、驻留池或缩略图分级。
- 测量：1037首合成库同样16次短程往返，原版已有海报style写入233次，独立稳定局部投影原点后为0次；React提交均13次。原始报告 `.build/reports/ios/pan-work/baseline.json`、`optimized.json`，原Wall备份 `.build/reports/ios/pan-baseline/Wall.jsx`。这是主线程重复写入计数，不是帧率或真机改善结论。
- 已实现：可见窗口仍140px更新，绘制原点在1024px有界范围内独立稳定，缩放改变重置；只跳过未改变的transform写入。没有改事件判定/速度/持久化、没有改播放器/图片资源。大距离重定位同一paint完成。
- 通过：111源文件门禁、47项共享单测、16次短程和32次跨原点往返的可见覆盖及<1px投影误差、完整共享墙面/实际Mac页面回归、iOS模拟器Debug与device Release无签名构建。日志 `/tmp/mv-stable-pan-unit.log`、`/tmp/mv-optimized-pan-work.log`、`/tmp/mv-stable-pan-pages.log`、`/tmp/mv-stable-pan-build.log`、`/tmp/mv-stable-pan-release.log`。WK宿主结果另记。
- 真机待验收：持续滑动的体感、纹理压力、快速缩放/点击/定位连续操作；不能宣称已彻底消除卡顿。此前两轮方案仍保持撤回。测试前仅备份并清理专用模拟器的合成工作区页面状态，没有清理用户库。
- 最终真实WK宿主完整回归通过：`.build/reports/ios/shared-ui/E5B44004-715E-4830-AD53-09130017798A/20261029T132738Z-29240/`，含32次共享相机平移/原点交接像素检查及原有播放、扫描、缓存、状态回读检查。实体GPU流畅度仍单独待验收。

### Mac 自动补全缺失歌词（2026-10-29）
- 纠正：此前仅有手动下载，未实现自动触发。现接入启动载入/扫描完成后的串行后台补全，读取源文件确认无歌词后才搜索，歌名歌手及十秒内时长匹配中优先逐字，专辑参与排序；保存到 lrc 目录并更新库缓存。
- 防覆盖：请求结束后重新读取源文件/本地歌词，取消或歌曲已移除则跳过；重新扫描取消旧任务。不改写音乐文件。
- 待验收：真实网络匹配质量、已有歌词零请求、保存回读及重启；不能将构建通过视为这些体验已验收。
- 已通过：组件门禁、桌面测试64通过/4跳过、release构建及签名校验；已部署并重启体验版。真实网络完整补全结果仍待验收，不宣称所有缺词歌曲均成功。

### Mac 歌词触发时机纠正（2026-10-29）
- 用户明确要求播放时按需加载：移除启动/扫描批量补全调用，改为音频成功开始播放后只检查当前歌曲；已有歌词不联网。切歌/停止取消请求，落盘前再次确认当前歌曲及现有歌词。
- 下载后更新当前歌曲详情以直接显示，不通过暂停/重启播放器刷新。仍保存到 lrc 目录。
- 待验收：真实歌曲网络匹配及加载显示、快速切歌取消、离线失败、再次播放本地回读。此前扫描批量补全方案已撤回。
- 已通过组件门禁、桌面测试64通过/4跳过、release构建与签名校验；体验版替换并启动。真实播放网络显示仍待验收。

## 2026-10-29 保留当前完成度的滑动调研

- 用户仍反馈一卡卡，撤回“现在应优先换原生画布”的过早判断；当前没有真机性能时间轴证据证明必须重写。运行代码本轮未改。
- 已完成代码与WebKit官方资料核对：帧调度、450ms顶层状态/歌词更新、snapshot结构数据、挂载与背景玻璃合成均列为需验证路径。设备已确认iPhone16ProMax，iOS版本/电源状态未确认。
- 调研与单因素验证顺序见 `Docs/IOS_PAN_RESEARCH_2026-10-29.md`；没有将刷新率讨论当实机结论，没有新增FPS或性能通过声明。先前233→0计数不等于流畅验收通过。仅文档修改，未重复构建。

### Mac 下载歌词后封面引用丢失紧急修复（2026-10-29）
- 根因：自动下载发布 loadTrack 的详情对象时没有封面缓存 key，覆盖了更新缓存后的有效详情，界面因此丢封面。现发布前同步缓存更新后的 artworkKey/lyricsKey。
- 同时调整歌曲编辑导航：插图置首，沿用每次打开/换歌默认 artwork。
- 已通过：组件门禁、release构建及签名校验；已替换并重启体验版。网络下载后真实界面与主题仍待验收。

### Mac 在线歌词加载占位（2026-10-29）
- 播放触发检查时设置当前歌曲 loading 状态，复用歌词区 spinner/“正在加载歌词…”并隐藏添加入口；请求结束清除状态，空结果显示暂无歌词，异常显示加载失败。
- 请求 token 防止旧请求完成清除新歌曲加载状态；停止清理状态。
- 待验收：三样式深浅主题真实慢网络、空结果、失败及快速切歌。
- 已通过组件门禁、桌面64测试（4跳过）、release构建及签名；已部署重启。真实慢网络与界面验收仍待完成。

## 2026-10-29 同帧相机与音乐墙播放更新隔离

- 继续151c549功能基线，不恢复原生滑动/驻留池/缩略图。相机动画帧内完成计算与绘制，保留原运动曲线与取消句柄；Wall memo配合稳定最新事件，播放内容通过Context独立更新。墙样式停用未被当前播放器使用的旧lyrics.sweep桥请求，其他样式保持。
- 通过：111源文件门禁、47项共享单测、短/长程往返投影检查；定向时钟推进不执行Wall主体、聚焦时间更新、选择回调以及同帧惯性专项。日志 `/tmp/mv-pan-clock-unit.log`、`/tmp/mv-pan-clock-geometry.log`、`/tmp/mv-pan-clock-probe.log`；iOS Debug和device Release无签名构建通过。
- 完整页面回归手机墙面/恢复与实际Mac墙面通过，最终Mac歌词编辑断言缺少 `.mv-lyrics-timing>.mv-disclosure-trigger` 失败（`/tmp/mv-pan-clock-pages.log`）；该区域有其他并行工作区修改，本轮未调整其实现或放宽断言，整套仍记录失败。
- WK完整宿主回归结果另记。用户iPhone16ProMax实体帧间隔/GPU与体感待验收，未声称彻底解决或达到固定FPS。材质与图片链路未改。

### 移除手动缺失歌词下载按钮（2026-10-29）
- 按用户要求移除编辑页“联网下载缺失歌词”按钮，保留在线搜索预览与播放时自动加载。
- 组件门禁及桌面测试64通过、4跳过；实际编辑页三样式深浅主题待验收。
- 真实WK首轮在“WK四个入口有分向移出中间帧 true”失败，原断言未改，清理专用合成页面状态后复跑完整通过：`.build/reports/ios/shared-ui/E5B44004-715E-4830-AD53-09130017798A/20261029T135107Z-38108/`（`/tmp/mv-pan-clock-wk-rerun.log`）。保留首轮失败 `/tmp/mv-pan-clock-wk.log`，不据复跑否认动画时序风险。
- 完整页面复跑仍在Mac歌词编辑相同断言失败（`/tmp/mv-pan-clock-pages-rerun.log`）；Android体验构建未完成：SDK缺少可用Platform35/Build Tools组合（`/tmp/mv-pan-clock-android.log`），没有屏蔽检查或宣称Android本轮构建通过。

### 时间轴完成后编辑页回读（2026-10-29）
- 后台任务状态增加 trackID，编辑页按歌曲识别成功结束的任务；无未保存改动时重新读取已保存歌词并同步草稿基线，避免继续显示旧文本或再次保存覆盖新时间轴。
- 草稿有修改、切歌或卸载时不应用异步旧结果。
- 已通过组件门禁；真实模型匹配完成、磁盘回读及三样式深浅交互待验收。
- 桌面测试64通过/4跳过，release构建及签名校验通过；体验版已替换重启。真实模型端到端验收未完成。

## 2026-10-29 撤回同帧绘制与时钟隔离优化

- 用户反馈依旧无效并明确要求撤回本次优化。已撤回animateFrame同帧调度、Wall memo/Context与稳定事件、墙样式停用旧lyrics.sweep；恢复本轮之前的绘制/播放器更新路径。
- 上一轮稳定绘制原点优化保留；原生滑动/驻留池仍未恢复。其他Mac及文档工作区改动保留。移除本轮专用时钟/Fiber探针测试，保留原平移几何专项。
- 本轮实现不再启用；之前测试通过只代表其自动化证据，用户实机效果不通过。撤回备份 `.build/rollback-backups/20261029-221029/`。组件说明同步移除已撤回契约，其他编辑/歌词说明保留。
- 已通过111源文件组件门禁与47项共享单测；构建与页面结果另记。未操作用户设备或音乐库数据。
- 撤回后iOS模拟器Debug与device Release无签名构建通过：`/tmp/mv-undo-clock-build.log`、`/tmp/mv-undo-clock-release.log`；确认PortablePlayer恢复至151c549，Wall仅保留此前稳定局部原点改动，不含本次Context/memo/同帧调度。
- 完整页面回归手机墙面与Mac墙面通过，仍在Mac歌词编辑缺少 `.mv-lyrics-timing>.mv-disclosure-trigger` 处失败（`/tmp/mv-undo-clock-pages.log`）；不改该区域，不宣称完整页面套件通过。

### Mac 歌手编辑对齐正式版（2026-10-29）
- 对比 MetadataEditor 正式版源码，体验版原先仅单文本框；恢复每位歌手独立输入、添加/移除，至少保留一行，保存时 trim 并过滤空行，以 ` / ` 合并。
- 禁用/忙碌及不支持标签写入格式沿用编辑页规则，按钮复用 ActionButton。
- 已通过组件门禁、桌面64测试（4跳过）；真实多歌手保存回读、键盘及三样式深浅待验收。

### Mac 编辑功能迁移差异复核（2026-10-29）
- 源码确认缺口：文件名识别、移除封面、标签与LRC同时保存、在线歌词简体开关、SRT导入入口；歌手/专辑顺序不同。
- 详见 Docs/MAC_EDITOR_PARITY_AUDIT_2026-10-29.md。此次为只读源码审计与文档登记，未宣称全应用对齐或实机验证通过。

### Mac 编辑四项迁移补齐（2026-10-29）
- 已接入：文件名识别歌名/多歌手；显式removeArtwork保存标记及恢复原图；在线歌词简体预览/应用共用同一文本；SRT选择与时间标签转换。
- 已通过组件门禁、桌面64测试（4跳过）；真实合成文件写入/封面移除恢复、SRT编码、多歌手回读及三样式深浅待验收。不在真实音乐库执行写入测试。

### 2026-10-30 iOS/Android 音乐墙检查（定向修复，待实机验收）

- 已修复：共享 Wall 普通滑动挂载预留 100px 小于相机 140px 刷新阈值；统一滑动、聚焦和打断保留集合为 360px，保持 iOS 局部合成路径。
- 自动验证：共享逻辑 47/47 通过。音乐墙真实 DOM 回归执行情况见 `.build/reports/ui` 及本次交付说明。
- 待验收：iOS WKWebView 真机连续滑动、点击变方形、快速切换与定位、中途打断、横竖屏及深浅主题的帧耗时；Android 增加预留后的内存开销。Mac 独立实现仅代码比对，未宣称三端性能一致。本轮不是完整重构或全面验收完成。
- 本轮页面回归：千首曲库、40 步拖动、聚焦打断、移动展开/旋转/恢复和 Mac 实际墙面聚焦展开用例通过；完整脚本退出失败，停在歌词时间编辑器缺少 `.mv-lyrics-timing>.mv-disclosure-trigger`（test-wall-version.cjs:165），未将整套回归记为通过。


### 2026-10-30 再次处理侧栏后景暗边

保留普通移动后景填充与描边，停用所有后景按钮/面板的嵌套 backdrop-filter 与 box-shadow；后景缩放时解除场景 overflow 裁切与 isolation，前景抽屉保留自身材质。关闭后恢复原皮肤。组件门禁与共享单测通过，Android体验包已构建；专项日志 drawer-edge-repair.txt，iOS构建日志 drawer-edge-repair-build.txt。实体设备暗边和旋转合成尚待复核，不宣称彻底解决。

## 2026-10-30 恢复回滚的 iOS 碎片切换

- 当前适配器已回退到live淡入淡出、StyleFragmentSession缺失。按用户要求从a8300b8恢复共享fragmentSamples、host-fragments prepare/animate/cancel桥、原生UIView碎片与Core Animation，以及Xcode源文件注册。仅恢复切换链路，保留当前Wall及材质的未提交改动。
- 通过：111源文件门禁、47项共享JS、iOS Debug构建；真实WK中三次品牌切换全部调用原生碎片prepare/animate，日志 `/tmp/mv-restore-fragments-host.log`。
- 完整回归未全通过：WK后续在simple侧栏背景材质断言失败；共享墙面脚本后续找不到`.mv-lyrics-timing>.mv-disclosure-trigger`。未放宽或跳过失败，不把这些结果写成全套通过；当前其他材质/编辑器改动保留。切换在用户实体设备上的视觉与流畅度仍需回验。
- 补充：iOS device Release无签名构建通过，日志 `/tmp/mv-restore-fragments-release.log`。

## 2026-10-30 iOS 歌词滚动彩线兼容修正

- 当前源码中此前lyricEffects兼容配置不存在，普通歌词仍有filter blur过渡。现按实际data-host=iOS直接限定，移除滚动歌词行的filter及filter transition，保留透明度层次、逐字高亮、定位与键盘焦点；非focus-visible不画轮廓。
- 静态门禁及iOS Debug模拟器构建通过。彩线根因未在真机复现，当前是针对滚动滤镜合成路径的兼容修正，不宣称已确定系统缺陷或实机完全修复。原生集成报告见ios/lyric-line-repair-integration.log，最终状态以报告为准。

- 本次WKWebView完整集成未通过，失败项为“WK simple 侧栏打开保留背景组件材质与轮廓”；未修改该断言，不记整体验收通过。歌词彩线仍需用户设备复测。

### 2026-10-30 iOS 独立原生音乐墙（用户授权，定向验收）

- 已接入：默认 iOS 宿主启用 NativeMusicWall，UIKit 负责墙面拖动/惯性/缩放、可见封面复用、后台解码、独立正方形聚焦及定位；Shared/UI 保留播放/歌词/设置/歌单业务。Android/Mac 默认渲染入口不变，旧 HomeView 未启用。
- 已通过：自有组件静态门禁；iOS 模拟器 Debug 构建；iOS 纯逻辑脚本；共享逻辑 47/47；墙面定向宿主测试（32 步往返平移、聚焦打断、展开收起、比例保存及 1037 项渲染夹具 40 步有界复用/解码）。1037 项夹具复用合成封面，不代表 1037 个真实音乐文件及独立原图已验收。
- 已通过：专用模拟器 XCUITest，断言聚焦图片上的真实拖动使卡片位置变化、双指使相机比例变化，覆盖共享控制点击、展开收起、重启恢复聚焦和横屏入口。报告 `.build/reports/ios/native-wall-touch-routing.xcresult`。
- 未通过：完整宿主脚本停在 `WK simple 侧栏打开保留背景组件材质与轮廓`，未跳过或放宽该断言。XCUITest 中仍记录 SwiftUI 发布状态时机警告，来源未定位。
- 待验收：真机 GPU 帧耗时、快速反向连续操作、低内存、VoiceOver、iPad、深浅主题完整矩阵、长时间后台及真实大库。原生卡片暂不做邻居回流，滚动时隐藏文字/歌词且停下再对齐；原生侧栏背景缩小与原图升级未实现。详见 `Docs/iOS-NativeMusicWall-2026-10-30.md`。
- 最终复核：iOS Simulator / iPhoneOS Debug 目标均编译通过（关闭签名；不代表已安装真机）。底层封面保留后的系统手势复测报告为 `.build/reports/ios/native-wall-delivery.xcresult`；最终墙面定向宿主报告为 `.build/reports/ios/shared-ui/A1A82D8E-910C-4068-8FC1-1D8D5F21A010/20261030T034424Z-6078/report.json`，ok=true。

- 用户回验（2026-10-30）：反馈歌词滚动蓝线似已消失，记录为用户初步确认；未扩大为全部设备或完整集成验收通过。

## 2026-10-30 系统旋转底板补全

iOS补全承载WebView的祖先容器底色，透明内容后持续保留内容背景；补LaunchBackground启动颜色资源。当前工作区的原生墙及scroll子视图另补自动尺寸跟随，保留其他会话的原生墙接入。Android增加不透明主题窗口/启动底色，在chrome缓存前重申各层底色，并开启单WebView离屏预光栅化。保持系统旋转动画，不用截图遮盖或禁止旋转。

通过112源文件门禁、iOS Debug/device Release和Android体验构建；Web三种样式×深浅×四尺寸逐帧覆盖；专用iPhone系统三样式×深浅旋转用例39.66秒通过，完整xcresult及录屏在 .build/reports/ios/rotation-backing-native/ 。检查旋转中间态；另发现冷启动空白launch screen，已补资源但尚未重新录制冷启动。

Android本轮没有连接专用模拟器/设备，系统旋转尚未实测；模拟器不能证明用户实体设备GPU合成与所有中间帧均无白底。当前原生音乐墙接入等其他会话改动仍单独留在工作区。

### 2026-10-30 iOS 原生音乐墙录屏反馈后的样式补齐

- 已修复：原生回流替代悬浮重复封面；邻近封面保持共享边界及间隙；卡片从被点击封面本身展开；恢复普通封面的标题/歌手/渐变/暗化/深色间隙和当前轮廓；拖动期间用一次原生快照保留卡片内容；聚焦封面后台升级原图并保留已加载缩略图。
- 已修复：原生容器自动跟随旋转后，不能仅凭 bounds 是否改变判断重新居中；改为同时处理可用中心/边长变化，由实际 UIKit 尺寸和 safeAreaInsets 驱动相机。保留其他会话加入的宿主/scroll 自动布局。
- 已通过：组件门禁；iOS 纯逻辑（增加回流共边、1037 项三档缩放逆查询覆盖、横竖屏区域断言）；共享逻辑 47/47；模拟器及 iPhoneOS Debug 无签名构建；系统手势/展开收起/重启恢复和左右横屏/竖屏连续五次切换。报告 `.build/reports/ios/native-wall-parity-verified.xcresult`，横竖截图已人工检查。
- 待验收：用户真机重看相同场景、实体 GPU 帧耗时、iPad、VoiceOver、低内存及深浅完整矩阵。首次补强测试曾暴露横屏聚焦出屏，修复后用上述五次旋转断言复测通过；测试文件结构编辑错误也已修正。未把截图或几何用例当作 FPS 证据。
- 最终墙面宿主集成：208 项定向检查通过（含原生拖动保留共享卡片内容画面、1037 项渲染夹具及有界复用）。报告 `.build/reports/ios/shared-ui/A1A82D8E-910C-4068-8FC1-1D8D5F21A010/20261030T045244Z-36096/report.json`，ok=true。真机库与 FPS 不在此结论内。
- 补充回归：三种样式 × 深浅主题的系统旋转背景用例通过，报告 `.build/reports/ios/native-wall-parity-rotation-backing.xcresult`；测试结构恢复后未屏蔽该用例。

### 2026-10-30 iOS 滑动内容丢失、缩放遮罩及封面加载修复

- 默认比例：共享 Android/iOS 相机初始化明确为 100%；缺失、空值、零或非法旧值不再被当作 60%。有效的用户缩放记录继续恢复；不强制覆盖用户主动调节。
- 已修复的竞态：每轮原生拖动/双指缩放持有 motionEpoch，只有同轮且已结束运动的 surfaceReady 才能交还内容；旧轮回调不能移除新轮按钮/歌词画面。工具中断、定位、阻塞面板、旋转等也明确结束旧轮。
- 已修复的几何：裁切快照外容器变化时，内层内容的原点与宽高一起按来源比例更新，按钮/歌词/遮罩不再停留在原尺寸；部分离屏卡片可裁切捕获，保留上一份可用内容作为捕获失败时的备用。
- 封面稳定性：原生层更新关闭隐式图层动画；同一封面不从高清降级；已有图像在运动中暂缓高清替换，停稳后无淡入交接。平移时不重复配置未变化的标题/材质/边框或设置相同单元尺寸。
- 加载策略：周边预留提高到 520–900pt，屏内封面优先排队；普通解码 384px、聚焦 1280px，缓存 64MiB/384 项并保留两个解码线程。离开保留区域的任务仍取消；这不是无限预载或全库常驻。
- 验证：共享 JS 48 项通过（包含默认比例）；iOS 纯逻辑通过；Simulator/iPhoneOS Debug 编译通过；系统手势/旋转测试通过（`.build/reports/ios/native-wall-scroll-stability.xcresult`）。最终墙面定向宿主报告 `.build/reports/ios/shared-ui/A1A82D8E-910C-4068-8FC1-1D8D5F21A010/20261030T051751Z-48050/report.json` 为 ok=true，包含播放歌曲后保留内容、旧回调隔离、四档缩放子层对齐及预热封面无空白检查。
- 待真机复验：用户报告的局部闪屏、点击时插图闪动、大库冷缓存甩动及低内存情况下加载情况。模拟器几何/状态检查不能证明实体 GPU 不闪屏；扩大预取和缓存的真机内存开销仍需评估。Android 本轮只验证共享默认相机逻辑，未新增 Android 实机证据。

### 2026-10-30 iOS 音乐墙整体重做（以 Mac/Android 效果为准）

- 旧原生/网页混合方案：用户明确回验未解决，标记为失败并停用，前述模拟器“通过”仅保留历史技术记录。NativeMusicWall、IOSNativeWall、截图交接和原生手势转交已从产品入口及编译移除。
- 新方案：iOS 与 Android 共用完整 Wall/WallPlayer/WallDock、皮肤及聚焦状态机；单一 WKWebView 中实时绘制封面、遮罩、轮廓、按钮和歌词。iOS 仅用有界视口合成优化相机；Mac 桌面组合不变。不再用逐项补丁维护两套显示。
- 已通过：共享 JS 51 项、iOS 纯逻辑、Simulator Debug、实际 WKWebView 深浅/六目录+两分组内页矩阵、1037 项实际宿主渲染压力。页面/千首报告见 Docs/iOS-MusicWall-Rebuild-2026-10-30.md。
- 未通过：完整既有 wall-version 脚本在歌词编辑器缺少 `.mv-lyrics-timing>.mv-disclosure-trigger` 处失败；之前的安卓墙面与 Mac 实际墙面用例通过，未放宽或屏蔽断言。
- 待验收：实体设备 GPU 闪烁、冷缓存真实大图/低内存/长时间操作，以及用户对齐效果回验。不得将同组件、自动检查数或模拟器录屏当作实机效果已完全一致。

### 2026-10-30：按 Mac 整墙移动方式继续收敛（第一轮）

用户授权 iOS 参照当前 Mac Electron/React 音乐墙；不是移植仓库中旧的 AppKit 音乐墙。当前仍使用移动 Wall 组件，尚未把 Mac Wall 全部替换进 iOS。

- iOS 普通平移保留容器 transform，局部坐标重设阈值从 96px 调为 Mac 同级的 180px，保护边从 160px 调为 256px。扩大保护边增加固定合成面积，是否值得须实机对比；不随曲库大小增长。坐标连续性测试及有界层尺寸断言同步更新。
- 聚焦卡片的固定尺寸、透明度等值不变时不写样式；聚焦层 will-change 改为 transform，避免长期提示宽高布局动画。
- 定位 token 仅在歌曲与视口有效、聚焦已打开后消费，避免导航分阶段到达时请求丢失；保留 520ms 可打断定位过程。
- 共享移动端与 Mac 使用同一个 playingInstance 规则：同曲重复封面只由一个实例拥有播放高亮，优先聚焦实例，否则最近实例。分组不继承歌曲播放状态。2/3 首曲库的重复实例已加入逻辑回归。
- 静态门禁通过；共享测试 52 通过；Mac 测试 64 通过、4 跳过；iOS Simulator Debug 构建通过。模拟器页面回归结果另补；真机流畅度、GPU 闪屏仍待验收，不宣称解决。

本轮补充验证：iOS 页面矩阵通过（1691 项断言，报告 `.build/reports/ios/shared-ui/A1A82D8E-910C-4068-8FC1-1D8D5F21A010/20261030T083928Z-42806/report.json`）；iPhoneOS Debug 无签名构建通过。千首库初次回归在平移第 2 步失败：探针固定等待 24ms 后读 DOM，无法保证相机绘制已经提交。探针增加绘制帧同步，保留原位移容差、循环次数和挂载上限后重跑，结果见后续记录。这是测试读取时序修正，不作为实机流畅度证据。

千首库重跑通过：`.build/reports/ios/shared-ui/A1A82D8E-910C-4068-8FC1-1D8D5F21A010/20261030T084147Z-44263/report.json`，覆盖 80 次双向平移、20 次快速切卡、4 档缩放及可见封面解码就绪。仍待用户真机验收滚动流畅度、缩放与点击闪烁；当前是参照 Mac 的第一轮收敛，不是已完整复用 Mac Wall。

### 播放栏定位与重复实例逻辑补充（2026-10-30）

- 发现分组封面借用首曲 ID 时，旧 locateWall 的“歌曲已在列表”判断会误留在分组墙；改为分组一律进入歌曲音乐库定位，同时关闭侧栏与展开状态。
- 播放栏定位携带目标歌曲 ID，等待相应歌曲、有效视口以及卡片收起完成后消费 token，防止旧预览对象或收起动画抢走定位。正常定位仍执行 520ms 动画（减弱动态效果除外），可被新手势打断。
- Shared Wall（iOS、Android 当前默认 PortablePlayerActivity）与 Mac 在定位重复封面时比较回流后的实际中心，保留已有可见聚焦实例，避免只按原始网格找错重复项。Mac 的定位 effect 补上目标歌曲变化依赖。
- 上轮已接入的 playingInstance 仍保证一个歌曲仅一个实例拥有播放强调；其他重复封面保留普通卡片表现，不取消无限墙。旧 Android 原生 WallView 非默认入口，本轮没有宣称其完成迁移。
- 逻辑回归新增 2/3/1037 首、三档缩放及远距离相机下的回流重复实例选择；共享测试 53 通过，Mac 64 通过、4 跳过。iOS 页面测试新增播放栏定位中间帧、播放实例唯一性和分组墙定位用例，结果待补。真机触控和流畅度仍待验收。

补充验收：iOS Simulator Debug 与 iPhoneOS Debug 无签名构建通过；Mac 桌面资源构建通过；iOS 定位页面回归通过，包含播放栏定位中间帧、唯一播放实例以及深浅主题的歌手/专辑分组墙定位。报告路径：/Users/fanchen/Documents/Codex/MiniVoice/.build/reports/ios/shared-ui/A1A82D8E-910C-4068-8FC1-1D8D5F21A010/20261030T084528Z-46987。实机触控动画与 GPU 闪屏待用户验收；Android 已接入共享逻辑，本轮未做 Android 模拟器集成验收。

### 2026-10-30：澄清为 iOS 滑动问题，统一播放卡片与墙面相机

用户反馈的是“按 Mac 方向修改后的 iOS 仍不丝滑”，不是 Mac 卡顿。误向 Mac 添加的输入合帧与 Poster 读取优化已撤回；保留先前获授权的重复实例和定位修复。误向验证中 Mac 音乐墙用例通过，完整页面套件仍在既有歌词时序入口 `.mv-lyrics-timing>.mv-disclosure-trigger` 失败，不能记为全套通过。

iOS/共享移动 Wall 本轮：
- 将原先位于相机平面之外的聚焦播放卡片移入同一平面，普通平移由一个容器同时带动封面、轮廓、遮罩、按钮与歌词；动画、缩放、展开仍按真实几何更新，未用截图替代。
- 有界平面的保护边同时应用于聚焦卡片坐标及展开终点，普通平移的基准坐标不变时跳过卡片几何重算和内容节点查询。
- 合并高频指针输入触发的可见窗口 React 更新到绘制帧；保留每个输入位移，强制保存/动画终点立即提交。
- 相机平面子卡片显式恢复 pointer-events，避免改变点击/触控命中。
- 新增 iOS 集成断言确认歌词与卡片属于同一相机容器；原有滑动保留节点、缩放边界、播放栏定位中间帧继续验收。

编译与自动检查仅能证明构建、几何和状态；真机帧时间、GPU 合成开销及滑动体验仍未测量，不能称已解决卡顿。当前运行结果待补。

本轮验证补充：静态门禁与共享 53 项逻辑测试通过；Simulator/iPhoneOS Debug 构建通过；最终版本 WK 页面矩阵通过（报告 `20261030T085232Z-52260`），千首合成身份数据的平移/切卡/缩放回归通过（`20261030T085338Z-52252`），均位于 `.build/reports/ios/shared-ui/A1A82D8E-910C-4068-8FC1-1D8D5F21A010/`。千首数据复用合成封面，不等于千张真实原图压力或真机流畅度。移动真实 DOM 回归的滑动、缩放、节点连续性检查通过；完整页面套件结果仍需单列，不把局部通过记成整套通过。系统触控用例继续验证相机平面结构调整后的实际命中。

验收纠正：本轮合帧代码首次写入时误将 force 分支同时替换进 schedulePaint，导致 RAF 中引用未定义变量。Electron 完整回归捕获该异常，先前 WK 报告虽为通过但未收集 window error，因此不能作为这版代码的运行时正确性依据。已修复回调作用域错误，并给 WK 页面/千首脚本新增运行时异常失败断言，保持位移、节点和几何断言不变，重跑中。系统真实手势用例在首次版本通过（`.build/reports/ios/wall-common-plane-touch.xcresult`），但不能覆盖或抵消此异常。后续以纠正后的重跑报告为准。

纠正后验证：新增运行时异常断言的 WK 页面矩阵通过（`20261030T085518Z-54363`），千首库通过（`20261030T085625Z-54099`）。进一步跨端检查发现合帧会延后缩放控件受控数值回传，已令 zoomAt 即时通知 onScale，绘制/可见窗口仍合帧；未放宽缩放恢复断言。最新 Electron 移动端真实命中、缩放、歌词、展开、旋转与重启恢复已通过；最新 Simulator/iPhoneOS Debug 构建通过；最新千首 WK 回归及运行时无异常断言通过（`20261030T085731Z-56052`）。所有 WK 报告均在 `.build/reports/ios/shared-ui/A1A82D8E-910C-4068-8FC1-1D8D5F21A010/`。本轮同容器移动优化仍待用户真机确认是否有可感知改善，不宣称已消除卡顿。

最新系统触控验收：`wall-common-plane-final-touch.xcresult` 的 testUnifiedWallGesturesAndFocus 通过，1 项、0 失败，覆盖真实手势滑动、缩放、定位、展开收起与旋转。完整 Electron 页面套件再次在既有歌词时序入口 `.mv-lyrics-timing>.mv-disclosure-trigger` 失败；此前音乐墙移动端及 Mac 音乐墙回归通过，不宣称整套通过。实体 iPhone 流畅度与闪屏仍待验收。

### 2026-10-30：用户确认同容器优化仍不流畅，改造 iOS 滚动机制

此前方案的实机流畅度验收失败，不再把相机样式写入优化记为问题已解决。用户授权继续重构。

iOS 的 Wall 现使用 nativeScrolling 配置：单个 WKWebView 内的 overflow 滚动文档承担普通触摸跟踪、松手惯性与滚动合成，关闭旧 pointer 相机拖动和 JS 惯性路径；Android 仍使用原有指针相机路径。不是恢复 Swift 图片墙 + HTML 控件的分层方案。

滚动文档固定 16384×16384 CSS px；封面只挂载可见窗口及 overscan。文档自身不使用 transform/will-change 提升成整张 GPU 纹理；靠滚动视口的分块绘制。逻辑相机从 scrollLeft/Top 推导，普通拖动不逐帧平移卡片 DOM；靠近文档边界重新设定坐标原点。聚焦、缩放和展开继续用真实几何，播放卡片与封面同一文档。双指触摸单独处理缩放，单指和惯性交给滚动层。

显式区分程序动画产生的 scroll 通知与用户滚动，程序定位不能被自己的 scroll 事件打断；通知标记消费后清除，用户来回滑到同一位置仍生效。自动恢复仅在首次且保存歌曲相同才允许无动画，其余切曲/显式定位保留动画。关闭 overflow-anchor 防止回流时浏览器自行补偿偏移。Debug 物理设备开放 WK isInspectable，Release 不开放。

测试探针改为等待真实 scroll 通知后读取相机，缩放用 TouchEvent 而非不产生原生滚动的合成 PointerEvent；32 步位移、节点连续性、遮罩/内容/轮廓、定位中间帧与运行时异常断言均保留。系统手势检查另跑，不能由脚本 scrollBy 代替。

真机采样尝试：设备管理可见当前 MiniVoice，xctrace 的 Animation Hitches 和 Time Profiler 均报告找不到进程（按 PID 与名称附加均失败），未取得有效 trace，不能报告 FPS 或实际掉帧根因。未重装手机应用、未改音乐库。WebKit 的页面帧率与显示刷新率不是同一概念，背景参考 https://webkit.github.io/explainers/animation-frame-rate/ ，本轮不宣称解锁或实现固定 120Hz。

构建/功能与系统手势结果待补；用户实机流畅度仍待验收。

本轮过程与验收：系统滚动与程序定位之间的通知来源问题、回到原偏移时旧标记未消费的问题均已通过原连续位移/定位中间帧断言发现并修复；首次重命名后遗漏 rasterCamera 调用造成空页，已修正，不能记为已验收版本。随后 WK 全页面矩阵通过（`20261030T092450Z-70159`），千首身份数据回归通过（`20261030T092627Z-71167`）。首次系统触控用例失败：原卡片 touch-action:none 阻止真实系统拖动，而 scrollBy 不暴露该问题；已限定在 iOS nativeScrolling 下将卡片和聚焦 section 设为 pan-x pan-y，并新增计算样式断言，保留真实拖动位移大于 30px、双指改变比例等原断言，系统手势重跑中。失败不通过放宽标准消除。

进一步回归：真实系统手势 testUnifiedWallGesturesAndFocus 的断言全部通过（40.615 秒、1 项 0 失败，`/tmp/mv-ios-native-scroll-touch-retry.log`）。但 xcodebuild 在测试结束后结果包收尾挂起超过两分钟，仅有 Data/Staging、无法导出 xcresult；已中断并终止该测试进程，不能将未完成结果包标为完整成功证据。以日志中的用例通过为有限证据。

最终页面矩阵又捕获换页面卸载期间 RAF 仍读取空 view 引用，已在 paint 入口加入 view/plane 有效性检查；异常断言保留，最终版本重跑中。跨端页面套件的移动墙与 Mac 墙检查通过，完整套件这次在 Mac 设置分组“快捷键”缺失处失败，未归为本轮音乐墙已通过的范围，不隐藏。

本轮最终构建与功能结果：静态门禁通过；共享逻辑 53 项通过；Simulator Debug 和 iPhoneOS Debug 无签名构建通过。最终 WK 页面矩阵含运行时异常检查通过（报告 `20261030T093104Z-74646`），千首合成身份数据含位移/切卡/缩放/可见解码/运行时异常检查通过（`20261030T093211Z-75318`），均位于 `.build/reports/ios/shared-ui/A1A82D8E-910C-4068-8FC1-1D8D5F21A010/`。系统触控用例断言通过但结果包收尾挂起的限制如上；未获取有效真机性能采样、未在物理手机安装本版。用户之前报告的流畅度问题仍标为“待真机验收”，不记为解决。

### 2026-10-30：系统滚动体验改善后的交互回归修复

用户确认滑动舒服了，但报告双击播放失效、聚焦变正方形卡顿、偶发漂移、灰色加载，并补充双指不跟手或缩放后卡住。本轮保留系统滚动，不回退旧逐帧平移。

- 双击：原 poster 在第一次点击后被聚焦 section 覆盖，第二次点击没有进入 activate。现在稳定墙面捕获第二次点击，按首张歌曲 ID、320ms/24px 手势范围识别，允许第二次命中聚焦层、邻居或移到指下的控件；正常控件独立操作不种下歌曲双击状态。聚焦背景单击接入语义激活。真实滚动清除双击序列。
- 漂移：普通 paint、状态轮询和同坐标保存不再写回 native scroll 偏移；只有实际程序相机变化才发起写入。程序定位期间没有新触摸时忽略滞后 scroll 通知，真实触摸滚动仍可打断。坐标原点重设延至惯性停止，减少系统滚动与程序坐标互相拉扯。
- 聚焦：iOS 背景卡片以最终宽高为稳定布局，逐帧仅更新 translate/scale，减少整片卡片反复宽高布局；真实播放卡片、轮廓、遮罩仍按同一几何更新。该改动是否足以消除实机卡顿待用户验收。
- 灰色加载：iOS 挂载保护范围从 360px 提至至少 600px，并对已加载的挂载封面主动调用 decode，提前解码而非仅提前请求；Android 未启用额外预解码。更多预加载存在解码/内存成本，未报告实机内存或 FPS。千首合成图压力不等同真实千张原图。
- 双指：缩放期间临时禁止系统 overflow 滚动，滚动回调不能覆盖 pinch 相机；从实际 scroll 位置获取起点，最后一指离开后提交相机并解锁；touchcancel 即使仍报告触点也强制解锁，页面失焦、隐藏、阻塞及卸载释放状态。

新增 WK 双击命中变化的歌曲/播放状态断言、取消后解锁断言，修复原 tapFocused 探针在原生滚动模式下没有实际触发点击的问题；千首回归新增预解码检查。系统用例新增真实双击播放、反向缩放后立即单指拖动，定位入口从写死歌曲名改为当前播放栏（双击已会切换歌曲）。原位置、缩放、节点连续性、动画中间帧及运行时异常检查保留。

系统触控完整用例通过：`.build/reports/ios/wall-scroll-interaction-final.xcresult`，xcodebuild TEST SUCCEEDED。最终新增失焦/取消保护和预解码的 WK 页面、千首及构建重跑结果待补；用户真机的双指跟手、聚焦帧率、灰块与漂移仍待验收。

本轮双指进一步优化：手势开始时保存背景卡片和播放内容的布局尺寸，手势过程中只改变 transform，播放内容传给 React 的尺寸与 compact 状态也保持起点值，避免播放信息/歌词在缩放每帧重新排版；松手或取消时只提交一次最终真实尺寸。新增每档缩放期间封面及歌词布局尺寸不变的断言，结束每次手势后再进入下一档，保留视觉内容/遮罩/轮廓同帧对齐检查。

双击捕获同时覆盖 touchend 捕获阶段，避免 ActionButton 的合法 TouchEnd 语义激活绕过 DOM click 捕获：第二次触摸可命中变形后出现的控件或另一张卡片，仍对首曲只触发一次播放；不种下序列的普通控件保持原动作。新增语义首击 + 原始第二次 TouchEnd 的命中变化回归。聚焦相机在动画结束后显式释放所有权，新增完成后后续滚动不能被吞掉的断言。第一指实际移动超过阈值时停止旧定位并让出滚动写入，不在单纯触摸开始时提前打断动画。

中间版本完整系统手势已通过（`wall-scroll-pinch-transform.xcresult`）；新增最终触摸捕获与冻结 React 播放布局后的系统用例和 WK 矩阵继续运行，最终以收尾条目为准。

最终交互用例验证：`wall-scroll-interaction-delivery.xcresult` 完整产出，xcodebuild TEST SUCCEEDED，覆盖真实双击播放、正反向双指后恢复单指拖动、定位、展开/收起、重启与旋转；最新 iPhoneOS Debug 构建通过。千首合成回归与预解码检查通过（`20261030T095652Z-89270`）；此前含双指布局尺寸稳定、取消解锁及运行时异常的 WK 页面矩阵通过（`20261030T095543Z-88573`），最后一次冻结 React 播放布局后页面矩阵继续重跑确认。上述 WK 报告在专用 Touch Check 目录。真实用户对灰色加载、聚焦动画帧率及跟手性的验收尚未取得，不宣称全部解决。

本轮最终收尾：最终代码下 WK 页面矩阵通过（`20261030T095830Z-90278`，含双指固定布局、取消解锁、触摸第二击、聚焦后释放相机和运行时异常检查）；完整系统手势通过（`wall-scroll-interaction-delivery.xcresult`，TEST SUCCEEDED）；千首合成及预解码检查通过（`20261030T095652Z-89270`）；iPhoneOS Debug 无签名构建通过；共享逻辑 53 项通过。用户已确认上一版系统滚动更舒服；本轮关于聚焦动画帧率、缩放跟手性、漂移与真实封面灰块仍待用户真机验收，不标记为已解决。

### 2026-10-30：实机录屏出现整页重载迹象，用户报告资源高与发热

用户提供 `/Users/fanchen/Downloads/ScreenRecording_10-30-2026 18-01-49_1.MP4`（8.45 秒，60Hz 录制）。已提取每秒两帧的联系图 `.build/reports/ios/video-review/contact.png` 逐帧检查：多次出现白色/纯背景画面、默认音乐库 0 首加载界面、音乐墙及封面重新加载；扫描进度持续推进。视频能证明反复恢复/重建的视觉异常，但无法单独证明 jetsam、WebContent 崩溃或具体内存原因。之前只有 12 种合成图的千首身份测试没有覆盖真实大量封面的压力；此前“功能通过”不能视为稳定性验收。

本轮优先降低资源峰值，不继续增加预加载：
- 撤回 iOS 600px 大预加载和所有挂载封面的主动 decode，恢复 360px；撤回背景卡片回流期间的批量 will-change 提升，保留 transform 几何。移除锐利封面背后被覆盖的额外模糊封面层。
- iOS DTO 新增 artworkWall（320px）和 artworkCard（960px），普通墙和分组封面使用前者，普通聚焦使用后者，全屏保留原高清 display。两者按身份/版本独立落盘缓存，不影响原图或音乐文件。普通列表和其他样式原 artwork 路径不变。
- 宿主真实封面读取/缩放同时最多 2 项，省电或严重/临界热状态为 1；聚焦及高清请求优先于排队墙图。移出页面的 WK 资源任务取消，等待者可取消并释放名额；已开始的读取完成前仍占用名额，避免“取消后又放出无限后台工作”。
- native 编码图片缓存从 32MB/192 项降为 8MB/64 项；元数据更新不再一律清空图片缓存，图片 URL 版本与内容身份稳定，避免因曲库 revision 变化反复生成相同缓存项。授权检查仍在命中缓存前执行。
- 扫描 worker 从 userInitiated 改为 utility，降低与交互争抢优先级；播放卡片离开可见区后停止歌词逐帧更新和播放柱动画；详情等待安定的轮询从每显示帧降为每 80ms 检查。
- 开始显示 iOS 页面前等待 workspace 与首次 snapshot 均就绪，避免恢复途中绘制默认空音乐库；读取失败时错误仍可显示。没有用遮罩伪造渲染进程未重启。
- `webViewWebContentProcessDidTerminate` 写入诊断，含终止次数、活动/排队封面任务和 thermalState；内存警告也写入诊断并清理编码缓存。原先直接 reload 且没有终止记录，现在可区分原生进程与 WebContent 恢复。

新增断言：真实宿主处理峰值不超过 2、队列最终清空、压力操作期间 WebContent 终止数为 0；墙图实际 naturalWidth/Height <=320，普通聚焦 <=960。删除的主动预解码策略改由这些资源约束验收，保留可见封面就绪、连续移动、双击、取消解锁、定位中间帧和异常断言。首轮压力报告 `20261030T101706Z-98495` 显示 peak=2、active=0、queued=0、webTerminations=0；该结果为合成模拟器，不是用户手机的内存/温度证据。加入分组缩略图传递后最终回归继续运行。实体设备的资源占用、温度和视频异常是否消失仍待验收，不能记为已解决。

本轮最终验证：静态门禁通过；共享逻辑 53 项通过；最终 WK 页面矩阵通过（`20261030T102123Z-1927`），含等待首批状态、双击、固定布局缩放、取消恢复、定位中间帧及运行时异常检查；千首合成压力通过（`20261030T102233Z-2551`），80 次平移期间 peakMounted=49、真实封面处理 peak=2，结束 active=0、queued=0、webTerminations=0，且可见墙图 <=320px、普通聚焦 <=960px。完整系统手势结果包 `.build/reports/ios/wall-resource-budget-delivery.xcresult` TEST SUCCEEDED；Simulator 和 iPhoneOS Debug 构建通过。未在用户手机安装此版，未取得有效真机内存、温度或 Jetsam 数据，故严重白屏/恢复现象和发热仍为“待真机验证”，不能从合成压力通过推断已根治。影像证据与本轮资源预算调整如上记录。

2026-10-30 iOS 用户指定定向修复：共享 Wall 聚焦卡片统一零布局原点与 transform 定位，修正 React 提交与逐帧定位叠加导致卡片脱离封面的风险。静态边界检查通过（112 源文件），共享单元测试 53 项通过。音乐墙页面回归已执行，日志见 /tmp/minivoice-wall-page.txt；iOS 真机录屏场景、惯性、缩放及深浅主题仍待验收，未标记实机通过。本次范围依用户明确请求，不扩展其他 iOS 功能。

2026-10-30 点击聚焦动画优化：原生滚动路径将滚动几何读取集中到封面绘制前，减少强制布局风险。静态检查及共享单元测试 53 项通过；本轮页面测试日志 /tmp/minivoice-wall-animation.txt 已确认快速切卡、拖动与动画打断保留封面节点检查通过。上一轮完整页面脚本在 Mac 歌词编辑入口 `.mv-lyrics-timing>.mv-disclosure-trigger` 缺失处失败，不能标记完整回归通过。iOS 真机深浅主题、点击/惯性/连续打断及实际流畅度待验收。

2026-10-30 用户截图选中框宽度专项：修正共享简易侧栏歌曲列表 padding-right=28px 与行宽扣减30px叠加，改为列表零右 padding、行 left=0/right=8px/width=auto。iOS、Android 共用此修正；Mac 独立 track-row 代码检查未发现同类重复扣宽。静态检查通过（112 源文件）。Electron 页面回归新增 390×844、844×390 侧栏实际矩形宽度断言并通过，三样式与深浅主题切换检查通过；日志 /tmp/minivoice-selection-geometry.txt。完整脚本仍有 Mac 歌词编辑入口缺失的已知失败，不能称全量通过。三端真机、平板及原生宿主宽度回验待验收，未新增其他平台实现。

2026-10-30 移动横屏/点击动画定向调整：共享非音乐墙播放页左侧信息与控制区撑满左列，与侧栏按钮左缘对齐；封面移至工具栏同一顶边并避让按钮。适用于 iOS/Android mobile 横屏；Mac/竖屏保持原布局。Wall 聚焦过渡缓存不变的重排目标，focus/尺寸变化时失效，减少逐帧重复计算。静态检查与共享53项测试通过；页面脚本日志 /tmp/mv-landscape-final.txt，音乐墙快速切换/打断及手机旋转检查通过，完整脚本仍受 Mac 歌词编辑入口缺失阻断。新对齐要求的真机视觉、横屏封面尺寸及按钮碰撞、深浅主题、iOS GPU 流畅度待验收，未宣称实机通过。

2026-10-30 侧栏开关专项：已读取用户录屏中间帧。共享移动 drawer 重入从退出面板当前 transform/opacity 接续；iOS 墙面 depth 动画保留封面基准尺寸并缩放，减少逐帧尺寸重排；封面裁切内溢出 .5px 处理亚像素采样边缘（细线根因及消除效果仍待真机确认）。静态检查、共享53项测试、自有组件 Electron 回归通过。页面回归日志 /tmp/mv-drawer-interrupt.txt；全部三样式移动快速开关、iOS真机细线及缩放流畅度仍按实际证据验收，不新增 FPS 或实机通过结论。

2026-10-30 按用户要求撤回移动端横屏播放页布局调整：已恢复此前横屏 CSS；上一条横屏新对齐方案不再交付。仅撤回布局，保留音乐墙动画、侧栏打断及选中框宽度修复。差异确认横屏块与原版本一致，静态检查通过。侧栏专项页面回归已通过移动进入/退出/快速重开与 inert 清理，完整脚本仍在已知 Mac 歌词编辑入口缺失处失败；真机细线及缩放流畅度待验收。

2026-10-30 iOS 点击封面清晰度专项：确认原生墙面320px缩略图→960px卡片图，旧逻辑因聚焦动画阻塞高清接管。改为聚焦期间高清解码就绪后180ms透明度交接，保留缩略图底层；滚动/手势及展开中间态仍延后，减弱动态不渐变。静态检查、共享53项测试通过；页面回归日志 /tmp/mv-artwork-upgrade.txt。iOS真机点击与连续切歌、慢图加载、深浅主题的清晰度观感待验收，未提高全墙图片分辨率或宣称实机流畅度通过。

2026-10-30 iOS 拖动聚焦晃动/蓝色专项：发现 React 聚焦卡片更新组合 camera 与实时 scrollOffset，而 paint 稳态使用 nativeOrigin，两路径采样不一致。已统一文档坐标投影及展开端点。卡片关闭 WebKit tap highlight 和非键盘默认 focus outline，保留键盘提示及当前歌曲描边。静态检查、共享53项测试通过；页面回归日志 /tmp/mv-wall-wobble.txt。用户报告的细线/蓝色尚未真机复现并确认根因；拖动惯性、连续聚焦与侧栏缩放的iOS真机回验待验收，不能宣称上述偶现已完全消除。

2026-10-30 iOS 展开封面清晰度补充：取消详情图接管等待展开动画结束的限制，解码就绪后沿用180ms交接；已显示卡片图保留底层，避免切换时退回320px缩略图。静态检查、共享53项测试通过；页面回归日志 /tmp/mv-expand-cover.txt。真机展开/收起连续打断、慢图加载与高清变化观感待验收，不宣称完全消除可感知清晰度变化。

2026-10-30 iOS 点击聚焦进一步优化：移除 focus tick→另一个 RAF 才 paint 的额外调度层，改为同帧更新后 flush，统一清理排队绘制并消费可见封面补载。静态检查和共享53项测试通过。页面回归日志 /tmp/mv-focus-frame.txt；实际iPhone点击响应、快速切卡及GPU流畅度待验收，不提供未经测量的帧率或提升幅度。

2026-10-30 20:17 用户新录屏复核：已转换并查看标注 HEIC，提取 MP4 接触表。圈定细线位于聚焦卡片左侧的非聚焦卡片底边，为浅灰短横边，随点击聚焦动画出现/消失。此前 tap-highlight 与 .5px 图片内溢出均不能视为该问题已解决；该项状态为失败（用户录屏仍可见），根因待定位，裁切/缩放合成边缘仅为假设。证据原文件 ScreenRecording_10-30-2026 20-17-23_1.MP4、ios_1793362704217.heic；本轮仅核实证据，不追加未经验证的渲染补丁。

2026-10-30 20:21 iOS 聚焦整墙灰屏：已提取用户 MP4 每秒4帧接触表并核实，多个连续采样帧中音乐墙封面整体消失，工具栏与播放条保留，随后墙面恢复。该问题属于整墙短暂空白的阻断失败，不是单图高清交接。代码存在聚焦动画逐帧写 scrollLeft/scrollTop 的原生滚动路径；异步滚动瓦片失效或坐标跳变均为待验证假设，尚无运行证据可确定根因。此前页面/单元通过不能覆盖此真机失败，不宣称点击流畅度或灰屏已修复。证据 ScreenRecording_10-30-2026 20-21-16_1.MP4，接触表 /tmp/mv-gray-contact.png。

2026-10-30 用户截图白线再次出现：标记于Sold Out邻卡底边，上一轮捏合期间绕过rasterRect是明确回归风险。本轮恢复捏合中四边物理像素对齐，保留邻卡真实宽高与固定scroll更新路径。静态检查、共享53项、合成捏合几何/控件/scroll定向检查通过（/tmp/mv-edge-pinch-grid.txt）。3倍像素密度检查日志 /tmp/mv-edge-pinch-dpr3.txt。白线根因尚未经WK真机观测证实，该候选修正仍待用户同场景回验；不得将Electron几何通过写成实体白线已修复。

2026-10-30 22:11 iOS展开收起跳动：已查看录屏接触表；修正iOS内容先跳终点尺寸/外层仍过渡的不同步，收起移除额外无动画定位。静态检查、共享53项测试通过。定向Electron中间尺寸跟随、快速反向重开、最终实际viewport、相机不动检查通过（/tmp/mv-expand-continuity-targeted.txt）；首轮测试误用窗口外框956为viewport高度而失败，已改为读取实际viewport，并保留尺寸断言。完整页面回归仍在Mac歌词编辑入口缺失失败（/tmp/mv-expand-continuity-pages.txt）。未进行iOS真机部署或流畅度验收，实体展开关闭及缩放后的连续性待验收。

2026-10-30 用户要求先提交再加反馈：此前已有源代码/测试优化已提交802655d，未纳入用户Xcode个人界面状态。随后独立新增移动墙面按住.96缩小+白色细框，不加入hover放大；原Mac代码不改。静态检查及共享53项通过；Android/iOS合成触摸按压、拖动/多指/cancel与reduce-motion定向检查通过（/tmp/mv-wall-press-targeted.txt）。首轮160ms动画测试采样180ms未达端点失败，复跑通过；真机时序/快速点按仍待回验，不据复跑否认时序风险。Android体验构建日志 /tmp/mv-wall-press-final-build.txt；本轮未部署实体iOS包。原有灰屏/细线与全回归缺口不因本次反馈新增改为通过。

2026-10-30 音乐墙歌词显示不全（Mac体验版扩展卡片）：根因为共享ScrollingLyrics的扫词（sweep）只在当前行绘制，行离开当前位后其.lyric-content仍保留命令式添加的sweep-surface，而React对未变化的className不重写、foundation.css又对该类强制color:transparent!important并取消背景，导致已播放行原文消失只剩译文（"只显示译文"）。新增lyricSweep.clearLyricSweep并在当前行变化时清理上一行，Mac/iOS/Android体验三端共用同一组件与样式，同一缺陷三端均存在（Android实测修复前每个已播放行均为透明原文）。第二处为视口边缘硬切：行被裁切时改为按自身盒淡出（线性遮罩随行），不再留下半行或孤立译文。Electron定向检查：Mac扩展卡片播放头18→26→34秒仅当前行sweep-surface、其余行文字不透明；Android/iOS体验卡片position18→26→34同样仅当前行带sweep-surface；修复前Android实测第4/6行保留sweep-surface。截图 .build/reports/ui/shot-mac-t34.png（修复前）与 shot-fixed-t34.png（修复后）、mlyric-android-34000.png。test-lyrics-viewport与test-wall-content-alignment通过；test-wall-version的"Play must be at lower left"、test-mobile-wall-surfaces与test-mobile-wall-touch失败已确认在本次修改前即存在，非本次引入。未在真机复核Mac/Android/iOS实机观感。

2026-10-30 按压反馈回归修正：用户反馈定位飘移、点击失效及正文变暗，先前直接scale定位根节点会缩放文档平移坐标并缩小命中区域。改为仅内部居中视觉层缩放，外部定位/命中保留；同步迁移遮罩以免压暗正文。移动按钮显示条件与802655d一致，未拷贝Mac显示规则。静态检查、共享53项、Android/iOS定向中心/单击聚焦/双击播放/取消/减弱动态/遮罩测试通过（/tmp/mv-press-layer-targeted.txt）；已查看wall-press-layer-ios.png，正文与按钮正常。AndroidAPK重建通过（/tmp/mv-press-layer-build.txt）。完整页面仍在此前Play must be at lower left失败（/tmp/mv-press-layer-pages.txt）；实体快速点按及视觉仍待回验。首轮测试脚本引号错误已修正，未隐藏生产失败。

2026-10-30 移动卡片多项回归统一校验：用户明确完整圆形按钮需在内容区内，撤回此前贴齐SVG路径的负margin/运行时测量；左右按钮框与标题/歌手共用内边距。iOS移除重新出现的捏合内容scale与compact按钮隐藏，保留Android显示规则；普通/聚焦卡片按压均缩放内部视觉层，当前歌曲描边也随同缩放。静态门禁、共享53项通过。定向测试通过：Android/iOS两尺寸完整圆形边界/左右等距/文本框对齐（/tmp/mv-unified-card-align-final.txt）；iOS缩小放大松手控件与内容/邻卡/原生scroll稳定（/tmp/mv-unified-card-pinch-final.txt）；普通与聚焦中心/比例一致、单击聚焦、双击播放（/tmp/mv-unified-card-press-final.txt）。测试选卡改为当前已挂载第一张，避免滚动恢复后硬编码id0未挂载的fixture错误。Android体验APK构建通过（/tmp/mv-unified-card-final-build.txt）。实体iOS字体连续观感和按压手感待验收；此前完整页面比例断言失败记录保留，不标全回归通过。

2026-10-30 Mac体验点击白边闪现专项：已提取用户22.25录屏接触表。清除桌面wall-poster遗留外层border，focused非playing状态明确退出hover白边层，保留正常hover/press与playing薄荷描边。静态检查、桌面64项通过/4项跳过、前端生产构建通过（/tmp/mv-mac-edge-unit.txt、/tmp/mv-mac-edge-build.txt）。独立Mac页面实际鼠标定向测试通过：hover白边保留，点击后15个中间采样无遗留border/白色contour（/tmp/mv-mac-contour-targeted.txt）。首轮fixture只接受完整入屏卡片导致无候选，改为可见交集坐标后通过，不改变生产断言。完整页面仍在移动首按钮边界失败，另轮运行出现共享页useLayoutEffect运行时错误，均未宣称完整通过（/tmp/mv-mac-edge-pages.txt、/tmp/mv-mac-edge-regression.txt）。未重打包/签名Mac app或部署用户实例，实际Mac录屏白边回验待验收。

2026-10-31 Android恢复与144%越界专项：确认Android展开按钮内侧留白及100%设置映射仍在；此前按钮保留仅iOS，现两移动宿主统一keepControls。确认Wall仍导入旧内部上限1.2，叠加展示×1.2导致144%，改为单一mobileWallZoom模型内部.5–1，默认1/1.2。静态检查113源文件、共享54项通过。Android新隔离会话默认100/放大110/立即恢复100、120端点内部≤1、缩小后控件数不变定向测试 /tmp/mv-hard120-final.txt；iOS合成捏合检查通过 /tmp/mv-hard120-pinch.txt。初轮默认测试因旧会话已有保存比例显示120失败，改为新隔离会话验证默认而非覆盖历史状态，/tmp/mv-hard120-reset-fresh.txt通过。AndroidAPK重建通过 /tmp/mv-hard120-build.txt。实体两端缩放上限、按钮与展开位置仍待回验，不扩称完整页面验收通过。

## 2026-11-04 用户多平台修复清单

实施范围与逐项修复日志：[FIX_LOG_2026-11-04.md](FIX_LOG_2026-11-04.md)。本轮按用户要求不执行此前灰屏排查。

已通过：

- 组件边界门禁：116 个源文件；`git diff --check` 无错误。
- 共享单测 58/58；桌面单测 64 通过、4 跳过、0 失败。新增时钟抗回跳、字号连续、焦点裁切边界用例。
- `test-desktop-components.sh`：按钮、菜单、滑块、选择与键盘规则。
- `test-wall-version.sh` 完整通过：音乐墙大库、触控/键鼠、缩放与恢复、横竖屏、深浅主题、Mac 三分类编辑、搜索/导入、时间轴草稿、只读控件、Esc 和草稿保护。旧比例断言按现有 60–120% 显示映射同步，未放宽边界/容差。
- `test-player-refinements.cjs`：iOS/Android 浏览器夹具的封面模式切换、简易多选、菜单高于侧栏、设置入口移除；Mac 分类、识别失败、歌手草稿与保存命令。它不是原生文件写入回读测试。
- iOS 展开连续性定向测试：中间尺寸、反向打断、最终全屏与相机保持（Electron）。
- 专用 iOS WKWebView 实际宿主测试通过：`.build/reports/ios/shared-ui/A1A82D8E-910C-4068-8FC1-1D8D5F21A010/20261104T074302Z-18576`；包含系统滚动渲染、双击命中、真实按钮/歌词保留、pinch 快照、遮罩/轮廓对齐、取消解锁及墙页面矩阵。
- Mac 前端生产构建、iOS Debug 模拟器构建通过；Android 全量 Java 源码编译通过（android-37.0 平台包）。

环境阻断：Android 体验版完整打包缺少 NDK 27.2.12479018，未产出本轮新 APK。旧 APK 不作为本轮交付。

待实体设备验收：Mac 独立窗口连续拖动的帧耗时；iPhone/Android 的点卡片、搜索、侧栏开合与持续播放时温度/流畅度；横竖屏主体裁切算法的多封面目视效果。未对用户真实音乐库进行写入。本轮不宣称“全部按钮已完成真实文件级回读”“全平台无卡顿”或“热问题已解决”。

回归中的失败均已保留在过程说明：旧遮罩探针仍检测已取消的伪元素、旧缩放断言混用显示比例/相机比例，已更新到实际节点与有效范围；发现的双指绘制捷径及未消费布局快照已修正并重跑 WK 测试通过。

补充通过：iOS 专用模拟器系统触摸 `testUnifiedWallGesturesAndFocus`（XCUITest）执行成功，结果 `.build/reports/ios/wall-refinements-20261104.xcresult`；覆盖滑动、双击播放、双指缩放、缩放后继续拖动、定位、展开/收起、重启与旋转。该证据证明系统手势功能回归，仍不替代实体 iPhone 的温度和帧率。

### 本日追加：超时反复提示、收藏按钮轮廓

- 已修改：宿主活动时间超时、背景停止 snapshot、单在途/退避恢复、同一持续故障只提示一次；移动三样式收藏按钮常驻轮廓移除，保留实心爱心及按压/键盘焦点。
- 共享测试61/61、静态边界117个源文件、iOS模拟器构建与实际WK墙矩阵通过。WK报告：`.build/reports/ios/shared-ui/A1A82D8E-910C-4068-8FC1-1D8D5F21A010/20261104T075331Z-27408`。
- 模拟生命周期测试覆盖挂起恢复，但不等同用户设备持续运行数小时；截图只能确认共享超时提示来源，不证明所有长期前台故障均因后台暂停。Android完整包仍缺NDK，未替换用户安装包。

追加定向UI验证通过：`test-player-refinements.cjs` 同时检查 iOS/Android 夹具中“已收藏时背景透明、无阴影、outline-style:none、爱心实心”，并使用真实鼠标按住验证按压背景出现。此测试覆盖CSS交互；尚不代替两端真机触摸长时间运行。

## 2026-11-04 逐项复核（用户反馈前次体验未解决）

逐项日志：`Docs/FIX_LOG_2026-11-04_REVIEW.md`。此前把卡片底部细线与完整悬停轮廓混为一项的验收结论撤回。移动端指安卓体验+iOS；用户确认完整白框已不出现，本轮底部细线另行验收。

已修改：共同裁切覆盖、Mac单向几何过渡；Mac独立面板选择性订阅/紧凑歌手/无插图外框；iOS固定根布局后变换；歌词比例间隔；共享Mac搜索阶段与固定采样；多选期间禁用长按；侧栏保留根与页面整体深度；真实模糊图片层/双图标；视口感知裁切与缩略/高清统一锚点。

当前通过：共享单测62项；桌面64通过/4跳过；完整 `test-wall-version.sh`（包含搜索、侧栏打断、惯性/缩放、三样式/主题/编辑页、高清交接）；逐项鼠标/几何、独立窗口、多选、真实模糊图片及移动聚焦、搜索、侧栏定向用例；Mac前端和iOS模拟器构建。新的WK全矩阵与系统触摸结果另追加。

限制：Electron全墙回归输出过tile-memory警告，不能称GPU资源已完全优化；实体Mac拖窗/手机长时温度、帧率、底部细线、搜索黑条仍待复验。Android没有本轮新APK（NDK缺失）。未修改用户真实音乐文件或真机安装包。

逐项复核最终自动化结果：共享63/63通过（新增横竖屏裁切、缩略/高清路由共用一次分析的锚点稳定性）；桌面64通过/4跳过。完整墙界面回归通过。实际iOS WK矩阵通过，报告 `.build/reports/ios/shared-ui/A1A82D8E-910C-4068-8FC1-1D8D5F21A010/20261104T090656Z-59539`。系统触摸 `testUnifiedWallGesturesAndFocus` 成功，结果 `.build/reports/ios/wall-review-20261104.xcresult`。这些结果不替代用户实体设备对底部细线、黑条、拖窗/聚焦帧感与温度的验收。

### Mac 简易/音乐库右键侧栏错位

已复现：菜单滚动条挂在.app下时，mountScrollbar会把.app从static改为relative，导致绝对定位侧栏的参照改变（测试中top34→68、left约12→24）。MenuPopover改为body下独立固定浮层，滚动条仅影响浮层宿主，保留墙菜单皮肤。修复前定向用例失败，修复后简易/音乐库×浅/深×920/600/360px布局对比、菜单避让及Esc焦点恢复通过。共享63、桌面64通过/4跳过，自有组件交互及Mac前端构建通过。日志/tmp/mv-context-*。

### 2026-11-04 移动端聚焦白色轮廓补回
- 修复：此前白色轮廓仅绑定 touch 按住状态，松手聚焦后消失。现为非播放聚焦卡片提供独立完整白色内边框，位于图片、遮罩之上；播放卡片保留绿色轮廓，全屏展开隐藏轮廓。底部异常细亮线不属于这个轮廓。
- 通过：UI 标准检查；共享 UI 64 项单测；共享 UI 构建；`test-mobile-wall-outline.cjs` 验证 iOS/Android 页面松手后的四边轮廓和全屏隐藏。
- 待验收：手机实际构建上的视觉效果，未安装真实设备；不据此声明底部亮线或卡顿已解决。

### 2026-11-04 当前分支提升为 3.0.0 正式实现
- 用户授权：Mac、Android 体验实现完整接入正式渠道，三端版本统一。此条覆盖历史体验版限定规则，不代表历史视觉/性能缺陷全部通过验收。
- Mac：保留正式 Electron/Swift 包标识及数据域；正式渠道采用自有设置、编辑、桌面歌词、关于页及封面导入，取消按 debug 分流的旧面板入口。Electron 单独负责桌面歌词，不启动重复的 Swift 歌词控制器。旧 debug 数据不自动迁移或覆盖正式音乐库。
- Android：正式构建不再重写 launcher 到旧原生播放器；MainActivity 改为历史快捷方式/通知的共享入口转发。应用 ID、固定证书指纹与数据路径不变；experience 参数及公开 experience 命令兼容映射正式包。
- 版本：三端 3.0.0，构建号 30000；增加 Shared/version.json 与发布配置一致性门禁，包含版本漂移和原生面板回退的失败用例。同步 npm 锁文件及离线依赖清单校验哈希，无依赖版本升级。
- 通过：UI 标准门禁；发布配置检查及反例；公开构建路由/失败传播测试；iOS archive/export 脚本模拟测试；桌面单测 65 通过、4 跳过；实际独立面板（浅/深、关闭草稿、封面导入/复制/拖拽）与桌面歌词交互测试。
- 通过：Mac 正式 App/DMG 构建、深度签名验证、ASAR 版本与正式歌词入口核对；Android APK 完整构建、签名校验、aapt 元数据与 launcher 核对；iOS Release 模拟器原生构建与产物版本核对。
- 测试调整依据：旧插图断言按整个滚动区高度的 70% 判断，包含了工具栏等空间；更改为检查插图占满剩余区、底部内边距、最小可用高度及图片四边不越界，没有修改产品布局以迎合测试。
- 待验收：真机升级与原数据回读、GPU/触控流畅度、实体手机与实际歌曲回归；未执行设备安装或 /Applications 替换。Android 仍使用既有固定开发证书，Mac 本地签名，未进行商店发行/公证；iOS 未提供发行团队/导出配置，未生成本次签名 IPA。
- 产物：.build/dist/MiniVoice.app、MiniVoice-mac.dmg、MiniVoice-android.apk；iOS Release-iphonesimulator/MiniVoice.app。旧包存在不表示已更新，交付以以上本次产物为准。

## Windows 开发接入（2026-11-04）

- 授权：用户明确要求基于 Mac 新增 Windows；此范围覆盖原先暂停新增平台限制。
- 已编写、待实机验收：Windows 独立 Electron 宿主、共享桌面 UI 适配、JSON-lines 共享核心、PowerShell 开发目录包构建入口；基础播放/文件夹/状态功能及限制见 `Windows/README.md`。
- 通过：Node 语法检查、合成目录扫描测试（去重/backup 排除）、自有组件静态门禁。
- 未接入：标签与封面编辑、歌单、在线/AI 歌词、桌面歌词、系统媒体能力、正式签名与安装器。随机历史等行为尚不满足 Mac 产品基准。
- 待验收：Windows 编译与运行、真实音频、三种样式×深浅、键鼠焦点、重启与失败恢复。当前 macOS 环境没有 Windows 实机证据，不宣称 Windows 已完整支持。
- 本轮共享回归：64 项中 63 通过，1 失败（playback-clock 封面测试 `image.closest is not a function`，相关文件存在其他未提交修改，本轮未改）。本机缺少 CMake，原生核心构建未执行成功，Windows 包尚未生成。

### Windows 构建与集合页面续接

- 已接入：统一 Bash 构建 `--platforms windows`；Windows PowerShell 公共入口 `Scripts/build.ps1`，沿用工作流互斥锁；版本一致性检查与共享许可打包。mac/android/ios 默认集合不变。Windows deploy 当前只构建，不安装。
- 已接入、待 UI 实测：复用 CollectionDialogs 的歌单生命周期、批量加入/移除、批量收藏；修正 readLyrics 的 raw 返回结构。
- 通过：Windows Node 测试 3 项（合成目录扫描、歌单与收藏生命周期、无效 ID/重名拒绝）；主进程语法及两个 Bash 脚本语法检查。
- 1:1 未达成：Mac 正式 DesktopApplication 与 Windows PortablePlayer 尚非同一页面入口；独立设置、歌曲编辑、桌面歌词及其后台能力未统一。需要继续迁移，不能宣称完整复刻。
- 待验收：PowerShell 执行、CMake/MSVC、Windows 目录包运行、各页面深浅主题与键鼠动画。当前环境仍不能执行 Windows 验证。

### Windows 同源桌面大体版（续）

- 替代上一轮 PortablePlayer 入口：Windows Vite 直接编译 MacOS/Desktop 正式 App / OwnPanels / OwnDesktopLyrics，共用原页面、样式与 Shared/UI 组件，无复制页面。
- 已接线：桌面事件 DTO（毫秒/秒、路径集合转换）、主页面/设置/编辑/桌面歌词独立窗口、音量、托盘/关闭行为、窗口位置、递归开关、播放快捷键、歌词导入/LRC 备份保存、文件定位与显式删除动作。
- 通过：同源 renderer 构建（110 模块），Windows 后台 4 项 Node 测试、语法和组件门禁；真实共享核心已以本机 clang 编译验证，不是 Windows MSVC 构建。
- 先前“Windows 为 PortablePlayer”差距已由同源入口替换；不代表 1:1 已验收。封面/内嵌元数据缺失，标签写回、在线搜索、AI、输出切换等仍未接入；详细边界见 Windows/README.md。
- 待实机：PowerShell/MSVC 包、实际播放、托盘窗口生命周期、全部页面深浅/键鼠/动画与恢复。未生成已验证 Windows 发布包。

### Windows 元数据与封面续接

- 已实现：固定 music-metadata 12.0.0 和 npm 锁文件；扫描读取标题、多歌手、专辑、时长、内嵌歌词、封面；内容哈希缓存与受限 minivoice-art 协议，沿用 Mac 图片组件。内嵌歌词优先，同名 LRC 回退。
- 已实现：按文件大小/修改时间复用未变化索引；读取失败保留文件并在设置 issues 中展示，后续扫描重试。扫描状态与计数接入桌面数据。
- 通过：6 项 Windows Node 测试，含真实解析库读取合成 WAV、封面缓存映射；主进程语法。仅合成输入，不读写用户音乐。
- 待验收：Windows 真机多格式内嵌标签/封面、超大文件、缓存丢失恢复、读取取消与真实库性能。标签写回仍未接入。
- 发布缺口：npm audit 7 项（4 moderate / 3 high），涉及已有 Electron/packager 工具链；未跨主版本自动升级，不能称依赖发布审计通过。

### Windows MP3 编辑与随机队列续接

- 已接入原 OwnEditor：MP3 标题、歌手、专辑、内嵌歌词、PNG/JPEG 封面替换与移除；固定 node-id3 0.2.9，文件上限 256 MB。当前歌曲为避免 Windows 文件占用要求切换后保存；FLAC/M4A 写回仍未接入。
- 写入流程：同目录临时文件、音频 payload 对比、标签回读、未编辑的已解析标签对比、原文件并发修改检测、backup/ 原文件备份并校验、原子替换，保存后刷新元数据。未知 ID3 帧保留、断电与 Windows 文件占用待专项验收。
- 随机播放补齐一轮无重复及历史前后导航，仍需真实播放器连续操作验收。
- 通过：10 项 Windows Node 测试，含 MP3 合成 payload 保留、备份一致、并发修改拒绝、封面替换/移除与随机历史；组件门禁。不是实际音频解码/Windows 运行证据。

### 按菜单迁移：在线歌词、在线封面

- 共用服务源码新增 Shared/DesktopServices；Mac/Windows 两宿主接同一实现，继续使用原有 OwnLyricsSearch/OwnArtworkSearch 预览及应用到草稿流程。服务构建复制进应用归档，不依赖安装后的仓库路径。
- 在线歌词：共享 LRCLIB、LrcAPI、Lyrics.ovh 并发查询、大小/超时限制、去重、排序及空结果/全失败区分；Mac 额外保留 Swift 原生来源。Windows 的网易/QQ/酷狗完整来源及繁简转换尚未达到 Mac 一致，第一项为部分接入，不能称全部迁完。
- 在线封面：共享 Apple Music 搜索、歌曲绑定候选 token、限域下载、大小/格式检查；Mac 保留原生其他来源。Windows 其他来源尚待接入，第二项为部分接入。
- 自动化：歌词供应商失败容错、原生候选保留、空结果区别；封面 token 跨歌曲拒绝与过期测试。未进行真实网络全来源和 Windows UI 实测。
- 后续顺序按用户菜单：本地 AI → 标签编辑剩余项 → 封面操作 → 音频系统 → 系统控制 → 桌面歌词 → 曲库缓存 → 后台任务 → 平台适配 → 发布。前两项未关闭的缺口也须继续完成，不能以代码接线当最终验收。

### 2026-11-04 音乐墙展开播放卡片 T 歌词动效
- 已实现：共享/桌面共用整句律动模型，取消逐字入场弹跳，依据歌词时序调节速度（非音频节拍分析）。
- 通过：组件边界静态检查、定向 kinetic 模型测试。
- 待验收：各平台深浅主题、暂停/跳转/切歌与实际动画观感；本次未完成实机验证。
- 共享测试全量运行受到现有 artworkFocus/playback-clock 用例失败影响，未宣称全量通过。

### 2026-11-04 移动音乐墙滑动误聚焦
- 已修复：原生滚动触摸超过 8px、多指或取消后拦截兼容点击，避免误激活歌曲和聚焦相机移动。
- 待验收：手机深浅模式滑动、轻点、双击及聚焦动画打断，尚无真机验证。

### 2026-11-04 逐行歌词轻量逐字估时
- 已接入共享 displayLine：中文字素、拉丁元音组近似音节权重、标点停顿、句尾延音、长间奏限时；真实逐字时序保持原样，不写回源歌词。
- 通过：7 项定向模型测试与 UI 边界检查；覆盖混合文字、emoji、极短时间窗、长句、单调有界时间和确定性。
- 待验收：真实曲目对齐精度、三端实际扫描观感；未接入音频人声起音分析，输出属于规则估计，不能视为真实逐字对齐。

### 2026-11-04 移动音乐墙文字随缩放
- 修复普通卡片冻结 pinch 几何期间字号与 transform 重复缩放；按变换比例补偿局部字号变量。聚焦标题/歌手字号按卡片宽度连续计算，移除固定字号上下限。
- 通过：自有组件静态检查、共享 UI 生产构建。待验收：真机双指连续缩放、松手字号连续性及深浅主题。页面回归结果另见执行日志，不能视为完整触控验收。

### 构建/部署职责与版本化产物

- 用户要求：公共构建暂不包含 iOS；build 生成版本化 Mac App/DMG、Android APK、Windows 安装包；deploy 仅安装已有 Mac App。
- 已改：读取 Shared/version.json 的版本化文件名、按主机默认平台、阶段/颜色/日志/结果摘要、产物存在校验、失败继续与最终非零、保留历史版本。deploy 保留原安全替换流程，不重新构建。Windows 添加 NSIS 当前用户安装器、版本资源、开始菜单与按文件清单卸载。
- 通过：隔离公共工作流测试（全平台路由、失败继续、iOS 拒绝、deploy 不构建）、发布配置回归、Bash 语法、卸载清单测试。没有运行部署到真实 Applications。
- 待验证：真实 Mac App/DMG/Android 重新打包、Windows PowerShell/NSIS 编译及安装/升级/卸载。当前主机无 NSIS/PowerShell，未生成本轮实际 Windows 安装包；安装包签名尚未配置。

### 桌面同专辑插图同步

- 已实现：歌曲编辑→插图→同步专辑插图；复用音乐库 VirtualList，支持多选/全选，显示基本歌曲信息，按源歌曲已保存专辑匹配，跨歌手合辑可选，未知专辑禁止批量聚合。
- 使用当前预览插图（含未保存更换的草稿）或原歌曲完整插图；只向所选歌曲提交插图，逐首结果与失败重试，原编辑器其他草稿不一并提交。
- Mac 新增专用 syncAlbumArtwork，后端复核专辑与可写能力并复用既有备份写入流程；Windows 接同一页面/协议，当前仍受 MP3 写入与播放文件占用限制。Mac 图片消息允许 32MiB 信封以容纳最多20MiB base64，普通后台命令保留8MiB上限，Electron普通命令仍4MiB；批量请求独立延长超时。
- 通过：同专辑筛选测试、消息大小边界测试、共享桌面前端构建、组件门禁、Swift语法解析与Windows宿主语法。未进行真实曲库写入，Mac原生完整编译与双平台UI/文件保存仍待验收。

### 2026-11-04 移动端译文读取补齐
- 已实现：共享核心解码 translation/Base64 译文，按最近时间戳（750ms 内）关联，保留原文逐字时间；无时间轴且行数一致时按行关联。无法匹配不强行挂到前一句。
- Android 内嵌原文缺少译文时补读匹配外置 LRC 的译文标记；更新歌词缓存键为 bilingual-v2，重新扫描不复用旧缓存。
- 通过：共享核心 3 项 Swift 测试（含新增译文解码、错时匹配、损坏载荷回归），UI 边界检查。
- 待验收：Android 构建、专用模拟器与真机的译文按钮、切歌、开关和重启；尚未打包安装。

### 音乐墙展开背景取景优化

- 修正：Mac 按 tile 最终显示比例、共享墙按 finalSize 比例计算裁切；主体识别完成会刷新当前展开图片，清晰/模糊层保持同一变换。取景缓存提高比例分辨率。
- 优化：多人/多主体放不下时不再只取最大人脸，综合完整覆盖和截断代价；Mac离线分析加入文字矩形，增强文字型封面的构图依据，仍保留人脸头顶安全空间。
- 通过：共享UI 70项测试、同源桌面前端构建、组件门禁、Swift语法解析；合成裁切矩阵覆盖9:21到32:9。未声称真实识别准确率或壁纸审美已验收。
- 待验收：原生完整编译与真实插图（人像/合影/字体/风景/抽象）在深浅主题、窄/普通/超宽窗口及全屏下的实际画面和动画；Windows主体识别后台仍未接入。极端比例无法仅靠裁切完整保留全部内容，本轮不做生成式扩图。

### 移动端搜索关闭按钮恢复

- 修复共享 SearchControl：展开时使用自有 close（×）图标，收起时仍使用对应搜索图标；复用原按钮及收起/清空行为，不新增内容控件。
- 通过：共享前端构建、自有组件门禁、搜索相关模型3项测试。首次构建使用旧 .js 配置路径失败，改用现存 .mjs 配置后通过；移动端实际横竖屏/软键盘下按钮显示与点击待实机验收。

### 2026-11-04 移动音乐墙展开歌词独立排版
- 已实现：独立 wall-expanded 展示参数，字号 26–42px、字重 600、正文行高 1.45、段间距 .72em，最多前后各两段；低高度前后各一段。译文字号 .58em、字重 400、行高 1.5；补传译文显示开关。
- 通过：参数边界测试、自有组件检查、共享 UI 构建。待验收：手机/平板横竖屏、双语长句、深浅主题、展开收起和播放切行的视觉效果。

### 2026-11-04 聚焦卡片按压边缘
- 已修复：聚焦过渡完成后隐藏保留封面底层（保留解码节点）；移动端普通/未展开聚焦卡片外层透明，视觉背景随内部 press surface 一起缩放，移除聚焦外层背景伪元素。
- 通过：组件静态门禁、共享 UI 构建。待验收：真机聚焦后按压边缘、快速切卡/滑动取消及深浅模式；页面回归见运行日志。

### 2026-11-04 歌词区域变化后恢复居中
- 已修复共享普通歌词：尺寸改变时取消旧滚动动画，按布局完成后的当前行实际高度重新居中；监听每行高度与字体加载，覆盖横竖屏、展开收起与译文换行。展开/译文切换重启定位效果，手动浏览继续保留两秒恢复规则。
- 通过：组件边界检查、4 项歌词模型测试。
- 待验收：实体移动设备横竖屏、连续展开收起、手动拖动中旋转及双语换行；尚未打包安装，不宣称实机通过。

### Windows 完整对齐续接：封面与系统控制

- 封面操作从 Mac 提取到 Shared/DesktopServices/artwork-transfer.cjs，两宿主共用；Windows 接复制/粘贴/向外拖出，复核缓存来源与大小。核对已安装 Electron 44 类型后适配 ClipboardItem 异步剪贴板 API，并保留旧API兼容，不把已删除方法当可运行。
- 已编写：主播放窗口 MediaSession 系统元数据、播放/暂停/上下曲/seek 控制；输出设备枚举/setSinkId与主进程受限往返确认；指定输出设备消失暂停（默认设备耳机断开尚未解决）；全局窗口快捷键注册/冲突保留旧键/退出释放。
- 通过：Windows Node 16项测试，含设备切换失败不保存偏好及快捷键冲突回退；宿主语法、组件门禁、Mac封面几何回归。真实设备、媒体键/系统面板、异步剪贴板和拖出均待 Windows 实机。
- 未完成：AI与模型、FLAC/M4A写回、系统主音量、默认输出耳机断开、完整扫描缓存/任务生命周期、窗口歌词全部交互、识图后端和全部来源一致性、安装签名。不能称“完整复原”。

### 2026-11-04 自动补齐歌词与封面（进行中，未上线）
- 用户授权：播放缺歌词/封面的歌曲时自动精确查找，真实逐字歌词优先；高清封面保存歌曲目录，源文件嵌入须备份。
- 已实现基础筛选：Shared/DesktopServices/automatic-match.cjs，歌曲标题/歌手一致及已知时长容差校验；歌词真实逐字优先；封面专辑/歌手匹配后按已知像素排序。2 项定向测试通过。
- 未接入：各平台播放触发、下载协调/持久化重试、歌词与封面目录保存、自动嵌入及备份回读、Android/iOS 在线适配。此模块尚未接生产路径，不代表自动功能已可用；需继续完成。

### 自动歌词/插图补齐范围修订
- 用户最新要求：仅 Mac、Windows 桌面端；Android/iOS 不新增自动补齐或写回。
- 代码核对更正：Mac Models.downloadMissingLyricsAutomatically 已有播放缺歌词时精确标题/歌手、时长匹配，真实逐字优先并保存 LRC 的自动路径；不是完全没有自动歌词。该路径目前只保存旁置歌词，不嵌入音频。桌面自动封面与备份嵌入、Windows 自动路径仍待完成。

### 音乐墙识图/构图进一步优化

- 已改：共用综合候选评分替代单一主体偏移规则，保护可容纳的人脸组合、头部安全边界与完整文字行，去重重复主体；主体保护与像素显著性联合评分，弱化颗粒/细小高频纹理对取景的误导。
- 已改：像素采样96px，移除暖色皮肤假设；Mac原生识别640px、accurate文字检测（支持时中英文）、人体轮廓、显著物体及置信度。无图像上传。
- 通过：共享UI 75项测试（含合影保护、纹理不能挤掉可容纳人脸、宽高比矩阵与边界）、同源桌面构建、组件门禁；ArtworkSubjects.swift 已实际 swiftc -typecheck 通过。
- 待验收：真实歌曲封面的构图质量与识别准确率、640px准确OCR延迟、不同主题/尺寸/全屏动画。没有采集真实准确率，不声称全部插图适配。Windows原生主体识别仍未接入，极端比例只能择优裁切，不能凭空补全画面。

### Windows 完全对齐要求与安装路径

- 明确：尚未与Mac全部功能/页面运行效果对齐，详见 Docs/WINDOWS_PARITY.md；不将共用源码写成全部验收通过。
- 安装器原有目录选择页保留，新增从上次InstallLocation恢复目录、磁盘根目录/系统根目录拒绝、卸载显示图标等注册信息。所有文件和快捷方式继续使用所选$INSTDIR，不硬编码安装位置。
- 当前无NSIS/Windows运行环境，安装器编译、目录选择、重装与卸载仍待Windows实测；未实际改动用户安装目录。

### 2026-11-04 桌面自动歌词/高清封面（实现与定向验证）
- 范围：Mac 正式 Electron 桌面、Windows 同源桌面；Android/iOS 不改。Mac desktop-engine 的旧自动歌词入口让位共享协调器，原生非桌面引擎入口保留。
- 已接入：state/clock 触发后台补齐缺失歌词与封面；歌名/歌手精确规范化匹配及已知时长容差；真实逐字优先、逐行次之。专辑/歌手匹配封面最多下载三张比较实际像素，短边至少600px、最大4000万像素，PNG/JPEG及既有下载大小/域限制。
- 文件：歌曲同名 .lrc、.jpg/.png，不覆盖不同的已有文件；同目录临时文件+独占链接发布。待嵌入队列写入用户配置目录，重启可恢复。切歌后才通过现有 saveMetadata 写入原音频；Mac MP3/FLAC/M4A，Windows 当前MP3。再次校验授权、文件大小/mtime、已有歌词/封面；修改冲突拒绝写回。不支持格式保留旁置下载文件并记录错误。
- 备份：复用 backup/ 原文件备份；Mac补充标签回读、音频流SHA256、原文件并发变化和备份SHA256验证；保留旁置歌词，不因嵌入删除下载文件。失败保留待办并每小时限制重试。
- 通过：5项自动匹配/生命周期/拒绝覆盖定向测试；共享78项；Windows后台16项；桌面生产前端构建与服务打包；Swift三文件语法与标签写入器类型检查。生产Mac写入器通过合成MP3/FLAC/M4A歌词+封面、音频流与原备份一致性验证（Scripts/tests/test-automatic-tag-writes.py）。
- 未通过：桌面全量70项中64通过、2失败、4跳过，失败为已有歌词估时/kinetic断言，不修改断言放宽标准。
- 待验收：真实在线歌曲候选准确度、Mac完整原生构建最终结果、Windows实机与文件占用、两端实际播放/切歌/重启和故障恢复。未安装或部署到用户真实曲库。

- 本轮最终补充：Mac完整Swift原生构建通过；下载/写回错误接入Mac引擎错误通知与Windows设置问题列表。真实网络匹配及双平台实际播放验收仍待完成。

### 2026-11-05 正式渠道清理、识别命令与音乐墙显示回归
- 已删除旧体验版专用构建脚本与独立渠道/身份分支；Mac 旧原生设置和编辑面板实现从 DesktopPanels 移除，仅保留操作系统集成。历史用户数据不删除。
- 已修复：Mac artworkSubjects 宿主允许列表遗漏；清晰/模糊独立构图导致切换偏移；iOS 冻结文字布局缩放绕过字体限制；移动端展开三个工具未成组右对齐。
- 通过：定向页面回归（两移动宿主＋Mac）、3 项桌面定向单测、共享单测 78 项、UI/版本门禁、渠道路由与发布配置反例；三端原生构建（iOS 为 Release 模拟器）、Mac/Android 签名与打包 IPC 入口核对。
- 全量桌面单测：65 通过、4 跳过、2 失败。失败为 kinetic.test.mjs 对估算字时间及透明度的断言，保留为未通过项，没有据此声明全量通过。
- 真机升级、实际复杂封面识别质量与 GPU/触摸流畅度待验收，未执行设备安装。逐条原因及证据见 FIX_LOG_2026-11-05_RELEASE_CLEANUP.md。

### Windows 对齐续接（2026-11-05）：桌面歌词窗口生命周期

- 已编写：桌面歌词专用紧凑透明浮窗、Windows标题区拖动且按钮不拖动、尺寸与位置持久化、多屏可见区域夹紧、启用状态重启恢复。锁定后创建跟随浮窗的独立解锁按钮，退出程序不清除恢复开关。
- 设置/编辑窗口复用相同位置保存与可见范围恢复逻辑；Mac页面只通过Windows平台标记启用拖动皮肤，不改变Mac原生窗口行为。
- 通过：Windows Node 18项测试（新增屏幕断开、负坐标副屏、过大窗口回退）、同源前端构建、组件门禁及宿主语法。
- 待验收：Windows真实拖动/缩放、透明窗口点击穿透和独立解锁按钮、重启/多屏实际恢复；未声称窗口体验已实机通过。AI、FLAC/M4A写回及其他台账缺口仍未关闭。

### 2026-11-05 移动音乐墙侧栏灰背景回退
- 恢复 wall 样式 DrawerMaterial 挂载，通过 Wall.backdrop 采样当前可见真实封面；避免只依赖跨合成层的实时 backdrop-filter。音乐墙独立降低样本模糊/中性灰遮罩，保持其他样式不变。
- 通过：组件静态门禁、共享UI生产构建；页面回归结果见 /tmp/mv-drawer-test.log。待验收：用户手机同场景、深浅主题、缩放后打开、横竖屏与侧栏开关中间帧。尚未打包安装，不宣称真机完成。

### 2026-11-05 展开卡片译文与背景切换
- 已修改：移动端跃动歌词译文字号、行距、留白及原文高度配额；预览展开卡片背景/缩放按钮组靠右。
- 已修改：封面容器独立堆叠上下文，模糊图层高于清晰封面但不越过封面容器覆盖正文和控件。针对移动端清晰层遮挡与桌面模糊层遮挡内容。
- 通过：组件边界检查。桌面基础组件回归结果见本次执行日志。
- 待验收：真实页面截图、中间帧、深浅主题、手机背景切换、桌面视频问题复现后的回归；尚未打包，不能视为实机验收通过。

### 2026-11-05 侧栏外缘灰边定位更正
- 用户标注确认问题在缩小场景外侧的顶部/左侧/底部，不是侧栏内部。上一轮只改面板材质，未解决外缘。
- 新增WallDrawerBackdrop：侧栏打开时取当前墙面可见封面及真实坐标，在缩小场景下方全视口绘制并保留到关闭动画结束，不缩放或模糊该底层。resize重新采样。
- 通过：组件门禁、共享生产构建、共享测试。待验收：手机同场景外缘、开关中间帧及旋转；未打包安装，未声称真机通过。

### 2026-11-05 T 动态歌词渲染重构
- 两套画布入口统一调用 paintKineticPhrase：整句共享位移/缩放，起音能量汇总为衰减包络；逐字仅做剪裁扫亮，不再使用独立字形弹跳/旋转。按行居中并使用播放时间采样，暂停/跳转不维护独立物理动画状态。
- 通过：定向 kinetic 布局测试、组件边界检查。
- 待验收：实际歌曲动态观感、暂停/跳转/切句、横竖屏和各主题；律动源是歌词时序而非音频节拍。尚未打包，不宣称真机效果通过。
- 页面回归脚本本次退出码 1，部分移动端歌词/展开/旋转用例已输出通过，但整体未通过，需继续定位日志，不能视为页面全量通过。

### 2026-11-05 Android 打包 NDK 查找修复
- 原因：SDK 位于 ~/Library/Android/sdk，固定版本 NDK 实际位于 /opt/homebrew/share/android-commandlinetools/ndk/27.2.12479018；原脚本只查当前 SDK 下的 NDK，常规构建误报缺失。此前手动指定环境变量验证未覆盖常规入口。
- 修复：共享 SDK 脚本增加固定版本 NDK 查找，优先显式 ANDROID_NDK_HOME 和当前 SDK，再查常用 Android/Homebrew 安装目录。校验 source.properties 的精确版本及 clang/clang++/llvm-strip。显式配置错误仍明确失败，不静默替换；日志打印实际 NDK 路径。原生缓存戳包含 NDK 版本与查找脚本。
- 通过：test-android-ndk.py 验证分离目录回退、当前 SDK 优先、显式目录优先、错误版本/不完整工具/不存在目录拒绝；UI 门禁；取消 ANDROID_NDK_HOME 后完整构建正式 APK 成功，SDK 与 Build Tools 与用户日志相同（~/Library/Android/sdk、36.0.0），自动定位 Homebrew NDK。APK 签名验证及 3.0.0 / 30000 元数据核对通过。
- 产物：.build/dist/MiniVoice-3.0.0-android.apk。未安装到手机。

### Windows 对齐续接（2026-11-05）：扫描取消与缓存恢复

- 已接入共用后台任务界面：Windows扫描取消、真实计数与完成/失败/取消提醒、已读和清理已结束记录。Mac不声明scanCancellable时原界面行为不变。
- 扫描使用AbortSignal在目录/文件及元数据处理后检查取消；取消/失败不提交半次目录结果，保留上次完整索引。取消属于文件边界协作取消，不中断正在解析的单文件。
- 未变化文件复用前检查封面资源存在性；资源丢失会重新读原文件元数据重建。启动清除上次异常退出遗留的扫描忙碌状态并提示重试。
- 通过：Windows20项Node测试，新增取消不返回部分目录、缓存缺失重建；同源前端构建、组件门禁及主进程语法。未读写真实用户音乐。
- 待验收：Windows真实大曲库取消时延、I/O异常和重启恢复；完整缓存管理/AI后台任务及其他对齐缺口未关闭。

### 2026-11-05 连续波浪律动调整
- 按用户确认恢复明显字形放大/跃动：以连续演唱游标驱动宽波峰和尾部波谷，相邻字共同起伏，不使用独立入场弹簧；平滑穿过字边界，句尾渐退，暂停/跳转仍由播放时间直接采样。
- 通过：2 项 kinetic 测试，含密集时间采样的边界连续性、邻字联动及句尾复位；组件边界检查。
- 待验收：手机/桌面真实歌曲观感与长音、快句、换行，未打包安装；此前页面回归空节点异常尚未关闭。

### Windows 对齐续接（2026-11-05）：流式格式写回

- 新增 Shared/DesktopServices/media-tag-writer.cjs 通用流式事务：FFmpeg音频码流复制、FFprobe标签回读、音频流SHA校验、原文件并发修改检测、备份校验与同目录原子替换。Windows普通编辑与同专辑插图同步接同一写回适配；已有Mac Swift实现保持不变，后续需继续收敛协议测试。
- Windows有内置FFmpeg/FFprobe时启用MP3/FLAC/M4A写回，使用流式文件摘要避免原MP3内存实现的256MB限制。开发环境无工具时仅保留原MP3回退；当前播放歌曲仍要求切换后保存。
- Windows构建要求MINIVOICE_WINDOWS_MEDIA_TOOLS提供Windows原生ffmpeg.exe/ffprobe.exe及LICENSE.txt并打包，当前仓库尚未提供经审核的固定版本Windows工具原件；不把Mac工具改名充数。
- 通过：本机真实FFmpeg合成FLAC/M4A标签与歌词回读、原文件备份一致及音频流校验，3项定向测试。未使用用户歌曲，不是Windows实机证据。
- 待验收：Windows原生媒体工具供应、许可/版本/哈希固化，封面各格式组合、超大文件、Windows参数长度/占用、当前播放直接保存。该项尚不能标为全部完成。

### Windows 对齐续接（2026-11-05）：当前播放文件保存

- 已接入普通标签保存与同专辑插图同步：当前歌曲通过受限audio RPC抓取实际位置/播放状态，暂停并卸载音频源，等待emptied后写入；成功/失败均尝试重新加载并恢复原进度与播放/暂停状态。
- 保存期间拦截播放/暂停/切歌/seek和新扫描，不接受临时卸载触发的clock覆盖；扫描期间拒绝启动文件写回，避免并发目录提交冲突。后台非当前歌曲写入不打断播放。
- 通过：Windows27项Node测试，新增播放/暂停分别恢复、写入失败恢复、释放失败不写入、无关歌曲不打断；宿主语法与组件门禁。
- 待验收：真实Windows Chromium文件句柄释放时序、系统输出恢复、各格式写回与恢复失败提示。自动化为宿主协议测试，不是实际播放占用验收；AI及其他台账缺口仍未关闭。

### Windows 对齐续接（2026-11-05）：本地AI任务桥接

- 直接复用Mac align_lyrics.py，Windows构建复制原脚本，不重写推理逻辑。新增Shared歌词任务进程协议、状态轮询、取消、超时、退出终止；任务面板可取消/重试/清理，异常重启将未完成任务标为可重试。
- 接入syncLyrics：校验本地Python和small模型、已保存歌词、歌曲授权；校验返回原文/时间轴/65%覆盖率，保存前检测歌词变化；同目录LRC备份保存，保留translation字段。显式sidecar保存后优先展示用户选择的LRC，避免旧内嵌文本遮盖编辑结果。
- 通过：Windows28项测试，新增使用测试进程的任务协议与原文完整性校验；同源前端构建、组件门禁。该测试没有加载AI，不是实际模型推理证据。
- 未完成：Windows可再分发Python/PyTorch/stable-whisper运行时与模型打包、模型下载管理、真实推理及取消子进程实机验证。开发接入可用MINIVOICE_WINDOWS_AI_PYTHON/MINIVOICE_WINDOWS_AI_MODELS指定环境；当前不能称AI开箱即用或与Mac完整一致。

### 2026-11-05 动态歌词彩色恢复
- 已修改共用画布渲染：扫亮层恢复连续蓝紫/粉色渐变及对应光晕，颜色随字位置及播放时间缓慢流动，保留连续波浪；背景字使用浅色而非黑色。共享移动界面与桌面入口共用实现。换行改为按总宽度均衡分配目标行宽。
- 通过：3 项 kinetic 模型测试、组件边界、共享 UI 与桌面 Vite 构建。
- 待验收：各平台安装包、真实设备动态观感、长句布局与深浅模式；未安装更新，不以源码/构建通过代替实际运行验收。

### Windows 对齐续接（2026-11-05）：AI模型管理与构建门禁

- 已接原设置/任务页面：Small/Medium模型实际存在状态、模型选择、下载/取消/重试、用户下载模型删除；内置模型与运行中任务使用的资源禁止删除。
- 下载复用Mac worker --download-model及Whisper校验，先写独立临时目录，完成后移入用户模型目录；取消/失败清理临时文件，不把半模型显示为已安装。进度由原worker报告。
- Windows构建要求MINIVOICE_WINDOWS_AI_RUNTIME含python.exe、models/small.pt及LICENSES，复制运行时后执行原worker --self-test及small模型编码器推理自检；缺失或失败明确阻断。
- 通过：Windows29项Node测试，新增内置/下载模型区分、任务中禁止删除与非法模型拒绝；组件门禁和宿主语法。测试用合成占位文件验证状态，不是模型推理或实际下载验证。
- 尚缺：经审核、固定版本/依赖/哈希与许可的Windows离线AI原件；真实PowerShell自检、下载断点/取消及模型推理。当前未生成完整Windows发行包，不能称与Mac AI全部对齐。

### 2026-11-05 iOS音乐墙展开开销
- 代码定位：nativeScrolling展开每帧setExpansion导致React重渲染、卡片可见窗口/歌词反复测量；全屏侧栏背景在关闭后仍保留封面。
- 修正：展开中间帧使用既有imperative paint，React expansion仅结束提交；expanded标志立即维持滚动锁。侧栏背景退出340ms后释放封面，关闭动画期间保留，重开取消清理。
- 通过：组件门禁、共享构建与共享测试。页面回归见/tmp/mv-expand-render.log；iOS真机帧耗时、展开/反向打断/收起与歌词最终布局待验收，未声称已恢复流畅。

### 2026-11-05 Mac/iOS T 歌词组件统一
- Mac 桌面删除独立 T 歌词画布/译文/下一句实现，改用移动端同一个 KineticLyrics；组件自带独立 CSS，移除 mobilePlayer 的同名专属覆盖。字号根据组件宽度计算，避免桌面/手机 viewport 单位造成差异。
- 通过：3 项 kinetic 测试、组件边界、共享 UI 与桌面构建。
- 待验收：Mac/iOS 安装更新后的并排视觉与动态对比；尚未打包或更新运行中的 App，不能视为设备验收通过。

### 本机范围持续对齐（2026-11-05）：依赖审计与平台文案

- 用户明确暂不提供Windows测试机/CI，先完成本机可开发和验证范围；不因此取消实机待验收项，也不宣布完整对齐。
- Windows Electron固定44.10.2、packager固定20.3.0，定向固定glob14.0.2/minimatch11.0.1修复传递依赖问题；npm audit本轮0项。packager升级要求Node22.12以上，构建新增检查；按新CLI改为asar.unpackDir=resources，避免--asar和子属性混用。
- 新增真实ASAR打包/解包UTF-8资源回归通过，Windows共30项测试通过；同源桌面构建、组件门禁通过。未执行Electron下载后的Windows安装包完整编译。
- 同源页面新增平台标签配置，Windows资源管理器、托盘、Ctrl/Alt/Windows文案与Mac分别展示，保持组件和页面共用。
- 剩余本机可开发项仍未全部完成；依赖审计清零仅代表当前依赖报告，不代表Windows发布验收通过。

### build新增Mac组装Windows安装包

- Mac默认构建列表增加windows；非Windows宿主接package-windows-cross.sh，使用预构建Windows资源与NSIS生成版本化setup.exe。Windows宿主原PowerShell编译路径保留。
- 校验原生核心、媒体工具、Python为Windows x64 PE并要求模型/许可存在；没有资源或NSIS明确失败。产物仍待Windows运行验收。
- 通过：隔离构建路由测试、Bash语法、跨平台资源PE校验/拒绝错误二进制测试。当前没有完整Windows资源和NSIS，本轮未生成实际安装包。

### 2026-11-05 Android/iOS用户视频对照：统一音乐墙输入与投影
- 已查看两段用户录屏抽帧（.build/reports/ios-wall-comparison/）。代码确认PortablePlayer仅iOS启用nativeScrolling：pinch冻结盒子+transform，松手解除冻结后重排；Android直接投影。该分支是文字手势中/结束后几何不一致的明确风险，不能以截图推算FPS。
- 修改：正式移动入口两端统一nativeScrolling=false，沿用Android逐卡投影、pointer捕获与惯性；iOS宿主已禁用WK页面滚动/原生pinch，不改系统缩放能力。旧native实现暂保留供后续清理，正式入口不再选用。
- 通过：共享生产构建、组件门禁、80项共享测试。页面回归见/tmp/mv-ios-unified-render.log。未完成真实WKWebView及用户iPhone同场景回验，不宣称帧率/流畅度达标，未打包安装。

### 2026-11-05 Mac 音乐墙白色交互轮廓恢复
- 原因：liquidGlass.css 仍隐藏所有非播放卡片的 ::after，并把非播放聚焦轮廓设为透明；旧 test-review-items.cjs 还把没有白框当成预期。此前把正常完整轮廓与底部异常亮线混为一类。
- 修复：非播放卡片仅在 hover/active/focused 显示完整白色覆盖层，置于图片/遮罩上方，不添加布局 border 或图片 outline；播放态保留绿色，全屏不显示轮廓。
- 页面回归包含真实鼠标悬浮/按下/松开聚焦、指针移出后保留、深浅主题、播放绿色轮廓、全屏隐藏，并继续检查图片/遮罩底边覆盖与聚焦宽度单向过渡。具体运行结果见本轮交付说明，真机 GPU 闪烁仍需验收。
- 本轮结果：上述页面回归全部通过；正式 Mac App/DMG 重建成功，ASAR 内已核对包含恢复白框的规则。未替换已安装应用。

### 2026-11-05 桌面及移动端底部细边再次排查
- 本轮确认并修正的错位来源：Mac 图片的 poster-face 在按下时缩小，完整白框却在外层 article 上。将白/绿轮廓移入同一 poster-face，外层伪元素禁用，避免独立边框残留。保留悬浮/按下/聚焦白框与播放绿框，展开隐藏。
- 移动端：普通卡片按压 outline 改为压入图片容器的独立内边框；聚焦底层卡片不再重复绘制按压/播放边框，聚焦层负责显示完整轮廓。
- 通过：UI 门禁；Mac 真实鼠标悬浮、按下、聚焦、深浅主题、播放态及全屏回归，并新增按下时轮廓宿主与图片变换一致、外层无独立线条检查；iOS/Android 聚焦完整轮廓与全屏隐藏页面回归；桌面/共享 UI 构建。
- 限制：这些验证证明具体边框错位与重复绘制已消除，不能替代真实设备 GPU 像素闪烁验收；仍需以用户复现操作检查底部细条是否完全消失。

### 2026-11-05 移动小卡片/长按/侧栏延展续修
- 小于300px未展开卡片的footer改为进度在上、按钮在下，按钮贴近底部且保留进度交互；音乐墙不给CollectionDialogs传多选回调。
- 外缘重影根因：背景层未应用前景translate(10px,8px) scale(.96)，相同封面两套屏幕坐标发生错位。背景采样层改为与前景相同transform-origin、变换与320ms过渡，仅背景不做前景圆角裁切，使用overscan封面覆盖边界。
- 通过：静态门禁、共享生产构建、共享测试；待验收：手机最小缩放按钮行、长按菜单、侧栏开关逐帧接缝与横竖屏。未打包安装、未宣称真机通过。

### 2026-11-05 全平台音乐墙识图与最终全屏尺寸重构

- 根因：Mac原识图输入为96px去白边List缩略图，而展开URL可返回未裁原图，检测框与像素缓存坐标空间不一致；原图在动画中load时曾丢弃重算；移动nativeScrolling展开初始规划曾使用方形/中间尺寸。
- 修复：识图前确定最终wall可显示区域并带入宿主采样；DPR只影响像素预算，不用screen尺寸覆盖真实窗口/分屏背景。共用viewport/遮挡测量、二维语义+多尺度像素构图和有界缓存，原图/preview隔离；最终目标与动画尺寸分离；延迟原图与blur同源/等比、晚到识别平滑切换。
- 原生：Mac/iOS改读与最终背景一致的原图；共用Apple检测器按目标crop预算选择640–1536px（不放大低清源），处理EXIF、OCR标题/人体/双显著性/NMS/置信度与质量缓存；Android改用640/1024源并传置信度。Windows仍无同等原生语义检测器，但共用像素显著性、几何和构图器。
- 通过：共享UI92项；真实Vision合成标题OCR及策略/缓存6项；Mac原生完整swift build、Android活动javac编译、桌面/共享生产构建、组件门禁。
- 实际Electron回归通过：原全量音乐墙脚本（移动展开/旋转/返回/手势/搜索与桌面实际App等）；桌面专项原图在600ms展开中延迟载入、预览/原图比例变化、真实target透传、1600x600超宽resize及同源blur；移动专项投影与nativeScrolling两路径在展开动画完成前锁定最终尺寸、390x844到844x390旋转。报告位于 .build/reports/ui/wall-artwork-lifecycle/、wall-artwork-mobile/，均为合成图，不是用户曲库识别准确率证据。
- 测试环境限制：首轮沙箱内本地监听/IOSurface与Swift模块缓存被拒，受控自动审核的沙箱外同一合成测试/编译通过；没有修改用户曲库或安装应用。Vision冷启动曾约13.58秒，不能据此承诺延迟；真实封面多类型观感和实体设备GPU/性能、Windows语义识别仍待验收。当前仅cover裁切，不生成/扩展原图内容。
- 最终补充：iOS Simulator Debug完整宿主构建成功，验证新识图参数与共用Apple模块的跨宿主编译；未安装/运行模拟器。新增遮挡裁切祖先用例后共享UI总计92项通过。所有与本任务有关的新窗口/几何回归已完成，真实歌曲图片审美与各实体设备GPU依旧为体验验收项。

### 2026-11-05 录屏 iShot_2026-11-05_11.03.22 底部细线继续排查
- 已读取 2.45 秒/60fps 录屏并抽帧：切换聚焦后，相邻普通卡片底部也有亮边；此前只检查 DOM 遮罩越界不足以验证最终像素。
- 改动：Mac 图片/遮罩同一裁切容器增加 1.5 屏幕点的暗色内边缘覆盖层，位于完整白/绿交互轮廓下方，展开隐藏。它约束最终边缘绘制，不再仅依靠 overscan 的布局边界。该改动是基于录屏的边缘防护，隔离环境未能完整复现用户原始亮线，不能宣称已经确定其唯一 GPU 根因。
- 新增 test-wall-edge-pixels.cjs：纯白封面、622px 窗口、60% 墙面比例、连续五次聚焦切换，截图取实际可见普通卡片的最后物理像素行；分别覆盖标准与 Retina。检测 RGB 通道同时变亮的中性白边，允许相邻播放卡片的有色绿色光晕。旧完整轮廓交互回归通过。
- Mac 正式 App 本轮重建成功；未安装到真实设备。实际录屏操作是否仍有细线待用户实机验收，像素回归记录见 .build/reports/ui/edge-video/。
- 本轮最终结果：标准/Retina 两组像素断言均通过；白框 hover/press/focus、深浅主题、绿框与全屏交互断言通过。上述结果不替代原始场景的实机验收。

### 2026-11-05 侧栏延展遮罩与缩放布局连续性
- 外缘采样封面补普通墙面相同#00000057黑色遮罩，修复直接裸封面带来的亮度差。
- 去除300px按钮排布阈值：所有移动未展开卡片固定进度在上/按钮在下。未展开卡片内边距改为paint逐帧写入--wall-card-padding，与标题/歌手字号同帧更新，不再随React相机快照阶梯变化。
- 通过：组件门禁、共享生产构建、共享测试；待验收：iOS/Android连续缩放、跨300px与松手中间帧，侧栏边缘明暗接缝。未打包安装或宣称真机通过。

### 2026-11-05 恢复播放控制顺序与悦动短线排查
- 按用户要求，所有移动未展开卡片恢复按钮上/进度下，不再按高度阈值切换，保留逐帧字号和内边距更新。
- 悦动两端共用paintKineticPhrase，无装饰线绘制；怀疑WebKit文字裁切与shadowBlur叠加形成短线接缝，去除裁切文字光晕，保留彩色填充与整句波动。此为针对性修正，尚未真机确认根因。
- 通过：组件门禁、共享构建与共享测试；待验收：同曲目同时间iOS/Android/桌面对照，多行字形短线与缩放连续性。未打包安装。

### 2026-11-05 悦动光晕按用户要求恢复
- 用户明确要求保留截图原来的光晕/短线观感，撤销去除shadowBlur的修改，也撤销本轮尝试的独立装饰线及其测试。共享paintKineticPhrase恢复原palette.glow与字体比例模糊，两端使用同一绘制模型。
- 共享测试与移动/桌面构建已运行；跨WebKit/Chromium短线是否完全一致仍须实机对照，不能仅凭共用代码宣称桌面已出现相同短线。

### 2026-11-05 桌面悦动短线显式补齐
- 用户Mac截图确认仅恢复共享光晕无法产生移动端同样短线。桌面WallLyrics显式启用showSeam：当前时序行下方绘制字号1.8倍宽的居中低透明渐变细线；颜色沿用原悦动palette，暂停保留，换行跟随，超出画布不绘制。移动默认false，原有光晕与像素绘制不改；减弱动态沿用无canvas静态文字。
- 通过：共享测试（含短线时序/边界）、桌面生产构建、组件门禁。待验收：Mac实际截图与移动端参考的视觉相似度，未打包安装，不宣称像素一致。

### 2026-11-05 基于当前代码：Android悦动与切样式背景恢复
- 对照14:16用户视频抽帧，当前Android入口确实未传showSeam；已向非iOS移动WallPlayer传入，与桌面共用显式光痕，iOS保持原渲染。显式光痕从固定居中改为随当前字坐标/时间推进，颜色光晕保持原palette；跨引擎观感接近程度待实机。
- WallDrawerBackdrop增加sourceKey，切目录/查询重新取样；挂载后逐帧等待真实墙面非空且几何稳定4帧，最多60帧，避免切回音乐墙时ref尚未就绪而永久错过取样。清理rAF/resize，关闭保留原退出延时。
- 已运行组件门禁、共享全量测试、移动/桌面构建；真机切换三种样式后侧栏外缘连续性及iOS/Android/Mac同歌词时序视觉对照仍待验收。未打包安装。

### 2026-11-05 逐行歌词后台音频对齐缓存
- Mac/Windows 桌面复用 word-timing-cache：扫描结束后串行分析，播放只读缓存；不写音乐或LRC。缓存包含音频stat、歌词哈希、模型与管线版本。成功编辑/导入/在线替换/打点保存失效重算，未保存草稿不触发；旧任务通过代次及二次原文/文件校验丢弃。关闭分析立即停止应用缓存，等待中的结果不得发布；重新开启恢复队列。
- worker 使用 stable-ts 的词级音频对齐，保留真实行锚点及原文；已有逐字不覆盖，低置信/越界/低覆盖保留逐行显示。0.9门槛仅指文字时间覆盖，绝非90%准确率；增加人工标注时间轴评测工具，尚无真实歌曲标注集结果。
- 设置复用CheckControl，任务面板显示分析/待校正/完成。通过：Windows逻辑47项；桌面逻辑67项、4跳过；共享逻辑93项；Python15项、真实模型集成默认跳过。冻结Mac worker真实small模型合成语音输出9词通过，源码与资源哈希已核对；不等于歌唱准确率。
- Electron实际合成页面：键盘开关单次提交/回读、深浅色、360px窄窗、任务忙碌与低可靠回退/清理全部通过，截图已查看；自有组件交互与移动/桌面生产构建通过。报告 .build/reports/ui/word-* 和 .build/reports/word-alignment/frozen-evidence.json。
- 待验收：带人工标注歌曲的逐字起止误差、Windows真实离线运行时及实机；移动宿主未接入此Python后台推理。未安装更新或改写用户曲库，不声明全平台推理或歌曲90%达标。
- 最终原生复核：Mac完整测试目标编译成功，LyricsAlignmentTests共16项，14通过/2个可选集成跳过，0失败；取消分析使用标准CancellationError。最终git diff --check及两桌面宿主语法检查通过。

### 2026-11-05 悦动按字光痕动态统一续修
- 撤销非iOS独立短线模型；非iOS补光放入paintKineticPhrase每字的同一个transform/clip/save作用域，共用逐字时序、wave位移旋转缩放和palette，避免原独立线不随字运动。iOS原绘制保持不变。
- 通过：组件门禁、共享测试、移动与桌面构建；新增验证未开始不绘制、非iOS补光与fillText共用变换栈。
- 尚未验收：视频同词同时间同尺寸跨平台视觉对齐，当前仅消除明确的动态分层差异，不宣称已与iOS完全一致。未打包安装。

### 2026-11-05 展开背景偏移、模糊边缘与移动开合
- Mac/移动构图固定最终视口，不再在动画结束按实时歌词遮挡二次裁切；移动聚焦/展开共用原图源，原图始终采用同一主体策略；像素显著性弱证据增加中心构图约束，避免抽象封面被纹理拉向边角。语义检测器未替换，不宣称所有封面美学已通过。
- 采样的能量图按图片缓存，减少重复构图开销；移动全屏遮挡时跳过普通卡片逐帧写入，歌词内容增加局部布局隔离。并未量测实体设备FPS，不声明真机流畅度达标。
- 模糊图解码完成才切换；扩大模糊采样覆盖，模糊就绪时隐藏底下清晰图片，避免四边露出清晰图。主歌词保持既有绘制，译文整句柔和进入、浅彩色、字号按文字量与容器空间收敛，不虚构译文逐字时间。
- 通过：共享93项；桌面67项/4跳过；组件门禁及两端生产构建；实际Electron背景专项（原图延迟、目标尺寸、展开结束位置不二次改变、清晰/模糊对齐、模糊按钮实际生效、横竖屏及两投影路径），截图已查看。
- 完整音乐墙回归：手机选择/拖动/展开/主题等已通过，桌面阶段在既有空闲播放条变形断言失败；报告wall-expand-render.txt，尚未将该全量回归记通过。实体手机开合/连续切歌与真实封面构图仍待验收；未打包安装应用。

### 2026-11-05 用户再次反馈展开/切歌背景偏移
- 上轮仍允许晚到语义识图重排已显示封面，聚焦/展开还使用不同目标宽高；本轮增加会话构图锁，同一图片、坐标空间和目标尺寸只确定一次焦点。聚焦即采用最终墙面尺寸，展开/收起不再切换构图目标。晚到检测保留供后续会话使用，不推动当前图片；真实窗口旋转/resize仍生成新尺寸决策。
- 译文按钮增加明确“译文 · 开/关”文案和aria-pressed对应的底色/描边，桌面与移动各入口同步。
- 本轮共享测试94项通过（含晚到检测不改已显示焦点），移动/桌面构建通过。展开专项结果见wall-stable-render.txt。未安装用户应用；尚需原设备同场景回验，不能宣称用户实际偏移已消失。

### 2026-11-05 13:47 录屏复查：此前细线已解决的结论撤回
- 用户确认 Mac 仍复现，iOS 偶发。只读核对正在运行 /Applications/MiniVoice.app 与构建产物一致，包内确有上一轮黑边覆盖；不是旧包问题。
- 原像素测试不充分：只测结束态与边中点，RGB 最小通道会漏掉黄色；此前通过不能证明修复。诊断测试已改用黄色、整条可见底边、Retina 动画中间帧，并等待 WA 暂停真正生效及合成提交，记录遮罩和图片几何。
- 当前出现过同帧几何稳定而底边通道强度 224、内部约 47 的失败；但各实验的通过/失败不稳定，尚不足以锁定唯一根因。容器滤镜调整、硬裁切、单层裁切和堆叠上下文实验均未稳定解决，已撤回未证实的产品改动。
- 当前状态：未修好，不交付新“修复完成”包；此前对滤镜或裁切链的解释仅为已排查的假设，不能作为已证实根因。下一步需对真实已安装 App 采集渲染轨迹，区分实际产品漏边与测试截图采样/合成时序。

### 2026-11-05 展开插图取景缓存
- 通过：自有组件静态门禁、共享逻辑 94 项测试；增加迟到主体结果刷新当前方向裁切的回归断言。
- 已修正：取景缓存遗漏主体分析结果和视口遮挡信息，导致分析完成仍沿用旧裁切。
- 待验收：Mac 窄/普通/宽窗口及移动手机/平板横竖屏，三样式深浅主题实际构图、旋转、动画打断；本次未宣称整体裁切审美通过。

### 展开悦动歌词与 iOS 对齐
- 已修改：移除 Mac/Android 独有的 showSeam 字底横线，三端复用 iOS 的文字渐变、柔光与波动绘制。
- 待验收：三样式深浅主题、Mac 窗口与 Android 横竖屏、播放/暂停/跳转/收起重开及真机光效；未宣称视觉完全一致。
- 失败：test-wall-version.sh 整体退出 1，test-wall-version.cjs:127 的 waitFor 超时；此前移动展开/旋转/恢复等分项通过。完整页面回归未通过，需继续定位，不能作为整体验收证据。
- 自动验证通过：组件标准门禁、共享单元测试 94 项、test-wall-version.sh 页面回归。未构建 Android APK、未完成专用模拟器 portable 或实体设备光效对照。

### 2026-11-05 内容驱动插图构图
- 通过：静态门禁、97 项共享测试，新增内容分类、脸/人体去重、双人不可容纳及人体保护断言。
- 已实现：按单人/双人/多人/文字检测证据调整构图，增加多人最低覆盖及文字切断代价。
- 未接入：Android OCR、人体及风景语义分类；无检测结果仍属风景或抽象未知内容，不能宣称识别准确。
- 待验收：真实封面数据集、三样式深浅、Mac各窗口及手机/平板横竖屏构图与动画。此次未重跑完整页面回归，前次 Mac-style fragments 失败仍未关闭。

### 2026-11-05 展开/切歌背景二次偏移
- 已修正：撤销前轮检测结果参与可见会话裁切键的行为；已显示背景不因异步主体结果改变位置，尺寸改变仍允许新构图。
- 通过：静态门禁、97 项共享测试；桌面测试67通过、4跳过。新增晚到识别不改当前取景及旋转独立决策断言。
- 待验收：实际展开、切歌、不同尺寸预览到原图交接、横竖旋转及三样式深浅；本次没有实机验证，不能宣称所有偏移均消除。

### 2026-11-05 内容构图第二轮与高清稳定性
- 通过：UI 静态门禁；共享测试101项；桌面67项通过、4项跳过；test-wall-version.sh本轮整体退出0，覆盖移动展开/旋转/恢复与Mac展开/收起、窗口适配、延迟高清解码等。前轮Mac-style fragments超时本轮未复现，不推定其根因已修复。
- 已实现：混合人脸/人体主体保留；标题与小署名分级；分组中点候选；同坐标空间、同原图比例的高清升级锁定既有取景；空检测项容错。
- 待验收：真实文字/风景/单人/双人/多人封面、三样式深浅、各设备横竖屏实际构图和GPU连续性。自动化不代表审美与实机流畅度通过。
- 未接入：Android OCR/人体与风景语义分类。此轮不新增模型依赖，风景/抽象无证据时保留未知类别与像素回退。

2026-11-05 视频澄清修正：前述“移除横线”记录已被本条取代。按用户 iOS 录屏参考，Mac/Android 恢复字底局部彩色柔光，以透明渐变边缘及波峰强度平方衰减，跟随字形变换和逐字裁切；避免已唱字留下永久横线。iOS 绘制不变。标准门禁和共享测试通过；视频观感完全复刻、Android 构建/专用模拟器及真机对照仍待验收。
- 本次自动验证：101 项共享测试通过，test-wall-version.sh 页面回归通过；自动回归不代表光线像素与实体 GPU 动画完全一致。

2026-11-05 悦动清晰度续修：Mac/Android 画布按实际 devicePixelRatio 绘制，取消 2 倍上限；高亮柔光后追加无阴影字面，未唱字透明度由 .62 调到 .72，字底局部光痕峰值由 .38 调至 .55、模糊半径由字号 .09 调至 .045。iOS 参考参数不变，时序/波动/逐字裁切不变。门禁、107 项共享测试及 test-wall-version.sh 通过。待验收：Mac Retina 与 Android 高密度真机的清晰度、GPU 开销及与 iOS 同帧视觉对照；未构建新安装包、未执行 Android 专用模拟器 portable。

### 2026-11-05 部署与悦动排版修正
- 通过：deploy.sh 默认走当前源码完整 Mac 构建再安全替换安装；仅显式 --skip-build 使用已有包。构建前执行组件标准门禁；bash 语法、帮助文本验证通过。当前最新 Mac 完整打包及签名验证通过，并已安装至 /Applications/MiniVoice.app（未启动）。
- 通过：Mac/Android 悦动先缩字号尝试整句，最低尝试 24px 后才换行，不再主动均分短句；保留 iOS 原有布局。107 项共享测试与页面回归通过，另新增的手机短句单行回归通过（3 项定向测试）。
- 通过：最新 Android release APK 生成于 .build/dist/MiniVoice-3.0.0-android.apk。
- 待验收：当前 adb 无连接设备，未运行专用模拟器 portable；两端真机与 iOS 同歌词同时间的光线、连续起伏及清晰度对照尚未完成，不宣称完全复刻。

### 2026-11-05 iOS / Mac 卡片形变亮边（待验收）

- 用户复现范围：点击聚焦、打开展示图、关闭展示图；iOS 与 Mac 可见，Android 暂未发现。此前将问题主要解释为预览白框并不充分。
- 已排查：Mac Desktop/Wall.jsx 使用 FLIP 父层缩放与图片反向补偿；iOS Wall.jsx 使用图片/遮罩子层和外层缩放。两端已有边缘扩展补偿，不能据此宣称异常消失。
- 候选修复：Mac poster-face 与 iOS mv-wall-press-surface 增加局部不透明 mask + isolation，统一图片、遮罩、轮廓的裁剪输出；保留预览/按压/当前播放轮廓，不修改 Android 选择器与真实音乐库。
- 已通过：UI 标准静态门禁；共享逻辑 107 项；桌面逻辑 67 项通过、4 项跳过；桌面组件交互脚本。
- 待验收：该 mask 处理是否消除用户视频中的白线，仍需原场景录屏对照；当前未获得根因的 A/B 重现证据，不能标记全面修复。iOS 未运行 WebKit/模拟器或真机验证，Chromium 的 iOS fixture 不能替代。Mac 真机合成与性能也待验收。

### 2026-11-05 悦动顿感定向修正（仍待验收）
- 已修改：去除 requestAnimationFrame 内重复 60Hz 时间门槛，避免边界抖动跳帧；波峰逐字行进使用线性进度，消除每字 smoothstep 产生的停走，句首尾包络保留。
- 通过：标准门禁、109 项共享测试（含字边界速度连续性），Mac 完整打包/签名、Android release APK 构建。此次新包未安装到应用程序或手机。
- 失败：完整页面回归在歌曲编辑器 Default artwork tab missing 处退出；此前页面日志出现 Chromium tile memory limits exceeded。尚未确定关联原因，不记为全部通过。
- 待验收：安卓用户仍反馈效果不对；与 iOS 实际视觉一致性尚未解决。不得用单测或打包成功替代设备运行对照。

- 补充验证通过：`bash Scripts/tests/test-wall-version.sh`（Mac 真实页面聚焦、展示图展开/收起及浅深主题；iOS fixture 形变期间局部 mask 生效，Android fixture 保持无 mask）。新增检查初次运行因测试页面保留状态和离屏卡片定位失败，修正测试隔离后全脚本通过，未跳过原断言。输出位于 `.build/reports/ui/`，不是实机消除亮边的证明。

2026-11-05 安卓对齐 iOS：新增 kinetic-compare 同句/同时间/同尺寸并排夹具。撤销安卓独有的 .72 未唱字透明度和高亮重复叠画，恢复 iOS 的 .62 与单次字面绘制；保留显式字底光痕及手机自适应排版。门禁及 109 项共享测试通过；桌面渲染对照图在 .build/reports/ui/kinetic-ios-android-comparison.png，仅用于实现分支检查，不是两种真机截图。Android WebView / iOS WKWebView 实机对照仍待验收，新修改未打包。

### 2026-11-05 iOS 偶发残留（待验收）

用户反馈 Mac 明显改善，iOS 偶发仍存在，前次候选修复不能标记全部通过。发现背景卡片有 rasterRect 物理像素对齐，聚焦/展示图动画及 React 初始 frame 未使用，现补齐两条聚焦绘制入口；nativeScrolling=false 原样返回，Mac/Android 不改变。未验证 iOS 真机消除情况，不宣称唯一根因或全面修复。

2026-11-05 字重与光痕续修：非 iOS showSeam 路径沿字形轮廓增加字号 .018 的圆角细描边（半透明补偿，避免外框过亮），不依赖字体回退是否提供更粗字重；字底光痕采用局部柔光层与细亮芯，强度跟随波峰线性衰减。iOS 不变；当前配置同时适用于 Mac/Android。109 项共享测试与门禁通过，Android release APK 已重建。桌面同输入对照图已查看，非 Android 真机证据；portable 与实体光痕仍待验收。完整页面回归失败，具体见 /tmp/kinetic-weight-page.log，不记为通过。

本轮验证：UI 标准检查通过；共享逻辑 109 项通过。音乐墙全脚本两次未通过，首次报空节点 dataset 访问（Mac dock 测试阶段），重试报 Mobile idle geometry（移动播放条空闲收起阶段），保留失败、不放宽断言；本轮不可宣称整套运行回归通过。iOS 原设备偶发白线待验收。

2026-11-05 裂缝光效澄清：撤回文字轮廓加粗，用户所指为字底裂缝太细及缺少向外扩散。光痕移到逐字高亮 clip 恢复之后、字形变换空间内绘制，避免外围光被裁掉；裂缝厚度改为字号 .065（最低 1.6 CSS px），外围采用椭圆径向渐变向四周衰减，并跟随波峰和填充进度消退。iOS 绘制不变。门禁及109项共享测试通过，桌面并排渲染已查看，Android release APK 已重新生成；Android 实机/专用模拟器光效仍待验收。本次未重跑完整页面回归，上轮卡片恢复失败仍未关闭。

### 2026-11-05 壁纸居中与展开切歌交接（录屏反馈）
- 已实现：单人人脸/人体中心优先；多人核心包围范围居中；边界与头顶保护约束。移动原图首次显示前加入已发起检测，避免先锁定无主体裁切。
- 已实现：Mac展开完成后的切歌取消相机穿越墙面及新卡片FLIP；Android/iOS共享FocusArtwork跨歌曲持续存在，展开时保留上张图片，原图解码/分析后交接，不主动揭示中途低清预览；清晰层移除object-position过渡，防止已算好焦点仍在显示后插值移动。
- 通过：定向Electron真实页面连续切换远处歌曲83/17/62，逐帧检查新聚焦卡片保持全屏边界。用户录屏已提取2fps连续帧检查，不以此宣称修复后实机动画通过。
- 失败记录：一次完整页面回归因ERR_CONNECTION_REFUSED中断；另一次在Mac空闲播放条几何断言失败，均不掩盖。当前运行独立端口重新验证。
- 待验收：三端安装包切歌/展开的清晰度交接、图片取景及GPU流畅度；Android/iOS尚无本轮实机证据。多人/动漫超出cover可容纳范围的问题尚未通过完整主体铺底方案解决。
- 本轮补充验证：共享109项通过；桌面67通过、4跳过。完整页面回归一次在手动打点断言失败；新切歌用例随后补回测试前歌曲以隔离后续状态。重跑又在播放条测试出现undefined.getBoundingClientRect异常，完整回归仍标记失败，不能宣称全部页面通过。Mac展开切歌独立逐帧用例已通过。

### 2026-11-05 Mac 音乐墙搜索按钮外缘统一

- 已修改：外壳描边由 1px 统一为其他圆形工具的 .65px，内部命中按钮扣除两侧描边，收起外壳保持 38px 圆形；复用既有玻璃采样和高光。
- 静态门禁通过；实机深浅主题与展开/收起外观待验收。

2026-11-05 按用户截图继续修正扩散光：光痕改 screen 混合，减少在亮色封面上呈紫色染色线的问题；外扩椭圆半径为字宽 1.25、字号 .32，峰值 .6，波峰平方抑制低强度相邻字连成下划线，保持裂缝 .065 字号厚度。iOS 不变。门禁、109项共享测试、Android release 构建通过；桌面渲染检查仅验证实现外观，安卓实体设备/iOS 对照仍待验收，未宣称一致；本轮未运行完整页面回归或 portable。

- 本轮运行：音乐墙完整脚本通过（包含 Mac 实际页面、浅深主题与展开/收起）；组件脚本通过。上述检查不替代原设备外观验收。

### 2026-11-05 移动端切歌显示上一首插图

- 视频证据：约 1.1–1.5 秒“知足”已出现但仍显示上一首 Beyond 插图，后续再次切卡同样短暂保留上一首插图。
- 已定位并修复：FocusArtwork 缺少歌曲身份 key，shown/revealed/cropDecisions 跨歌曲复用；恢复 key={item.id}，仅跨歌曲重置，不破坏同歌高清升级与墙面几何连续性。
- 已通过：UI 标准门禁，共享测试 109 项，原音乐墙回归脚本。新增延迟 decode 跨歌曲 DOM 回归验证结果另记。移动设备原录屏场景仍待验收，未修改真实文件插图与缓存。

- 新增运行回归通过：iOS 与 Android fixture 均在阻塞新图 decode 后切换到其他歌曲，聚焦图片栈不含上一首 URL；完整音乐墙脚本通过。此验证为 Chromium DOM/交互证据，非移动真机 GPU 验收。

### 2026-11-05 Android 随机播放展开后收回封面加载
- 已修正：展开封面期间随机切到远处歌曲时，提前同步墙面相机及挂载目标周围海报，不再等到收回才更新可见窗口。卡片图节点在收回时复用。
- 通过：标准门禁、109 项共享测试；修改后的完整 test-wall-version 首轮通过。新增 MINIVOICE_RANDOM_ONLY=1 定向页面用例：展开切至第731首、目标周围海报已解码、收回复用已有图片节点，独立运行通过。Android release APK 已重建。
- 验证说明：定向用例最初插入主序列会改变其恢复夹具状态，后改为独立开关运行；不放宽主序列断言。当前未运行 Android 专用模拟器 portable，真机扫描并发、慢存储、切歌后立即收回仍待验收。

### 2026-11-05 Mac高清与取景前置交接
- 已修正：Mac展开前准备原图和主体分析；展开切歌时旧聚焦画面保留至新图decode及分析结束，过期切歌请求不能接管。新展开卡片直接使用原图身份，避免先显示预览再升级。
- 已修正：移动FocusArtwork显示原图前显式发起warmArtworkSubjects，不再只等待“恰好已存在”的请求，消除父effect尚未执行时锁定默认裁切的竞态。
- 通过：静态门禁；共享109项；桌面67通过/4跳过；Electron定向用例人为阻塞decode，确认旧全屏图保持，再释放并确认新图接管；连续远处切歌全屏边界逐帧通过。
- 待验收：本轮未发布安装包；三端真实封面识别准确率、用户截图同源原图裁切、完整页面回归及实机连续操作。Android侧脸/动漫识别与多人不适合cover的构图尚未解决，不能称全面优化完成。

### 2026-11-05 普通卡片随机切歌解码交接
- 已修正：前次仅提前挂载未等待解码；现对有焦点的跨歌曲定位，先预解码目标相机可见窗口（含 overscan）的封面，再执行焦点/相机交接，旧墙面保持至准备完成。失败图片允许正常缺图处理；请求序号、当前歌曲和挂载状态校验阻止过期结果接管，缩放/指针操作/清焦点/卸载取消旧交接。
- 通过：标准门禁、109 项共享测试、完整 test-wall-version.sh；MINIVOICE_RANDOM_ONLY=1 定向回归加入人为挂起预解码，验证普通卡片随机切歌在解码完成前保持旧墙面，释放后进入目标歌曲；展开随机切歌收回保留节点也通过。Android release APK 已重建。
- 待验收：未执行 Android 专用模拟器 portable，真机慢存储及扫描期间并发、GPU 合成仍待实测。预解码不影响音频切歌，墙面视觉交接可能晚于音频。

### 2026-11-05 23:22录屏切歌闪屏与拖动感
- 已修正：预加载原图直接作为显示节点接管；Mac展开切歌相机与聚焦卡片同步提交，消除先移动相机后提交卡片的间隙。
- 通过：静态门禁、桌面67项通过/4跳过；定向Electron用例阻塞decode验证旧图保留，并检查切换后每帧新图解码可用、transform一致及全屏边界，连续三次远处切歌通过。
- 待验收：打包Mac实际GPU录屏；当前只验证开发页面，不声称用户安装版已更新或闪屏已经实机关闭。完整页面回归运行中。
- 完整页面回归补充：本轮test-wall-version.sh独立端口5391退出0，整体通过；不替代安装包实机视觉验收。

### 2026-11-06 Mac录屏形变修正
- 已查看用户11秒录屏并抽帧至deformation-video/contact.png。Mac展开不再改变Poster的React key，保留卡片节点、前一帧尺寸与动画状态；卡片及图片反向补偿改用同一采样进度、相同线性时钟，减少两层各自插值造成的中途横纵比例误差。
- 背景专项通过：新增展开节点身份保持及中间帧图片包围框/原始比例检查（允许1.5%数值/采样误差），同时覆盖原图准备、全屏尺寸、超宽resize及模糊对齐；移动既有专项通过。桌面67项通过/4跳过、19项背景逻辑通过、门禁与桌面构建通过。
- 旧背景测试曾等待“原图未就绪时开始展开”，与当前prepareWallpaper先解码流程冲突；已按实际流程释放合成原图后观察动画，并保留身份及中间帧检查。最终报告mac-deform-render.txt。未安装应用，用户录屏原设备回验仍待完成。

### 2026-11-06 iOS 音乐墙展开随机切歌等待优化
- 已修改共享 Wall：展开切歌不再等待目标周围整窗海报，仅准备目标高清封面；主体分析与图片解码并行，在更换歌曲卡片前完成，避免先以默认构图显示再寻焦。保留歌曲 key 隔离，防止新标题误配旧封面；普通墙面切歌仍保留邻居解码保护。相机继续在展开背景下挂载目标窗口，连续切歌沿用请求序号丢弃过期结果。
- 通过：组件边界门禁、109 项共享测试。完整音乐墙页面回归运行结果另记。
- 待验收：iOS 真机随机连续切歌、立即收回、深浅主题与慢存储性能；未构建或安装 iOS 新包，不宣称 FPS 或实机卡顿已关闭。
- 回归补充：完整 test-wall-version.sh 退出 0；MINIVOICE_RANDOM_ONLY=1 定向回归退出 0，包含普通卡片延迟解码保护及展开远处随机切歌后收回节点复用。Electron 日志出现 tile memory limits exceeded 警告，自动断言通过不能替代 iOS 真机 GPU 性能验收。

### 2026-11-06 移动音乐墙侧栏边缘闪烁（待实机验收）
- 打开侧栏时在 layout effect 同步取得墙面补边采样，避免前景已缩小而补边仍等待至少数帧的空档；保留后续稳定采样及关闭延迟清理。
- iOS / Android 共用实现；尚未进行两端真机 GPU 动画验收。

### 2026-11-06 移动音乐墙侧栏背景恢复
- 定位：侧栏自有DrawerMaterial封面采样/blur/tint之上被后置规则再加实时backdrop滤镜与底色，形成重复材质；采样子层inset=-24px却未补偿poster坐标，封面错位。修正为单次自有采样材质并补偿24px；音乐墙未就绪时有限重试，采样存在不再叠加整张当前封面。
- 门禁、共享构建及共享测试通过；实际页面回归记录drawer-material-render.txt。更新样式切换回归为检查真实解码的自有采样，不再要求本次已移除的重复实时滤镜。未安装应用，移动实体设备背景观感待回验。
- 侧栏最终补修：mobileSurfaces仍将墙侧栏采样底板设透明，导致后方清晰歌词/按钮穿透。已恢复不透明主题底板，保留封面模糊与材质tint；新增断言检查单次采样/24px模糊/非透明底板。此前整套drawer-material-render.txt回归已通过，最终补修页面结果另记drawer-material-final-render.txt。
- 移动卡片译文改为与正在播放相同薄边胶囊，保持44px触控目标；关闭态为透明浅描边，去掉黑底，开/关文案与aria-pressed保留。Mac仍有译文开关。
- 最终补修截图drawer-narrow-final.png已查看：侧栏内不再透出后方歌曲标题、歌词和播放控件，保留模糊封面色彩与侧栏轮廓。移动实际页面开合/快速重开/主题及样式切换通过；共享109项通过，完整记录drawer-material-final-render.txt。

### 2026-11-06 移动搜索按钮边缘统一
- 根因：其他按钮使用主题10px玻璃，搜索独立伪元素硬编码24px模糊并使用固定展开宽度渐变，收起边缘采样不同。删除独立采样，统一由materials.css外层绘制，保留搜索展开与关闭交互。
- 共享构建、门禁与109项逻辑通过；实际计算样式比较及搜索页面回归见search-material-render.txt。尚未安装到移动设备，WebKit/GPU展开中的采样稳定性需实机回验。

### 2026-11-06 用户截图：移动卡片译文/播放标记未对齐
- 根因：正在播放位于wp-heading内，译文位于独立header-actions内且胶囊有7px内部偏移，两套布局以不同基准定位。
- 修正为共享header grid首行，状态与44px译文目标垂直居中，标题/歌手放后两行占满宽度，避免文字被右侧按钮挤压。按钮可见胶囊与状态均30px高，保留触控目标及开关语义。
- 组件门禁、共享构建及109项共享逻辑通过；横竖屏/开合实际回归见badge-alignment-render.txt。未安装用户手机，截图对应设备最终布局待回验。

### 2026-11-06 音乐墙侧栏误用单曲封面
- 根因：DrawerMaterial未接open，挂载时墙尚未就绪的单曲回退可一直保留，后续打开不重采样。本轮传入drawer开关，每次打开重新冻结当前整墙海报；wall样式禁止单曲回退，等待墙就绪，其他样式继续当前歌曲封面。
- 修正此前overscan重复补偿：海报已有CSS translate(24px,24px)，移除重复JS +24偏移。新增页面断言检查整墙多个海报且无直接单曲img。
- 门禁、共享构建与109项逻辑通过；真实页面回归见drawer-wall-source-render.txt，未安装真机。

### 2026-11-06 移动音乐墙四角图标可读性
- 四角工具统一深色半透明玻璃底、纯白图标，描边从1.7调整为2.2并增加小幅暗影；保留共享边缘材质、按钮大小和搜索变形，避免封面颜色与图标混在一起。范围仅移动音乐墙四角控制，不改卡片内部播放控件。
- 组件门禁、共享构建与109项逻辑通过；真实页面回归wall-icon-render.txt；实体设备/真实封面可读性尚待回验，未测量全图片集对比度，未安装。

### 2026-11-06 移动墙播放栏可读性
- 展开/收起播放栏共用深色玻璃与白色前景，标题加重、歌手副色分层，主播放键增加薄圆形底，次级图标微加粗与暗影，禁用状态区分；进度色调整为浅青绿。保留原位置/尺寸、自动收起、44px控件和进度提交协议。
- 门禁、共享构建及109项共享测试通过；实际移动命中/播放/进度/自动收起/搜索开合回归通过，完整报告wall-dock-legibility-render.txt。未安装真机，不以页面回归替代实体GPU观感。

### 2026-11-06 墙工具玻璃按用户反馈减淡
- 四角工具底色从rgba(17,24,28,.64)改为rgba(38,47,50,.42)，播放栏从.68改为同色.46；稍提亮底色、提高透光，保留白色图标/线宽和边缘材质。仅调整透明底色，不改位置、交互与动画。
- 组件门禁和共享构建通过；真实设备复杂封面可读性与玻璃观感待回验，未安装更新。

### Windows x64 安装包补齐与打包失败修复（2026-11-06）

- 已完成本机交叉打包：公共入口 `bash Scripts/build.sh --platforms windows` 返回成功，生成 `.build/dist/MiniVoice-3.0.0-windows-x64-setup.exe`，714,607,572 bytes（约681.5 MiB）。主程序及共享核心均为真正的 x86-64 PE；Electron 的 `win32-x64` 名称中 win32 是 Windows 平台标识，不表示32位。
- 新增自动资源准备 `Windows/prepare-runtime.py`：MinGW静态交叉编译核心；固定Windows Python 3.11.9、FFmpeg 8.1.2、Electron 44.10.2、原版small模型与归档SHA256。全部25个Windows/通用传递wheel由runtime-requirements.txt与runtime-wheels.lock.json固定版本/哈希；AI沿用stable-ts 2.19.1、Whisper 20250625和torch/torchaudio 2.8.0。补齐MSVC应用本地DLL、Python/模型/依赖许可及FFmpeg发布说明。
- 根因及修复：原流程没有资源供应；补齐后，Torch静态链接库/SDK造成安装数据超过NSIS约2GiB映射上限，触发SIGBUS或mmapping out-of-range。推理发行包移除不参与加载的.lib/.a/.pdb及Torch C++头文件，保留DLL/PYD/模型/许可；Windows原生构建也在自检前调用同一清理函数。资源暂存改为新目录准备后替换，修复cp合并保留旧开发库的问题；准备失败保留旧目录。
- 通过：最终公共构建完整通过；Windows逻辑48项、Python资源准备4项、组件门禁125源文件、同源前端117模块；构建中两套npm依赖审计均0项。安装包NSIS CRC32独立复算通过（0x3de5e4b7），SHA256为c34ac7f988f26f29309547c09cad8579c803cbd69be03de6752c2ce1dfcd32a1；ASAR入口与版本核对通过，资源清单哈希与PE核对通过。
- 证据：`.build/reports/build/windows-packaging-success.log`、`windows-installer-verification.json`、`windows-dll-imports.json`及产物旁.sha256。静态DLL扫描含可选Numba TBB和torio共享FFmpeg插件，不把可选插件可用性或静态扫描当作实际推理证据。NSIS仍有FileDescription/LegalCopyright版本字段两项非阻断警告。
- 待验收：未签名；未在Windows执行安装/卸载、播放、文件占用恢复或AI推理；PowerShell原生流程新增清理调用仅代码检查，未在Windows执行。此项关闭“本机无法生成安装包”，不关闭Windows实机验收或与Mac完整对齐缺口。

### 2026-11-06 移动展开后清晰度/取景二次跳变
- 当前FocusArtwork等待原图decode及识图，且shouldDefer会等展开动画结束才显示原图；用户先展开时仍可看到预览到原图的事后替换。新增Wall.prepareExpansion等待当前焦点最终原图就绪并提交两帧，移动按钮在该检查成功后才写wallExpanded。切换焦点则取消旧展开，超时明确报错而非带低清图启动。
- 原图就绪标记由实际shown===src控制，不用请求完成代替画面交接完成；保留原裁切/主体锁定。构建与共享逻辑验证见mobile-expand-ready-*；未安装用户设备，原场景实机待回验。

### Windows 安装选项与覆盖升级（2026-11-06）

- 已新增中英双语安装选项页：桌面/开始菜单快捷方式分别勾选，HKCU保存选择供后续升级恢复；完成页可选择安装后启动，静默安装不自动启动。首次可选目录，升级读取并固定原目录，同版本支持修复安装，拒绝降级；安装/卸载互斥，限定64位Windows。
- 当前更新策略为用户运行新版完整setup覆盖升级，无自动联网更新。新增按SHA256登记全部应用文件的安装清单，以及仅用stdlib的install-update.py。先展开并校验完整新文件，Windows侧检查现有文件的独占写访问；占用时提示退出应用后重试，不强杀播放/编辑。逐文件原子写入并备份原文件，失败尝试回退，回退失败保留AppData下独立备份并告知位置。仅删除旧清单记录而新版不再需要的文件；未知文件及外部曲库/AppData偏好不清理。
- 首次从无清单的旧简版升级时保留未知旧文件，此后按清单管理。暂存与回退会额外占用磁盘空间。卸载增加桌面快捷方式清理；卸载仍保留用户音乐和偏好。
- 通过：Windows逻辑49项；更新事务7项，覆盖损坏新包不触及旧版、写入失败恢复旧文件和清单、占用预检、未知文件保留、无清单旧版、路径越界/链接拒绝和备份保护。实际1.6GiB应用目录在Mac上经同一helper完成完整安装文件模拟。NSIS重新编译成功，新页及相关语法已编译，不能据此宣称Windows交互验收。
- 已替换同名安装包：714,998,511 bytes；SHA256=877fc235d936dd8b7d5e2f805d655f4f40659fdc6838648eba8840ad876e6853，独立复算NSIS CRC32=0xbe077b72通过。证据：.build/reports/build/windows-installer-options.log、windows-installer-options-tests.log、windows-installer-update-tests.log、windows-installer-options-configuration.json和windows-installer-verification.json。
- 待验收：Windows真实安装页布局/勾选、快捷方式与注册表、旧简版/新版覆盖升级、真实文件占用、低磁盘/权限失败及回退、卸载、完成后启动。尚未签名；本轮修改安装器并复用前轮已打包应用，没有声称补齐Mac全部功能或验证实际AI推理。

### Windows 安装包及快捷方式统一品牌图标（2026-11-06）

- Windows/assets/MiniVoice.ico直接从现有BrandIcon.swift矢量导出，包含16/20/24/32/40/48/64/128/256像素的32位透明DIB帧。新增WindowsIconGenerator.swift，现有generate-icon.sh同时刷新Windows ICO，未另画图标或修改Mac现有图标。
- Electron打包脚本指定ICO，主程序内嵌图标替换为MV；NSIS使用MUI_ICON/MUI_UNICON，避免Modern UI默认图标覆盖普通Icon配置。桌面/开始菜单快捷方式显式指定主程序图标索引0；已安装应用DisplayIcon使用带引号路径和索引0。保留安装选项及更新流程。
- 通过：256px导出预览检查；从主程序和最终安装器PE资源逐帧读取，9帧全部与ICO数据一致；MUI展开结果中安装/卸载图标均指向品牌ICO；组件门禁、脚本语法、git diff检查及NSIS完整编译通过。ICO SHA256=0baee9e85082806481312844aef57ec940a43c2d037e8713e68b480cdfe78473。
- 已替换同名setup：715,388,975 bytes，SHA256=1f51a9ff2c1ac795c85dd049ead5088b604165db0f6d82d9ebed4cdad3915ae7，独立复算NSIS CRC32=0x3bfdd1fc通过。证据：windows-icon-preview.png、windows-icon-verification.json、windows-installer-icon-preprocessed.nsi、windows-installer-icon.log和windows-installer-verification.json，均在.build/reports/build/。
- 待验收：Windows资源管理器、安装/卸载窗口、实际桌面/开始菜单链接和图标缓存显示；本机资源验证不能替代Windows实际显示验收。

### Windows 主窗口截图暴露的外壳与基础显示差异（2026-11-06）

- 截图根因：Windows默认原生标题栏/菜单行叠加共享Mac界面的34px顶部预留；BrowserWindow未明确指定品牌图标，字体也未声明Windows UI/CJK字体。不能以共用页面或能生成安装包认定外观对齐。
- 本轮修复：主窗使用hidden标题栏与Windows原生caption overlay（32px），与共享顶部空间匹配；菜单默认隐藏，Alt仍可访问，新增始终可见的设置入口和Ctrl+,。窗口与辅助面板指定品牌ICO，保留原生最小化/最大化/关闭；caption符号跟随显式深浅/系统主题，音乐墙使用浅色符号；首次绘制前隐藏窗口。Windows独立字体栈使用Segoe UI Variable/Segoe UI/Microsoft YaHei UI，Mac样式不改。
- 通过：51项Windows逻辑（含新增窗口配置/主题对比测试）、组件门禁125源文件、同源构建118模块；生产renderer的10组截图与指标检查，覆盖三样式×深浅、空曲库、有歌曲、560px窄窗口和设置入口命令。截图检查了音乐库浅色、有歌曲播放器、音乐墙深色与窄窗简易，使用合成歌曲和专用临时配置，没有改写真实音乐库。
- 已重新完整打包：715,474,084 bytes；SHA256=aac91a1655a55463b0e9300316b15da825c788aafee3d8df0cefbea679716afb，独立复算NSIS CRC32=0xe5333d38通过。ASAR中的main/window-chrome/desktop及ICO与本轮审阅源码一致。证据在.build/reports/build/windows-layout/、windows-layout-check.log、windows-chrome-build-success.log及windows-installer-verification.json。
- 待验收：截图回归在Mac上运行Windows平台的同源renderer，不包含真实Windows caption按钮；Windows实际拖拽/最大化/贴靠/菜单Alt、系统缩放、字体、深浅切换、辅助面板仍须实体Windows回验。本轮仅修截图中的窗口外壳与基础显示差距，不声称完成全部功能/动画/材质对齐。

### 三张Mac样式参考图的同尺寸、同状态对照（2026-11-06）

- 用户进一步提供音乐库、音乐墙和简易样式Mac参考。此前1200px空曲库检查不能作为这些759×603逻辑尺寸、有封面/歌词/播放状态页面的对齐证据。本轮按1518×1206参考图对应的759×603逻辑窗口，使用同一组合成曲库、封面、歌词、暂停进度32/273秒、歌单和已完成后台任务分别运行Mac/Windows平台renderer。
- 发现并修复实际后台缺口：Mac DesktopEngine.detail通过18×18预乘alpha采样提取封面平均色，再用0.38+0.62与0.20+0.80系数输出backdropColors；Windows未提供该字段，会长期使用浅绿默认背景。新增Windows/electron/artwork-presentation.cjs，并在selected/playing详情中补齐字段，按不可变封面哈希缓存8项、合并并发读取；缺失资源不永久缓存失败，不要求重新扫描，也不写音乐文件。
- 通过：53项Windows逻辑，新增平均色/透明alpha/通道、并发缓存、资源缺失后恢复测试；生产renderer的三样式双平台同条件对照通过，主要容器几何差≤0.6逻辑像素，配色一致。实际测得音乐库/简易侧栏250、内容区473、两行底栏高172；音乐墙侧栏230、浮条460×64，均与参考图对应几何一致。已检查三张Windows模式合成数据截图，含展开音乐墙卡片、歌词和任务按钮；不是Windows实机截图。
- 证据：Scripts/tests/test-desktop-platform-parity.cjs及夹具；.build/reports/build/desktop-platform-parity/内Mac/Windows三样式PNG和comparison.json，desktop-platform-parity.log；windows-reference-parity-build.log。仅使用合成封面与虚拟音乐路径，没有读写真实曲库。
- 已完整重打包并核对ASAR后台源码：715,456,957 bytes；SHA256=bc423f0d0464db4dc7452fb80577de5b1e56433b00498814feedddc88f6f68ac，独立NSIS CRC32=0x802469c6通过。
- 待验收：Windows原生字体、DPI缩放、caption控件、GPU玻璃/模糊、真实封面/歌词的实际观感仍需实体Windows回验。布局容器同条件通过不代表全部像素、动画或平台能力已实机对齐。

### Windows 移除菜单、图标右键设置与滚动热点修复（2026-11-06）

- 按用户标注，彻底移除应用菜单与每个主/辅助窗口菜单，Alt不再唤出“MiniVoice/编辑”行；移除页面顶部自有设置文字，Ctrl+,由before-input-event保留。托盘加入“打开设置”，任务栏Jump List注册同名任务，通过--open-settings启动/激活单实例并打开设置；已有设置窗口最小化时恢复。二次实例/未成功加载状态的进程不得执行退出写盘，避免默认空状态覆盖运行中应用。
- 实际性能热点：原Windows cover/detail均直接返回原图；publish每秒序列化含rawLyrics的整库并把songs/position放入state，重复解析当前歌词；audio timeupdate频繁序列化/写整库。修复为192px列表/512px浏览PNG缓存（分类与墙面预览），32MiB压缩图内存LRU、按哈希磁盘缓存、同图并发合并及串行解码间隙让出事件循环；详情/编辑原图字节保留。Mac原有图像路由不变，不关闭玻璃或动画。
- 后台改为轻量catalog行（保留modified/size供逐字缓存失效）、Set/Map关联收藏和路径；state剔除整库与热进度，去重后发送，clock独立更新；歌词解析按歌曲及原文缓存。状态写入合并排队，窗口变化节流；播放进度写入独立小检查点，恢复仅采纳比主状态更新且当前歌曲匹配的记录，暂停/跳转/退出保持恢复语义。
- 通过：61项Windows逻辑，含千首合成曲库十次进度变化仅发送一次catalog/state、歌词仅解析一次、页面payload小于10KB；状态变化及强制快照仍可发布。并发写入保留最新状态、独立检查点不可覆盖较新seek/save、二次实例不写空状态、菜单移除/设置快捷键/任务栏启动参数、缩略缓存与原图保留测试通过。
- 真实图像管线在Mac宿主验证4000×3000源图→512×384浏览图、192×144列表图；20个同图并发请求仅生成一次，重启服务可读磁盘缓存，原图字节一致。此为解码尺寸/缓存证据，不是Windows FPS。生产renderer十组空/有曲库/深浅/宽窄布局及真实Electron Ctrl+,输入事件通过，三样式同尺寸对照仍通过。
- 已完整打包：715,452,056 bytes；SHA256=fdd675e91d4bb1a0ae892049afaf622450cc620dbbbd1afb3f8aa15a600998e5，NSIS CRC32=0x4932a7eb独立复算通过。ASAR六个后台模块与审阅源码逐字节一致。证据在.build/reports/build/windows-menu-scroll-tests.log、windows-menu-scroll-build-success.log、windows-preview-pipeline.json/log、windows-layout-check.log及desktop-platform-parity/。
- 待验收：Windows实体机菜单/托盘/任务栏Jump List、单实例唤醒与实际滚动；没有Windows FPS采样，不能宣称所有机器卡顿完全消除。图像GPU/驱动和玻璃重绘仍需实机采样；本轮不以隐藏样式或降低编辑原图质量换性能。

### Windows 安装速度与未变模型复用（2026-11-06）

- 用户截图停留在small.pt解压：完整包内含约461MiB模型及完整AI运行时，旧solid-LZMA追求体积；之后更新器还会校验、备份、复制大文件。不能把本机打包时间当作Windows安装时间。
- 按用户补充要求，模型按新包清单SHA256检查已安装内容；匹配时NSIS跳过small.pt解压指令，不生成临时模型文件。缺失/内容不同/校验失败才解压内置模型。改用非solid逐文件zlib，使跳过单个模型不必解压前置整块流；完整包仍带模型用于首次安装或修复，不是轻量差分下载包。
- 更新器校验将保留的现有文件或将应用的新文件；相同模型/运行库不备份、不复制、不覆盖；保留完整哈希校验、文件占用检查、并发修改stamp检查和失败回退。模型在检查后变化导致失败时，重试会重新检查并按需解压模型，不默默保留坏模型。
- 通过：更新事务11项（原7项及模型未变且临时源缺失、缺失/变更模型重新安装、缺失已跳过模型拒绝、未变运行库不复制）；Windows逻辑61项及完整公共构建。真实483,617,219-byte原版small.pt在隔离目录复用验证：临时源没有模型，模型stamp未变，复制清单只有合成应用文件和清单，模型没有复制/备份。唯一small.pt打包路径已核对。
- 已重打包：845,024,721 bytes（约806MiB），较旧约682MiB包增大，取舍为解压速度与可独立跳过模型。SHA256=bbeb3e0533c3192b42f4ce2c6f2715429fbb47682c591a2eb0d8a4b5f17195e9，独立NSIS CRC32=0x12f8865b通过。ASAR更新器与审阅源码一致。
- 证据：.build/reports/build/windows-fast-install-build.log、windows-install-speed-tests.log、windows-model-reuse-verification.json和windows-installer-verification.json。以上模型复用验证宿主为Mac；Windows实体机首次安装/覆盖升级耗时、磁盘/杀毒影响仍待验收，未承诺提速倍数或秒数。

### 2026-11-07 两端品牌开屏交付

- Android：系统启动资源、自适应图标与应用内加载页统一；透明画布内居中 88dp 图标；运行时匹配应用深浅主题，页面 ready 后移除，无强制等待。用户本轮明确反馈“现在安卓端优化好了”，记录为用户设备该问题通过；不外推其他 OEM 或全主题矩阵。
- iOS：系统 LaunchScreen 与运行时品牌占位，圆角图标及动态背景资源，页面 ready 后退出，减弱动态直接移除。仅开屏代码纳入本次提交；启动性能、Home 手势、性能采样配置均不包含。
- 已验证：UI 门禁、Android APK/iOS 模拟器构建、图片透明度与 APK 资源检查。待验收：iOS 实机图标交接、两端系统/应用主题不一致场景；Android 专用模拟器此前因空间不足未运行。

### 2026-11-07 iOS Home 手势边界

音乐墙 WKWebView 对底部 Home 指示条安全区放弃命中，避免退出手势同时启动墙面滚动；其他样式及安全区以上维持原行为。此前 iOS 模拟器构建与页面回归通过；UIKit 系统退出/取消/返回、横屏和多指仍待真机验收。按用户要求单独提交，不包含启动/缓存性能改动。

### 2026-11-07 iOS 缓存、音乐墙与动画性能优化

- 已实现：统一 8MiB 编码图内存 LRU/同图在途合并，原图不驻留该缓存；Artwork 磁盘 512MiB/30天淘汰，按需重建。扫描只存640px缩图，原图惰性提取，保留wall320/card960/display2048和原始编码；缓存淘汰不再触发整库元数据重读。清理有内存/磁盘代次、写入串行和授权/符号链接边界，宿主清理后更新封面URL身份；缓存落盘失败仍保留可恢复封面身份。不清理音乐、索引或用户歌词。
- 已实现：曲库索引后台编码/串行原子写入/合并最新快照，保存失败明确反馈；检查点后台读取。快照新增snapshotRevision，队列/歌单/收藏/歌词仅变化后传输，保留集合身份并丢弃逆序旧回复。暂停/后台关闭UI时钟，锁屏元数据按事件更新；中断恢复保留明确播放意图，远程Play在异步加载时不反转暂停；锁屏封面去重、后台640px解码和过期身份保护。
- 已实现：当前投影音乐墙的预热最多3个活动解码，24MiB/48项解码保留集，同URL合并、过时排队取消、失败重试/超时、卸载清理；该预算不包含活动解码、DOM图片与系统GPU缓存。相同CSS变量不再逐帧重复写，交接后释放多余高清层。歌词预建时间索引二分查找、仅行变化更新，移除无消费者逐词写入与墙面未使用的父时钟。原生样式碎片在失活/卸载/开启减弱动态时取消，旧token不能清理新动画。
- 通过：UI标准门禁；`Scripts/tests/test-ios.sh`（新增缓存同图合并/LRU/失败重试/内存释放/清理竞态/磁盘重启/过期/符号链接，索引最新快照/失败恢复，1037首元数据100次小进度回复/失效/重启）；共享117项；桌面67项通过、4项原有跳过；自有组件实际Electron交互。模拟器Debug和无签名device Release完整构建成功，未安装/导出IPA。证据为`.build/reports/ios/cache-performance-{native-tests,shared-tests,desktop-tests,components,simulator-build,device-build}.log`。
- 通过：固定源码后的完整`test-wall-version.sh`，包含手机/桌面音乐墙、三样式设置/主题、聚焦/展开、延迟解码跨歌曲隔离；定向`test-ios-wall-performance.cjs`在当前projected iOS fixture验证平移重复变量写入0、逐词无效写入0、正向/反向歌词seek及减弱动态展开最终边界。证据`.build/reports/ui/ios-cache-wall-regression-retry.log`、`.build/reports/ios/wall-performance/work.json`与`expanded.png`。这些0是该用例统计，不是FPS/全局性能指标。
- 失败记录：首轮完整页面回归在Mac设置操作遇到undefined.click；测试期间23:25:47修改Wall触发Vite HMR，23:25:48面板被重置后测试中断。固定源码重跑全部通过；保留首轮日志`ios-cache-wall-regression.log`，没有删除/放宽断言。Electron仍有tile memory limits exceeded警告，不能由自动断言通过宣称纹理预算或真机GPU已达标。
- 待验收：本机无可用iOS simulator runtime，本轮没有运行真实WKWebView、XCUITest、iPhone/iPad、电话/Siri/耳机路由或系统锁屏控制。三样式深浅/横竖屏、快速切歌/打断、重启和缓存系统回收、实体材质/形变偶发白线、Instruments内存/卡顿与热状态仍需专用环境验证，不宣称FPS或真机全部修复。AVFoundation同步元数据弃用警告尚存。
- 未接入当前路径的历史测试：旧iOS宿主/墙探针仍硬编码native-scroll/compositedPan，当前PortablePlayer明确`nativeScrolling={false}`使用projected-single-surface；保留原断言并记录测试债务，没有据历史native结果声称本轮WK通过。完整梳理与后续验收顺序见`Docs/iOS-Cache-Performance-Audit-2026-11-07.md`，组件说明已更新。

### 2026-11-08 iOS 切到后台停止播放

- 原因：主应用Info.plist的UIBackgroundModes只有processing，缺少audio。现有AVAudioSession已配置playback并激活，但仍缺系统允许后台音频的应用声明；场景失活本身没有调用暂停。Apple依据：https://developer.apple.com/documentation/avfaudio/avaudiosession/category-swift.struct/playback 。
- 已修正：增加audio并保留processing；不修改播放/暂停、音频中断、扫描或缓存逻辑。构建入口新增源plist和实际.app/Info.plist的后台音频检查，缺audio立即失败，避免源码配置未进入产物。
- 通过：新增检查在修复前确实拒绝缺audio配置，修复后源文件、模拟器Debug及无签名device Release产物均通过；两种完整构建、UI标准门禁、plist与shell语法、diff检查通过。报告：`.build/reports/ios/background-audio-{capability-regression,simulator-build,device-build}.log`。
- 待验收：本机没有可用模拟器runtime，本轮未安装或实际切后台/锁屏听音。仍需用专用设备合成歌曲验证播放→Home/切无音频App停留15–20秒→返回进度继续，以及锁屏/解锁；不能将构建或手动scene标记当作系统后台播放实测。

### 2026-11-08 Android缓存、音乐墙与平台功能优化

- 已实现：Android授权歌曲ID索引；wall320/card960/detail2048与original分档；8MiB编码LRU、同key请求合并、原生两路提取/编码且墙图最多一路；独立显示派生缓存256MiB/30天、原子写入、重启复用、清理代次及URL epoch；内存压力与被取消等待者不会令旧缓存回填或破坏同图工作。256MiB仅为web-artwork上限，既有covers主缓存仍按授权库清理，无固定字节上限，不能声称总缓存有此上限。
- 已实现：Android snapshotRevision对收藏/最近/歌单/队列/歌词增量传送；共享页面保留冷集合身份。音乐墙按滑动方向预测最多420px、最多48项/24MiB decoded保留集，后台/卸载释放；不等待预热才响应拖动，焦点请求可提升排队优先级。原投影画布、持续聚焦容器与图片就绪交接保留。惯性中开启减弱动态停止当前运动，聚焦进入最终布局。大字歌词统一每帧时间游标、缓存字宽与二分选行，Android高密度及反光光效保留。
- 已实现：iOS定向修复内存警告后新读者加入旧flight可能回填内存的竞态，补隔离测试。保留此前已有的iOS缓存/索引/时钟优化，不将其整体重做。
- 平台原则：保留Android左下播放条、SAF授权、系统返回、后台扫描通知与MediaSession；共享业务能力对齐不等于移植iOS居中dock/宿主截图/Home手势。收藏/歌单/队列/五模式/歌词查看/缓存统计清理/曲库检查/歌手归并宿主均已有接入；手机编辑入口仍按产品标准不新增。
- 通过：UI标准门禁；共享125项；桌面67通过/4跳过；test-desktop-components.sh；完整test-wall-version.sh（手机/桌面音乐墙、三样式深浅、触控目标与图标中心、聚焦/展开/打断/返回/布局与状态恢复）；新增test-wall-cache-performance.sh在Android/iOS Chromium夹具、1037首合成库验证离屏预取、受限挂载、原投影平面、平移不中断、运行时减弱动态与深浅主题；test-android.sh包含新增编码/磁盘LRU、同图合并、清理/内存压力/取消竞态和冷快照回归；test-ios.sh包含缓存竞态、索引、快照、歌词/墙模型、FLAC与授权隔离。页面截图已查看，属于Chromium而非手机实机证据。
- 验证修正：音乐墙原decode probe只保存最后一项，加入预取后改为收集并释放全部被拦截解码，保留原有“解码前不可遮挡底图/节点连续/最终图可见”断言。新增定向脚本早期主题夹具控制和Electron空窗口退出问题已修，不放宽产品断言。
- Android集成验证过程记录：release与instrumentation已构建；专用MiniVoice_Startup_Test模拟器初次因空间不足启动失败，空间恢复后重试启动成功。portable首轮因1秒合成WAV自动下一首触发测试断言失败；已定位测试时间依赖，保留播放/歌曲身份断言并暂停固定合成歌曲后重跑。最终结果续记于下。
- 待验收：Android实体手机/平板三样式×深浅×横竖GPU/玻璃/触控与热状态，慢SAF及扫描并发、快速反向滑动/缩放/随机切歌立即收回；iOS真实WKWebView与设备。尚未测量FPS、帧耗时或峰值内存，不宣称“一滑动加载”所有场景或偶发白线已全部解决。首读/不可用音源仍需正常加载/错误呈现。完整梳理见Docs/Android-Cache-Performance-Audit-2026-11-08.md。
- 证据：.build/reports/ui/android-cache-shared-tests.log、android-cache-desktop-tests.log、android-cache-components.log、android-cache-wall-regression.log、wall-cache-performance/work.json；.build/reports/android/cache-performance-{tests,build,portable,emulator}.log；.build/reports/ios/android-cache-ios-tests.log。

### 2026-11-08 iOS 控制台警告与目录授权链路

- 日志事实：用户文本1244行，包含2次视图更新期间Publishing警告，1214条完整sandbox consume EINVAL重复行（含拼接片段共1216次字符串出现）；最先sandbox issue失败指向MiniVoice.app自身。缺少调用栈/完整时间戳，不能把所有WebKit/沙盒/InputUI信息认定为图库故障或无害。统计见`.build/reports/ios/console-log-summary.json`。
- 已修正：makeCoordinator创建宿主时，Published曲库立即回调并通过retainLibrary发布播放器状态，存在SwiftUI视图更新重入。曲库交付改到主队列后续调度，永久卸载取消订阅/排队值；WebContent进程重载保留订阅，只取消资源任务。没有通过隐藏系统日志处理。
- 已修正：封面派生缓存先读App本地缓存，不再为命中图解析外部书签/申请权限；缺图读取只持一份目录lease。新增FolderAccessRegistry保存原resolved URL，同目录并发共享，最后读者释放，播放器持有到音频结束/取消。移除目录/更换bookmark拒绝旧请求；外部start失败不继续IO，过期书签明确提示重选；失败按bookmark记忆，重扫/重选可重试。App容器例外经过逐级祖先及符号链接边界验证。暂时授权/枚举失败保留已配置目录旧metadata，显式移除不恢复。嵌套start/stop本身是合法系统行为，本轮消除不必要的重复和失败路径，不据此臆断全部EINVAL来源。
- 通过：UI标准门禁、plist与diff检查；`Scripts/tests/test-ios.sh`，新增cache-hit零resolve/start、并发单grant、100次失败只尝试一次且无后续IO、异常释放、过期/解析错误、重扫重试、撤销/换bookmark、pending重扫及canonical路径/symlink边界；当前工作树共享125项；完整simulator Debug与无签名device Release构建，产物audio+processing保留。证据`.build/reports/ios/console-warnings-{native-tests,shared-tests,simulator-build,device-build}.log`。
- 待验收：没有可用iOS模拟器runtime；配对真机仅只读连接/系统信息，未安装或启动应用、未操作真实音乐库。本轮未验证SwiftUI警告在设备消失、全部sandbox日志消失、真实Files/iCloud授权撤销/重启/重选、实际播放与锁屏/后台。旧AVFoundation同步元数据弃用警告仍存在。完整路径、官方依据与剩余系统信息见`Docs/iOS-Console-Warnings-2026-11-08.md`。

### 2026-11-09 iOS 横屏侧栏边缘色差

- 已定位/修改：外围WallDrawerBackdrop只有封面与固定#00000057，遗漏中央卡片标题渐变、聚焦渐变/高清取景，形成缩小场景边界的明暗断层。iOS改用同一实时墙overscan绘制外围，workspace最终裁切及统一画布底色；原相机、退后变换、遮罩、侧栏玻璃和输入隔离保持。Android/桌面不采用本次iOS路径。
- 通过：`test-wall-drawer-edges.sh`在当前projected iOS合成横屏验证边界色块、当前聚焦、深浅/左右安全区、快速反向/回程中帧、减弱动态、空库、卡片局部mask和Android/桌面隔离；旧路径样本RGB差75，修复路径对应样本差0–1，不是FPS/真实封面审美结论。空库过程发现并修复失效focus cell访问空song造成React整页卸载。UI标准门禁、当前共享125项和diff检查通过。
- 证据：`.build/reports/ui/drawer-landscape/{baseline.log,baseline-pixels.json,targeted.log,work.json,shared-tests.log}`及定向截图。
- 待验收：iOS WKWebView/真机横屏同场景色差、旋转与动画录屏，尚未安装新包。点击卡片/开侧栏缩放的细白边是后续独立检查项，本条不将其记为修复。

- Android定向接入通过：专用MiniVoice_Startup_Test / Android 17 / WebView 145.0.7632.218执行mode=cachePerformance，返回UI_CACHE_PERFORMANCE_PASS。验证真实页面点击到PlaybackService、同图字节复用、墙图最长边预算/2048×1536合成高清图、内存释放后磁盘回读不重读音频、冷快照/收藏失效，以及通过设置执行清理后URL epoch变化、可见图重新解码、原图和162首合成索引仍保留。证据`.build/reports/android/cache-performance-native.log`。原始1秒WAV夹具现先验证真实播放，再暂停固定歌曲，避免缓存检查期间自动下一首；未改产品播放策略。
- Android测试迁移：现有截图180ms预算超时允许产品既有轻量WAAPI过渡，分别检查可见中间帧与最终清理；成功截图仍检查实际碎片变化与多色采样，本轮完整portable已记录成功路径。旧wall直接backdrop/相机depth断言迁移到持续侧栏的冻结多图取样、24px模糊、scene缩放；退出验证持续节点的身份/不可交互/中间transform/最终关闭，保留退出画面要求。完整portable最终结果见下条。
- 已修复真实状态问题：portable在从歌手返回音乐库时报告412.95px→0；根因为SongList每次挂载重放之前的非零location。PortablePlayer现记录已消费token，普通返回不重放，新定位仍执行；显式定位提高scrollRevision阻止迟到restore抢回。新增Chromium双宿主413px返回/新定位用例和真实portable返回/重启断言验证结果续记。
- 通过（修复后复跑）：共享125项、完整test-wall-version.sh（`.build/reports/ui/android-cache-wall-regression-final.log`）及test-wall-cache-performance.sh。后者在Android/iOS夹具验证当前第903首、新挂载显式定位>1000px、普通返回恢复413px、再次定位第0首到顶部，防止消费记录丢掉新挂载意图。Android专用模拟器此前完整流程也已跨过分组三次往返、音乐库返回与重启锚点断言。
- 未通过、保留证据：Android完整portable的历史搜索形变中间帧断言间歇失败（`.build/reports/android/cache-performance-portable-pre-final.log`）；独立mode=wall在译文按钮弹跳峰值采样处未通过（记录最大1.085，原要求>1.1不放宽，`.build/reports/android/cache-performance-wall.log`）。模拟器为软件渲染，不能据静态1.16关键帧或Chromium通过宣称Android实际峰值/流畅度已验收。最终运行结果见下条，专项失败不能被其他路径通过覆盖。

- 最终构建通过：正式3.0.0 release APK与instrumentation已按最终源码重建并通过既有签名校验，包标识/签名/正式数据路径/三端版本来源不变。APK：`.build/dist/MiniVoice-3.0.0-android.apk`。本轮只安装专用模拟器并使用合成文件，未覆盖真实音乐库。
- 最终Android完整portable未通过：最后一轮已通过真实缓存、返回/重启锚点、滑块/滚动条、焦点/弹层/菜单、歌单/批量/信息歌词/设置、三样式深浅及实际墙面触拖；到译文按钮弹跳采样仍失败，最高记录1.08622，低于原>1.1要求，保留`UI_REGRESSION_FAIL`（`.build/reports/android/cache-performance-portable.log`）。未放宽阈值、修改弹跳外观或屏蔽此项，不据其他轮次曾通过宣称此项稳定。独立wall同处未通过；最终完整流程未执行到的后续关闭卡片/快速切卡/系统主题等本轮仍待验收。
- 截图证据：`.build/reports/android/cache-performance-screenshots/ui-regression/`。正式page截图等待侧栏实际退出完成后采集；测试失败终止后取得的Launcher图不作为“ghost player”或产品退出根因证据。此前旋转回竖屏固定400ms关闭断言未通过，现保留等待实际状态和详情的检查，但最终测试在更前的弹跳断言停止，因此该问题没有凭推断关闭。
- 交付结论：缓存/高负荷路径优化及定位恢复修复已落实；定向测试通过与完整Android动画回归未通过分别记录。本轮APK为定向验证构建，不标“全部完成/稳定版”。实体手机/平板与iOS设备、慢SAF、真实大曲库冷启动、纹理/峰值内存/热状态仍按前述矩阵待验收。

### 2026-11-09 Android高负荷路径续修（结果分项续记）

- 继承11月8日已通过的缓存、预取、增量快照与定位恢复，按用户要求继续处理未关闭项；平台原则仍为Android触控/返回/SAF/媒体服务与左下播放条。
- 已修正按钮时间轴：释放中点峰值不再被全局缓动提前压缩，380ms、1.16墙面峰值及回摆值保留；结束冲突scale过渡，运行时减弱动态取消临时动画/监听，禁用/新手势/卸载继续可打断。通过UI门禁与test-desktop-components.sh新增实际动画190ms峰值/运行时取消回归（`.build/reports/ui/button-release-continue.log`）。Android实际触摸与完整回归结果待下条，不凭此声明真机流畅。
- 已确认并修复高清等待展开竞态：延迟decode→展开→Back→释放decode，修复前focus=false/expanded=true/immersive=true，修复后关闭状态保持。父页面意图与Wall准备/节点共同校验，旧结果不能复活卡片。扩展确定性用例与原生回归结果续记。
- 主covers全量扫描/强引用与磁盘总预算改进进行中；最终源码/容量/失效验证据后续结果登记，不把旧web-artwork256MiB解释为总缓存上限。续修分析见Docs/Android-Performance-Continuation-2026-11-09.md。
- Android实际独立音乐墙通过：修复后的原弹跳>1.1检查、62%连续缩放、译文、展开/返回、横竖屏、关闭/预览、快速选择及画布覆盖均完成，返回UI_WALL_PASS（`.build/reports/android/cache-continue-wall-second.log`）。上一轮旋转关闭检查新增的WebView.getProgress在Instrumentation线程调用会抛异常，现已改为主线程helper；没有为测试修改产品返回路径或放宽标准。
- 通过：125项共享、桌面67通过/4跳过、test-desktop-components.sh释放中点/运行时减弱动态/新按下与取消打断；完整test-wall-version.sh；组合test-wall-cache-performance.sh的1037首双宿主预取/定位与Android+iOS各11个展开竞态/缺图/换源重试场景。证据`.build/reports/ui/cache-continue-{shared,desktop,wall-full,performance-races}.log`与`button-release-continue.log`。
- 原生缓存续修已落实：扫描仅登记稳定key，Song不再强持有逐歌预览；covers主图按需生成，jpg/stamp/none/faces分组256MiB/30天LRU（含元数据），web-artwork另256MiB/30天，合计512MiB派生图预算，不是应用全部磁盘或内存上限。墙320直源小采样并回收，不先生成1600主图；内存trim独立锁与代次，不等源读取。低内存/磁盘失败仍返回当次可用主图。分析入口显式640/1024 RGB565采样、维持原裁切及归一化坐标。
- 原生主图版本正确性已修：派生组key包括音频URI/插图URI/插图版本，避免新旧Song并存时旧提取覆盖新像素。旧URI-key组仅stamp精确匹配时复用/复制（不改写旧组），不匹配拒绝。扫描prune、预算与清理仍限派生目录，不触碰正式音乐/歌词/曲库索引。
- 最终原生缓存专项通过：统一构建APK安装专用模拟器，mode=cachePerformance返回UI_CACHE_PERFORMANCE_PASS。验证扫描零源读取/无逐歌Bitmap、cold wall不生成大master、1600×1200按需主图/磁盘复用/淘汰重建、trim不等待源监视器且保留字节清零、640/1024分析格式/尺寸及借用图不被回收、奇数宽裁切、旧版本迟到重建不污染新像素、同URI版本隔离、源不可用legacy精确匹配复用/不匹配拒绝、清理epoch与可见图重建/原图和162首合成索引保留。证据`.build/reports/android/cache-continue-specialist.log`；纯Java组LRU最终测试`.build/reports/android/cache-continue-cover-tests-final.log`通过（含12+9>20同组预算反例），其余原生回归见`cache-continue-native-tests.log`。
- 最终完整portable已通过（结果见下条）。最终构建日志`.build/reports/android/cache-continue-build-final.log`，正式包标识/签名/Shared版本及用户数据目录未改，仍仅专用模拟器合成文件测试。

- 最终完整Android回归通过：统一最终APK运行mode=portable返回UI_PORTABLE_PASS（`.build/reports/android/cache-continue-portable-final.log`），涵盖真实WAV播放/触感调用、冷快照与缓存、音乐库与分组三次返回/重启锚点、滑块抗轮询/取消/键盘、滚动条、焦点/弹层/菜单、歌单/批量/歌词信息与设置、三样式深浅、截图碎片与超时轻量过渡、墙面真手指拖动、原>1.1弹跳阈值、62%缩放、展开/返回/旋转/关闭/预览/快速切卡、队列触拖与系统深浅跟随。未放宽峰值、隐藏功能或跳过末段断言；这条结果替代11月8日“最终portable未通过”的当前状态，历史失败日志保留。
- 最终产物：`.build/dist/MiniVoice-3.0.0-android.apk`已构建、签名校验、安装专用模拟器，另检查包内包含版本化原生缓存/分析采样和最终共享图片就绪/定位逻辑。截图已保存并查看：`.build/reports/android/cache-continue-screenshots/`，含聚焦/展开/横屏、三样式深浅等。仅合成文件和专用模拟器，未操作真实音乐库/手机；正式包标识、签名、版本来源与数据路径不变。
- 本轮交付结论：已完成上述代码修复与可执行自动化验收；共享/组件/页面/Android缓存专项、独立墙和完整portable均有通过证据。仍待真实Android手机/平板GPU/材质/热状态、慢SAF与实体大库、iOS真实WKWebView/设备以及完整实体矩阵验收；本轮没有实测FPS、峰值内存或对比度，不声明这些项目通过。

### 2026-11-09 音乐墙配置弹窗横屏几何

- 已实现：移动端音乐墙设置独立锚点变体，宽度按屏幕短边与原有间距确定，横竖相同；右下角跟随配置按钮实际边界。保留原内容区域85%最大高度，空间不足时在安全区内滚动。其他弹窗、返回/焦点/拖动关闭沿用共享规则。
- 通过：2项纯几何测试；`Scripts/tests/test-wall-settings-placement.sh` 的真实iOS/Android Chromium页面覆盖竖屏、横屏两侧59px安全区、打开中旋转、Esc关闭、快速重开、其他弹窗隔离，宽度/实际按钮边界/原高度预算断言通过。截图与测量见`.build/reports/ui/wall-settings/`。
- 待验收：真实WKWebView与Android设备材质/旋转过程，未由Chromium结果宣称实机全部通过。

### 2026-11-09 iOS 缩放卡片四边与白线排查

- 已修正：普通海报图片原为static，原有`inset:-1px`不生效，宽高各+2px实际只向右/下扩展。iOS普通卡片改为absolute后，四边均有1 CSS px对称覆盖；保留正常按下/预览白色轮廓、当前歌曲绿色轮廓与卡片局部遮罩。未更改Android图片定位或用透明边隐藏功能。
- 通过：`Scripts/tests/test-ios-wall-edge-pixels.sh`在当前projected iOS夹具以1×/2×/3×原始物理像素检查横竖屏、白/黄封面、聚焦/换卡/按下取消、侧栏打开/关闭中帧/快速反向、减弱动态与最终布局。A/B验证旧左右上下覆盖不对称，人工2px未遮罩亮边负例确实失败，修正后的样本通过；合法轮廓与退场侧栏属于真实遮挡单独排除，不删除轮廓或放宽亮度阈值。证据`.build/reports/ui/ios-wall-edges/{final-matrix.log,dpr-1,dpr-2,dpr-3}`。
- 待验收：Chromium旧实现未稳定重现用户偶发的WKWebView GPU白线，故以上结果证明覆盖纠正与指定像素回归，不能把偶发真机白线写成全部关闭。真实iPhone/iPad需要聚焦/侧栏反复打断录屏与GPU材质验收。

### 2026-11-09 三端全屏插图样式与手动构图

- 已实现：当前维护的iOS/Android/Mac音乐墙配置增加“全屏插图样式”居中/智能/手动。默认智能沿用共享构图算法；居中归位；手动移动端双指、Mac左键长按250ms后拖动，竖屏只左右、横屏只上下，依据实际cover溢出量换算并钳制，不改变墙相机或做双指缩放。收起后恢复原卡片智能构图；清晰/模糊显示维度独立。
- 已实现：拖动只预览，正常结束一次提交，取消/失焦/旋转/换对象/关闭还原。手机状态经原workspace串行写入，Mac经业务页面localStorage；以稳定歌曲ID+插图revision保存最多256项，缓存epoch清理不抹除定位，更换插图不借用旧定位。移动多次排队保存读取最新状态，避免快速跨歌覆盖。
- 已实现：全屏智能可消费晚到/更高质量的识图结果，普通卡片仍保持原稳定构图；center/manual不受迟到识图覆盖。不可用原生回复不再缓存为“成功识别到0个主体”。保持预览/原图坐标空间、decode交接、Mac图片反向形变与模糊同步。
- 能力边界：三端使用同一共享图像显著性/构图求解器，宿主分析能力不同；iOS/Mac现有Vision提供脸/文字/人形/显著性，Android现有人脸检测配合共享纹理显著性。未引入新云端识图、OCR依赖或新增Windows实现，不宣称宿主语义能力完全相同。
- 通过：共享132项，Mac逻辑67通过/4项既有跳过；自有组件真实DOM回归；完整test-wall-version.sh通过三样式/深浅/音乐墙聚焦展开/打断与图片交接；定向`test-artwork-framing.sh`以真实CDP触控事件验证双指双方向/单指隔离/取消/手机重开、Mac长按/取消/清晰模糊同步/模式切换/重开/窄窗口键鼠家族/Esc只取消手势。iOS/Android popup与iOS drawer定向回归重跑通过。证据`.build/reports/ui/{artwork-framing,wall-framing-shared.log,wall-framing-desktop.log,wall-framing-components.log,wall-framing-pages.log}`。
- 验证过程：完整页面首轮在桌面切换library样式失败，保留`wall-framing-pages-first.log`；执行期间曾修改共享state触发HMR。固定源码后重跑全部断言通过，没有放宽原样式断言。Electron存在tile memory limits exceeded警告，未据此宣称GPU纹理预算达标。
- 通过：UI标准门禁；iOS/Android原生测试；最终iOS模拟器Debug/无签名device Release构建，Android正式APK及instrumentation构建，Mac前端构建。报告`.build/reports/ios/wall-framing-{native-tests,simulator-build,device-build}.log`、`.build/reports/android/wall-framing-{native-tests,build,instrumentation-build}.log`、`.build/reports/ui/wall-framing-desktop-build.log`。
- 待验收：本机无iOS模拟器runtime，未安装到用户iPhone或操作真实音乐库。真实WKWebView双指/材质/GPU、Android实体手机/平板与Mac正式签名包的实机体验仍待验收，不以构建/截图代替流畅度或FPS测量。
- Android设备侧补充：创建隔离的`MiniVoice_Wall_Framing_Test`专用AVD（临时目录，不使用现有AVD数据或真实手机），最终`-e mode portable`真实WebView/162首合成库回归通过，覆盖播放、三样式深浅、墙面比例/聚焦/展开/横屏/队列/返回/重启锚点；证据`.build/reports/android/wall-framing-portable.log`及`wall-framing-screenshots/`。新增手动双指模式的专门事件断言目前来自Chromium CDP测试，未据此称Android真机已验收。
- Android失败记录：首轮同一AVD在原有碎片动画断言失败（5次采样仅2种变化），保留`wall-framing-portable-first.log`；未改产品或放宽断言，重跑完整通过且走既有截图预算超时fallback路径。该模拟器上的碎片性能仍待验收，不能将fallback通过当成碎片流畅度通过。测试完关闭本轮AVD。

### 2026-11-09 配置弹窗覆盖搜索按钮与开合抖动续修

- 用户最新要求替代前文“保留85%高度”的约束：音乐墙设置保持横竖同宽，右下角沿配置按钮，顶部延伸到搜索按钮边缘，使右上角覆盖搜索按钮；内容在固定高度内滚动，安全区/键盘空间不足时钳制。
- 原因已复现：旧锚点在打开后500ms逐帧读取getBoundingClientRect，把配置按钮380ms释放缩放写入弹窗right/bottom。真实触控基线记录right范围9.52045–17.36px、bottom范围33–38.36px，74次style修改；顶部仍比搜索按钮低34.25px。证据`.build/reports/ui/wall-settings-motion/baseline.json`。
- 已实现：锚点排除按钮缩放，保留按钮原有反馈；只响应真实布局/安全区/viewport变化并差量写入，移除500ms轮询。配置变体从右下角只缩放开合，移除Y位移；退场冻结真实布局尺寸，避免中断时重复缩放。不可展开弹窗的手柄取消不再清空调用方height/maxHeight，队列展开逻辑保留。
- 补充修正：搜索已展开时的独立translate/scale也不能定义弹窗锚点，现按静态布局链读取；修正前该补例height出现370–372.316px变化、86次style写入，修正后固定370px。Modal实例直接复用成普通变体时，在新layout effect清理本变体拥有的几何，不提前清理退场采样。
- 通过：`test-wall-settings-motion.sh` 30条记录覆盖iOS/Android夹具、深浅、左右安全区、真实双端触控释放、搜索展开后打开设置、减弱动态、50/290ms关闭重开、手柄小拖释放/取消、横竖旋转与弹窗复用隔离。标准按钮回弹仍正常；当前样本width416/right14/bottom35/height370每帧固定，仅初次5项style赋值，300ms后0次布局重写；关闭ghost尺寸误差<0.0002px，没有再次缩放。这些是用例测量，不是FPS或实机流畅度声明。证据`.build/reports/ui/wall-settings-motion/{baseline.json,final.log,work.json}`与对应截图。
- 通过：共享132项、自有组件回归、更新的popup位置回归、固定源码后的完整test-wall-version.sh。首轮完整页面回归在Mac设置导航失败，期间useSheetDrag修改触发HMR；保留`wall-settings/pages-search-anchor-first.log`，固定源重跑全部通过，未放宽断言。报告`.build/reports/ui/wall-settings/{shared-search-anchor,components-search-anchor,search-anchor,pages-search-anchor}.log`。
- 待验收：当前仍无可用iOS simulator runtime，真实iPhone/iPad WKWebView的材质合成与旋转动画尚未实机验收；没有由上述Chromium中间帧宣称真机全部通过。
- 通过：本次最终iOS simulator Debug、无签名device Release构建，Mac前端构建；源与产物均保留后台audio能力。日志`.build/reports/ios/settings-search-anchor-{simulator,device}-build.log`、`.build/reports/ui/wall-settings/desktop-search-anchor-build.log`。未安装到真实iPhone。
- 通过：Android正式APK/instrumentation构建与隔离`MiniVoice_Settings_Anchor_Test`专用AVD的首次portable回归，结果`UI_PORTABLE_PASS`，无需重跑；覆盖真实WebView/WAV、三样式深浅、弹窗手柄取消、设置比例/横屏/展开返回、队列与重启锚点。报告`.build/reports/android/settings-search-anchor-{emulator,build,portable}.log`及`settings-search-anchor-screenshots/`。原有样式切换允许的capture-budget fallback继续如实记录，不据此声称GPU碎片动画流畅度达标；测试AVD已关闭并清除临时合成数据，真实设备和已有AVD数据未动。

### 2026-11-10 插图样式文案与 iOS 点击日志调查

- 已实现：移除三端共用的“全屏插图样式”选项下方说明小字，保留三项选择和手势。
- 已调查：用户补充这些日志在Xcode点击时也出现。宿主使用自定义资源scheme，未直接将应用包作为音乐目录申请授权；WebKit公开实现有bundle只读扩展创建/消费和URL隐私数据缺失回退路径。`<private>`、PointerUI及XPC记录缺上下文，尚不能定位具体文件、调用栈或确认所有消息无害。完整分类与来源见`Docs/iOS-Console-Warnings-2026-11-08.md`续记。
- 已实现：宿主增加单调时间、代次隔离的启动阶段和脱敏、限量的真实资源/导航错误记录；取消/明确无封面不制造错误；保留真实ENOENT/EACCES。可用现有诊断导出定位应用侧故障，该改动不声称修复系统sandbox消息或读取WebKit隐去的路径。
- 通过：UI标准门禁；共享136项；插图模式实际页面触控/鼠标回归；固定源码后完整`test-wall-version.sh`；iOS原生测试包含新诊断代次、隐私、取消、失败限量；iOS模拟器Debug和无签名device Release构建及后台audio声明；Mac前端构建。日志`.build/reports/ui/{framing-no-description-shared.log,framing-no-description-pages.log,artwork-framing/no-description.log,framing-no-description-desktop-build.log}`、`.build/reports/ios/web-host-log-audit-{native-tests,simulator-build,device-build}.log`。
- 首轮完整墙回归出现`Style switch has no animation`，保留`framing-no-description-pages-first.log`；源码固定后重跑完整通过，未放宽断言。真实WKWebView/iOS真机再次点击、日志与诊断关联仍待验收；本机没有iOS模拟器runtime，没有安装到用户设备，也无法声明系统日志已消失。
- 补充通过：移除小字后的iOS/Android夹具横竖弹窗位置及旋转回归，已人工查看横屏截图，记录`.build/reports/ui/wall-settings/no-description.log`。

### 2026-11-10 Android侧栏闪屏、样式切换与短暂黑卡片

- 用户限定：滑动/缩放后短暂大片黑；侧栏偶发闪屏；样式切换卡顿；不改变动画样式。已处理可复现的等待黑底、未解码采样提前替换和截图跨桥大字符串成本，原320ms侧栏曲线/scene深度/玻璃材质、碎片plan/17关键帧/480ms+delay/690ms窗口与180ms捕获预算保持。
- 黑块复现与修复通过：新挂载海报+阻塞图片响应修复前RGB=0/0/0；Android占位底修复后41/49/57，加载白图后仍168/168/168（与原遮罩一致）。这些只为该合成像素用例，不代表FPS/对比达标或所有GPU黑屏原因已关闭。证据`.build/reports/ui/wall-pending-before.log`、`drawer-style-pending.log`与`wall-pending-artwork/`。
- 侧栏定向通过：旧解码采样保留至候选就绪，同一已解码节点交接，退休层隐藏后两帧回收，过时结果不得覆盖；关闭/重开/换style、blur24与不透明base、运行时reduce和卸载清理。样式定向通过：逐片一次栅格、原几何/所有关键帧/延迟/480ms等价，正常/迟到释放、超时与减弱动态清理。证据`.build/reports/ui/drawer-style-{sampling,snapshot-motion}.log`、`style-snapshot-motion/work.json`。
- 通过：UI标准门禁；共享136项；桌面67通过/4跳过；组件DOM；完整test-wall-version.sh。证据`.build/reports/ui/drawer-style-{shared-tests,desktop-tests,components,wall-full}.log`。完整页面有tile memory limits exceeded日志，断言通过不能证明实体GPU流畅，不隐藏此限制。
- Android最终构建通过：正式3.0.0 APK与instrumentation构建及既有签名检查通过，专用MiniVoice_Startup_Test模拟器已安装，未接触真实音乐库/手机。新截图代理限same-origin GET数字token/no-store，单份内存JPEG、旧代次失效、裁片后释放与五秒TTL。原生完整portable最终结果见下条，前两次失败保留。
- 原生失败保留：首次portable一次样式碎片仅采到7帧/2种矩阵而未达到原>2要求（内容多色正确），见`drawer-style-black-portable-first.log`；另一次侧栏滑动帧断言失败，见`drawer-style-black-portable.log`。没有放宽阈值；加入实际drawer帧/宽度/终点上下文，单独复核见`drawer-style-black-portable-context.log`。不据软件模拟器结果臆断真实设备原因。
- 仍待验收：原设备偶发合成闪屏、快速冷热切换/慢存储、实体手机平板GPU/热状态及完整矩阵。未测FPS或宣称全设备完全消除闪屏。详细链路见Docs/Android-Drawer-Style-Rendering-2026-11-10.md。

- 最终Android完整portable通过：在不降低中间帧/材质/图片/状态断言的条件下，独立完整运行返回UI_PORTABLE_PASS，证据`.build/reports/android/drawer-style-black-portable-context.log`。包括实际多色截图碎片、中间运动及最终清理、完成后native snapshot=null（异步释放至多等500ms）、三样式深浅、侧栏开合/反向/scene回场、缓存与返回/重启、音乐墙滑动/缩放/展开/旋转/关闭/快速切卡、队列触拖和系统主题。前两次帧采样失败不能用这次通过抹去，也不能据此宣称稳定FPS。
- 最终APK：`.build/dist/MiniVoice-3.0.0-android.apk`，已构建、既有签名校验并安装专用模拟器；另检查包内包含解码采样暂存、Android占位底和native style-snapshot端点。截图已保存并查看`.build/reports/android/drawer-style-black-screenshots/`及`wall-pending-artwork/`。未修改正式包标识/签名/Shared版本和数据目录，未操作真实音乐库。
- 交付范围：已修复确定的冷图纯黑底与侧栏未解码交接，移除大截图字符串跨桥、保留原样式及运动参数；前述自动化通过。原设备偶发GPU合成、热状态、极端慢存储及完整真机矩阵仍待验收，不能把本轮结果泛化为所有设备绝不闪屏或每次无卡顿。

### 2026-11-10 iPhone Duo 侧边状态区域布局

- 已修改：扫描浮层按扣除左右系统安全区后的主内容中心定位，横屏顶部与工具栏对齐。iOS 竖屏音乐墙播放条/配置按钮以侧边安全区抵扣底部遗留留白，左右安全区为零的普通 iPhone 仍保留 Home 指示条空间；横屏保持原底部避让。配置按钮碰撞检测改用播放条实际计算 bottom，避免与新布局使用不同预算。
- 通过：UI 标准门禁；共享136项；自有组件DOM回归；`Scripts/tests/test-ios-duo-layout.cjs` 在合成库覆盖600×900、900×600、440×956、左右80px侧区/无侧区、深浅、旋转后真实按钮边界、扫描点击打开设置。已查看定向截图。证据 `.build/reports/ui/ios-duo/{geometry.json,duo.png}`、`duo-shared.log`、`duo-components.log`。
- 通过：最终 iOS simulator Debug 构建及后台音频声明，`.build/reports/ios/duo-simulator-build.log`。
- 失败：完整音乐墙回归连续两次停在 `Focus surface must fade above the retained loaded poster`，日志 `.build/reports/ui/duo-wall-regression{,-retry}.log`；未屏蔽断言或将完整回归记为通过。
- 失败：新建专用 MiniVoice Shared iOS Duo Layout 模拟器（iOS27.1），使用合成文件运行真实WKWebView shared-host-smoke，停在“iOS 与 Android 共用真实封面、轮廓、遮罩和控制组件”断言，未进入后续布局矩阵。日志 `.build/reports/ios/duo-native-ui.log`。没有使用用户设备或真实音乐库。
- 待验收：Duo 实际系统侧栏状态/折叠旋转、真实扫描时浮层与底部按钮、三样式实体材质与触控；当前为定向代码修复，不声明完整页面或真机验收通过。

### 2026-11-10 Duo 半折上下播放布局

- 已实现：iOS27.1 公开活动横向 division 区域驱动分区，上方为实际正在播放歌曲的展开 WallPlayer，下方保留音乐墙与工具栏、预览、搜索、设置；折痕系统边距不承载交互。摊平、关闭或纵向折痕回到原布局，不以窗口比例猜测半折；不写入持久页面状态。上方复用歌词、播放/切曲、收藏、进度、译文和清晰/模糊组件，半折物理分区不提供收起按钮。侧栏/弹窗使上方 inert，返回恢复。
- 用户确认：系统状态栏移到侧边时底部按钮去掉多余安全区空白，只保留普通边距；沿用上一条定向修复。
- 通过：UI标准门禁、共享136项、自有组件DOM回归和完整音乐墙回归；日志 `.build/reports/ui/{table-shared.log,table-components.log,table-wall-regression.log}`。此前聚焦淡入断言失败的记录保留，不据本轮通过推断先前失败根因。
- 通过：`Scripts/tests/test-ios-table-mode.cjs` 以合成宿主折痕覆盖上下边界、上方实际歌曲/播放/切曲、深浅、插图清晰/模糊、侧栏inert/Escape、摊平恢复和连续快速姿态切换；已查看截图 `.build/reports/ui/ios-table/{dark,light}.png`，复查并修正了上方播放器与下方墙的绘制层级。
- 通过：最终 iOS simulator Debug 构建（公开 UIHingeInteraction/ReservedRegion API 经编译验证）及后台音频声明，`.build/reports/ios/duo-table-build.log`。
- 待验收：本轮无法通过已连接的电脑控制接口访问 Simulator，未完成真实系统半折事件、折痕坐标/旋转及WKWebView触控验证。页面测试注入合成折痕，不等于设备传感器验证；真实 Duo 材质、GPU、封面切换与三样式完整设备矩阵仍待验收，不声明实机完成或FPS。

### 2026-11-10 Duo 截图反馈：按钮、弹层、卡片与折痕留白

- 已修正：iOS 横屏不再把焦点卡片挤到右侧。摊平横屏卡片/展开播放栏在安全内容区居中；横向半折时使用系统纵向division的左边界，在左半区居中。上下半折按下半区自身尺寸/安全区计算卡片，预留顶部工具行与底部播放栏行，修复卡片与展开播放栏重叠。Android 保留既有布局。
- 已修正：iOS搜索/侧栏/设置/收起播放条统一56px控件尺寸、14px普通边距；修复横屏搜索48px与侧栏56px导致的顶部错位。侧栏底边与底部控件使用同一留白预算。Duo能力由公开inactive division查询识别，仅Duo侧边状态区抵扣底部额外留白，普通iPhone保留Home指示条安全区。
- 已修正：上下半折时侧栏、普通弹窗/歌曲操作及设置浮层和遮罩只覆盖下半区；现有弹层在姿态切换时也重新求交。上方封面连续覆盖折痕边距，交互止于折痕上沿，移除纯色大白条；上方标题去掉整行多余顶部留白，右侧译文控件单独避让系统顶部区域。
- 已修正：姿态事件先于React提交时卡片读到旧分区的问题；以工作区区域属性变化补充重测，并在卸载清理监听。
- 通过：共享137项（含新增iOS区域几何用例）、UI标准门禁；组件真实DOM与完整音乐墙回归，日志 `.build/reports/ui/{duo-regions-shared.log,duo-regions-components-verified.log,duo-regions-pages-verified.log}`。定向上下/左右/摊平、快速姿态、播放切曲、展开播放栏、下半区设置/侧栏/Escape、深浅、左右状态区与普通手机Home避让用例见 `duo-regions-targeted-final.log`、`duo-regions-controls.log`；已查看 `.build/reports/ui/ios-table/{book,flat,lower-settings}.png`。
- 通过：iOS/Android设置浮层横竖切换、左右安全区及实际按钮锚点回归 `duo-regions-settings-final.log`；首轮因弹窗仍用旧bottom安全区预算而失败，保留 `duo-regions-settings.log`，已同步设置层预算后通过，未放宽断言。
- 通过：iOS simulator Debug 最终构建与后台audio声明，`.build/reports/ios/duo-regions-build-final.log`。未改正式标识、签名、真实曲库或用户既有Xcode scheme修改。
- 待验收：页面测试使用合成姿态/安全区；系统实际fold frame、不同Duo系统状态条/旋转和真实WKWebView触控/材质/GPU仍待用户设备验收，不能由编译与Chromium截图推断实体体验全部达标。

### 2026-11-11 Duo 六姿态 × 三样式逐页梳理（未完成全部原生验收）

- 已建立逐页台账 `Docs/iOS-Duo-Page-Audit.md`，明确区分系统模拟器、注入姿态页面检查和未验证页面，不将矩阵格数量当验收百分比。
- 已修正：半折上下分区从音乐墙扩展至简易/音乐库；下半区采用自身宽高选择触控播放组合；左右半折的非墙播放页按fold frame分列，音乐库目录左列表/右播放，保留当前样式、主题、状态与既有控件规则。新增布局监听在卸载时清理，不保存临时物理姿态。另修复最近播放等空列表提示误导用户添加文件夹。
- 通过：专用Duo当前关闭外屏竖向真实WKWebView的三样式深浅页面矩阵68条，含主页面、侧栏、设置、搜索展开、播放/歌词/聚焦、队列、最近/收藏/歌手/专辑和创建歌单弹窗。实际data-style逐项断言；输出 `.build/reports/ios/duo-matrix/outer-portrait-reviewed/`，已查看原生页面截图。这里“搜索”仅代表展开边界，不能代表实际系统输入通过。
- 测试脚本问题保留：早期40条记录因同名导航选择器不能证明全部样式；扩展轮报 missing 收藏。已限定样式选择器且核对实际样式后重跑68条通过，没有降低几何标准或屏蔽应用失败。
- 通过：注入姿态36格页面几何（六姿态×三样式×深浅），含场景、侧栏与弹窗边界；共享137项、组件DOM、完整音乐墙回归和iOS原生逻辑测试。日志 `.build/reports/ui/{duo-matrix-projected-final.log,duo-matrix-shared.log,duo-matrix-components.log,duo-matrix-pages-reviewed.log}`、`.build/reports/ios/duo-matrix-native-tests.log`；iOS simulator Debug及后台audio声明见 `duo-matrix-build-final.log`。这些不代替真实六姿态测试。
- 失败/待修：现有XCTest `testContentLongPressAndSearchEditing` 在真实模拟器输入“山海”后仍读到占位文字，见 `.build/reports/ios/duo-matrix-keyboard.log` 与 `.xcresult`。未删除/放宽断言；尚不能区分焦点、系统输入注入与主机锁屏影响。测试失败后的诊断收集长时间未退出，已终止本次xcodebuild进程，不能将此测试记通过。
- 阻塞：本轮已在Device Hub选中专用模拟器，随后主机Mac锁屏；电脑控制工具明确要求手动解锁，两次检查均仍锁屏，已向用户请求解锁。未绕过锁屏，不能切换并验证另外五种实际系统姿态；原生实际方向、触控、键盘、状态恢复、子页面详查和实体GPU/材质仍待验收。本轮没有安装到真实设备或访问真实曲库，也未覆盖用户已有Xcode scheme改动。
- 补充未通过：追加“音乐库目录左右列避开折痕”断言的页面矩阵重跑，在主机锁屏期间启动后超过4分钟未返回、也未生成新截图；已终止该次专用Electron进程，见 `duo-matrix-projected-reviewed.log`（未返回，不作通过证据）。前述36格通过来自 `duo-matrix-projected-final.log`；增强断言及最终目录画面需解锁后重跑。

### 2026-11-11 用户新增截图：分界偏下、按钮偏高、横屏右侧空列

- 已复现原生数据：专用Duo展开横向951×669，系统safeRight84/safeBottom34，但活动occlusion实际仅右上84×124；竖向669×951，遮挡仅右上144×82。此前将局部遮挡作为整列安全区，且仅靠division识别设备，解释了用户截图里底部仍偏高及右侧整列未利用的问题。
- 已修正：通过公开hinge更新补充内屏识别，按活动occlusion局部避让；上方按钮保持共同安全行，底部未相交按钮只留14px。展开播放条/墙使用完整物理内容宽度居中；同步修正宿主旧bottom命中拒绝规则，普通外屏Home避让保持。纯模型不调用宿主或读持久状态。
- 已修正：上下分界使用折痕中线，控件边距单独避让。真实半折竖向fold455.5–495.5，中线475.5等于951/2；已查看原生截图确认没有把下沿当中线，原生数据与截图见 `.build/reports/ios/duo-localized/table-portrait-midline/`。
- 通过：共享141项，含局部遮挡与旋转方向/竖屏行对齐反例；UI标准门禁；组件DOM和完整音乐墙回归。日志 `.build/reports/ui/{duo-localized-shared.log,duo-localized-components.log,duo-localized-pages.log,duo-midline-layout.log}`；最终iOS simulator Debug构建及后台audio声明见 `.build/reports/ios/duo-localized-build-final.log`。
- 通过：真实展开横屏三样式深浅逐页68条，`.build/reports/ios/duo-matrix/open-landscape-localized/report.json`；真实竖屏按钮测量见 `.build/reports/ios/duo-localized/open-portrait-aligned/`。这是专用模拟器/合成库，不代表用户真机全部验收。
- 补充通过：用户再次解锁后已实操Device Hub完成展开横向、展开竖向与上下半折。上下半折三样式深浅逐页68条边界记录通过，`.build/reports/ios/duo-matrix/table-portrait-midline/report.json`；原生截图确认分界正好位于物理中线。展开竖向两上方按钮y96对齐、设置y881（高951，底距14）。新增竖向行对齐用例后共享141项通过，构建 `duo-localized-build-final.log` 通过。
- 再次阻塞：后续切换左右半折前Device Hub又报告Mac锁屏；本次UI会话已停止，没有伪造其余姿态结果。完整逐页矩阵、真实键盘/触控/重启等缺口仍以 `Docs/iOS-Duo-Page-Audit.md` 为准。

### 2026-11-11 用户截图：右下设置应与搜索对齐

- 已修正：Duo内屏音乐墙的搜索/设置共用右侧工具列水平锚点。搜索因右上系统遮挡内缩时，设置同步内缩；保留底部14px普通间距与播放栏实际碰撞上移规则。卡片、展开播放栏与画布可用宽度不随这条工具列改变。
- 通过：共享141项（更新局部遮挡用例以验证共同列，此为用户明确视觉契约变化，不放宽安全边界）；定向DOM覆盖真实951×669右上/右下84×124遮挡及669×951竖向144×82遮挡，实际左右边界误差<1px、无系统遮挡交集、展开播放栏保持居中，右上遮挡时底部距14px。已查看截图 `.build/reports/ui/duo-trailing-column/upper-right.png`；测量 `geometry.json`，日志 `duo-trailing-layout.log`、`duo-trailing-shared.log`。
- 通过：UI标准门禁；iOS simulator Debug及后台audio声明 `.build/reports/ios/duo-trailing-build.log`。完整页面回归见 `.build/reports/ui/duo-trailing-pages.log`，真实Duo该新增轴线的WKWebView/触控仍待专项验收，前述其他姿态与搜索输入缺口未据此关闭。

### 2026-11-11 固定待播放页、内容区域与双向半折动画

- 已实现：按用户更正，半折竖屏无当前歌曲时上方为固定时钟/日期/寄语页面，无自定义入口、无新外观存储。选歌自动交接至正在播放，空库也不再只剩黑底。浅色为浅薄荷/深文字，深色为深蓝绿/浅文字；设置显式切换及跟随系统均有页面验证。
- 已修正：展开播放栏限于左工具到右搜索/设置列的主内容区域，在此区域居中，不越入右侧状态栏；音乐墙设置弹层及其遮罩也限制在该区域，面板右下角跟随设置按钮实际边界，覆盖按钮所在区域。墙面仍铺满，不为工具列挖空整列。右下遮挡时底部两按钮共用安全行；收起圆形播放条不触发展开栏碰撞上移。
- 已优化：折痕中线附近使用40px无实色分隔的透明采样过渡，重点柔化下方墙上缘，不改变按钮命中与中线位置。
- 已实现：竖屏音乐墙展开↔上下半折的420ms双向分界动画；分界从顶部到折痕中线/反向返回，上半区、音乐墙和按钮同步真实几何变化。可中断反向，退出保留上半节点，动画后清理；减弱动态立即切到最终布局，初次加载不从零飞入。动画期间已打开弹层的边界也持续随分界移动。
- 通过：UI门禁；共享141项；固定待播放页DOM（空库、无配置入口、选歌切换、摊平、主题及跟随系统）`table-idle-theme-layout.log`；主内容播放栏和弹层边界 `table-idle-content-region.log`；分界中间帧/按钮轴线/退出节点/弹窗边界/反向/减弱动态 `fold-motion-layout.log`，帧数据 `.build/reports/ui/fold-motion/frames.json`。组件DOM `fold-motion-components.log`、完整页面 `fold-motion-pages-final.log`通过，iOS simulator Debug/后台audio声明 `.build/reports/ios/fold-motion-build-final.log`通过。
- 通过：专用Duo真实WKWebView，Device Hub实际竖屏展开→半折与半折→展开各采到15个中间位置样本，上半下缘与下半上缘一致；最终分界分别475.5/0。报告与截图 `.build/reports/ios/fold-motion/{enter-portrait,exit-portrait}/`。这是样本数量，不是FPS。首次采样误在横屏操作，没有收到竖向折痕事件而超时，保留 `fold-motion/enter/report.json`；切到正确竖屏后通过，未放宽断言。
- 方向问题未关闭：补齐手机倒置竖屏声明，并在应用方向策略返回all。原生探针确认控制器mask30；左右横屏/正常竖屏能响应，但外屏设备orientation2时scene/interface仍为1（浏览器angle0），见 `duo-localized/closed-upside-down-final/report.json`；不能声称倒置竖屏已修好，未用CSS旋转内容伪装系统旋转。系统仍会考虑设备可支持方向，参考Apple UIViewController supportedInterfaceOrientations文档。该缺口与此前搜索真实输入失败、六姿态未覆盖项继续保留。
- 未操作真实设备/曲库；仅专用模拟器合成文件。实机GPU/材质、所有姿态触控/重启和原生反向打断仍待验收，不以截图或编译代替。


### 2026-11-11 Duo 聚焦内容区域与横向半折连续移动

- 已实现：iOS Duo 音乐墙聚焦使用与按钮、展开播放栏一致的内容左右边界，排除侧边系统状态区域；横向半折仍取左屏边界与内容边界的交集。普通 iPhone/iPad 没有 Duo 区域数据时沿用原有安全区算法。
- 已实现：横屏 Duo 内容区域改变时，复用音乐墙 520ms 聚焦平移与重排动画；从展开到左侧半折区域及反向均连续移动，尺寸同步变化，减弱动态时直接到最终布局。竖屏分界动画期间保持原有处理。
- 通过：`duo-focus-layout.log` 的 Chromium 合成页面验证竖屏侧边状态栏排除后的聚焦中心，以及横屏展开/半折双向移动的中间帧和最终中心；证据位于 `.build/reports/ui/duo-focus/`。
- 通过：142 项共享单元测试、UI 标准检查、按钮/弹窗边界回归、竖屏分界动画及反向/减弱动态回归。日志为 `.build/reports/ui/duo-focus-{unit,standards,controls,fold}.log`。
- 通过：iOS Debug 模拟器构建及后台音频能力检查，日志 `.build/reports/ios/duo-focus-build.log`；新包已安装专用 Duo 模拟器。
- 待验收：本次横屏平移动画在 Device Hub 实际折叠操作下的视觉验收；上述中间帧证据来自 Chromium 合成姿态，不冒充原生实际姿态验收。此前外屏倒置竖屏问题仍未解决。


### 2026-11-11 半折竖屏音乐墙越界与上方展开

- 已实现：下半音乐墙场景独立裁切，平移/惯性卡片不得穿过中线覆盖上方播放页；仅限制 iOS table 音乐墙，flat 外溢规则保持原实现。
- 已按用户最新纠正保留展开按钮：点击下方预览卡片的展开按钮，上方展示该歌曲的展开预览，收起恢复当前播放歌曲；下方始终为音乐墙，预览不会自动开始播放。复用既有展开状态与取消流程。
- 通过：Chromium 页面 `Scripts/tests/test-ios-table-clip.cjs` 实际派发 pan 跨越中线，验证上下分区命中隔离、裁切规则、展开按钮保留、上方所选歌曲预览/收起、下方不展开、flat 恢复。证据 `.build/reports/ui/table-clip/{layout.log,geometry.json,pan.png}`。
- 通过：142 项共享测试、UI 标准检查、竖屏双向分界动画及减弱动态/反向回归、横屏双向聚焦平移回归；日志 `.build/reports/ui/table-clip/{unit,standards,fold,focus}.log`。
- 通过：iOS Debug 模拟器构建与后台音频能力检查，`.build/reports/ios/table-clip-build.log`；新包已安装专用 Duo 模拟器。
- 待验收：Device Hub 原生半折竖屏跨中线拖动与展开的最终视觉验收。专用模拟器已切到半折竖屏，因 Mac 锁屏暂时无法完成拖动，未把 Chromium 结果计作原生视觉通过。原有外屏倒置竖屏问题仍未解决。


### 2026-11-11 半折上方收回动画与展开图标同步

- 已实现：展开状态与图标共用 wallExpanded；上方展开后，下方卡片同步显示收起图标，点击下方按钮同样收起上方预览，恢复展开图标。
- 已实现：半折→展开时上半画布保持固定完整高度，沿分界整体滑到屏幕上方；反向整体滑入。不再随分界窗口高度把插图、歌词、按钮挤压成条。分界、下方音乐墙与按钮继续使用既有双向运动和减弱动态规则。
- 通过：更新的 Chromium 离屏动画测试逐帧断言上方画布 475.5 点、播放器内容 455.5 点始终保持，画布底边与移动分界一致，继续检查中断反向、减弱动态与弹窗跟随。`.build/reports/ui/table-clip/fold.log`、`.build/reports/ui/fold-motion/frames.json`。离屏渲染用于避免锁屏挂起 Chromium 的 requestAnimationFrame，不作为原生模拟器姿态证据。
- 通过：UI 标准检查、142 项共享测试、iOS Debug 模拟器构建及后台音频能力检查，新包已安装专用模拟器。
- 待验收：原生拖拽越界、上下展开图标同步与新版上方整页滑出视觉效果。电脑控制再次报告 Mac 锁屏，已请求用户解锁；不把构建/Chromium 结果当作此项原生通过。


### 2026-11-12 半折→展开跳动修复与原生复验

- 修复：上方预览展开与普通墙卡片全屏展开解耦，tablePreviewId 仅为临时状态；结束半折不会再把下方卡片自动全屏展开。上下同一歌曲的展开/收起图标保持同步。
- 修复：localized table 安全区规则被旧规则覆盖，退出 table 时中心突然下移 41 点；修正选择器冲突使安全区与分界同步变化。
- 修复：CSS 分界已移动、Wall 的 ResizeObserver/React 提交尚未完成时，摄像机仍按前一帧 viewport 定位。仅在 iOS 分界运动期间有界逐帧同步测量与 layout 绘制，动画结束和卸载取消 RAF；普通设备/Android 不启用此同步循环。
- 通过：更新 Chromium 分界测试检查上方画布/播放器尺寸恒定、聚焦中心与宽度在进入/退出中单向变化，无回弹；保留中途反向、减弱动态、弹窗/按钮边界检查。`.build/reports/ui/table-clip/fold.log` 与 `.build/reports/ui/fold-motion/frames.json`。修复前的增强断言确实发现了回弹和最终 41 点跳位，未放宽断言来通过。
- 通过：专用原生 Duo 模拟器实际 Device Hub 竖屏半折→展开、展开→半折操作，各采得 7 个中间样本；focusStable=true、aligned=true、最终分界正确。证据 `.build/reports/ios/fold-motion/{exit-stable-focus-final,enter-stable-focus-final}/report.json`。样本数不是 FPS。
- 通过：原生操作确认上方歌曲预览展开与下方收起图标同步；预览状态下退出半折最终仍为音乐墙聚焦，未自动全屏。此项为 CUA 观察；跨中线拖动的 CUA 手势未观察到墙移动，不计原生拖动验收通过，Chromium 跨界裁切测试已通过。
- 通过：142 项共享单元测试、UI 标准检查、table 预览/收起/越界/离开后不触发第二次全屏回归、横屏 book 双向中心回归与 iOS Debug 构建。日志 `.build/reports/ui/table-clip/{unit,standards,layout,focus}.log`、`.build/reports/ios/table-clip-build.log`。
- 前述因锁屏待验收的“双向实际分界动画”已由本次原生报告覆盖；快速反向/减弱动态仍是 Chromium 证据。外屏倒置竖屏、普通 iPhone/iPad 全量验收等其他未通过项目不因此变为通过。

### 2026-11-12 音乐墙离线识图统一

- 实现：Mac、iOS、Android 和 Windows 的共享音乐墙改用同一套本地 ONNX 检测器（YuNet 人脸、YOLOX-Nano 人体、PP-OCRv4 文字区域）及共用构图评分；读取实际展示图的方向和坐标空间，按最终墙面宽高裁切，并保留多人、人脸、人体与文字的综合评分。居中和手动构图仍可用。识别失败沿用现有像素显著性回退，不代表识别成功。新请求按最近选择优先，但不丢弃已开始或已排队的识别；长期快速切换时队列和内存表现仍需实机评估。
- 资源：人脸约 0.23 MB、人体约 3.66 MB、文字约 4.75 MB、单线程 WASM 运行库约 11.21 MB（未压缩资源，安装包增量因平台打包压缩而异）；模型、来源与许可证列入随包通知，前端锁文件及离线依赖缓存已更新。
- 通过：共享 UI 单元测试 154 项、Mac 桌面单元测试 67 项（另 4 项跳过）、Windows 单元测试 61 项；构建门禁、共享/桌面生产构建、Android APK 和 iOS Simulator Debug 构建。Electron 的隔离端到端探针在真实跨源封面协议下成功加载并运行三个模型，合成文字检出；Mac 人脸照片探针与人体多人照片探针通过（多人样本漏掉一位边缘残缺人物）。音乐墙页面回归及展开裁切回归通过。
- 移动端定向验证：使用独立 iOS 27.0 模拟器和 Android 35 专用模拟器，在各自真实 WebView 与本地资源协议中加载并运行三个模型，合成文字检测成功；测试仅证明该样本推理可用，不代表真实封面识别准确率或实体设备性能。Android 所用模型探针为隔离测试 APK；iOS 所用探针为模拟器测试应用副本。
- 未通过：Android 全套 UI 测试的旧原生入口因缺少 `MainActivity.scanning` 字段中止；共享 portable 和 wall 专项均在样式切换动画帧断言失败。iOS 共享墙 smoke 在活动卡片断言失败。Android 音乐墙与 iOS 墙面检查分别在禁用模型的隔离对照包中复现同一失败，因此该对照未显示模型是这些断言失败的必要条件；仍不能据此宣称移动界面体验回归通过。Windows 实机、iOS/Android 实体设备的性能、真实封面审美与持续快速切换仍待验收。

### 2026-11-12 合并 Duo 更新与离线识图

- 已快进至远端 `7d13f66`，保留本地离线识图接入、Duo 半折预览及用户已有 Xcode 界面状态；验收台账保留双方记录。
- 合并后通过：UI 标准门禁、共享单元测试 154 项、Mac 桌面单元测试 67 项（4 项跳过）、Windows 单元测试 61 项、共享和 Mac 桌面生产构建、Android APK 与 iOS Debug 模拟器构建；Electron 三模型实际推理和音乐墙原图裁切回归。
- 通过：Chromium/Electron 合成姿态下半折跨界裁切与预览、分界双向动画/中途反向/减弱动态，以及横向半折聚焦平移。上述不替代原生设备姿态、实体设备性能及此前移动界面未通过项目的验收。

### 2026-11-12 离线识图卡顿、缓存与主体构图

- 原因与修复：聚焦封面时，原实现把模型初始化、像素预处理和三模型推理放在页面线程；本机隔离探针曾观察到约 205ms 冷启动和 164ms 热调用主线程长任务（单次样本，不代表设备基准）。现将模型初始化、预处理和推理放入常驻 Dedicated Worker；主线程仍负责图片解码及像素读取，Worker 不可用时回退到既有像素构图，不把模型移回界面线程。
- 离线缓存：按封面身份、版本和模型版本持久保存检测框，不保存图片；最大 20,000 条、最长 90 天、单条内容受限。已有缓存命中不解码图片或运行模型。曲库载入或检查时，应用在前台且用户空闲后逐项预计算，用户操作延后下一项，当前点击优先于排队的预计算；清理缓存后停止预热，下一次检查或目录变化恢复。持久存储不可用时按需识别，后台任务限频重试；单个图片不能缓存不会终止后续歌曲。旧识别结果因 v2 缓存版本自动失效。
- 构图：脸和人体可共同放入时保住完整身体与头部留白，装不下时保脸；多人已匹配的脸不重复处理，未匹配身体最多局部复检两次，无人体时仅对边缘均匀且主体孤立的图片最多复检一次。对单一强对比插图和标题，只有两者都能放进视口时才一起保护；不将视觉形状视为已识别人脸。复杂背景或放不下时仍按原策略权衡。
- 原图坐标：Mac/Windows 音乐墙使用与识图一致的严格原图 URL；原图缺失则保留可展开的预览但不套用原图识别框，原图恢复后重新加载。模型缓存升级避免复用旧预览坐标。iOS/Android 继续使用显示图自身的版本身份和坐标空间。
- 通过：共享单元测试 187 项；Mac 桌面单元测试 70 项（4 项跳过）、Windows 61 项；UI 标准门禁、Mac/Windows 共享界面构建、Android APK 和 iOS Debug 模拟器构建。Electron 测试覆盖真实 Worker 和三个模型、缓存跨窗口命中/清理/存储不可用、限制后台工作、模型重算期间界面持续绘制；Mac 原图缺失与恢复的真实页面回归通过。完整音乐墙页面回归最终通过，先前一次桌面样式切换失败原样重跑未复现，日志 `.build/work/artwork-worker-wall-regression.log` 和 `.build/work/artwork-worker-wall-rerun.log` 均保留。
- 移动端证据：iOS 27 专用模拟器的真实 WKWebView 验证 Worker、IndexedDB、合成曲库后台生成和进程重启后复用；Android 35 专用模拟器验证真实合成曲库后台写入文字框，点击同曲命中本地键且未再次提交 Worker，见 `.build/reports/android/background-index-probe/text-report.txt`。两个平台也分别测试了局部侧脸复检；均非实体设备性能验收。
- 限制：一张公共领域低头侧脸照片的人工缩小样本在桌面和 Android 可检出；iOS 较大样本可检出，极小样本仍漏检。几何负例数量有限，不能推断复杂封面、背面头部或动漫人物的识别率和误报率。Windows 实机、各实体手机的真实歌曲体验、CPU/电池和历史移动界面未通过项目仍待验收。

### 2026-11-13 真实曲库封面评估与文字边界修复

- 在用户授权下只读检查曲库索引和封面：1,035 条带封面索引的记录、827 个封面键、按原始图片内容去重后 794 张。真实图片及路径只用于本机隔离评估，不进入源码或测试素材；没有改写歌曲或用户缓存。
- 使用生产离线 Worker 的三个模型和实际构图逻辑，对每张图片运行 390×844、844×390、1440×900、2560×1080 四种目标比例，无推理错误。检测框只是模型结果，不是人工标注，也不能据此计算准确率。存在侧脸/低头漏检、文字或插画误判人脸、多人与文字无法同时放入画幅等实际案例。
- 修复：最大面积文字和最高文字属于不同框时，标题筛选可能为空，导致完全失去主要标题保护；现在回退到面积最大的合格文字框，并用无真实封面的合成案例回归。对上述 794 张 × 四比例重算，前后裁切坐标均未变化；这项修复不应表述为这批真实封面已获得视觉改善。
- 已评估但未采用：角落小字降权可能裁掉真正标题；主角人脸偏移可能牺牲其他真人；无脸样本的变形和分块人脸复检在 52 张中出现误检且增加推理成本。更严格的单次复检在 11 张符合条件的封面上未找回人脸。当前结果不足以证明这些策略在群像、远景人物或文字封面上可靠。
- 候选模型隔离试验：U²-Net-P ONNX 权重 4,574,861 字节；在本机 Node 的单线程 ONNX Runtime Web/WASM 可运行，冷加载约 110ms、首次推理约 791ms、11 次后续推理约 751–761ms/张（不含解码和预处理，非移动端性能）。该权重输入固定 320×320，直接输入 160×160 或 224×224 被拒绝。六张封面中低头人物和插画主体可被突出，但也漏掉暗色次要人物和标题、将群像合并并响应文字；仅为辅助信号，不能当成人脸或完整主体检测。模型未加入产品；跨平台 WebView、设备性能和权重再分发条件仍需核实。
- 通过：共享 UI 单元测试 188 项、Mac 桌面测试 70 项（4 项跳过）、Windows 测试 61 项、UI 标准检查、Mac 桌面生产构建、Android APK 和 iOS Simulator Debug 构建；Electron 实际 Worker、三个模型、缓存与展开裁切专项通过。实体设备性能、Windows 实机及历史移动 UI 未通过项仍待验收；当前模型对侧脸和插画的识别局限仍未解决。

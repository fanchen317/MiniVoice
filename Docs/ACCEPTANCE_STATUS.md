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

当前报告目录：`.build/Shared/Core/`。重点报告 `experience-search-*`、`full-controls-*`。历史报告证明当时对应改动，不自动视作未来改动仍通过。

## 当前交付

Android 定向体验包：`.build/Android/MiniVoice-android-experience.apk`。包含音乐墙可见区修正和搜索变形动画；实体手机视频场景仍需回验。

Mac 体验包：`.build/MiniVoice-debug.app`，继续与正式版隔离。

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

本轮 Android 专用 MiniVoiceRegression 模拟器 portable 回归通过（UI_PORTABLE_PASS，parity-android-portable.txt）：真实 WAV 播放、三样式主题、歌词、触控滑块/滚动条、长按取消、横竖屏、设置及重启锚点。测试仅使用合成音乐库；截图已拉取至 .build/Android/ui-tests/parity-screenshots。实体手机/GPU 与正式版 1:1 对照继续待验收。

## 2026-10-23 用户截图按钮 / Android 整墙闪屏专项

输入证据：用户 Screenrecorder-2026-10-23-14-42-19-67.mp4（约 6.78 秒）及四张标注截图。抽帧显示切卡过程中整片墙面短暂消失，悬浮工具仍在，不能归结为单张封面解码。原视频抽帧 contact.png 位于 .build/Shared/Core/user-flash/。本机未稳定复现用户实体 GPU 的相同故障，唯一根因仍待真机诊断。

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

验证：组件边界 91 源文件通过，共享逻辑 30 项通过，git diff --check 通过。Electron 页面全套回归通过，包含四边安全区、拖动跟手/回弹/取消/关闭及拖动后 Enter 激活（insets-sheet-render.txt）。专用 MiniVoiceRegression 模拟器分别在手势导航、三键导航执行完整 portable 回归，均 UI_PORTABLE_PASS；真实 Activity 横竖屏系统 inset 与页面比较、真实触摸注入拖动/取消均通过（insets-sheet-android-gesture.txt、insets-sheet-android-threebutton.txt）。已恢复模拟器手势导航。最终键盘兼容修正后重新构建 Android 体验 APK，路径 .build/Android/MiniVoice-android-experience.apk。实体手机触感、用户设备 GPU 流畅度仍待实机验收；本轮没有修改 Mac。

## 2026-10-26 手机侧栏宽度和可见动画纠正

用户反馈手机侧栏过宽、开关和样式切换看不到动画。本轮收窄为 80vw、最大 340px；侧栏由仅 28px 位移改为从屏幕左侧完整滑入，关闭滑出时保留退出层直到 280ms 动画结束（原遮罩提前移除会截断退出），退出层继承 mobile 布局。样式切换改为持续页面根的自有 WAAPI 收束/进入及图标标记旋转，不依赖 WebView 整页快照；保留最新连续点击意图和减弱动态规则。

已通过：组件边界 91 源文件、共享逻辑 30 项、Electron 页面回归，包括侧栏实际宽度/中间位移、退出保留/清理/快速重开、三种样式根节点的运行中动画，以及原系统安全区和弹窗拖动条。专用 MiniVoiceRegression Android 模拟器 portable 完整回归 UI_PORTABLE_PASS（drawer-slide-android.txt），通过 requestAnimationFrame 采样验证侧栏从屏外到最终位置的多个中间帧、样式切换存在多个不同的非单位变换，包含真实系统栏横竖屏及其他原功能回归。最终退出副本布局修正后重新构建并复测结果另记。实体手机 GPU 流畅度继续待实机体验确认，未将模拟器采样称为实机 FPS。

最终复核：drawer-slide-android-final.txt 再次 UI_PORTABLE_PASS；drawer-slide-render-final.txt 增加连续三次切换以最新意图落位、结束后 transform 归零、减弱动态直接更新状态的页面验证通过，原 Mac 页面回归通过。已查看 drawer-narrow-final.png 确认收窄后标题与按钮可容纳、右侧页面留白可见。Android 最终 APK 已更新至 .build/Android/MiniVoice-android-experience.apk。

## 2026-10-26 手机侧栏前后与上下分区层次

按用户“弹出后有上下层次、三种样式都优化”的要求：音乐墙、音乐库、简易共用前景侧栏/后景主页面关系。侧栏弹出时主页面仅视觉缩小至 .96、下沉 8px、圆角及边缘阴影，关闭恢复原几何；侧栏浮层阴影强化，顶部品牌/操作区与下方导航用分隔线组织，简易样式歌曲区再分层。没有增加整页模糊、重新排版或改变墙面相机尺寸；正文继续 inert，系统减弱动态取消过渡。

页面验证通过（drawer-depth-render.txt）：三种样式/深浅主题/横竖屏原回归、侧栏前后层次参数、关闭恢复 transform 与交互、快速重开、连续样式切换、安全区、弹窗拖动，以及原 Mac 页面回归。已查看新的 drawer-narrow-final.png 确认前后圆角边缘、标题分隔与层次。组件门禁 91 源文件及 git diff --check 通过。Android 首轮新增层次检查通过，宿主固定延时检查退出层时已错过短动画，改为浏览器 requestAnimationFrame 记录真实退出中间帧后复测，最终结果另记。实体设备 GPU 流畅度仍待实机确认。

补充复核过程：初始固定时长的滚动断言在歌手页异步 page.restore 返回前读取了 0；随后返回音乐库的断言也早于恢复完成。SongList 增加 aria-busy 恢复标记和卸载帧保护，可见性回调不再在恢复请求未完成时提前标记就绪；原始像素锚点断言保留，测试等待明确就绪。动画检查同样从宿主固定时间点轮询改为页面 RAF 记录开始至结束，仍要求多个不同的中间变换，未放宽为“存在动画对象即通过”。

最终 Android 完整 portable 回归 UI_PORTABLE_PASS（drawer-depth-android-complete.txt）：三种样式层次及复位、侧栏真实进出中间帧、样式切换、原像素滚动锚点/分组返回/重启、系统安全区、触控等全部通过。共享逻辑 30 项通过；最终组件边界及差异空白检查通过。体验 APK 已更新为 .build/Android/MiniVoice-android-experience.apk。

## 2026-10-26 手机样式切换对齐 Mac 碎片扩散

用户明确指出手机仍未实现与 Mac 一样的切换。本次核对：此前手机是淡入/缩放，Mac 是当前页面快照从品牌图标向外碎片扩散，前轮不能称为已对齐。本轮抽取 Mac 原 fragmentCells/fragmentProgress 与绘制公式为共享 fragmentMotion.js，Mac 和手机都调用同一 paintFragments，保留 200ms 距离延迟、480ms 运动、680ms 总扫动、旋转/卷曲/缩小/140px 散开的原效果。

Android 增加自身 Activity WebView 区域 PixelCopy 快照能力（不录屏、不读取其他应用），经适配器注入；手机先以旧页面画布覆盖再提交新样式，随后碎片散开揭示新样式。获取或解码失败仍有短进入兜底，但验收要求快照碎片路径，不能用兜底冒充对齐。连续切换按最新意图；旋转、运行时减弱动态和完成均清理画布/帧/监听器，状态更新失败不吞错。

已通过：组件边界 92 源文件，共享逻辑 30 项，Mac 逻辑 55 项（3 项跳过）。Electron 实际页面回归通过（fragment-render-final.txt），包含真实页面截图作为碎片纹理、多个碎片中间帧、连续切换最终状态、运行时减弱动态、动画中 resize 清理，以及三种样式、深浅、侧栏层次/安全区/弹窗拖动和原 Mac 页面回归。已查看 phone-mac-style-fragments.png 确认旧画面碎片实际旋转散开。Android 最终结果另记；实体手机 GPU 流畅度仍待实机验收。

Android 最终完整 portable 回归 UI_PORTABLE_PASS（fragment-android.txt）：三种样式切换经真实 PixelCopy 宿主链路，RAF 要求多个不同碎片时间帧且绘制纹理具有多个非透明颜色，确认没有走无快照兜底；原安全区、层次/侧栏开关、实际触摸、滚动锚点/重启等回归通过。最终组件边界与 git diff --check 通过，Android 体验 APK 已更新至 .build/Android/MiniVoice-android-experience.apk。

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

过程与限制：仪器输入已修正为 SOURCE_TOUCHSCREEN/TOOL_TYPE_FINGER 和实际 Down/Up 间隔；之前未知工具类型会产生空 pointerType 而没有 click，不能作为真实手指的通过证据。长时运行模拟器曾出现旧图块，冷启动 host/OpenGL 后端（本轮关闭 Vulkan）并按真实手指事件重新完整验证；已查看 mobile-wall-final-android.png 和 mobile-wall-native-touchend.png，未再见早轮残留块。常驻整页合成、全墙 Canvas、强制 WebView 硬件层等未改善的实验均已撤销，交付不包含这些尝试。实体手机的 GPU 流畅度、偶发闪屏和物理震感仍需实机体验，不宣称所有设备均已消除闪屏。Android 体验 APK 已更新至 .build/Android/MiniVoice-android-experience.apk。

### 2026-10-27 手机实机截图反馈：侧栏背景边线、露底和响应
已实现：后方卡片/播放栏边框与阴影在侧栏打开期间隐藏并恢复；导航与歌曲列表增加分层材质；音乐墙增加冻结封面的全幅背景，保留前景内容后退而不露出纯色底。打开侧栏不再连续读取墙面，前景平移与遮罩渐入分开合成。切换按钮立即提供工作中反馈，截图准备不再等待状态 flush，提交仍序列保存。Android 维持截图分辨率上限，独立线程编码 JPEG 95，减少无损 PNG 的体积与编码负担。
验证：mobile-drawer-layer-android.txt 完整 UI_PORTABLE_PASS；含实际手指输入、侧栏真实进入/退出帧、背景边框隐藏/导航层次/墙面全幅背景、三样式与主题、系统栏、横竖屏、滑动取消和返回还原。mobile-drawer-layer-render.txt 原三样式与 Mac 页面回归通过；共享单元 mobile-drawer-layer-unit.txt 33 项通过。截图与日志位于 .build/Shared/Core。
待验收：用户实体手机的帧稳定性与截图链路时延；本次未测量实机 FPS，不以模拟器或静态截图宣称所有设备均无卡顿。截图编码已改变格式但未降低原有分辨率上限，需要实机确认细字与碎片边缘观感。
补充验证：mobile-drawer-layer-touch.txt 覆盖简易/音乐墙分层、全幅背景、关闭动画过程中保留背景且完成后释放、延迟 700ms 返回截图时按钮立即出现工作动画、切换完成后清理碎片画布；mobile-drawer-layer-components.txt 自有组件键鼠/忙碌/减弱动态回归通过。最终 Android 包的 targeted mobile-drawer-layer-final-android.txt 为 UI_WALL_PASS。

### 2026-10-27 手机音乐库列表左右留白
已调整主音乐库普通歌曲行：去除滚动容器右侧 28px 预留与行内 26px 预留的叠加，改为左右各 8px 行外间距；封面与收藏图形到面板的可见边距均为 20px。标题栏左侧对齐封面，歌曲信息使用释放出的宽度；收藏按钮维持 44px 触摸区域，时长不压缩。分组卡片、侧栏列表及 Mac 页面未调整。
验证通过：mobile-library-spacing.txt 中 360/390/430px 竖屏及 844px 横屏的两侧可见边距均为 20px、收藏命中区 44px、封面/文字/时长/收藏无重叠；已查看 mobile-library-balanced.png。组件边界及 git diff --check 通过，Android 体验 APK 已重建。实体手机观感待验收。

### 2026-10-27 双端普通歌词滚动与边缘渐隐
已实现：手机普通歌词补齐与 Mac 相同的上下渐隐（各为视口 7%，最多 28px），当前行及邻行使用一致的距离强调；手机去掉歌词 shell 顶部 40px 保留区，Mac 简易歌词控制条改为浮动，去掉独占顶部行。手机首尾留白改按实际歌词视口高度计算，Mac 末尾补齐对称留白，最后一句亦可居中；Mac 用行/视口实际坐标定位，尺寸变化尊重手动滚动保护。音乐墙自己的歌词呈现保持原逻辑。
验证通过：Scripts/test-lyrics-viewport.cjs，日志 lyrics-viewport-geometry.txt，检查手机/Mac 首、中、尾行可居中、渐隐存在、顶部控制条浮动、歌词视口不超出卡片；过程发现手机默认 50vh 留白导致内层撑高，已改为初始零留白、测量后设置像素值，并重新检查实际 436px 视口。lyrics-viewport-final-android.txt 完整 UI_PORTABLE_PASS；lyrics-viewport-render.txt 现有双端页面回归通过；lyrics-viewport-unit.txt 共享 33 项通过。截图已查看，组件边界、diff 空白检查及 Mac codesign --verify --deep --strict 通过。Android 体验 APK 和 .build/MiniVoice-debug.app 已重建。实机滚动观感待用户验收。

### 2026-10-27 Mac 搜索栏边界与信息按钮材质
已实现：音乐库搜索栏从窗口固定宽度改为在 workspace-header 可用宽度内收缩，browse-tools/input 允许 flex 收缩，搜索图标保持尺寸；侧栏覆盖/并排、窄窗口不再把搜索框挤出右边界。简易样式右上角歌曲信息按钮纳入与侧栏按钮相同的共享玻璃材质，沿用统一的圆形 38px 布局与图标组件。
验证通过：mac-search-layout-geometry.txt，304/486/770/1100px 窗口侧栏开/关全部检查搜索框在标题栏和窗口边界内、输入区宽度为正；信息/侧栏按钮计算背景、尺寸、圆角一致。mac-search-layout-render.txt 原双端页面回归通过；已查看 mac-search-layout.png。组件边界、diff 空白及 Mac 体验包签名验证通过。新包为 .build/MiniVoice-debug.app；实机外观待验收。

### 2026-10-27 Mac 桌面歌词按钮、横竖布局与焦点轮廓
按用户明确要求，Mac 非输入控件取消 focus-visible 轮廓（保留焦点、Tab 与 Enter/Space 操作），仅输入框/文本编辑区域保留轮廓；这是本轮对原通用键盘轮廓规范的用户指定外观例外，不改变手机组件默认规则。桌面歌词移除显示播放器/播放暂停两个按钮，新增横竖切换；保留窗口内锁定与关闭，移除设置里的锁定开关。解锁悬浮按钮默认透明无边框，悬浮出现材质与轮廓，歌词窗口内按钮亦只在悬浮显示轮廓。横竖布局经专用配置协议保存，按显示器可用范围调整窗口与独立尺寸限制，竖排原文/译文继续自适应字号。音乐墙收起状态在播放时复用 NowPlayingIndicator 持续四音柱律动，展开后的暂停控制保持原语义。
验证通过：mac-lyrics-actions-geometry.txt 覆盖三按钮/移除旧控件、横竖切换命令和竖向 writing-mode、解锁默认透明、键盘聚焦图标无轮廓、设置锁定项移除及收起播放音柱在两个采样时刻确实变化；mac-lyrics-actions-render.txt 原双端页面回归通过。mac-lyrics-actions-unit.txt 60 项通过、4 项后端条件跳过，含新增竖向配置持久化尺寸约束；组件边界、main.cjs 语法、diff 空白和体验包签名校验通过。新包 .build/MiniVoice-debug.app。窗口在实际多显示器间的旋转、竖排长歌词观感待实机验收。

### 2026-10-27 双端图标与手机队列、主题切换
已实现：Mac 音乐库定位/排序/清除搜索改用共享 SVG，手机设置的主题选中与添加文件夹也使用共享图标，保持 24 点画布与既有语义映射；静态审计两端 103 处 Icon/icon 引用均能解析到共享真实路径。手机三样式的队列统一行边距、10px 间隔、44px 收藏操作与选中态，取消音乐墙对队列行的玻璃卡片/背景模糊污染。手机主题选择立即显示并保存，失败恢复原状态并显示错误，后续写入不会清除更新的选择；缺少偏好时跟随系统。弹窗独立按选定主题取色，避免墙面样式覆盖设置/队列配色。
验证通过：theme-queue-matrix.txt 覆盖三样式×浅深主题六组合、设置选中语义、队列背景/行材质/间距/图标画布及重载后持久化；已查看 theme-queue-light.png / theme-queue-dark.png。theme-queue-android.txt 完整 UI_PORTABLE_PASS；theme-queue-render.txt 原双端页面回归通过；theme-queue-unit.txt 共享 33 项通过。theme-queue-icons.txt 静态图标审计、组件边界、diff 空白及 Mac 签名校验通过。双端体验包已更新，实体设备切换响应仍待用户验收。

### 2026-10-27 用户录屏与七张截图定向修复（本轮）

已实现：手机展开卡片隐藏轮廓，移除只在动画端点更新的全墙黑遮罩；侧栏背后使用实际页面缩放，删除外侧静态封面拼接层，恢复后相机不变。侧栏内部保留独立模糊采样并复用按钮材质色罩/模糊参数。播放栏恢复原歌曲信息与控制同排、进度在下的紧凑布局；缩放滑块去掉圆点刻度并缩小圆形手柄。原生 Android configuration 的 systemDark 进入快照，修复 WebView media query 与系统主题不一致；手机设置弹层不再将整层玻璃祖先与面板同时淡入。

Mac：解锁命中区闲置时包括图标与底框均透明，悬浮/焦点可见；竖置的歌名/歌手及控制区同步纵向布局，目标至少 28px。歌词默认窗口压缩至横 600×112、竖 110×600，仅迁移旧默认预设，自定义尺寸保留。Mac 音乐墙配置映射共享 wallSettings，设置齿轮改为两端共用的中心对称路径。

通过：组件边界；共享逻辑 33 项；桌面逻辑 61 项、4 项宿主测试在普通运行跳过；打包后台以独立 MiniVoice.Test.* 偏好域额外运行 4 项全部通过；Mac codesign --verify --deep --strict；自有组件交互、test-wall-version 实际页面回归（1037 首、三种样式/深浅、打断、缩放/拖动、展开返回、窗口边界）；test-mobile-wall-touch（真实播放/收藏/歌词区域拖动、不误触、侧栏相机与实际页面缩放、原紧凑播放栏、展开无轮廓、收缩中间帧无黑遮罩）；test-desktop-lyrics（600×112/360×88 长句和译文拟合、110×600 竖向元信息、默认透明解锁及真实点击）。上述截图已检查。

Android 专用 emulator-5554：portable 完整回归通过 UI_PORTABLE_PASS；新增系统主题用例在设置页保持打开时通过 cmd uimode night yes/no，原生 configuration 驱动 WebView 分别到 dark/light，结束恢复模拟器原夜间设置。覆盖横竖屏、安全区域、三种样式深浅、播放/队列/设置/返回、缩放与歌词。日志 `.build/review/`，定向包 `.build/Android/MiniVoice-android-experience.apk` 和 `.build/MiniVoice-mac-experience.zip`；Mac 体验版身份/数据域隔离保留。

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
截图：mobile-full-wall-drawer-light/dark、mobile-wall-scale-marks、mobile-queue-half/full-dark、mobile-queue-full-light、mobile-simple-drawer-unframed 已检查；实际 APK 截图保存于 .build/review/mobile-rework-android-shots，已检查墙面浅色侧栏、简易浅色侧栏和真实手指展开队列。最终包 .build/Android/MiniVoice-android-wall-glass-20261027.apk（同时更新 experience.apk）。
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

最终补充：最终 APK 在 emulator-5554 得到 UI_PORTABLE_PASS，含实际截图纹理、碎片变换中间值、三样式深浅、横竖/返回、原生系统主题和真实手指队列手势。最终 Android 截图保存在 `.build/review/mobile-thin-android-shots/`；交付 `.build/Android/MiniVoice-android-thin-glass-20261027.apk`，并更新 experience.apk。

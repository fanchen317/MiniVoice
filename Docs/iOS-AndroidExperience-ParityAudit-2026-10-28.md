# iOS 对齐 Android 体验版审计（2026-10-28）

审计对象为当前工作区源码、现有 Android 体验版 APK、现有 iOS Debug 模拟器包，以及已有专用模拟器报告。此次为审计，没有修改播放器行为，也没有重新安装或操作真实音乐库。

## 1. 基准与证据边界

- **Android 基准：体验版 `PortablePlayerActivity` + Shared/UI。不是正式版 `MainActivity`。** `AndroidManifest.xml` 启动器指向 PortablePlayerActivity；`Scripts/build/build-android.sh:24` 的 release 分支才会把启动器转移给旧 MainActivity。对照包是 `.build/dist/MiniVoice-android-experience.apk`。
- iOS 默认入口为 `MiniVoiceApp.swift:15` 的 SharedPlayerView。HomeView 是旧原生参考，未被默认入口调用；不把它的设置、队列、歌词页当作当前 App 已提供的功能。
- 证据标记：**复现**＝本轮定向执行证明；**代码确认**＝两端路径明确不同；**包确认**＝对比实际打包资源；**待验**＝缺少运行证据，不能写成已发现视觉故障。
- 本轮重新运行：共享 JS 单测 45 项通过、自有组件边界门禁通过、iOS LRC/旧原生墙几何测试通过。后者不验证 WKWebView 音乐墙全部行为。本轮未重新执行双平台真机触控或横屏截图验收。
- 证据文件：`.build/reports/ios/android-experience-audit/`，包括 URL 往返复现、排序复现、设置能力比较、打包资源 SHA-256 与 CSS 差异。

## 2. 总结

**当前不是完整对齐。** 页面结构已大量共用，但存在真实数据缺陷、宿主能力缺口和安装包版本落后。仅凭“同一份 Shared/UI”不能宣称页面效果、播放规则和设置内容全部一致。

优先处理真实歌曲封面 ID，再同步两端构建资源；之后补设置/数据协议、播放/系统接入，最后完成横竖屏与实际触控验收。用户明确指定的 iOS 竖屏长条居中、圆形左下及 iPad 设置按钮避让不属于应回退的缺陷。

## 3. 页面、布局与视觉矩阵

| 范围 | 当前结论 | 证据与后续要求 |
| --- | --- | --- |
| 三种样式入口、切换顺序 | 结构共用 | PortablePlayer / MobileSettings；两端同为 mobile/android 参考。未证明两种引擎每一帧一致。 |
| 音乐墙分区、拖动/缩放、聚焦/回流 | 算法/组件共用 | Wall、wallLayout、WallPlayer；真实封面 ID 故障会破坏实际展示，见 F01。双指及中断需 iOS 真触控验收。 |
| 侧栏导航、完整/简易目录、歌单区 | 结构共用 | 同一 DrawerLayer/DrawerMaterial/PortablePlayer。歌单排序数据不同，见 F13。当前 iOS 包的关闭动画落后，见 B02。 |
| 搜索框与查询状态 | 结构共用，键盘布局待验 | SearchControl / SearchWorkspace；未跑 iOS 中文输入法、键盘出现/收起、长查询及横屏。 |
| 音乐库列表、歌手/专辑网格、长按菜单、批量选择 | 结构共用，行为待补验收 | SongList / CollectionDialogs；歌手别名、日期字段等数据不足使结果不同。未跑 iOS 大库、真实长按/取消。 |
| 简易播放页、封面/歌词分栏 | 结构共用，横屏待验 | 共享 mobilePlayer.css。iOS 的安全区适配没有 Android 的非墙横屏对称处理，见 L02。 |
| 播放条竖屏长条 | **用户指定差异，保留** | iOS portraitDock=center；Android leading。不能为了“对齐”改回 iOS 左对齐。 |
| 播放条收起圆形 | 共用规则，已保留左下 | 移动端 hoverExpand=false；此前 iPhone/iPad DOM 检查通过。实体手指/外接鼠标仍待验证。 |
| iPad 右下设置按钮 | **用户指定行为，保留** | useDockSettingsCollision；无实际碰撞不移动。此前专用 iPad 报告通过，不代表横屏所有尺寸都验收。 |
| 全屏展开歌词与系统栏 | **宿主未对齐** | Android immersive 真正隐藏系统栏；iOS 直接返回 true，见 L01。 |
| 展开页大字歌词/收起按钮 | 源码共用，**现有 iOS 包落后** | Android 包新增透明无底板皮肤，iOS 包仍有原底色，见 B01。 |
| 收藏选中颜色、主控按压反馈 | 源码共用，**现有 iOS 包落后** | Android 包包含红色收藏与更明确按压反馈，iOS 包没有对应 CSS。 |
| 播放条进度轨道内缩居中 | 源码共用，**现有 iOS 包落后** | Android 包包含 `width:calc(100% - 16px);align-self:center`，iOS 包没有。 |
| 设置弹窗 | **内容不完整** | iOS 未声明维护/诊断能力，整段缓存、检查、归并与诊断内容不出现，见 F02/F03。 |
| 队列半屏/全屏、拖拽弹窗 | 结构共用，实际手势待验 | Modal / useSheetDrag / Slider / ScrollRail 共用；iOS 旧脚本主要调用 DOM click，不等于系统触摸拖动。 |
| 深色/浅色/系统主题 | 选择器共用，**初始策略不同** | Android 新安装默认 system，iOS 默认 dark，见 F10；首次启动浅色系统截图未验收。 |
| 背景采样、玻璃、模糊、图标中心、文字换行 | 代码共用，视觉待验 | WKWebView 与 Android WebView 渲染不等于相同。需固定同一组封面，在 phone/tablet × 横/竖 × 深/浅对照。 |

## 4. 已确认缺口

### F01 [P1，复现] 真实歌曲 ID 经过封面 URL 后无法还原

- `iOS/MiniVoice/MusicLibrary.swift:256` 用 `folderID + "/" + relativePath` 生成歌曲 ID，实际 ID 含多个 `/`。
- `SharedPlayerView.swift:100` 使用 `.urlPathAllowed` 编码，这个字符集**保留斜杠**；`SharedPlayerView.swift:259` 只用 `lastPathComponent.dropLast(4)` 还原 ID。
- 本轮 Swift 复现：短 ID `ui-fixture-0` 匹配；真实形式 `/private/.../Music/歌手/歌曲.mp3` 被还原成 `歌曲.mp3`，不等于原 ID，随后 allowedSong 拒绝。影响墙面、歌曲列表、分组图、播放器和封面背景。
- 此前夹具在 `MusicLibrary.swift:354` 附近使用 `ui-fixture-*`，所以旧封面测试通过不能证明真实音乐库正确。
- 修复应采用不含路径分隔符的安全资源身份或完整 ID 编解码，并覆盖中文、空格、`#`、`%`、多层目录及同名文件；不能放宽授权检查。

### F02 [P2，代码确认] 音乐库维护整段未接入

- Android `PortableLibraryActions.java:24` 声明 cacheInfo、clearCache、inspectLibrary、artistAlias、clearArtistAliases。
- iOS `SharedPlayerView.swift:201` 只声明目录选择/移除、递归、重扫和清空最近。
- `Shared/UI/src/MobileSettings.jsx:25` 以 cacheInfo 决定是否挂载 MobileLibraryTools。因此 iOS 不只是少了后端，还少了整个维护界面：缓存用量/清理、文件可用性/进度/不可用列表、疑似重复提示、歌手归并与清除规则。
- 应复用现有 MobileLibraryTools，补宿主能力及错误/取消/忙碌规则，不新造 SwiftUI 维护页。

### F03 [P2，代码确认] 诊断分组与报告导出未接入

Android 宿主 `PortablePlayerActivity.java:152` 提供 ZIP 导出，getSettings 提供 exportDiagnostics/crashCount。iOS 未提供该命令或对应系统导出流程，Shared MobileSettings 中“诊断与稳定性”不显示。

### F04 [P2，复现] 日期排序入口存在，但 iOS 数据缺失

Android `PortablePlayerActivity.java:65` 发送 sourceAdded/added/size；iOS `SharedPlayerView.swift:97` 没有这些字段。PortablePlayer 音乐墙设置仍显示“添加时间”和“更新时间”；catalogFor 比较缺失值，不能按日期排序。Node 定向复现中，Android 降序得到 new→old，缺失日期的 iOS 得到 old→new。需要补索引/扫描日期与 DTO，不应隐藏排序入口冒充对齐。

### F05 [P2，代码确认] 高清原封面链路未对齐

Android 提供 artworkDetail（原图请求）和带 artworkVersion 的封面 URL；iOS 仅提供 artwork，没有原图服务和版本字段。`MusicLibrary.swift:288` 把缓存封面最长边限制为 640；共享英雄图/聚焦图只能回退到该缩略图。iPad 大图清晰度及同 ID 封面更新需验证，不能称高清已对齐。

### F06 [P2，代码确认] 歌词发现和回退规则不同

Android FolderLibrary 搜索 LRC/YRC，并处理授权根目录的歌词索引；LyricsRepository 先检查内嵌文本是否有效，再回退侧车文件。iOS `MusicLibrary.swift:296` 直接接受首个非空内嵌歌词，只查相邻目录及相邻 `lrc/` 的 LRC，未扫描 YRC。因此共享解析器支持 YRC，并不代表 iOS 能找到 YRC；无效内嵌文本也可能挡住有效侧车歌词。

### F07 [P2，代码确认] 音频扫描格式范围不同

Android FolderLibrary.java:100 接受 audio MIME 或已列扩展名（包括 OGG）；iOS MusicLibrary.swift:198 仅接受固定扩展集合，不含 OGG。不能把平台解码支持当作已实现；需要确定 OGG 等格式的实际可播放能力及清晰的不支持提示，才可作兼容性结论。

### F08 [P2，代码确认] 上一首与随机播放策略不同

- Android PlaybackService.java:106：进度 ≤3 秒时，首曲“上一首”回到队列尾，不区分播放模式。iOS MusicPlayer.swift:134 仅 repeatAll 回尾，其余在首曲归零。
- Android 随机在曲终继续从队列选取其他歌曲；iOS MusicPlayer.swift:153 的随机剩余集耗尽后，自动播放会停止，并维护独立历史。
- 这是业务策略不一致，不是共用五个模式按钮就已对齐。应以体验版为准确定并测试每种模式的首/尾/单曲/自动结束/手动切换。

### F09 [P2，代码确认；系统影响待验] 音频打断与路由状态同步未接入

Android PlaybackService 有音频焦点和耳机拔出接收器。iOS 设置了 AVAudioSession，但没有 interruptionNotification / routeChangeNotification 等处理，也没有观察 AVPlayer.timeControlStatus。系统暂停可能已经发生，而 Published isPlaying/共享页面仍保留请求时的状态。具体电话、蓝牙切换、拔耳机与恢复行为需真机验证；本轮未宣称复现漏音或无法暂停。

### F10 [P2，代码确认] 新安装默认主题不同

Android AppAppearance.java:12 默认 system；iOS MiniVoiceApp.swift:9 和 SharedPlayerView.swift:151 默认 dark。样式同为 wall，但浅色系统下首次进入的主题不同。已保存用户偏好不应因修复被覆盖。

### F11 [P2，代码确认] 扫描进度、增量复用与后台任务缺口

Android LibraryScanService 提供分阶段详情/进度、扫描日志与中断恢复、已有索引复用、歌词/封面预热。iOS 启动页面的 onAppear 调用 restoreAndScan 后会重扫，scanCount 只在完成时更新，宿主一直发固定“正在扫描音乐…”，没有等价的扫描任务/进度恢复服务。不能把 Task.detached 等同为系统后台任务；大库、文件提供方失效和 App 切后台中断均待验证。

### F12 [P2，代码确认] 系统媒体入口定位当前歌曲的信号链缺失

Android acceptNavigation/onNewIntent 发 navigationAction/navigationToken，Shared PortablePlayer 消费 LOCATE_PLAYING 并定位歌曲。iOS 仅支持远程播放命令，没有给共享界面发送对应导航字段。需设计 iOS 系统媒体入口/重入应用的等价行为；不要求照搬 Android Intent。

### F13 [P3，代码确认] 次要集合排序与容量不同

Android 快照歌单来自 TreeSet，按名称排列；iOS 按创建数组顺序显示。iOS 最近播放截断到 100 条，Android 本条路径未设同样上限。会导致侧栏歌单次序和最近播放条数不同，需要产品规则统一，不能把它们解释为渲染差异。

### F14 [P2，代码确认；性能影响待验] 主线程工作分配不同

Android 宿主把 Core、状态持久化和资源读取放到 worker / rasterWorker；iOS SharedPlayerHost 是 MainActor，Core、JSON 写盘、封面 Data(contentsOf:)、截图 JPEG 编码均在该路径。大型歌词/封面、频繁墙相机保存有阻塞风险，但本轮没有实测帧率或证明卡顿。需要压力/打断测试后决定调度方式。

### F15 [P2，代码确认] 同身份歌曲的锁屏元数据更新不同

Android retainLibrary 后 refreshLibrary 更新队列歌曲与当前元数据；iOS retainLibrary 只移除失效 ID，不替换同 ID 的 current/queue 值。扫描发现标题/封面改变时，共享页面可能读到新 catalog，锁屏仍使用旧 Song/nowPlayingArtwork。需添加当前歌曲元数据刷新测试。

## 5. 宿主布局差异

### L01 [P2，代码确认] 沉浸命令在 iOS 是空操作

Shared PortablePlayer 在音乐墙展开页调用 adapter.chrome。Android `PortablePlayerActivity.java:128` 按样式/横屏/沉浸状态隐藏系统栏并更新安全区；iOS `SharedPlayerView.swift:199` 对 immersive 直接成功返回，没有等价状态栏/Home 指示器处理。`.ignoresSafeArea()` 不等于隐藏系统栏。此项直接影响全屏歌词可用高度与上/下边距。

### L02 [P2，代码确认；实际排版待验] 横屏安全区策略尚未对齐

Android `PortablePlayerActivity.java:143` 对非墙横屏将左右安全区取较大值保持对称，并持续发布 minivoice-insets。iOS 仅把 CSS 变量设为 env()；缺少对应宿主策略与显式更新事件。横屏刘海、分屏和键盘是否产生偏移需跑真实 viewport 验收，不能仅根据 CSS 相同判定通过。

## 6. 现有安装包中的实际版本差异

### B01 [P2，包确认] Android 体验版比当前 iOS 包多四项视觉更新

两包 JS/CSS SHA-256 不同；本轮直接提取 APK 的 assets 与 iOS .app 的 SharedPlayer 对比。

Android 包 CSS 额外包含：

1. 展开播放器的大字歌词/收起按钮移除固定底板。
2. 收藏选中变为红色 `#f04f64`。
3. 播放控件按下背景和 `.88` 缩放反馈。
4. 播放条进度轨道内缩 16px 并 align-self:center。

当前源码 `Shared/UI/src/mobilePlayer.css:42` 已有这些规则；现有 iOS Debug 包尚无。属于**打包版本落后**，不应再写一份 iOS 样式补丁。需要用同一源码快照重新构建两端，并记录资源指纹。

### B02 [P2，包确认；运行表现待验] 侧栏/弹窗退出动画更新尚未进入当前 iOS 包

Android 包已有 `useSurfaceMotion.js:18` 的退出面板测量/固定几何逻辑；iOS 包仍是较早实现。代码用于避免脱离原父容器后因安全区/布局选择器改变而跳位。已确认包内代码不同；没有把“可能在退出时跳位”写成此次实屏复现。

## 7. 已对接但不能扩大宣称的部分

- 搜索、普通排序、收藏、批量收藏、歌单增删改/成员管理、队列选择、进度命令已经连到 iOS；未找到“必须切回原生 HomeView 才能使用”的默认入口。
- Shared Core 解析/逐字歌词、页面 reducer、三种样式、长按/弹窗/滚动条等是共同实现。业务数据和宿主行为仍可不同。
- 本轮没有把 Android 的 PortableMetadataActions 全部能力当作 iOS 前台缺口。当前体验版 CollectionDialogs 对单曲只提供信息/歌词查看；saveLyrics 虽存在于 Android 后端，但不能据此要求 iOS 新增正式版编辑页、标签写回或在线封面工具。
- 系统文件选择器、系统媒体控制的外观本来就随平台变化，不要求复制 Android 系统控件。对齐的是应用内内容与等价业务结果。

## 8. 验收证据还缺哪些

| 缺口 | 当前证据为什么不足 |
| --- | --- |
| 真实多层目录和文件提供方 | 旧夹具用短 ID 和沙盒内合成 WAV，没有真正走系统目录授权/真实扫描。F01 正是被这类夹具漏掉的。 |
| phone/tablet × 横/竖 × 深/浅的同场景布局 | 旧 iOS 报告 viewport 只有 402×874 与 744×1133；没有完整横屏对照。设置切三种样式不等于三个样式所有页面都验收。 |
| 五种播放模式语义 | 旧 shared-host-smoke.js:91 只设置 mode=4 再回读，标签却写“五种播放模式接入”；不能当作五模式首尾/曲终行为都通过。 |
| 真手势与取消 | 主要是 element.click() 和构造 pointerover；未覆盖真实触摸拖动、长按、多指、丢失捕获、快速中断、弹窗手柄上拉/下拉。 |
| 键盘、输入法、VoiceOver | 缺少中文输入组合态、弹窗软键盘遮挡、焦点恢复、系统辅助功能实际检查。 |
| 大音乐库与后台 | iOS 合成库 12 首；不能替代千首以上、扫描中切后台、授权失效、播放中扫描的压力测试。 |
| 媒体/音频系统 | 未覆盖电话/蓝牙/耳机/锁屏入口及 App 重入后的状态同步。 |
| 截图与版本追溯 | test-ios-shared-ui.sh 复制所有 PNG，目录仍有旧 `dock-compact-centered.png` 和新 leading 图共存；报告没绑定包 hash/run ID，不能混用旧截图证明新版行为。 |

## 9. 建议实施顺序

1. **真实音乐库阻断**：封面资源身份往返、真实目录夹具/授权路径测试。
2. **版本同步**：同一快照构建体验版 APK 与 iOS 包，核对资源指纹、侧栏关闭和四项样式更新。
3. **数据/设置对齐**：时间字段排序、缓存/文件检查/歌手归并、诊断导出与高清封面。
4. **播放与系统接入**：首尾/随机策略、音频打断/路由、锁屏定位、同 ID 元数据刷新、沉浸与安全区。
5. **布局验收矩阵**：固定封面/字体/内容，在手机和平板横竖、深浅、键盘与多窗口下逐项记录几何、截图和真实触摸结果。

不需要为此另建 iOS 内容组件；优先补宿主/DTO、更新同一份共享实现和验收覆盖。

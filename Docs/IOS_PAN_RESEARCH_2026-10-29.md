# 保留151c549体验的iOS墙面流畅度调研

日期：2026-10-29。用户设备：iPhone 16 Pro Max；iOS版本、低电量模式及暂停/播放差异尚未确认。

## 结论与边界

仍有现架构内的优化空间。没有真实设备Rendering Frames/CPU/Layers采样，尚不能认定WebKit已到性能极限，也不能把当前问题全归因于图片或GPU。此前233→0的style写入计数只验证重复工作减少；用户反馈仍卡，说明该指标不是最终验收指标。本轮调研不修改运行逻辑，不恢复已经撤回的原生滚动/预热池/缩略图方案。

## 已确认代码事实

1. `Shared/UI/src/Wall.jsx`：Pointer移动更新live相机，schedulePaint通过rAF绘制；松手惯性的tick本身由rAF驱动，update又安排绘制rAF。计算与显示分属回调，存在一帧流水线延迟的可能；不是“必定减半帧率”。应统一相机计算和绘制帧，并保持原速度曲线及取消/定位规则。
2. 同文件：超过140px会setCamera并重算可见集合；即使已有节点style不写，新卡片的DOM/图片解码与图层内容更新仍存在。稳定绘制原点没有消除这一部分。原点1024px重定位也需与卡顿时间轴关联，不能只验最终坐标。
3. `Shared/UI/src/PortablePlayer.jsx:71-73`：每450ms读取snapshot、更新页面顶层，位置变化还发lyrics.sweep请求并更新frame。`Wall.jsx`并非memo边界，接收每次新建的focusContent和回调；memo化海报不代表整页无React工作。可把时钟与歌词状态限制在播放控件子树，歌曲/焦点等语义变更继续立即同步，不能冻结业务状态。
4. `iOS/MiniVoice/SharedPlayerView.swift:288-300`：目录版本一致时已不重复传songs，但snapshot仍包含原歌词、完整播放队列、收藏、最近播放、歌单映射/排序；在MainActor组装并JSON回复。这是随数据规模增长的潜在开销，尚未实测用户库大小下耗时。应测payload字节数、组装/序列化耗时，再考虑分开时钟与结构数据版本。
5. `Shared/UI/src/wall.css:11`：固定工具控件与播放条使用真实backdrop-filter。墙面在它们后方持续变化，即使transform不引发布局，仍有背景采样与合成成本。必须用Layers及实验开关验证，不能直接把所有玻璃去掉交付。
6. 封面节点为img、decoding=async，Swift缓存编码图片，不等于GPU纹理缓存；重复往返仍卡时，不能未经采样就认定读取慢或优先扩大缓存。

## 外部证据

- WebKit《Controlling Animation Frame Rate》区分Core Animation加速动画与rAF驱动页面更新，说明两者刷新路径/频率可能不同。这是设计提案背景，不是当前用户iOS实测，也不能将其中拟议frameRate API当成已支持功能：https://webkit.github.io/explainers/animation-frame-rate/
- WebKit #294338为WKWebView高刷新率公开能力请求，查询时仍NEW；讨论中有WKWebView在ProMotion设备受60Hz节奏限制的报告。不能把讨论中的私人测试泛化成所有系统必然60Hz，亦不通过私有偏好开关作为产品方案：https://bugs.webkit.org/show_bug.cgi?id=294338
- Apple的CADisableMinimumFrameDurationOnPhone说明的是应用请求显示支持帧率的能力，不构成WKWebView rAF自动解锁120Hz的保证：https://developer.apple.com/documentation/bundleresources/information-property-list/cadisableminimumframedurationonphone
- WebKit Layers提供层尺寸、内存与paint count；过多图层消耗内存，不应直接给每张封面加will-change：https://webkit.org/web-inspector/layers-tab/
- WebKit说明backdrop-filter需要额外渲染pass，即使有硬件加速也可能增加成本：https://webkit.org/blog/3632/introducing-backdrop-filters/
- Frames/CPU时间轴用于对应JS、layout、paint与逐帧开销：https://webkit.org/web-inspector/timelines-tab/ ， https://webkit.org/blog/8993/cpu-timeline-in-web-inspector/

## 应优先执行的对照实验

各组只改变一个因素，运行同一路径、相同歌曲/相机/缩放；分别测跟手拖动和松手惯性。对照组不作为发布皮肤或功能降级。

| 顺序 | 对照 | 判断依据 | 若成立的修复方向 |
| --- | --- | --- | --- |
| 1 | 实机空负载rAF、静态墙、移动墙 | 区分稳定刷新节奏与长帧尖峰；记录分位数/最长停顿，不只平均值 | 明确可达节奏和优化目标，避免误以为加CSS能保证120Hz |
| 2 | 播放与暂停；诊断模式隔离时钟/歌词UI更新 | 卡顿是否与450ms更新/桥回复同步 | 分离时钟订阅与页面状态，结构数据版本化，播放控制即时 |
| 3 | 原帧调度与同帧计算/绘制 | 输入到提交延迟、帧间隔、惯性节奏 | 统一rAF调度器，保留原业务与运动曲线 |
| 4 | 原材质与临时禁用backdrop采样 | Paint/composite时间差；不是只看FPS | 保留真实玻璃，调整采样层级、范围与重复pass |
| 5 | 原可见更新与诊断固定小范围已加载卡片 | 尖峰是否跟可见集合变化及解码一致 | 拆分增量挂载，当前可见优先；不重新引入大驻留池 |
| 6 | 小库与大库的snapshot | payload大小和MainActor序列化时间 | 时钟小包与目录/队列/歌词版本化，控制消息保持即时 |

需要记录：设备/iOS/低电量状态、应用构建标识、显示方向/主题/样式、库规模、相机轨迹、rAF间隔分布、React提交、JS长任务、可见节点增删、资源解码、Layers尺寸/paint计数、输入与显示时间关联。rAF回调频率不等于实际显示FPS；模拟器和Electron不能代替真机GPU证据。

## 实施建议

首先做诊断采样与第2/3项低风险对照，再据证据处理材质/挂载。每项独立开关及独立提交，以151c549的定位/点击/切歌/展开/返回为回归基线。界面、自有ActionButton、图片质量和状态规则不因优化改变。三样式/主题继续按标准验收。

只有现架构实测达到稳定节奏、仍无法满足用户期望时，才讨论更换渲染后端；现在没有证据要求重写为原生。即使需要更高刷新率，也先评估现有DOM合成动画路径的适用范围；惯性可研究可打断的合成transform动画，跟手拖动不能假定同样可脱离主线程。

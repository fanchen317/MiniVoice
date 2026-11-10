# iOS 缓存、音乐墙与动画性能梳理（2026-11-07）

## 当前实现与范围

正式入口为 MiniVoiceApp → SharedPlayerView → WKWebView → Shared/UI/PortablePlayer。Swift 管理授权、扫描、音频与存储，共享页面管理音乐墙、歌词、控件与内容动画。HomeView 是未接入的旧参考页面，本轮不扩展它。

以当前代码为准：PortablePlayer 显式传入 `nativeScrolling={false}`，iOS 使用 projected-single-surface，不是部分历史文档描述的原生 overflow 滚动。当前没有独立的“高性能模式”设置；本轮优化现有高负荷路径，保留玻璃材质、高清封面、聚焦、展开与歌词效果。

不改变正式包标识、版本来源、签名和数据路径，不操作用户真实音乐库。导入歌词、曲库索引与页面状态是持久数据；可重建封面是缓存，两者生命周期分开。

## 已落实的改动

| 链路 | 原有开销或缺口 | 本轮处理 |
| --- | --- | --- |
| 原生内存封面 | 宿主另存缓存，底层同图请求可重复读取，清理边界分散 | 统一 ArtworkRequestCache：8 MiB 编码字节 LRU、同 key 在途合并；原图不驻留；内存警告释放；保留宿主最多 2 路、聚焦优先门控 |
| 磁盘封面 | 原图和各档派生文件无统一上限 | ArtworkDiskCache 仅管理 Caches/Artwork；512 MiB 上限，超限回收至 7/8；冷启动清理 30 天未用项；按访问更新 LRU，每文件每分钟最多持久化一次访问时间 |
| 扫描与高清图 | 扫描即落整张原始大图，缓存缺失可能以缩略图充当原图 | 扫描只落最长边 640px 缩略图；原图按需从授权音频提取；wall 320px、card 960px、display 2048px；original 保留源编码。淘汰后按需重建 |
| 清理和授权 | 旧任务可能清理后回写，派生读取授权检查不足 | 内存/磁盘代次隔离，清理与写入串行；旧任务不得回写/发布；读取前后检查授权及符号链接边界；缓存维护不触碰音乐和歌词 |
| 曲库存储 | 整库编码和原子写入在主线程，扫描检查点也同步读取 | 后台编码、串行原子保存、合并最新待保存快照；过时编码跳过；失败显示错误；检查点后台读取 |
| 播放桥 | 每 450ms 快照重复映射/传送队列、歌单、收藏和完整歌词 | 曲库 revision 之外新增 snapshotRevision，冷字段变化后懒构建；热回复仅进度/播放/扫描/导航；前端保留集合身份，逆序回复不能覆盖新状态；兼容 Android 完整快照 |
| 锁屏与暂停 | 暂停/后台也有 4Hz 计时器，每 tick 重建锁屏字典 | 仅前台播放采样；暂停/后台停 UI 时钟，音频继续；恢复/seek/中断即时同步；锁屏按系统 rate 推算；封面按版本去重、后台解码至 640px |
| 墙面切歌 | 预热解码没有统一并发/保留预算，旧意图仍排队 | 每墙实例最多 3 个活动解码；同 URL 合并，过时排队跳过；失败/超时可重试；解码保留集最多 24 MiB / 48 项，卸载释放 |
| 墙面逐帧工作 | 相同变量反复写样式；展开层保留多档旧图 | 值变化后才写 CSS；完成图片交接后释放多余高清层；保持持续材质容器及解码后交接 |
| 歌词 | 每帧遍历全时间轴、写无消费者的逐词变量；墙面还有未使用的父级时钟 | 时间轴二分查找，仅行变化更新 React；去掉无消费者样式写入；背景尺寸不变跳过；墙面由自身歌词时钟负责 |
| 原生切换动画 | 失活/减弱动态仍可能留截图层；旧超时可能清理新动画 | 失活、卸载、开启减弱动态即取消；超时按 token；重复 animate 等待原动画，不替换活动层 |

以上容量是工程预算，不是实测峰值或设备承诺。24 MiB 只限制保留集，不含最多 3 个活动解码、WebKit 自身图片和 GPU 纹理；不能将各项相加作为进程内存上限。

## 验证与限制

结果以 ACCEPTANCE_STATUS.md 本日条目为准。合成用例覆盖 LRU/重建、同图合并、清理竞态、最新快照保存、千首元数据与小进度回复、逆序响应、歌词时间轴与预热调度。

本机 `xcrun simctl list runtimes` 没有可用运行时。没有执行本轮真实 WKWebView、XCUITest、iPhone/iPad 或实体设备安装。Electron 的 iOS fixture 仅证明页面逻辑和布局，不证明 WebKit 合成、触控、热状态或 FPS。已有偶发形变白线仍需原场景录屏验收，不能据减少样式写入宣布消除。

旧 shared-host-smoke.js、wall-smoke-helpers.js 和部分 test-ios-*.cjs 包含 native-scroll / compositedPan 硬断言，与当前 projected 入口不符。本轮没有删除原断言掩盖问题：这些历史集成测试尚未适配当前路径，新桥增量/音频断言也尚未在 WK 执行。

## 后续验收顺序

1. 专用 iOS 模拟器接入当前 projected 路径的集成探针，验证清理→可见图重建、重启、移除目录、桥增量字段、MP3/FLAC 前后台时钟。
2. iPhone/iPad 三样式 × 深浅 × 横竖屏，连续拖动/缩放、快速聚焦/收起/切歌、展开时返回、动画中开启减弱动态；检查封面、歌词、播放条身份与最终边界。
3. 真机 Instruments Time Profiler / Allocations / Animation Hitches，分别测冷/暖启动、1037 首合成库拖动和连续展开切歌，记录设备、系统、温度与低电量状态。按实际主线程和纹理成本继续制定档位预算。
4. 系统内存警告、iCloud 音源不可用、磁盘不足、授权失效、蓝牙/电话中断、后台返回。失败可见，旧意图不得覆盖最新歌曲。

仍可优化：前台 position 的 Published 更新使 SwiftUI 外壳每秒更新四次，可进一步拆分观察边界，需处理旧 HomeView 依赖。Vision 冷启动、WebKit 纹理和实体材质采样仍需真实分析。

## 设计依据

Apple 将可从源重建的缩略图归为可清理数据，建议置于 Caches，持久用户内容不能采用该生命周期：[iCloud Backup 数据优化](https://developer.apple.com/documentation/foundation/optimizing-your-app-s-data-for-icloud-backup)。锁屏时间由系统按先前时间与 rate 推算，不需高频重写：[ElapsedPlaybackTime](https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfopropertyelapsedplaybacktime)。容量和调度参数是本项目选择，不是 Apple 通用固定参数。

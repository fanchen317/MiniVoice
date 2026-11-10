# iOS 控制台日志梳理（2026-11-08）

## 日志证据与边界

用户提供的1244行日志包含：

- `Publishing changes from within view updates…`：2次。
- `sandbox_extension_consume failed: 22 (Invalid argument)`：1214条完整重复行，另有拼接/拆分输出。
- 启动时针对 `MiniVoice.app` 自身的 sandbox extension issue/create 失败，以及 WebKit Network/GPU/WebContent 进程约3.5秒启动记录。
- WebContent私有路径打不开、图层volatile失败，FigApplicationStateMonitor及InputUI keyboard scene信息。

其中22是EINVAL，表示沙盒凭证消费的参数无效。日志没有音乐路径、系统调用栈或完整时间戳，不能把全部失败归因于音乐目录；最先输出的路径是应用包，不能据此让用户删除音乐库、清空真实数据或重置所有授权。WebKit自身也使用沙盒扩展。其余系统信息暂不作无害或已修复的结论。

## 已确认并修正的应用路径

### 视图更新期间发布状态

`UIViewRepresentable.makeCoordinator → SharedPlayerHost.init → library.$songs` 同步发送当前值，随后 `updateCatalog → player.retainLibrary` 修改Published播放器属性。此时SwiftUI仍在创建视图协调器，存在明确的更新重入路径。

曲库订阅改为在主队列后续调度交付，退出协调器时取消订阅及排队事件。WebContent进程重载只取消资源读取，保留曲库订阅，避免恢复后不再更新音乐库。修改的是产生副作用的交付时机，不屏蔽系统警告。

### 目录授权反复申请与失败处理

此前wall/card/display派生磁盘缓存命中前仍解析书签并start scope；缺图还会嵌套再次解析和start。若授权失效，重复图片请求会重复尝试，且部分路径在start返回false后继续访问源目录。目录书签过期标记也被忽略。

系统允许正确配对的嵌套start/stop；本轮修复的是不必要的热路径调用、失败继续IO和失效处理，不能仅因存在嵌套就判定系统契约违规。

授权改由音乐库持有的FolderAccessRegistry管理：按目录及bookmark身份保留原始resolved URL，重叠读者共享lease，最后读者结束才stop；播放器持有lease直到释放音频。不同目录的系统调用在锁外执行。移除目录/更换bookmark会使旧请求失效，读源前检查相对路径、符号链接和授权身份。

外部目录start失败时明确拒绝源文件读取；过期书签提示重新选择目录，不把失败当成功。不重复消费已失败凭证，显式重扫或重新选目录可重试。App自身容器内的合成资源使用明确的canonical路径例外，不以“任意路径可读”绕过外部授权。

可重建封面缓存先读本地数据，源文件缺图恢复只申请一次lease。缓存前后仍校验音乐库目录身份。扫描授权失败时保留该目录既有元数据并显示失败，防止暂时无权访问就从索引清空歌曲；真正移除目录仍撤销播放与后续访问。

这些改动消除了明确的重复申请和失败继续IO路径，但没有真机调用栈证明1214条日志全部来自这里，不能据代码调整宣称所有sandbox日志消失。

## 验证

实际命令、结果与证据路径记录在 `ACCEPTANCE_STATUS.md` 本日条目。FolderAccessRegistry使用注入的系统调用与隔离临时文件验证并发共享、失败无后续读取、过期书签、重扫重试、撤销、路径边界和释放配对；合成测试不等于iOS系统授权实现的实测。

本轮实际通过：UI标准门禁、`Scripts/tests/test-ios.sh`（含新增授权用例）、当前工作树125项共享测试、模拟器Debug和无签名device Release构建及两份产物后台audio声明检查。日志位于 `.build/reports/ios/console-warnings-{native-tests,shared-tests,simulator-build,device-build}.log`，原日志统计见 `console-log-summary.json`。仅原生宿主/授权链路发生本轮改动，没有据此重跑或宣称全量页面/实体设备体验通过；编译中的旧AVFoundation弃用警告仍在。

本机没有可用iOS模拟器runtime。检测到配对真机时只读取了连接/系统信息，没有安装、启动应用或操作真实音乐库。仍需在设备验证冷启动不再触发SwiftUI发布警告、切换样式及页面重载、外部目录首次授权/重启/撤销/重选、播放时切后台与锁屏，并对比同阶段日志。

## 依据

- [Apple：Combine receive(on:options:)](https://developer.apple.com/documentation/combine/publisher/receive(on:options:))：控制下游事件交付调度器。
- [Apple：Providing access to directories](https://developer.apple.com/documentation/uikit/providing-access-to-directories)：目录scope、书签、过期与授权撤销必须处理。
- [WebKit：SandboxExtensionCocoa.mm](https://github.com/WebKit/WebKit/blob/main/Source/WebKit/Shared/Cocoa/SandboxExtensionCocoa.mm)：WebKit也创建和消费沙盒扩展，单行错误不足以定位调用方。

## 2026-11-10：用户补充在 Xcode 点击时出现的日志

- 用户反馈日志在 Xcode 调试、点击操作时也会出现；这不是只有冷启动才出现的证据。现有文本没有完整时间戳、线程/子系统、调用栈、iOS 版本或未脱敏路径，不能判断每条日志具体对应哪个点击操作。
- MiniVoice 当前通过 `minivoice://app/index.html` 与 `WKURLSchemeHandler` 加载界面；JS/CSS/封面由宿主读取、返回给 WebKit，并未使用 `loadFileURL(...allowingReadAccessTo:)` 把整个应用包授予页面。应用代码没有直接把 `MiniVoice.app` 作为音乐目录申请 security-scoped 授权。点击封面可能触发资源读取/识图，但本次日志不足以证明这些请求导致了某条沙盒消息。
- WebKit 公开源码显示，其 WebProcess 初始化会尝试为 UI 进程的 bundle resource path 创建只读 sandbox extension，并在子进程消费相应凭证。用户日志指向 `.app` 路径，**与这条系统路径吻合，是合理推断而非实机调用栈证明**；`issue_file ... 1` 是拒绝该次凭证签发，`consume ... 22` 是消费参数无效，不能据此断言具体是哪张图片、哪段凭证或曲库授权失败。[WebKit process pool](https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebKit/UIProcess/Cocoa/WebProcessPoolCocoa.mm)、[WebKit sandbox extension](https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebKit/Shared/Cocoa/SandboxExtensionCocoa.mm)。公开源码不保证与设备上系统构建逐字一致。
- `Unable to hide query parameters from script (missing data)` 在 WebKit 公开源码中对应高级 URL 隐私保护的允许参数数据为空时记录并返回原 URL；不能据此认定音乐文件缺失或应用查询参数一定配置错误。[WebKit WebPageCocoa](https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebKit/WebProcess/WebPage/Cocoa/WebPageCocoa.mm)。
- GPU/WebContent/Networking `took 1.5–1.6 seconds to launch` 是启动耗时日志。WebKit 公开代码在子进程启动超过1秒时记录该行；仅这行不证明崩溃，也不能代替端到端启动/渲染耗时测量。[WebKit AuxiliaryProcessProxy](https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebKit/UIProcess/AuxiliaryProcessProxy.cpp)。
- `Reading from public effective user settings` 文本本身表示读取配置；PointerUI 服务端口及 XPC foreground uid 是系统服务交互信息。项目未发现直接调用该私有服务；缺少系统进程上下文不能确认具体触发原因或把它们一概定为无害。`Couldn't open <private>` 中的路径被系统隐藏，ENOENT/EACCES 是实际读取失败的结果，但无法据此判断是系统可选文件还是应用资源。
- 已补充应用自有诊断：记录WK宿主创建、导航和页面ready的单调累计耗时；资源失败按 document/script/style/icon/artwork/other 归类并仅记允许的错误域与代码，保留真实ENOENT/EACCES，取消/明确缺封面不记录。错误类至多8组、按1/2/4等次数抽样，代次隔离旧回复，不写文件路径、歌曲ID、URL、查询参数或token。原有设置中的诊断导出可用于下一次关联点击行为；该记录不能解密WebKit私有日志，也不声称令系统日志消失。未添加权限、私有API或禁用日志/隐私保护。

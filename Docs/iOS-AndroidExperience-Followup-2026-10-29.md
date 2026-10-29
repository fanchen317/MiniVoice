# iOS 继续对齐安卓体验版：诊断与键盘交互

按用户最新要求继续开发，以 Android PortablePlayerActivity 体验版和开发标准为基准；复用共有 Modal、ActionButton、SheetDrag、DialogBoundary，不引入旧原生内容页。

## 本轮实现

1. **补本地诊断链路**：iOS 接入 MetricKit 的系统崩溃报告，记录启动、前后台、扫描和宿主/播放器错误。通过串行后台存储保留最近 5 条崩溃及 200 条事件，限制单条大小；按报告时间窗、序号和内容指纹避免重复投递重复计数。重新启动读取历史，共享设置显示实际本地数量。
2. **完善诊断导出**：现有 ZIP 增加有界事件/错误/崩溃记录；擦除常见路径和 URI，MetricKit JSON 先解析再清理，覆盖转义路径。写入或读取损坏失败会报错，不能假装成功，也不静默覆盖损坏历史。系统导出仍走平台选择器。MetricKit 由系统延迟投递，**接入不等于所有崩溃即时捕获**，未在真实设备制造崩溃验证投递。
3. **修复真实键盘遮挡**：XCUITest 复现 iPhone 新建歌单的创建按钮落在键盘下方。共享 useDialogViewport / dialogViewport 按 visualViewport 及宿主实际遮挡约束弹窗，响应滚动、旋转和安全区更新，卸载清理。移动文本框至少 16px，避免 WKWebView 聚焦自动缩放整页，保留辅助缩放。
4. **同步修复安卓体验版宿主**：实际 Android 35 键盘弹出时，WebView 仍报告完整 915 CSS px 高度，不能仅依靠 visualViewport。宿主将窗口键盘与 WebView 的实际交集发布为 `--mv-keyboard-bottom`；已经 adjustResize 的窗口交集为 0，不重复扣除。添加 API 29 回退，但 API 29 未实测。
5. **保持既有布局**：无键盘时保留弹窗原有 85% 高度限制和平板居中间距。页面和播放条不随弹窗移动；竖屏展开播放条居中、圆形左下、iPad 按实际碰撞避让继续保留。截图 JPEG 编码移到后台任务。

## 验证结果

| 检查 | 本轮结果 |
| --- | --- |
| 组件门禁、diff、脚本语法 | 通过 |
| 共享 JS | 46 项通过，新增 iOS 可视键盘、视口平移、Android 原生遮挡及不重复扣除模型 |
| iOS 基础/诊断存储 | 通过：数量和大小上限、路径清理、重复报告、跨实例读取、损坏文件保留、写入失败、ZIP 解包/CRC |
| 实际宿主诊断 ZIP | iPhone/iPad 均通过；解包确认 process started、宿主错误及保留上限，没有用合成崩溃充当系统投递成功 |
| WKWebView 桥接 | iPhone 89 项、iPad 90 项通过 |
| iPhone / iPad XCUITest | 两台各 4 个测试通过：三样式×深浅×横竖页面与设置；系统诊断导出打开/取消；搜索与歌单软键盘；队列真实上拉展开、下拉收起；横屏 WebView |
| Android 实际体验 APK | 专用 MiniVoiceRegression / Android 35，真实软键盘、创建按钮/弹窗位于可见区、真实关闭点按，`UI_KEYBOARD_PASS` |
| 共享完整页面 | test-wall-version 全部通过；新增实际 DOM 的可视/原生键盘、视口平移、键盘收起恢复检查，包含 Mac 原有回归 |
| 构建与资源 | iOS 模拟器 Debug、无签名 device Release、Android 体验 APK 均通过；实际 JS/CSS SHA-256 一致 |

失败到修复的记录：

- 初始 iPhone 创建按钮底边约 738pt，键盘顶边约 590pt，断言明确失败；修复后通过，截图已检查。
- 初始 Android 页面未扣除 883 物理像素的实际键盘遮挡，关闭点按落入其他窗口而失败；补宿主交集后，弹窗底边 566.62 CSS px，小于可用区域底边 578.62 CSS px，真实关闭成功。
- iPad 诊断测试初次使用 isHittable 判断离屏长列表条目，可能点到弹窗外。修正为先滚动到设置弹窗实际可见矩形内，再点按；未取消可见性/系统面板断言，最终通过。

## 证据

- 汇总日志、Android 键盘截图：`.build/reports/ios/2026-10-29-followup/`
- iPhone 系统测试：`.build/reports/ios/layout/E4D86FE2-4A02-463B-BB0E-AF9961F67ABF/20261028T174526Z/`
- iPad 系统测试：`.build/reports/ios/layout/CA6853B6-D675-4B5C-BF93-E5A7002EC070/20261028T175253Z/`
- iPhone 宿主：`.build/reports/ios/shared-ui/E4D86FE2-4A02-463B-BB0E-AF9961F67ABF/20261028T175542Z-92687/`
- iPad 宿主：`.build/reports/ios/shared-ui/CA6853B6-D675-4B5C-BF93-E5A7002EC070/20261028T175601Z-92911/`
- 两端资源指纹：`.build/reports/ios/parity-resource-fingerprints-next.json`

iPhone 布局矩阵后补了 MetricKit JSON 清理，随后 iPad 全矩阵、双设备宿主和 device Release 均使用更新后的代码通过。没有宣称重新执行了真实崩溃投递或完整 Android portable 的全部历史用例。

## 仍待完成/验收

OGG/Vorbis 解码、大库索引主线程开销和长期后台扫描仍未完整对齐；真实电话/蓝牙/耳机、锁屏、MetricKit 系统投递、iCloud/授权失效、浮动/分离/横屏键盘、完整中文 IME 组合态和 VoiceOver 仍需专项或真机验收。本轮覆盖实际中文文字输入，但不将 typeText 等同于完整输入法组合态验证。此前的“崩溃捕获未接入”已由本轮 MetricKit 接入取代，仍不宣称即时、全量捕获。

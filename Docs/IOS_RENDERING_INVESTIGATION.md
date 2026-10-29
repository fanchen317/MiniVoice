# iOS 样式切换与音乐墙滑动排查（2026-10-29）

## 录屏证据与判断边界

用户录屏长15.55秒，1320×2868，声明帧率60。按每秒2帧抽样检查：样式切换附近出现两条横贯侧栏与背后页面的细线；快速滑动段多次出现封面区域空底、文字仍在。录屏的编码帧率不等于应用渲染帧率，不能从此计算或承诺应用FPS。

横线跨越独立组件边界，因此不符合单个按钮/侧栏描边问题。原切换链路执行 WKWebView.takeSnapshot → JPEG编码/base64桥接 → 解码 → 多块canvas裁图 → 逐块动画。整屏截图与分片合成是本轮移除的可疑路径；没有WebKit GPU跟踪证据，尚不能把特定系统缺陷认定为唯一根因。

抽帧记录保留于 `.build/reports/ios/render-investigation/`，不把用户原始视频加入仓库。

## 实施

1. iOS适配器选择`live`样式过渡：当前页面100ms淡出至0.35，提交目标样式并等待布局，再180ms恢复。使用一个真实页面的opacity动画，零截图请求、零JPEG编解码、零分片canvas。Android/Mac既有碎片动效保留。旋转、减弱动态、失败均清理动画；快速切换仍以最新目标为准。iOS宿主旧captureStyle入口返回空，避免旧调用再次触发读回。
2. iOS音乐墙挂载窗口提前360 CSS px，超过140px相机重定位阈值。原未聚焦overscan只有100px，小于阈值，连续滑动会在刷新前露出尚未挂载的区域。范围保持有限，不挂载整库。
3. 可见集合、封面React节点与逐卡投影按相机窗口/布局状态更新，普通播放位置轮询不再重建集合、重写每张封面的样式。纯平移沿用一个容器transform；缩放、聚焦、展开仍进行必要的逐卡布局。
4. iOS授权资源读取增加32MiB成本预算、192条数量预算的NSCache编码图片缓存（预算由系统管理，不是硬内存上限）；每次请求先校验歌曲和当前文件夹身份，目录更新清空缓存，原图请求不进入该缓存。版本化资源允许短期私有缓存，避免滚出/滚回时反复磁盘读取与授权解析。缓存不保存解码后的整库位图，系统可回收。

## 验证内容

`Scripts/tests/test-ios-rendering.cjs`：三样式顺序切换、零capture调用、无碎片层、最终opacity恢复、快速连续点击后的最终目标、旋转中断、减弱动态；播放轮询期间封面style写入为零；1037首合成墙面18次正反方向平移，逐次将实际挂载ID与几何模型可见ID比较，无可见区域缺挂载。

`Scripts/tests/test-ios-wall-pan.cjs`：真实wheel事件驱动位移、已解码封面保留、相机提交前后无跳变。`test-wall-version.sh`覆盖共享墙面聚焦/展开/收起、Android参考样式及Mac实际页面。

`iOS/Tests/shared-host-smoke.js`新增真实WKWebView中的三样式切换、零截图请求、无遗留碎片层、滑动后封面加载断言。测试先明确展开播放栏，再验证遮挡和闲置收起；原测试隐含“前面的检查少于3秒”，增加渲染探测后不再成立，已显式初始化，不放宽遮挡断言。

真实设备横线是否消失、快速滑动主观流畅度和GPU内存压力仍需安装新构建后回验。模拟器/Chromium的逻辑断言不代表用户设备上的帧率承诺。

## 参考

- [Apple WKSnapshotConfiguration](https://developer.apple.com/documentation/webkit/wksnapshotconfiguration)：截图尺寸与配置接口；不提供横线缺陷结论。
- [WebKit accelerated rendering and compositing](https://trac.webkit.org/wiki/Accelerated%20rendering%20and%20compositing)：理解合成层与动画成本的背景资料，非当前设备性能测量。

## 本轮结果

111文件静态门禁、47项共享JS、完整共享墙面/Mac页面回归、定向渲染与平移检查通过。iOS Debug模拟器、device Release无签名和Android体验APK构建通过。

真实WKWebView最终报告：`.build/reports/ios/shared-ui/A1A82D8E-910C-4068-8FC1-1D8D5F21A010/20261029T091341Z-21611/`，全部通过，包含切换/滑动、缓存清理重建、1037首扫描及两种真实音频解码。首轮播放栏断言受新增测试时长影响；次轮缓存清点与新目录显示资源生成并发。测试明确初始展开状态，并等待新资源完成后再清点，保持原断言后通过。

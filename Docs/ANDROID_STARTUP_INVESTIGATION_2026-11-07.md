# Android 启动图标复查（2026-11-07）

## 问题与证据

用户 22:38 录屏在启动器展开窗口阶段显示短暂的大方形图案，随后应用加载页圆角正常。此前数轮修复均未通过用户实机验收，应视为问题仍存在，不能用构建成功代表修复。

## 检查链路

- Manifest：正式包 com.xcosmos.minivoice，Application icon / roundIcon / launcher Activity icon 均指向同一个 adaptive-icon；未更换包名、签名或数据路径。
- 图像源：launch_logo 为 528×528 RGBA，角像素确实透明；不是 PNG 缺 alpha。
- Android 12+ 系统图标原为 layer-list + 固定 item + inset，尺寸与应用 88dp 图标不同，存在缩放差异；不能仅由代码认定这是 OEM 方形帧的唯一根因。
- 应用加载页原使用包含标题的组合居中，导致图标自身高于屏幕中心，与系统图标中心不同。
- 深浅主题：系统采用 values / values-night，运行时加载页采用已保存应用主题。系统/应用主题不同时仍需实机检查交接。

## 本轮修改

- 系统图标使用 288dp 透明画布的 xxxhdpi PNG（1152px），可见图标 88dp（352px），位于中心，避开系统裁切区；移除嵌套 drawable 尺寸推导。绘制和透明度断言在 Scripts/assets/AndroidSplashGenerator.swift。
- 应用内加载页使图标本身居中，标题在下；低版本 windowBackground 图标同为中心 88dp。
- 保留系统 adaptive launcher 入口；未关闭系统动画、禁用功能或要求用户清数据。

## 实际验证与限制

通过 UI 门禁、正式 APK 构建、导出资源检查、生成图角透明/中心不透明/尺寸断言；确认 APK 的 windowSplashScreenAnimatedIcon 引用 xxxhdpi PNG。

创建独立 MiniVoice_Startup_Test AVD 尝试运行，因系统镜像要求 userdata 空间 7372.8MB，高于可用约 5.6GB，启动失败。未清理用户文件、未连接/安装到真实手机，portable 与录屏回验未完成。模拟器也不能代替用户 OEM 启动器。

结论：定向修改已实施，实机方形过渡仍待验收。应覆盖系统深/浅 × 应用深/浅/跟随系统、冷启动/热启动/后台恢复，逐帧检查启动器→系统图标→应用占位→共享页面。

参考：https://developer.android.com/develop/ui/views/launch/splash-screen

## 用户回验更新

用户本轮明确反馈“现在安卓端优化好了”；此前 OEM 过渡待验收条目在该用户设备上转为通过，不代表其他设备或全主题矩阵通过。

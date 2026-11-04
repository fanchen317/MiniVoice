# MiniVoice 3.0.0 正式渠道切换日志

2026-11-04，当前 `version3.0.0` 分支。三端版本 3.0.0，构建号 30000。

## 代码与入口

- Mac：将原体验版设置、歌曲编辑、桌面歌词及封面导入能力接入正式 Electron + Swift 宿主，不再因正式身份返回旧原生内容面板。保留正式身份与数据域，内部 debug 继续隔离。
- Android：共享播放器成为唯一正式 launcher，删除 MainActivity 中旧播放器实现，仅保留历史启动入口转发。通知动作不变，正式包保留原 applicationId 和签名校验。
- iOS：保留当前共享宿主，同步 Debug/Release 原生版本声明。
- 公共 build/deploy 入口统一正式渠道，旧 experience 命令兼容映射正式构建；内部隔离 debug 构建仍可用于开发。
- 统一关于页、诊断版本、原生版本与 npm 包版本；新增发布配置门禁及失败用例。离线依赖清单更新锁文件哈希，没有修改依赖版本。

## 升级与交付

正式标识、原有正式数据路径不变。旧 Mac-debug 数据保留，不自动合并正式数据；Android 继续使用同一应用 ID/证书，不能通过卸载解决升级问题，以免删除授权与数据。

生成本地正式 App、DMG、APK；iOS 完成 Release 模拟器构建。未替换已安装应用或操作真实音乐库。版本提升不代表此前所有视觉/性能问题已解决，具体通过项和待验收项见 ACCEPTANCE_STATUS.md 最新记录。

后续更改版本时同步 Shared/version.json 与各端原生声明，运行 `node Scripts/checks/check-release-config.mjs`；不一致时构建立即失败。

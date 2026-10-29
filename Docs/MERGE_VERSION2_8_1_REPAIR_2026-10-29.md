# version2.8.1-repair 合并记录（2026-10-29）

## 分支与根因

- 目标：当前 `version2.8.1`，合并前 HEAD 为 `5de704f`。
- 来源：重新 fetch 后的 `origin/version2.8.1-repair`，最新 `c3a7903`，包含 `28c9948`、`dc7f0a9`、`38c6c02`、`c3a7903` 四个提交。
- 使用 fast-forward 保留来源提交历史，再提交当前开发内容和兼容整合；没有改写历史，也没有推送远端。
- 核心部署故障：旧 `.gitignore` 的 `build/` 匹配所有层级，导致 `Scripts/build/` 存在于本机却没有进入 Git。其他电脑拉取后缺少 Xcode 和公开构建入口引用的脚本。

## 保留与冲突处理

- 接受 `/build/` 规则、入库的构建脚本、集中 Node 运行时选择，以及 SharedPlayer 资源根目录的 standardizedFileURL 修正。
- 保留当前 iOS 正式/体验双通道、独立 bundle/cache/产物与签名覆盖配置，避免修复分支较早的 package-ios.sh 重新禁止体验版打包。
- Shared UI 打包兼容 Xcode PATH，按 TARGET_BUILD_DIR 与 UNLOCALIZED_RESOURCES_FOLDER_PATH 定位资源目录，清理旧 hash 资源，仅 Debug 携带集成冒烟脚本。
- 保留严格的共享许可文件检查；缺少必要许可文件会失败，未改为忽略缺失许可。
- 工程文件保留当前 UITest、MetricKit 和所有源码引用，同时保留修复分支的开发团队设置；签名打包仍可由现有 TEAM 配置覆盖。
- 验收台账合并双方记录，不用某一侧覆盖另一侧。
- 按用户“合并后提交代码”的要求，一并收纳当前未提交的 iOS/共享组件开发、打包双通道和测试源码，避免只提交工程引用而遗漏源码。Xcode 个人界面/用户 scheme 状态不纳入此次整合提交。
- 合并前对未提交/未跟踪源码和此前被忽略的构建脚本做了 Git stash 与本机 `.git/merge-backups/` 备份；核对原待提交文件无缺失。

## 实际验证

- 新增 `Scripts/tests/test-tracked-build-scripts.py`：只从 Git index 导出干净目录，不复制本机未跟踪文件/依赖；验证必要脚本已跟踪且不被忽略、根 build 输出仍忽略。在精简 PATH、异目录、没有 Mac/Shared node_modules 的条件下离线构建共享 UI 通过，产物含第三方声明。
- `test-package-workflows.py`、`test-package-ios.py`、`test-shared-ui-independent.py` 通过。
- 自有组件门禁通过，46 项共享 JS 通过；iOS 基础、诊断持久化、缓存范围、身份、播放策略与 ZIP 测试通过。
- `build-ios.sh simulator Debug`、`build-ios.sh device Release` 无签名构建通过。
- 专用 iPhone/iPad 的 WKWebView 宿主集成通过，并实际解包宿主诊断 ZIP。
- Shell 语法与 Git diff 检查通过；无未解决合并冲突。

日志目录：`.build/reports/merge-repair/`。本轮未执行真实 Apple 签名导出或实体手机部署，未覆盖全部 Android/Mac 原生回归；不把构建成功写成全部实机体验验收。

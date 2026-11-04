# 脚本入口

从项目根目录使用四个公开入口：

- `Scripts/build.sh`：正式版 App、DMG、APK、签名 IPA。
- `Scripts/build-experience.sh`：正式版安装包的兼容入口（体验实现已提升为正式版）。
- `Scripts/deploy.sh`：正式版移动安装包及 Mac 应用替换。
- `Scripts/deploy-experience.sh`：正式版部署的兼容入口。

均支持 `--platforms mac,android,ios`、`--no-launch` 和 `--help`，默认三个平台。iOS 正式/体验均走 archive + exportArchive；仅需 iOS 时传 `--platforms ios`。签名与固定产物说明见根 README。

| 目录 | 用途 |
| --- | --- |
| `build/` | 平台构建、组装、部署实现；通常由四个入口调用 |
| `common/` | SDK 查找、签名、应用校验等共享函数 |
| `checks/` | 产品与组件静态门禁 |
| `tests/` | 单元测试、模拟器测试、Electron 实际交互验证 |
| `tools/` | 预览、资源更新、历史产物归档、目录迁移 |
| `assets/` | DMG 布局、图标生成源码、Python 依赖和打包配方 |

例如：`node Scripts/checks/check-ui-standards.mjs`、`bash Scripts/tests/test-android.sh`、`python3 Scripts/tests/test-package-workflows.py`。

旧的内部脚本已移动，仓库内调用和文档已同步；不再在根目录保留重复别名。构建目录规则见 [项目结构](../Docs/PROJECT_STRUCTURE.md)。

三端版本声明为 `Shared/version.json`，平台原生元数据由 `node Scripts/checks/check-release-config.mjs` 检查一致性。公开打包入口统一正式渠道；`build-debug-app.sh` 仅用于隔离的内部调试，不是体验产品。

# 脚本入口

从项目根目录使用四个公开入口：

- `Scripts/build.sh`：正式版 App、DMG、APK、签名 IPA。
- `Scripts/build-experience.sh`：体验版安装包。
- `Scripts/deploy.sh`：正式版移动安装包及 Mac 应用替换。
- `Scripts/deploy-experience.sh`：体验版移动安装包及 Mac 应用替换。

均支持 `--platforms mac,android`、`--no-launch` 和 `--help`。iOS 体验宿主尚未接入；正式 IPA 需配置签名，详见根 README。

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

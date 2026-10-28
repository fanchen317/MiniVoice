# 项目结构与构建文件管理

## 源码与依赖

- `Android/`、`MacOS/`、`iOS/`：平台宿主与平台能力。
- `Shared/Core/`：共享核心、C/JNI/Swift 适配。
- `Shared/UI/`：独立 React/Vite 包，拥有自己的 package.json、package-lock.json；直接执行 `npm --prefix Shared/UI ci`、`npm --prefix Shared/UI run build` 即可构建，不依赖 Mac 前端 node_modules。
- `Shared/Tooling/`：两个前端共用的依赖准备工具与离线 npm 归档。
- `Scripts/`：只保留四个公开打包部署入口，其余按职责放在子目录。
- `Docs/`：设计、验收和实测依据；`Experiments/`：实验源码。

React、ReactDOM、Vite 在两个包中固定为一致版本，各自锁文件明确各自依赖。桌面 Vite 将共享组件的 React 显式解析到桌面包，避免一个页面加载两份 React。共享 UI 显式解析自身依赖，不再借用 Mac 目录。

离线准备命令：

```sh
node Shared/Tooling/prepare-dependencies.mjs shared-ui
node Shared/Tooling/prepare-dependencies.mjs desktop
```

脚本分别验证对应锁文件及归档 SHA-256，并运行 npm ci --offline。`MacOS/Desktop/electron/prepare-dependencies.mjs` 继续作为桌面兼容入口。更改依赖时应同步更新离线资源清单。所有层级的 node_modules、Vite 缓存都不纳入 Git。

## 构建目录

| 目录 | 内容 | 清理含义 |
| --- | --- | --- |
| `.build/cache/` | Swift/Clang 编译缓存、npm/Electron 缓存、工具环境、SDK、依赖源码缓存 | 按子目录清理；SDK、工具环境可能需要重新安装或下载 |
| `.build/work/` | Android 类文件及 native 库、共享 UI/Core、原生引擎、组装暂存、歌词实验资源 | 可重建，但实验模型不应盲删 |
| `.build/reports/` | 测试结果、截图、日志、迁移清单 | 属于验收证据，应按保留周期归档 |
| `.build/archive/` | 旧安装包、历史项目副本、与新产物重名的旧文件 | 确认不再回退或参考后再删除 |
| `.build/dist/` | 当前两版 App、DMG、APK 和实际导出的 IPA | 用户安装与交付使用的产物 |

正式 App：`.build/dist/MiniVoice.app`；体验 App：`.build/dist/MiniVoice-debug.app`。Mac 应用标识和数据目录保持原有隔离。正式保留原生设置等窗口，体验使用自有组件窗口。

新产物写入上述目录，不在根 `.build` 生成日志或安装包。测试 APK、截图和日志在 `.build/reports/android/`，Electron 页面验证在 `.build/reports/ui/`。Swift 主构建使用 `.build/cache/swift`，共享核心单独 Swift 验证使用 `.build/cache/swift-shared-core`。

## 历史目录迁移

```sh
python3 Scripts/tools/migrate-build-layout.py          # 预览
python3 Scripts/tools/migrate-build-layout.py --apply  # 移动并记录清单
```

迁移不删除文件。已存在的新产物优先保留，旧副本进入 `.build/archive/pre-migration/`；未知历史目录进入 `.build/archive/legacy-layout/`。迁移清单位于 `.build/reports/build-layout-migration.json`。正在运行打包流程时拒绝迁移。

旧 Clang 模块缓存包含绝对路径，不能搬迁后直接复用；旧缓存保留在 `.build/cache/legacy/clang-modules`，新位置重新生成。旧实验 CMake Python 环境同样保留在 legacy 下，需要时按实验 README 重建工具环境。历史 Swift 缓存保留在 `.build/cache/legacy-swift`，不作为新路径的编译输入；仅复用 checkouts/repositories 和依赖状态。已有依赖齐备时，可设置 `MINIVOICE_LOCKED_BUILD=1` 使用锁定依赖，避免联网更新。

本轮只迁移和停止跟踪误入库缓存，没有清空缓存、模型、历史包或验收证据。

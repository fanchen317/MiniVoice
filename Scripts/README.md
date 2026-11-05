# 构建与部署入口

版本统一读取 `Shared/version.json`，当前 3.0.0。公共工作流暂不包含 iOS。

| 命令 | 行为 |
| --- | --- |
| `bash Scripts/build.sh` | macOS 默认生成 Mac App、DMG 和 Android APK；Windows Git Bash 默认 Windows 安装包 |
| `bash Scripts/build.sh --platforms mac` | 只生成 Mac App 和 DMG |
| `bash Scripts/build.sh --platforms android` | 只生成 Android APK |
| `./Scripts/build.ps1 -Platforms windows` | Windows PowerShell 构建安装包 |
| `bash Scripts/deploy.sh` | 将已构建的当前版本 Mac App 安全替换到 `/Applications/MiniVoice.app` 并启动，不构建其他产物 |
| `bash Scripts/deploy.sh --no-launch` | 替换后不启动 |

`deploy.sh --target /absolute/MiniVoice.app` 可指定安装路径。没有当前版本的完整 App 时明确失败，先执行 build。安装保留原有校验、退出检查、暂存替换和失败回退；应用内部标识、数据路径与安装名不因文件版本后缀改变。

公开产物在 `.build/dist/`：

- `MiniVoice-3.0.0-mac.app`
- `MiniVoice-3.0.0-mac.dmg`
- `MiniVoice-3.0.0-android.apk`
- `MiniVoice-3.0.0-windows-x64-setup.exe`

版本变化后自动更新文件名，历史不同版本保留，不自动归档。Windows 打包的中间应用目录 `MiniVoice-win32-x64/` 不是最终安装包。

原生工具链按主机运行：Mac App/DMG 需要 macOS；Windows 核心与安装包需要 Windows x64、Node.js 22+、MSVC/CMake 和 NSIS 3（makensis.exe 在 PATH）。不能在当前 Mac 上把原生 Mac 核心改名为 Windows exe。Android 沿用现有 SDK/NDK 与签名配置。可以显式列出 `--platforms mac,android,windows`，不兼容主机的平台明确失败，其他平台继续，最终返回非零。

Bash 构建按平台显示阶段、成功/失败、产物路径、耗时与日志，日志在 `.build/reports/build/<版本>-<平台>.log`。交互终端使用颜色，重定向或 NO_COLOR 环境下为纯文本。build/deploy 共用互斥锁，防止并发修改缓存或应用。

Windows NSIS 安装包为当前用户安装，包含开始菜单与卸载入口，尚未签名。卸载只删除本次打包清单中的文件，保留音乐、应用偏好和用户额外文件。实际安装/升级/卸载须在 Windows 验收。

内部脚本按 build/common/checks/tests/tools/assets 分类；iOS 的定向开发脚本保留，但不参与上述公共流程。旧 experience 公开入口已撤除，不重新添加。

正式构建只有一个渠道。Debug/Release 只表示编译配置，不改变应用标识和数据路径；旧体验版打包脚本已删除。

## Mac 生成 Windows 安装包（新增）

Mac 的 `build.sh` 默认平台现为 mac,android,windows；只需本机两端可显式 `--platforms mac,android`。

在 Mac 上生成 Windows 安装包需 NSIS 3（makensis在PATH），并设置 `MINIVOICE_WINDOWS_RESOURCES=/绝对路径/Windows资源`。目录包含Windows x64原生minivoice-core.exe、ffmpeg.exe、ffprobe.exe、LICENSE.txt及LyricsAI/python.exe、models/small.pt、LICENSES目录和完整Python依赖。脚本校验x64 PE标头后构建共享前端、打包Windows Electron并生成带版本号的setup.exe；不执行Windows工具，也不等于实机验证。资源目录应来自已验证Windows构建；缺资源时失败，不跳过或制造成功提示。

执行 `bash Scripts/build.sh --platforms windows` 可只打Windows安装包。Windows主机仍使用PowerShell完整编译入口。

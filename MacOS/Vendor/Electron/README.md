# Electron 本地构建资源

`arm64/electron-v44.8.0-darwin-arm64.zip` 是 Electron 官方 macOS arm64 发行包，使用 Git LFS 保存。

来源：<https://github.com/electron/electron/releases/download/v44.8.0/electron-v44.8.0-darwin-arm64.zip>

SHA-256 同时记录在 `arm64/SHA256SUMS` 和 npm Electron 包的 `checksums.json` 中；构建以 npm 包中的校验值为准。Electron 及 Chromium 许可随 ZIP 中的 `LICENSE`、`LICENSES.chromium.html` 保存。

新检出仓库后先执行 `git lfs pull`。部署脚本从这里复制安装包到 `.build/`，不联网下载。升级 Electron 时应同时更新 `MacOS/Desktop/package.json`、锁文件、本目录发行包及校验值，以及 npm 离线依赖缓存。

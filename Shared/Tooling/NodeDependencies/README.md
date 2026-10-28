# 前端 npm 离线依赖

`npm-cache.tar.gz` 保存 `MacOS/Desktop/package-lock.json` 与 `Shared/UI/package-lock.json` 所需的 npm 内容寻址缓存，使用 Git LFS 保存，不包含机器相关的 `node_modules` 或安装日志。适用于当前 macOS arm64 部署。

`manifest.json` 通过 `packageLocks` 记录两个包的锁文件哈希，并记录缓存归档的 SHA-256。构建脚本先校验两个哈希，再解压缓存并运行 `npm ci --offline --include=dev --bin-links=true --no-audit --no-fund`。Electron 的 npm 安装脚本不下载二进制；对应安装包由 `MacOS/Vendor/Electron` 提供。

缓存内容来自 npm，包版本、来源及完整性校验值均由锁文件记录。各依赖原有许可保存在包内。修改 npm 依赖时，维护者需先联网用新锁文件完成安装，再重新归档 `_cacache` 并更新 manifest 的归档哈希和对应锁文件哈希；不要手动修改包内容。

Node 和 Xcode 工具链需预先安装。本缓存不包含 Swift 包或 DMG Python 工具依赖。

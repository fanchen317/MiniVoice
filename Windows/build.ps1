$ErrorActionPreference = 'Stop'
function Run([scriptblock]$Command) { & $Command; if ($LASTEXITCODE -ne 0) { throw "构建失败：$Command" } }
$Repo = Split-Path $PSScriptRoot
Push-Location $Repo
try {
 Run { node -e "const [major,minor]=process.versions.node.split('.').map(Number);if(major<22||(major===22&&minor<12))throw Error('Windows打包需要Node.js 22.12以上');" }
 Write-Host 'MiniVoice · Windows 构建' -ForegroundColor Cyan
 Run { node Scripts/checks/check-ui-standards.mjs }
 $Version = Get-Content Shared/version.json -Raw | ConvertFrom-Json
 $Package = Get-Content Windows/package.json -Raw | ConvertFrom-Json
 if ($Version.version -ne $Package.version) { throw 'Windows 版本与 Shared/version.json 不一致' }
 Run { npm --prefix Shared/UI ci }
 Run { node Shared/UI/node_modules/vite/bin/vite.js build --config Windows/vite.config.mjs }
 Run { node Scripts/build/package-shared-notices.mjs Windows/ui Shared/UI }
 Run { cmake -S Shared/Core -B .build/cache/windows-core }
 Run { cmake --build .build/cache/windows-core --config Release --target minivoice-core }
 New-Item -ItemType Directory -Force Windows/resources | Out-Null
 Copy-Item MacOS/Sources/MiniVoice/Resources/align_lyrics.py Windows/resources/align_lyrics.py -Force
 Copy-Item .build/cache/windows-core/Release/minivoice-core.exe Windows/resources/ -Force
 if (-not $env:MINIVOICE_WINDOWS_MEDIA_TOOLS) { throw '请设置 MINIVOICE_WINDOWS_MEDIA_TOOLS，指向已审核的 Windows FFmpeg/FFprobe 目录（包含 LICENSE.txt）。' }
 foreach ($Tool in @('ffmpeg.exe','ffprobe.exe','LICENSE.txt')) {
  $Source = Join-Path $env:MINIVOICE_WINDOWS_MEDIA_TOOLS $Tool
  if (-not (Test-Path $Source -PathType Leaf)) { throw "缺少 Windows 媒体工具或许可：$Source" }
  Copy-Item $Source (Join-Path 'Windows/resources' $Tool) -Force
 }
 if (-not $env:MINIVOICE_WINDOWS_AI_RUNTIME) { throw '请设置 MINIVOICE_WINDOWS_AI_RUNTIME，提供含 python.exe、models/small.pt、LICENSES 的离线 AI 运行环境。' }
 foreach ($Resource in @('python.exe','models/small.pt','LICENSES')) {
  if (-not (Test-Path (Join-Path $env:MINIVOICE_WINDOWS_AI_RUNTIME $Resource))) { throw "AI 运行时缺少资源：$Resource" }
 }
 $AIRoot = Join-Path $Repo 'Windows/resources/LyricsAI'
 if (Test-Path $AIRoot) { Remove-Item $AIRoot -Recurse -Force }
 Copy-Item $env:MINIVOICE_WINDOWS_AI_RUNTIME $AIRoot -Recurse
 Run { & (Join-Path $AIRoot 'python.exe') Windows/resources/align_lyrics.py --self-test (Join-Path $AIRoot 'models/small.pt') }
 New-Item -ItemType Directory -Force Windows/electron/shared-services | Out-Null
 Copy-Item Shared/DesktopServices/*.cjs Windows/electron/shared-services/ -Force
 Run { npm --prefix Windows ci }
 Run { npm --prefix Windows test }
 Write-Host "── Windows 应用打包 · $($Version.version) ──" -ForegroundColor Cyan
 Run { npm --prefix Windows run package -- --app-version=$($Version.version) --build-version=$($Version.build) }
 $Compiler = Get-Command makensis.exe -ErrorAction SilentlyContinue
 if (-not $Compiler) { throw '缺少 NSIS 3：安装后将 makensis.exe 加入 PATH，再执行构建以生成安装包。' }
 $AppDir = Join-Path $Repo '.build/dist/MiniVoice-win32-x64'
 $Installer = Join-Path $Repo ".build/dist/MiniVoice-$($Version.version)-windows-x64-setup.exe"
 $UninstallFiles = Join-Path $Repo '.build/work/windows-uninstall.nsh'
 New-Item -ItemType Directory -Force (Split-Path $UninstallFiles) | Out-Null
 Run { node Windows/generate-uninstall.mjs $AppDir $UninstallFiles }
 $Temporary = "$Installer.pending.exe"
 try {
  Run { & $Compiler.Source "/DVERSION=$($Version.version)" "/DAPP_DIR=$AppDir" "/DOUTPUT=$Temporary" "/DUNINSTALL_FILES=$UninstallFiles" Windows/installer.nsi }
  if (-not (Test-Path $Temporary)) { throw 'NSIS 未生成安装包' }
  Move-Item $Temporary $Installer -Force
 } finally { if (Test-Path $Temporary) { Remove-Item $Temporary -Force } }
 Write-Host "[成功] MiniVoice $($Version.version) Windows 安装包" -ForegroundColor Green
 Write-Host "  $Installer"
} finally { Pop-Location }

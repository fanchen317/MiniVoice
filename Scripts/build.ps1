param([string]$Platforms = 'windows')
$ErrorActionPreference = 'Stop'
if ($Platforms -ne 'windows') { throw 'PowerShell 入口当前支持 -Platforms windows；Mac/Android 使用 build.sh。' }
$Repo = Split-Path $PSScriptRoot
$Lock = Join-Path $Repo '.build/work/package-workflow.lock'
New-Item -ItemType Directory -Force (Split-Path $Lock) | Out-Null
try { New-Item -ItemType Directory $Lock -ErrorAction Stop | Out-Null } catch { throw '另一个打包流程正在运行；请检查 package-workflow.lock。' }
try { & (Join-Path $Repo 'Windows/build.ps1') } finally { Remove-Item $Lock -Force }

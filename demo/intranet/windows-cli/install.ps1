param(
  [string]$RootPath = ""
)

$ErrorActionPreference = "Stop"

function Resolve-Root {
  param([string]$GivenPath)

  if ($GivenPath -and (Test-Path -LiteralPath $GivenPath -PathType Container)) {
    return (Resolve-Path -LiteralPath $GivenPath).Path
  }

  return (Split-Path -Parent $PSCommandPath)
}

$root = Resolve-Root -GivenPath $RootPath
$srcExe = Join-Path $root "opencode.exe"
$srcRg = Join-Path $root "rg.exe"
$srcCfg = Join-Path $root "opencode.json"

if (-not (Test-Path -LiteralPath $srcExe -PathType Leaf)) {
  throw "Missing CLI binary: $srcExe"
}
if (-not (Test-Path -LiteralPath $srcRg -PathType Leaf)) {
  throw "Missing ripgrep sidecar: $srcRg"
}
if (-not (Test-Path -LiteralPath $srcCfg -PathType Leaf)) {
  throw "Missing config file: $srcCfg"
}

$baseDir = Join-Path $env:LOCALAPPDATA "opencode-demo\cli"
$binDir = Join-Path $baseDir "bin"
$cfgPath = Join-Path $baseDir "opencode.json"
$runtimeDir = Join-Path $baseDir "runtime"
$runtimeBinDir = Join-Path $runtimeDir "xdg-data\opencode\bin"
$shimDir = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"
$shimPath = Join-Path $shimDir "opencode.cmd"

New-Item -ItemType Directory -Force -Path $binDir | Out-Null
New-Item -ItemType Directory -Force -Path $runtimeDir | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $runtimeDir "xdg-config") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $runtimeDir "xdg-data") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $runtimeDir "xdg-cache") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $runtimeDir "xdg-state") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $runtimeDir "home") | Out-Null
New-Item -ItemType Directory -Force -Path $runtimeBinDir | Out-Null

Copy-Item -LiteralPath $srcExe -Destination (Join-Path $binDir "opencode.exe") -Force
Copy-Item -LiteralPath $srcRg -Destination (Join-Path $binDir "rg.exe") -Force
Copy-Item -LiteralPath $srcRg -Destination (Join-Path $runtimeBinDir "rg.exe") -Force
Copy-Item -LiteralPath $srcCfg -Destination $cfgPath -Force

$launcher = @'
@echo off
setlocal

set "BASE=%LOCALAPPDATA%\opencode-demo\cli"
set "BIN_DIR=%BASE%\bin"
set "BIN=%BIN_DIR%\opencode.exe"
if not exist "%BIN%" (
  echo OpenCode CLI not found at "%BIN%".
  exit /b 1
)

set "OPENCODE_CONFIG=%BASE%\opencode.json"
set "OPENCODE_DISABLE_PROJECT_CONFIG=1"
set "OPENCODE_SAFE_MODE=1"
set "OPENCODE_ALLOWED_HOSTS=10.90.79.111:8000"
set "OPENCODE_DISABLE_MODELS_FETCH=1"
set "OPENCODE_DISABLE_DYNAMIC_INSTALLS=1"
set "OPENCODE_DISABLE_REMOTE_INSTRUCTIONS=1"
set "OPENCODE_DISABLE_REMOTE_MCP=1"
set "OPENCODE_DISABLE_AUTOUPDATE=1"
set "OPENCODE_DISABLE_DEFAULT_PLUGINS=1"
set "OPENCODE_DISABLE_PROXY=1"
set "HTTP_PROXY="
set "HTTPS_PROXY="
set "ALL_PROXY="
set "http_proxy="
set "https_proxy="
set "all_proxy="
if defined NO_PROXY (
  set "NO_PROXY=%NO_PROXY%,127.0.0.1,localhost,::1,10.90.79.111,10.90.79.111:8000"
) else (
  set "NO_PROXY=127.0.0.1,localhost,::1,10.90.79.111,10.90.79.111:8000"
)
if defined no_proxy (
  set "no_proxy=%no_proxy%,127.0.0.1,localhost,::1,10.90.79.111,10.90.79.111:8000"
) else (
  set "no_proxy=127.0.0.1,localhost,::1,10.90.79.111,10.90.79.111:8000"
)

set "RUNTIME=%BASE%\runtime"
set "XDG_CONFIG_HOME=%RUNTIME%\xdg-config"
set "XDG_DATA_HOME=%RUNTIME%\xdg-data"
set "XDG_CACHE_HOME=%RUNTIME%\xdg-cache"
set "XDG_STATE_HOME=%RUNTIME%\xdg-state"
set "OPENCODE_TEST_HOME=%RUNTIME%\home"
set "RUNTIME_BIN=%RUNTIME%\xdg-data\opencode\bin"

set "PATH=%BIN_DIR%;%RUNTIME_BIN%;%PATH%"
"%BIN%" %*
'@

New-Item -ItemType Directory -Force -Path $shimDir | Out-Null
Set-Content -LiteralPath $shimPath -Value $launcher -NoNewline

Write-Host "Installation complete."
Write-Host "CLI binary: $(Join-Path $binDir 'opencode.exe')"
Write-Host "Launcher: $shimPath"
Write-Host "Config: $cfgPath"
Write-Host "No user/system environment variables were changed."
Write-Host ""
Write-Host "Open a new terminal and run: opencode"

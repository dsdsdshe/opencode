param(
  [string]$RootPath = "",
  [string]$ApiKey = "",
  [string]$ServerHost = ""
)

$ErrorActionPreference = "Stop"

function Get-PlainText {
  param([Security.SecureString]$Value)

  $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
  }
  finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
  }
}

function Resolve-ApiKey {
  param([string]$CurrentValue)

  if ($CurrentValue) {
    return $CurrentValue
  }

  if ($env:OPENCODE_INTRANET_API_KEY) {
    return $env:OPENCODE_INTRANET_API_KEY
  }

  while ($true) {
    $secure = Read-Host "Enter intranet API key" -AsSecureString
    $plain = Get-PlainText -Value $secure
    if ($plain) {
      return $plain
    }
    Write-Host "API key is required."
  }
}

function Normalize-ServerHost {
  param([string]$Value)

  if (-not $Value) {
    return ""
  }

  $next = $Value.Trim()
  if ($next -match '^https?://') {
    $next = ([Uri]$next).Host
  }
  $next = $next.TrimEnd("/")
  if ($next.EndsWith(":4000")) {
    $next = $next.Substring(0, $next.Length - 5)
  }
  return $next
}

function Resolve-ServerHost {
  param([string]$CurrentValue)

  $next = Normalize-ServerHost -Value $CurrentValue
  if (-not $next -and $env:OPENCODE_INTRANET_HOST) {
    $next = Normalize-ServerHost -Value $env:OPENCODE_INTRANET_HOST
  }
  if ($next -and $next -match '^[A-Za-z0-9.-]+$') {
    return $next
  }
  if ($next) {
    throw "Server IP/hostname must contain only letters, digits, dots, or hyphens."
  }

  while ($true) {
    $input = Read-Host "Enter intranet server IP or hostname"
    $next = Normalize-ServerHost -Value $input
    if ($next -and $next -match '^[A-Za-z0-9.-]+$') {
      return $next
    }
    Write-Host "Server IP/hostname must contain only letters, digits, dots, or hyphens."
  }
}

function Resolve-ModelLimit {
  param([string]$ServerHostValue)

  if ($ServerHostValue -eq "10.90.79.111") {
    return 262144
  }

  return 196608
}

function Write-Config {
  param(
    [string]$Source,
    [string]$Destination,
    [string]$ApiKeyValue,
    [string]$ServerHostValue
  )

  $json = Get-Content -LiteralPath $Source -Raw | ConvertFrom-Json
  $baseUrl = "http://${ServerHostValue}:4000/v1"
  $limit = Resolve-ModelLimit -ServerHostValue $ServerHostValue
  $json.provider."internal-vllm".options.apiKey = $ApiKeyValue
  $json.provider."internal-vllm".api = $baseUrl
  $json.provider."internal-vllm".options.baseURL = $baseUrl
  $json.provider."internal-vllm".models."hiq-llm".limit.context = $limit
  $json.provider."internal-vllm".models."hiq-llm".limit.output = $limit
  $json.security.allowed_hosts = @("${ServerHostValue}:4000")
  $next = $json | ConvertTo-Json -Depth 100
  $encoding = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($Destination, $next, $encoding)
}

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

$ServerHost = Resolve-ServerHost -CurrentValue $ServerHost
$ApiKey = Resolve-ApiKey -CurrentValue $ApiKey

Copy-Item -LiteralPath $srcExe -Destination (Join-Path $binDir "opencode.exe") -Force
Copy-Item -LiteralPath $srcRg -Destination (Join-Path $binDir "rg.exe") -Force
Copy-Item -LiteralPath $srcRg -Destination (Join-Path $runtimeBinDir "rg.exe") -Force
Write-Config -Source $srcCfg -Destination $cfgPath -ApiKeyValue $ApiKey -ServerHostValue $ServerHost

$srcInstructions = Join-Path $root "uv-python.md"
if (Test-Path -LiteralPath $srcInstructions -PathType Leaf) {
  Copy-Item -LiteralPath $srcInstructions -Destination (Join-Path $baseDir "uv-python.md") -Force
}

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
set "OPENCODE_CONFIG_DIR=%BASE%"
set "OPENCODE_DISABLE_PROJECT_CONFIG=1"
set "OPENCODE_SAFE_MODE=1"
set "OPENCODE_ALLOWED_HOSTS=__OPENCODE_INTRANET_HOST__:4000"
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
$launcher = $launcher.Replace("__OPENCODE_INTRANET_HOST__", $ServerHost)

New-Item -ItemType Directory -Force -Path $shimDir | Out-Null
Set-Content -LiteralPath $shimPath -Value $launcher -NoNewline

Write-Host "Installation complete."
Write-Host "CLI binary: $(Join-Path $binDir 'opencode.exe')"
Write-Host "Launcher: $shimPath"
Write-Host "Config: $cfgPath"
Write-Host "No user/system environment variables were changed."
Write-Host ""
Write-Host "Open a new terminal and run: opencode"

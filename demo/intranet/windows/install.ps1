param(
  [string]$InstallerPath = "",
  [string]$ApiKey = ""
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

function Write-Config {
  param(
    [string]$Source,
    [string]$Destination,
    [string]$ApiKeyValue
  )

  $json = Get-Content -LiteralPath $Source -Raw | ConvertFrom-Json
  $json.provider."internal-vllm".options.apiKey = $ApiKeyValue
  $next = $json | ConvertTo-Json -Depth 100
  $encoding = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($Destination, $next, $encoding)
}

function Resolve-Installer {
  param([string]$GivenPath)

  if ($GivenPath -and (Test-Path $GivenPath)) {
    return (Resolve-Path $GivenPath).Path
  }

  $scriptRoot = Split-Path -Parent $PSCommandPath
  $preferred = Join-Path $scriptRoot "OpenCode-Setup.exe"
  if (Test-Path -LiteralPath $preferred -PathType Leaf) {
    return (Resolve-Path -LiteralPath $preferred).Path
  }

  $candidate = Get-ChildItem -Path $scriptRoot -Filter *.exe -File |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

  if (-not $candidate) {
    throw "No installer .exe found in $scriptRoot. Pass -InstallerPath explicitly."
  }

  return $candidate.FullName
}

$scriptRoot = Split-Path -Parent $PSCommandPath
$cfgSource = Join-Path $scriptRoot "opencode.json"

if (-not (Test-Path $cfgSource)) {
  throw "Missing config file: $cfgSource"
}

$installer = Resolve-Installer -GivenPath $InstallerPath
Write-Host "Running installer: $installer"
if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) {
  throw "Installer not found: $installer"
}
Unblock-File -LiteralPath $installer -ErrorAction SilentlyContinue
$process = [System.Diagnostics.Process]::new()
$process.StartInfo = [System.Diagnostics.ProcessStartInfo]::new()
$process.StartInfo.FileName = $installer
$process.StartInfo.Arguments = "/S"
$process.StartInfo.WorkingDirectory = Split-Path -Parent $installer
$process.StartInfo.UseShellExecute = $true
$started = $process.Start()
if (-not $started) {
  throw "Failed to start installer: $installer"
}
$process.WaitForExit()
$code = $process.ExitCode
if ($code -ne 0) {
  throw "Installer failed with exit code $code"
}

$baseDir = Join-Path $env:LOCALAPPDATA "opencode-demo"
$cfgDir = $baseDir
$cfgPath = Join-Path $cfgDir "opencode.json"
$ApiKey = Resolve-ApiKey -CurrentValue $ApiKey
New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
Write-Config -Source $cfgSource -Destination $cfgPath -ApiKeyValue $ApiKey

$runtimeDir = Join-Path $baseDir "runtime"
$xdgConfig = Join-Path $runtimeDir "xdg-config"
$xdgData = Join-Path $runtimeDir "xdg-data"
$xdgCache = Join-Path $runtimeDir "xdg-cache"
$xdgState = Join-Path $runtimeDir "xdg-state"
$sandboxHome = Join-Path $runtimeDir "home"

New-Item -ItemType Directory -Force -Path $xdgConfig | Out-Null
New-Item -ItemType Directory -Force -Path $xdgData | Out-Null
New-Item -ItemType Directory -Force -Path $xdgCache | Out-Null
New-Item -ItemType Directory -Force -Path $xdgState | Out-Null
New-Item -ItemType Directory -Force -Path $sandboxHome | Out-Null

Write-Host "Installation complete."
Write-Host "Config: $cfgPath"
Write-Host "Runtime state dir: $runtimeDir"
Write-Host "No user/system environment variables were changed."
Write-Host "You can start OpenCode normally from Start Menu."

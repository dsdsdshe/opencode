param(
  [string]$InstallerPath = ""
)

$ErrorActionPreference = "Stop"

function Resolve-Installer {
  param([string]$GivenPath)

  if ($GivenPath -and (Test-Path $GivenPath)) {
    return (Resolve-Path $GivenPath).Path
  }

  $scriptRoot = Split-Path -Parent $PSCommandPath
  $candidate = Get-ChildItem -Path $scriptRoot -Filter *.exe -File |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

  if (-not $candidate) {
    throw "No installer .exe found in $scriptRoot. Pass -InstallerPath explicitly."
  }

  return $candidate.FullName
}

function Broadcast-EnvironmentChange {
  Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class NativeMethods {
  [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
  public static extern IntPtr SendMessageTimeout(
    IntPtr hWnd,
    int Msg,
    UIntPtr wParam,
    string lParam,
    int fuFlags,
    int uTimeout,
    out UIntPtr lpdwResult
  );
}
"@

  $HWND_BROADCAST = [IntPtr]0xffff
  $WM_SETTINGCHANGE = 0x1A
  $SMTO_ABORTIFHUNG = 0x0002
  $out = [UIntPtr]::Zero
  [void][NativeMethods]::SendMessageTimeout(
    $HWND_BROADCAST,
    $WM_SETTINGCHANGE,
    [UIntPtr]::Zero,
    "Environment",
    $SMTO_ABORTIFHUNG,
    5000,
    [ref]$out
  )
}

function Merge-NoProxy {
  param(
    [string]$Current,
    [string[]]$Entries
  )

  $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
  $items = @()

  foreach ($value in @($Current -split ",") + $Entries) {
    $entry = "$value".Trim()
    if (-not $entry) {
      continue
    }
    if ($seen.Add($entry)) {
      $items += $entry
    }
  }

  return ($items -join ",")
}

$scriptRoot = Split-Path -Parent $PSCommandPath
$cfgSource = Join-Path $scriptRoot "opencode.json"

if (-not (Test-Path $cfgSource)) {
  throw "Missing config file: $cfgSource"
}

$installer = Resolve-Installer -GivenPath $InstallerPath
Write-Host "Running installer: $installer"
$process = Start-Process -FilePath $installer -ArgumentList "/S" -Wait -PassThru
if ($process.ExitCode -ne 0) {
  throw "Installer failed with exit code $($process.ExitCode)"
}

$baseDir = Join-Path $env:LOCALAPPDATA "opencode-demo"
$cfgDir = $baseDir
$cfgPath = Join-Path $cfgDir "opencode.json"
New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
Copy-Item -Path $cfgSource -Destination $cfgPath -Force

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

$proxyBypass = @(
  "127.0.0.1",
  "localhost",
  "::1",
  "10.90.79.111",
  "10.90.79.111:8000"
)

$mergedNoProxy = Merge-NoProxy `
  -Current ([Environment]::GetEnvironmentVariable("NO_PROXY", "User")) `
  -Entries $proxyBypass

$vars = @{
  OPENCODE_CONFIG                      = $cfgPath
  OPENCODE_DISABLE_PROJECT_CONFIG      = "1"
  OPENCODE_SAFE_MODE                   = "1"
  OPENCODE_ALLOWED_HOSTS               = "10.90.79.111:8000"
  OPENCODE_DISABLE_MODELS_FETCH        = "1"
  OPENCODE_DISABLE_DYNAMIC_INSTALLS    = "1"
  OPENCODE_DISABLE_REMOTE_INSTRUCTIONS = "1"
  OPENCODE_DISABLE_REMOTE_MCP          = "1"
  OPENCODE_DISABLE_AUTOUPDATE          = "1"
  OPENCODE_DISABLE_DEFAULT_PLUGINS     = "1"
  XDG_CONFIG_HOME                      = $xdgConfig
  XDG_DATA_HOME                        = $xdgData
  XDG_CACHE_HOME                       = $xdgCache
  XDG_STATE_HOME                       = $xdgState
  OPENCODE_TEST_HOME                   = $sandboxHome
  NO_PROXY                             = $mergedNoProxy
}

foreach ($item in $vars.GetEnumerator()) {
  [Environment]::SetEnvironmentVariable($item.Key, $item.Value, "User")
}

Broadcast-EnvironmentChange

Write-Host "Installation complete."
Write-Host "Config: $cfgPath"
Write-Host "You can start OpenCode normally from Start Menu."

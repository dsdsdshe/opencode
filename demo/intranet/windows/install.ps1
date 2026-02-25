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

$scriptRoot = Split-Path -Parent $PSCommandPath
$cfgSource = Join-Path $scriptRoot "opencode.json"

if (-not (Test-Path $cfgSource)) {
  throw "Missing config file: $cfgSource"
}

$installer = Resolve-Installer -GivenPath $InstallerPath
Write-Host "Running installer: $installer"
Start-Process -FilePath $installer -ArgumentList "/S" -Wait

$cfgDir = Join-Path $env:LOCALAPPDATA "opencode-demo"
$cfgPath = Join-Path $cfgDir "opencode.json"
New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
Copy-Item -Path $cfgSource -Destination $cfgPath -Force

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
}

foreach ($item in $vars.GetEnumerator()) {
  [Environment]::SetEnvironmentVariable($item.Key, $item.Value, "User")
}

Broadcast-EnvironmentChange

Write-Host "Installation complete."
Write-Host "Config: $cfgPath"
Write-Host "You can start OpenCode normally from Start Menu."

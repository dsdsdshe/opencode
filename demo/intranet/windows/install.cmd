@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%install.ps1"

if not exist "%PS_SCRIPT%" (
  echo Missing installer script: "%PS_SCRIPT%"
  pause
  exit /b 1
)

echo Starting OpenCode demo installer...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"
set "CODE=%ERRORLEVEL%"

if not "%CODE%"=="0" (
  echo.
  echo Installation failed. Exit code: %CODE%
  pause
  exit /b %CODE%
)

echo.
echo Installation finished.
pause

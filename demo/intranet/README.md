# Intranet Demo Installer

This package is for a simple demo deployment:

- Linux: CLI only
- Windows: desktop client and CLI (separate packages)
- Fixed model endpoint: `http://10.90.79.111:8000/v1`
- Fixed model: `MiniMaxAI/MiniMax-M2.5`
- Safe mode and outbound host allowlist enabled
- Installers prompt for the intranet API key once and persist it into the demo config
- Proxy bypass for `10.90.79.111` is configured automatically (no manual `no_proxy` required)
- Proxy usage is disabled by default (`OPENCODE_DISABLE_PROXY=1`) for direct-only intranet access
- Windows installer does not write persistent environment variables; policy is applied only in the app process

## Linux (CLI)

Package contents:

- `opencode-glibc` (Linux binary for glibc distributions)
- `opencode-musl` (Linux binary for musl distributions)
- `rg-glibc` (ripgrep sidecar for glibc path)
- `rg-musl` (ripgrep sidecar for musl path)
- `opencode.json`
- `install.sh`

Install:

```bash
bash install.sh
```

Non-interactive install:

```bash
OPENCODE_INTRANET_API_KEY=your-key bash install.sh
```

Run:

```bash
opencode
```

## Windows (Desktop Client)

Package contents:

- `OpenCode-Setup.exe` (NSIS installer)
- `opencode.json`
- `install.ps1`
- `install.cmd`

Install (double-click):

Double-click `install.cmd`.

Install (PowerShell, optional):

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Non-interactive install:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -ApiKey "your-key"
```

After install, launch OpenCode normally from Start Menu.

## Windows (CLI)

Package contents:

- `opencode.exe` (Windows CLI binary)
- `rg.exe` (ripgrep sidecar)
- `opencode.json`
- `install.ps1`
- `install.cmd`

Install (double-click):

Double-click `install.cmd`.

Install (PowerShell, optional):

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Non-interactive install:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -ApiKey "your-key"
```

After install, open a new terminal and run:

```powershell
opencode
```

## Reconfigure API key

Re-run the installer script for the package you installed. It will prompt again and overwrite the saved key in the demo `opencode.json`.

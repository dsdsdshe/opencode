# Using Python via uv

This environment uses uv as the standard way to manage and run Python. Do not invoke `python`, `python3`, `pip`, or `pip3` directly — use `uv` instead.

## Setting Up uv

Before first use, check if `uv` is available by running `uv --version`. If it is not installed, install and configure it as follows.

### Installing uv

This intranet environment mirrors `astral.sh/uv/` at `http://uv.tool.huawei.com`. Use the mirror URL instead of the official one.

**Linux / macOS:**

```bash
curl -LsSf http://uv.tool.huawei.com/install.sh | sh
```

**Windows (PowerShell):**

```powershell
powershell -ExecutionPolicy ByPass -c "irm http://uv.tool.huawei.com/install.ps1 | iex"
```

### Configuring uv for intranet

After installation, create the uv config file with intranet mirrors.

**Linux / macOS** — write to `~/.config/uv/uv.toml`:

```bash
mkdir -p ~/.config/uv
cat > ~/.config/uv/uv.toml << 'EOF'
python-install-mirror = "http://uv.tool.huawei.com/repository/python-build-standalone/releases/download"
index-url = "https://mirrors.tools.huawei.com/pypi/simple"
allow-insecure-host = ["mirrors.tools.huawei.com"]
EOF
uv python install 3.11
```

**Windows (PowerShell)** — write to `%APPDATA%\uv\uv.toml`:

```powershell
$uvDir = Join-Path $env:APPDATA "uv"
New-Item -ItemType Directory -Force -Path $uvDir | Out-Null
@"
python-install-mirror = "http://uv.tool.huawei.com/repository/python-build-standalone/releases/download"
index-url = "https://mirrors.tools.huawei.com/pypi/simple"
allow-insecure-host = ["mirrors.tools.huawei.com"]
"@ | Set-Content -Path (Join-Path $uvDir "uv.toml") -Encoding UTF8
uv python install 3.11
```

## Quick Reference

| Instead of | Use |
|---|---|
| `python script.py` | `uv run script.py` |
| `python3 script.py` | `uv run script.py` |
| `pip install package` | `uv pip install package` |
| `pip3 install package` | `uv pip install package` |
| `python -m module` | `uv run -m module` |
| `python -m venv .venv` | `uv venv` |
| `pip install -r requirements.txt` | `uv pip install -r requirements.txt` |
| `pipx run tool` | `uvx tool` |

## Running Scripts

```bash
uv run script.py
uv run --with requests --with pandas script.py
uv run -m pytest
```

## Installing Packages

```bash
uv pip install requests pandas
uv pip install -r requirements.txt
```

## Running CLI Tools

```bash
uvx ruff check .
uvx black .
```

## Project Management

```bash
uv init my-project
uv add requests pandas
uv sync
```

## Creating Virtual Environments

```bash
uv venv
uv venv myenv
```

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_BIN_GLIBC="$ROOT/opencode-glibc"
SOURCE_BIN_MUSL="$ROOT/opencode-musl"
SOURCE_BIN_LEGACY="$ROOT/opencode"
SOURCE_RG_GLIBC="$ROOT/rg-glibc"
SOURCE_RG_MUSL="$ROOT/rg-musl"
SOURCE_CONFIG="$ROOT/opencode.json"
API_KEY_PLACEHOLDER="__OPENCODE_INTRANET_API_KEY__"
API_KEY_INPUT="${OPENCODE_INTRANET_API_KEY:-}"

if [ "${1:-}" = "--api-key" ]; then
  if [ $# -lt 2 ]; then
    echo "Missing value for --api-key" >&2
    exit 1
  fi
  API_KEY_INPUT="${2:-}"
  shift 2
fi

if [ ! -f "$SOURCE_BIN_GLIBC" ] && [ ! -f "$SOURCE_BIN_MUSL" ] && [ ! -f "$SOURCE_BIN_LEGACY" ]; then
  echo "Missing Linux binary in package."
  echo "Expected one of:"
  echo "  - $SOURCE_BIN_GLIBC"
  echo "  - $SOURCE_BIN_MUSL"
  echo "  - $SOURCE_BIN_LEGACY"
  exit 1
fi

if [ ! -f "$SOURCE_CONFIG" ]; then
  echo "Missing config: $SOURCE_CONFIG"
  exit 1
fi

BIN_DIR="$HOME/.local/bin"
APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/opencode-demo"
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode-demo"
RUNTIME_DIR="$APP_DIR/runtime"
CFG_PATH="$CFG_DIR/opencode.json"

mkdir -p \
  "$BIN_DIR" \
  "$APP_DIR" \
  "$CFG_DIR" \
  "$RUNTIME_DIR/xdg-config" \
  "$RUNTIME_DIR/xdg-data" \
  "$RUNTIME_DIR/xdg-cache" \
  "$RUNTIME_DIR/xdg-state" \
  "$RUNTIME_DIR/home"

if [ -f "$SOURCE_BIN_GLIBC" ]; then
  install -m 755 "$SOURCE_BIN_GLIBC" "$APP_DIR/opencode-glibc"
fi
if [ -f "$SOURCE_BIN_MUSL" ]; then
  install -m 755 "$SOURCE_BIN_MUSL" "$APP_DIR/opencode-musl"
fi
if [ -f "$SOURCE_BIN_LEGACY" ] && [ ! -f "$SOURCE_BIN_GLIBC" ]; then
  install -m 755 "$SOURCE_BIN_LEGACY" "$APP_DIR/opencode-glibc"
fi
if [ -f "$SOURCE_RG_GLIBC" ]; then
  install -m 755 "$SOURCE_RG_GLIBC" "$APP_DIR/rg-glibc"
fi
if [ -f "$SOURCE_RG_MUSL" ]; then
  install -m 755 "$SOURCE_RG_MUSL" "$APP_DIR/rg-musl"
fi

prompt_api_key() {
  if [ -n "$API_KEY_INPUT" ]; then
    return
  fi

  if [ ! -t 0 ]; then
    echo "Missing API key. Re-run with OPENCODE_INTRANET_API_KEY=... or --api-key <key>."
    exit 1
  fi

  while [ -z "$API_KEY_INPUT" ]; do
    printf "Enter intranet API key: " >&2
    stty -echo
    IFS= read -r API_KEY_INPUT
    stty echo
    printf "\n" >&2
    if [ -z "$API_KEY_INPUT" ]; then
      echo "API key is required." >&2
    fi
  done
}

write_config() {
  if printf '%s' "$API_KEY_INPUT" | grep -q '[[:cntrl:]]'; then
    echo "API key cannot contain control characters." >&2
    exit 1
  fi

  local escaped="$API_KEY_INPUT"
  escaped=${escaped//\\/\\\\}
  escaped=${escaped//\"/\\\"}
  escaped=${escaped//&/\\&}
  escaped=${escaped//|/\\|}

  sed "s|$API_KEY_PLACEHOLDER|$escaped|g" "$SOURCE_CONFIG" >"$CFG_PATH"
  chmod 644 "$CFG_PATH"
}

prompt_api_key
write_config

cat >"$BIN_DIR/opencode" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CFG="${XDG_CONFIG_HOME:-$HOME/.config}/opencode-demo/opencode.json"
BIN_GLIBC="${XDG_DATA_HOME:-$HOME/.local/share}/opencode-demo/opencode-glibc"
BIN_MUSL="${XDG_DATA_HOME:-$HOME/.local/share}/opencode-demo/opencode-musl"
BIN_LEGACY="${XDG_DATA_HOME:-$HOME/.local/share}/opencode-demo/opencode-real"
RG_GLIBC="${XDG_DATA_HOME:-$HOME/.local/share}/opencode-demo/rg-glibc"
RG_MUSL="${XDG_DATA_HOME:-$HOME/.local/share}/opencode-demo/rg-musl"
RG_LINK="${XDG_DATA_HOME:-$HOME/.local/share}/opencode-demo/rg"
RUNTIME_BASE="${XDG_DATA_HOME:-$HOME/.local/share}/opencode-demo/runtime"

export OPENCODE_CONFIG="$CFG"
export OPENCODE_DISABLE_PROJECT_CONFIG=1
export OPENCODE_SAFE_MODE=1
export OPENCODE_ALLOWED_HOSTS=10.90.79.111:8000
export OPENCODE_DISABLE_MODELS_FETCH=1
export OPENCODE_DISABLE_DYNAMIC_INSTALLS=1
export OPENCODE_DISABLE_REMOTE_INSTRUCTIONS=1
export OPENCODE_DISABLE_REMOTE_MCP=1
export OPENCODE_DISABLE_AUTOUPDATE=1
export OPENCODE_DISABLE_DEFAULT_PLUGINS=1
export OPENCODE_DISABLE_PROXY=1
unset HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy
export NO_PROXY="${NO_PROXY:+$NO_PROXY,}127.0.0.1,localhost,::1,10.90.79.111,10.90.79.111:8000"
export no_proxy="${no_proxy:+$no_proxy,}127.0.0.1,localhost,::1,10.90.79.111,10.90.79.111:8000"

# Isolate OpenCode runtime state from user/global config to prevent accidental policy bypasses.
export XDG_CONFIG_HOME="$RUNTIME_BASE/xdg-config"
export XDG_DATA_HOME="$RUNTIME_BASE/xdg-data"
export XDG_CACHE_HOME="$RUNTIME_BASE/xdg-cache"
export XDG_STATE_HOME="$RUNTIME_BASE/xdg-state"
export OPENCODE_TEST_HOME="$RUNTIME_BASE/home"

pick_bin() {
  if [ -n "${OPENCODE_BIN:-}" ] && [ -x "${OPENCODE_BIN:-}" ]; then
    echo "$OPENCODE_BIN"
    return 0
  fi

  if [ -x "$BIN_GLIBC" ] && "$BIN_GLIBC" --version >/dev/null 2>&1; then
    echo "$BIN_GLIBC"
    return 0
  fi

  if [ -x "$BIN_MUSL" ] && "$BIN_MUSL" --version >/dev/null 2>&1; then
    echo "$BIN_MUSL"
    return 0
  fi

  if [ -x "$BIN_GLIBC" ]; then
    echo "$BIN_GLIBC"
    return 0
  fi

  if [ -x "$BIN_MUSL" ]; then
    echo "$BIN_MUSL"
    return 0
  fi

  if [ -x "$BIN_LEGACY" ]; then
    echo "$BIN_LEGACY"
    return 0
  fi

  return 1
}

BIN="$(pick_bin || true)"
if [ -z "$BIN" ]; then
  echo "No runnable OpenCode binary found."
  echo "Tried:"
  echo "  - $BIN_GLIBC"
  echo "  - $BIN_MUSL"
  echo "  - $BIN_LEGACY"
  exit 1
fi

pick_rg() {
  if [ "$BIN" = "$BIN_GLIBC" ] && [ -x "$RG_GLIBC" ]; then
    echo "$RG_GLIBC"
    return 0
  fi

  if [ "$BIN" = "$BIN_MUSL" ] && [ -x "$RG_MUSL" ]; then
    echo "$RG_MUSL"
    return 0
  fi

  if [ -x "$RG_GLIBC" ]; then
    echo "$RG_GLIBC"
    return 0
  fi

  if [ -x "$RG_MUSL" ]; then
    echo "$RG_MUSL"
    return 0
  fi

  return 1
}

RG="$(pick_rg || true)"
if [ -n "$RG" ]; then
  ln -sf "$RG" "$RG_LINK" 2>/dev/null || cp -f "$RG" "$RG_LINK"
  chmod 755 "$RG_LINK" || true
fi

exec "$BIN" "$@"
EOF

chmod 755 "$BIN_DIR/opencode"

echo "Installed OpenCode demo launcher to: $BIN_DIR/opencode"
echo "Config file: $CFG_PATH"
echo
echo "Run with: opencode"
echo "If 'opencode' is not found, add this to your shell profile:"
echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""

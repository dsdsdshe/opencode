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
HOST_PLACEHOLDER="__OPENCODE_INTRANET_HOST__"
API_KEY_INPUT="${OPENCODE_INTRANET_API_KEY:-}"
SERVER_HOST_INPUT="${OPENCODE_INTRANET_HOST:-}"

while [ $# -gt 0 ]; do
  case "${1:-}" in
    --api-key)
      if [ $# -lt 2 ]; then
        echo "Missing value for --api-key" >&2
        exit 1
      fi
      API_KEY_INPUT="${2:-}"
      shift 2
      ;;
    --server-host)
      if [ $# -lt 2 ]; then
        echo "Missing value for --server-host" >&2
        exit 1
      fi
      SERVER_HOST_INPUT="${2:-}"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

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

normalize_server_host() {
  local value="$1"
  value="${value#http://}"
  value="${value#https://}"
  value="${value%%/*}"
  value="${value%:4000}"
  printf '%s' "$value"
}

resolve_model_limit() {
  if [ "$1" = "10.90.79.111" ]; then
    printf '%s' "262144"
    return
  fi

  printf '%s' "196608"
}

prompt_server_host() {
  SERVER_HOST_INPUT="$(normalize_server_host "$SERVER_HOST_INPUT")"
  if [ -n "$SERVER_HOST_INPUT" ] && printf '%s' "$SERVER_HOST_INPUT" | grep -Eq '^[A-Za-z0-9.-]+$'; then
    return
  fi

  if [ -n "$SERVER_HOST_INPUT" ]; then
    echo "Server IP/hostname must contain only letters, digits, dots, or hyphens." >&2
    exit 1
  fi

  if [ ! -t 0 ]; then
    echo "Missing server IP. Re-run with OPENCODE_INTRANET_HOST=... or --server-host <host>." >&2
    exit 1
  fi

  while :; do
    printf "Enter intranet server IP or hostname: " >&2
    IFS= read -r SERVER_HOST_INPUT
    SERVER_HOST_INPUT="$(normalize_server_host "$SERVER_HOST_INPUT")"
    if printf '%s' "$SERVER_HOST_INPUT" | grep -Eq '^[A-Za-z0-9.-]+$'; then
      return
    fi
    echo "Server IP/hostname must contain only letters, digits, dots, or hyphens." >&2
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
  local host="$SERVER_HOST_INPUT"
  host=${host//\\/\\\\}
  host=${host//&/\\&}
  host=${host//|/\\|}
  local limit
  limit="$(resolve_model_limit "$SERVER_HOST_INPUT")"

  sed \
    -e "s|$API_KEY_PLACEHOLDER|$escaped|g" \
    -e "s|$HOST_PLACEHOLDER|$host|g" \
    -e "s|\"context\": 196608|\"context\": $limit|g" \
    -e "s|\"output\": 196608|\"output\": $limit|g" \
    "$SOURCE_CONFIG" >"$CFG_PATH"
  chmod 644 "$CFG_PATH"
}

write_launcher() {
  cat >"$BIN_DIR/opencode" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode-demo"
CFG="$CFG_DIR/opencode.json"
BIN_GLIBC="${XDG_DATA_HOME:-$HOME/.local/share}/opencode-demo/opencode-glibc"
BIN_MUSL="${XDG_DATA_HOME:-$HOME/.local/share}/opencode-demo/opencode-musl"
BIN_LEGACY="${XDG_DATA_HOME:-$HOME/.local/share}/opencode-demo/opencode-real"
RG_GLIBC="${XDG_DATA_HOME:-$HOME/.local/share}/opencode-demo/rg-glibc"
RG_MUSL="${XDG_DATA_HOME:-$HOME/.local/share}/opencode-demo/rg-musl"
RG_LINK="${XDG_DATA_HOME:-$HOME/.local/share}/opencode-demo/rg"
RUNTIME_BASE="${XDG_DATA_HOME:-$HOME/.local/share}/opencode-demo/runtime"

export OPENCODE_CONFIG="$CFG"
export OPENCODE_CONFIG_DIR="$CFG_DIR"
export OPENCODE_DISABLE_PROJECT_CONFIG=1
export OPENCODE_SAFE_MODE=1
export OPENCODE_ALLOWED_HOSTS=__OPENCODE_INTRANET_HOST__:4000
export OPENCODE_DISABLE_MODELS_FETCH=1
export OPENCODE_DISABLE_DYNAMIC_INSTALLS=1
export OPENCODE_DISABLE_REMOTE_INSTRUCTIONS=1
export OPENCODE_DISABLE_REMOTE_MCP=1
export OPENCODE_DISABLE_AUTOUPDATE=1
export OPENCODE_DISABLE_DEFAULT_PLUGINS=1
export OPENCODE_DISABLE_PROXY=1
unset HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy

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

  local host="$SERVER_HOST_INPUT"
  host=${host//\\/\\\\}
  host=${host//&/\\&}
  host=${host//|/\\|}
  local tmp
  tmp="$(mktemp)"
  sed "s|$HOST_PLACEHOLDER|$host|g" "$BIN_DIR/opencode" >"$tmp"
  mv "$tmp" "$BIN_DIR/opencode"
}

copy_instructions() {
  local src="$ROOT/uv-python.md"
  if [ -f "$src" ]; then
    install -m 644 "$src" "$CFG_DIR/uv-python.md"
  fi
}

prompt_server_host
prompt_api_key
write_config
copy_instructions
write_launcher
chmod 755 "$BIN_DIR/opencode"

echo "Installed OpenCode demo launcher to: $BIN_DIR/opencode"
echo "Config file: $CFG_PATH"
echo
echo "Run with: opencode"
echo "If 'opencode' is not found, add this to your shell profile:"
echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""

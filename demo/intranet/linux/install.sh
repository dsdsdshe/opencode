#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_BIN="$ROOT/opencode"
SOURCE_CONFIG="$ROOT/opencode.json"

if [ ! -f "$SOURCE_BIN" ]; then
  echo "Missing binary: $SOURCE_BIN"
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

mkdir -p \
  "$BIN_DIR" \
  "$APP_DIR" \
  "$CFG_DIR" \
  "$RUNTIME_DIR/xdg-config" \
  "$RUNTIME_DIR/xdg-data" \
  "$RUNTIME_DIR/xdg-cache" \
  "$RUNTIME_DIR/xdg-state" \
  "$RUNTIME_DIR/home"

install -m 755 "$SOURCE_BIN" "$APP_DIR/opencode-real"
install -m 644 "$SOURCE_CONFIG" "$CFG_DIR/opencode.json"

cat >"$BIN_DIR/opencode" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CFG="${XDG_CONFIG_HOME:-$HOME/.config}/opencode-demo/opencode.json"
BIN="${XDG_DATA_HOME:-$HOME/.local/share}/opencode-demo/opencode-real"
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

# Isolate OpenCode runtime state from user/global config to prevent accidental policy bypasses.
export XDG_CONFIG_HOME="$RUNTIME_BASE/xdg-config"
export XDG_DATA_HOME="$RUNTIME_BASE/xdg-data"
export XDG_CACHE_HOME="$RUNTIME_BASE/xdg-cache"
export XDG_STATE_HOME="$RUNTIME_BASE/xdg-state"
export OPENCODE_TEST_HOME="$RUNTIME_BASE/home"

exec "$BIN" "$@"
EOF

chmod 755 "$BIN_DIR/opencode"

echo "Installed OpenCode demo launcher to: $BIN_DIR/opencode"
echo "Config file: $CFG_DIR/opencode.json"
echo
echo "Run with: opencode"
echo "If 'opencode' is not found, add this to your shell profile:"
echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""

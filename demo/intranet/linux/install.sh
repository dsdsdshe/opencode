#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_BIN_GLIBC="$ROOT/opencode-glibc"
SOURCE_BIN_MUSL="$ROOT/opencode-musl"
SOURCE_BIN_LEGACY="$ROOT/opencode"
SOURCE_CONFIG="$ROOT/opencode.json"

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
install -m 644 "$SOURCE_CONFIG" "$CFG_DIR/opencode.json"

cat >"$BIN_DIR/opencode" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

CFG="${XDG_CONFIG_HOME:-$HOME/.config}/opencode-demo/opencode.json"
BIN_GLIBC="${XDG_DATA_HOME:-$HOME/.local/share}/opencode-demo/opencode-glibc"
BIN_MUSL="${XDG_DATA_HOME:-$HOME/.local/share}/opencode-demo/opencode-musl"
BIN_LEGACY="${XDG_DATA_HOME:-$HOME/.local/share}/opencode-demo/opencode-real"
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

exec "$BIN" "$@"
EOF

chmod 755 "$BIN_DIR/opencode"

echo "Installed OpenCode demo launcher to: $BIN_DIR/opencode"
echo "Config file: $CFG_DIR/opencode.json"
echo
echo "Run with: opencode"
echo "If 'opencode' is not found, add this to your shell profile:"
echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""

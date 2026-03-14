#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LABEL="${OPENCLAW_GATEWAY_SRC_LABEL:-ai.openclaw.gateway-src}"
PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
UID_NUM="$(id -u)"
TARGET="gui/$UID_NUM/$LABEL"
OFFICIAL_LABEL="${OPENCLAW_GATEWAY_OFFICIAL_LABEL:-ai.openclaw.gateway}"
OFFICIAL_TARGET="gui/$UID_NUM/$OFFICIAL_LABEL"
PLIST="${OPENCLAW_GATEWAY_SRC_PLIST:-$HOME/Library/LaunchAgents/${LABEL}.plist}"
LOG_OUT="${OPENCLAW_GATEWAY_SRC_LOG_OUT:-/tmp/openclaw-gateway-src.log}"
LOG_ERR="${OPENCLAW_GATEWAY_SRC_LOG_ERR:-/tmp/openclaw-gateway-src.err.log}"
DIST_ENTRY="${OPENCLAW_GATEWAY_SRC_ENTRY:-$ROOT/dist/index.js}"

resolve_preferred_node_bin() {
  local current_node nvm_default_alias nvm_default_node
  current_node="$(command -v node || true)"
  if [[ -f "$HOME/.nvm/alias/default" ]]; then
    nvm_default_alias="$(tr -d '[:space:]' < "$HOME/.nvm/alias/default")"
    if [[ -n "$nvm_default_alias" ]]; then
      nvm_default_node="$HOME/.nvm/versions/node/${nvm_default_alias}/bin/node"
      if [[ -x "$nvm_default_node" ]]; then
        case "$current_node" in
          ""|/opt/homebrew/bin/node|/usr/local/bin/node|/usr/bin/node)
            printf '%s\n' "$nvm_default_node"
            return 0
            ;;
        esac
      fi
    fi
  fi
  printf '%s\n' "$current_node"
}

NODE_BIN="${OPENCLAW_GATEWAY_NODE_BIN:-$(resolve_preferred_node_bin)}"
DEFAULT_PATH="$HOME/Library/pnpm:$HOME/.local/bin:$HOME/.cargo/bin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
if [[ -n "$NODE_BIN" ]]; then
  NODE_BIN_DIR="$(dirname "$NODE_BIN")"
  case ":$DEFAULT_PATH:" in
    *":$NODE_BIN_DIR:"*) ;;
    *) DEFAULT_PATH="$NODE_BIN_DIR:$DEFAULT_PATH" ;;
  esac
fi
PATH_VALUE="${OPENCLAW_GATEWAY_PATH:-$DEFAULT_PATH}"
ALL_PROXY_VALUE="${OPENCLAW_GATEWAY_ALL_PROXY:-${ALL_PROXY:-}}"
HTTP_PROXY_VALUE="${OPENCLAW_GATEWAY_HTTP_PROXY:-${HTTP_PROXY:-${http_proxy:-}}}"
HTTPS_PROXY_VALUE="${OPENCLAW_GATEWAY_HTTPS_PROXY:-${HTTPS_PROXY:-${https_proxy:-}}}"
NO_PROXY_VALUE="${OPENCLAW_GATEWAY_NO_PROXY:-${NO_PROXY:-${no_proxy:-}}}"

find_lsof_bin() {
  local lsof_bin
  lsof_bin="$(command -v lsof || true)"
  if [[ -z "$lsof_bin" && -x /usr/sbin/lsof ]]; then
    lsof_bin="/usr/sbin/lsof"
  fi
  printf '%s\n' "$lsof_bin"
}

extract_launchctl_value() {
  local key="$1"
  local text="$2"
  printf '%s\n' "$text" | sed -nE "s/^[[:space:]]*${key} = (.+)$/\\1/p" | head -n 1
}

launchctl_dump() {
  local target="$1"
  launchctl print "$target" 2>/dev/null || true
}

pid_cwd() {
  local pid="$1"
  local lsof_bin="$2"
  if [[ -z "$pid" || -z "$lsof_bin" ]]; then
    return 0
  fi
  "$lsof_bin" -a -p "$pid" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p' | head -n 1 || true
}

port_pid() {
  local port="$1"
  local lsof_bin="$2"
  if [[ -z "$lsof_bin" ]]; then
    return 0
  fi
  "$lsof_bin" -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null | head -n 1 || true
}

xml_escape() {
  printf '%s' "$1" \
    | sed \
        -e 's/&/\&amp;/g' \
        -e 's/</\&lt;/g' \
        -e 's/>/\&gt;/g' \
        -e 's/"/\&quot;/g' \
        -e "s/'/\&apos;/g"
}

require_dist_entry() {
  if [[ ! -f "$DIST_ENTRY" ]]; then
    echo "missing build output: $DIST_ENTRY" >&2
    echo "run: pnpm build" >&2
    return 1
  fi
}

#!/usr/bin/env bash
set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/gw-common.sh"

"$SCRIPT_DIR/gw-ha-install.sh" >/dev/null

LSOF_BIN="$(find_lsof_bin)"
OWNER_PID="$(port_pid "$PORT" "$LSOF_BIN")"
OWNER_CWD=""
SERVICE_DUMP=""
SERVICE_PID=""
OFFICIAL_DUMP=""
READY_TIMEOUT_SEC="${OPENCLAW_GATEWAY_READY_TIMEOUT_SEC:-30}"
MAX_ATTEMPTS=$((READY_TIMEOUT_SEC * 2))

if [[ "$LABEL" != "$OFFICIAL_LABEL" ]]; then
  OFFICIAL_DUMP="$(launchctl_dump "$OFFICIAL_TARGET")"
  if [[ -n "$OFFICIAL_DUMP" ]]; then
    echo "competing launchd service is loaded ($OFFICIAL_LABEL)" >&2
    echo "stop it first: openclaw gateway stop" >&2
    echo "or: launchctl bootout $OFFICIAL_TARGET" >&2
    exit 1
  fi
fi

if service_dump="$(launchctl_dump "$TARGET")" && [[ -n "$service_dump" ]]; then
  SERVICE_DUMP="$service_dump"
  SERVICE_PID="$(extract_launchctl_value "pid" "$SERVICE_DUMP")"
fi

if [[ -n "$OWNER_PID" ]]; then
  OWNER_CWD="$(pid_cwd "$OWNER_PID" "$LSOF_BIN")"
  if [[ -n "$OWNER_CWD" && "$OWNER_CWD" != "$ROOT" ]]; then
    echo "port $PORT is already owned by pid $OWNER_PID from a different working tree" >&2
    echo "stop the other gateway first or set OPENCLAW_GATEWAY_PORT to a different port" >&2
    exit 1
  fi

  if [[ -n "$OWNER_CWD" && "$OWNER_CWD" == "$ROOT" && "$OWNER_PID" != "$SERVICE_PID" ]]; then
    echo "stopping stale gateway pid $OWNER_PID from this working tree"
    kill "$OWNER_PID" 2>/dev/null || true
    sleep 1
  fi
fi

launchctl bootout "gui/$UID_NUM" "$PLIST" 2>/dev/null || launchctl bootout "$TARGET" 2>/dev/null || true
launchctl enable "$TARGET" 2>/dev/null || true
launchctl bootstrap "gui/$UID_NUM" "$PLIST"
launchctl kickstart -k "$TARGET"

for ((attempt = 1; attempt <= MAX_ATTEMPTS; attempt++)); do
  if "$SCRIPT_DIR/gw-status.sh" >/dev/null 2>&1; then
    echo "gateway HA service started ($LABEL)"
    "$SCRIPT_DIR/gw-status.sh"
    exit 0
  fi
  sleep 0.5
done

echo "gateway HA service failed to become ready ($LABEL)" >&2
"$SCRIPT_DIR/gw-status.sh" || true
exit 1

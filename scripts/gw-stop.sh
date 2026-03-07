#!/usr/bin/env bash
set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/gw-common.sh"

launchctl bootout "gui/$UID_NUM" "$PLIST" 2>/dev/null || launchctl bootout "$TARGET" 2>/dev/null || true
launchctl disable "$TARGET" 2>/dev/null || true

LSOF_BIN="$(find_lsof_bin)"
OWNER_PID="$(port_pid "$PORT" "$LSOF_BIN")"
OWNER_CWD=""

if [[ -n "$OWNER_PID" ]]; then
  OWNER_CWD="$(pid_cwd "$OWNER_PID" "$LSOF_BIN")"
fi

if [[ -n "$OWNER_PID" && "$OWNER_CWD" == "$ROOT" ]]; then
  echo "stopping local gateway pid $OWNER_PID from this working tree"
  kill "$OWNER_PID" 2>/dev/null || true

  for _ in {1..10}; do
    sleep 0.2
    if [[ "$(port_pid "$PORT" "$LSOF_BIN")" != "$OWNER_PID" ]]; then
      break
    fi
  done

  if [[ "$(port_pid "$PORT" "$LSOF_BIN")" == "$OWNER_PID" ]]; then
    echo "force killing stuck gateway pid $OWNER_PID"
    kill -9 "$OWNER_PID" 2>/dev/null || true
  fi
fi

rm -f "$ROOT/.gateway.pid"

echo "gateway stopped ($LABEL)"

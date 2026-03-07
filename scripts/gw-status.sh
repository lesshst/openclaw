#!/usr/bin/env bash
set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/gw-common.sh"

service_dump=""
service_state=""
service_pid=""
service_last_exit=""
service_cwd=""
official_dump=""
official_pid=""
owner_pid=""
owner_cwd=""
ownership_ok=0
probe_ok=0

if service_dump="$(launchctl_dump "$TARGET")" && [[ -n "$service_dump" ]]; then
  echo "service: loaded ($LABEL)"
  service_state="$(extract_launchctl_value "state" "$service_dump")"
  service_pid="$(extract_launchctl_value "pid" "$service_dump")"
  service_last_exit="$(extract_launchctl_value "last exit code" "$service_dump")"
  if [[ -n "$service_state" ]]; then
    echo "service state: $service_state"
  fi
else
  echo "service: not loaded ($LABEL)"
fi

if [[ "$LABEL" != "$OFFICIAL_LABEL" ]]; then
  official_dump="$(launchctl_dump "$OFFICIAL_TARGET")"
  if [[ -n "$official_dump" ]]; then
    official_pid="$(extract_launchctl_value "pid" "$official_dump")"
    echo "competing service: loaded ($OFFICIAL_LABEL)"
    if [[ -n "$official_pid" ]]; then
      echo "competing pid: $official_pid"
    fi
  fi
fi

LSOF_BIN="$(find_lsof_bin)"

if [[ -n "$service_pid" ]]; then
  echo "service pid: $service_pid"
  service_cwd="$(pid_cwd "$service_pid" "$LSOF_BIN")"
  if [[ -n "$service_cwd" ]]; then
    echo "service cwd: $service_cwd"
  fi
else
  echo "service pid: not running"
  if [[ -n "$service_last_exit" ]]; then
    echo "last exit code: $service_last_exit"
  fi
fi

if [[ -n "$LSOF_BIN" ]]; then
  owner_pid="$(port_pid "$PORT" "$LSOF_BIN")"
  if [[ -n "$owner_pid" ]]; then
    echo "port $PORT: listening (pid $owner_pid)"
    owner_cwd="$(pid_cwd "$owner_pid" "$LSOF_BIN")"
    if [[ -n "$owner_cwd" ]]; then
      echo "port owner cwd: $owner_cwd"
    fi
    "$LSOF_BIN" -nP -iTCP:"$PORT" -sTCP:LISTEN | sed -n '1,3p'
  else
    echo "port $PORT: not listening"
  fi
else
  echo "port $PORT: status unavailable (lsof not found)"
fi

if [[ -n "$service_pid" && -n "$owner_pid" && "$service_pid" == "$owner_pid" ]]; then
  ownership_ok=1
  echo "ownership: ok ($LABEL owns port $PORT)"
elif [[ -n "$owner_pid" ]]; then
  echo "ownership: mismatch ($LABEL pid ${service_pid:-none}, port pid $owner_pid)"
elif [[ -n "$service_pid" ]]; then
  echo "ownership: mismatch ($LABEL pid $service_pid, port $PORT is idle)"
else
  echo "ownership: inactive ($LABEL is not running and port $PORT is idle)"
fi

if [[ -n "$owner_cwd" && "$owner_cwd" != "$ROOT" ]]; then
  echo "ownership detail: port $PORT belongs to a different working tree"
fi

if [[ -n "$official_dump" && "$ownership_ok" -ne 1 ]]; then
  echo "competing detail: stop $OFFICIAL_LABEL before starting $LABEL"
fi

echo "health probe:"
if [[ "$ownership_ok" -eq 1 ]]; then
  if probe_body="$(curl -fsS --max-time 2 "http://127.0.0.1:$PORT/" 2>/dev/null)"; then
    printf '%s\n' "$probe_body" | head -c 120
    echo
    probe_ok=1
  else
    echo "gateway http probe failed"
  fi
else
  echo "skipped: port $PORT is not owned by $LABEL"
fi

echo
echo "logs: $LOG_OUT $LOG_ERR"

if [[ "$ownership_ok" -eq 1 && "$probe_ok" -eq 1 ]]; then
  exit 0
fi

exit 1

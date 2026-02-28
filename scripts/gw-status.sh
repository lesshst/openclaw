#!/usr/bin/env bash
set -euo pipefail
LABEL="ai.openclaw.gateway-src"
UID_NUM="$(id -u)"

if launchctl print "gui/$UID_NUM/$LABEL" >/dev/null 2>&1; then
  echo "service: loaded ($LABEL)"
else
  echo "service: not loaded ($LABEL)"
fi

LSOF_BIN="$(command -v lsof || true)"
if [[ -z "$LSOF_BIN" && -x /usr/sbin/lsof ]]; then
  LSOF_BIN="/usr/sbin/lsof"
fi

if [[ -n "$LSOF_BIN" ]] && "$LSOF_BIN" -nP -iTCP:18789 -sTCP:LISTEN >/dev/null 2>&1; then
  echo "port 18789: listening"
  "$LSOF_BIN" -nP -iTCP:18789 -sTCP:LISTEN | sed -n '1,2p'
else
  echo "port 18789: not listening (or lsof unavailable)"
fi

echo "health probe:"
curl -sS --max-time 2 http://127.0.0.1:18789/ | head -c 120 || echo "gateway http probe failed"

echo
echo "logs: /tmp/openclaw-gateway-src.log /tmp/openclaw-gateway-src.err.log"

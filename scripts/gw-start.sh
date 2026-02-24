#!/usr/bin/env bash
set -euo pipefail
ROOT="/Users/lizhibo/.openclaw/workspace/tmp-openclaw-src"
PIDFILE="$ROOT/.gateway.pid"
LOGFILE="/tmp/openclaw-gateway-src.log"

if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "gateway already running: pid $(cat "$PIDFILE")"
  exit 0
fi

cd "$ROOT"
nohup env -u ALL_PROXY HTTP_PROXY=http://127.0.0.1:7897 HTTPS_PROXY=http://127.0.0.1:7897 \
  node dist/index.js gateway --port 18789 >"$LOGFILE" 2>&1 &
echo $! > "$PIDFILE"
echo "gateway started: pid $(cat "$PIDFILE"), log $LOGFILE"

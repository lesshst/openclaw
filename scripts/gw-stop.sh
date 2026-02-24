#!/usr/bin/env bash
set -euo pipefail
ROOT="/Users/lizhibo/.openclaw/workspace/tmp-openclaw-src"
PIDFILE="$ROOT/.gateway.pid"

if [[ -f "$PIDFILE" ]]; then
  PID="$(cat "$PIDFILE")"
  kill "$PID" 2>/dev/null || true
  rm -f "$PIDFILE"
fi

pkill -f "node dist/index.js gateway --port 18789" || true
echo "gateway stopped"

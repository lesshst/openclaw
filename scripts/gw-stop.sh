#!/usr/bin/env bash
set -euo pipefail

LABEL="ai.openclaw.gateway-src"
UID_NUM="$(id -u)"
launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || true
launchctl disable "gui/$UID_NUM/$LABEL" 2>/dev/null || true

# best-effort cleanup for old nohup mode
pkill -f "node dist/index.js gateway --port 18789" 2>/dev/null || true
rm -f "/Users/lizhibo/.openclaw/workspace/tmp-openclaw-src/.gateway.pid"

echo "gateway stopped ($LABEL)"

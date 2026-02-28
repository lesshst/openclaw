#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/lizhibo/.openclaw/workspace/tmp-openclaw-src"
SCRIPTS="$ROOT/scripts"
PLIST="$HOME/Library/LaunchAgents/ai.openclaw.gateway-src.plist"
LABEL="ai.openclaw.gateway-src"

"$SCRIPTS/gw-ha-install.sh" >/dev/null

launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null || true
launchctl enable "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl kickstart -k "gui/$(id -u)/$LABEL"

echo "gateway HA service started ($LABEL)"
"$SCRIPTS/gw-status.sh"

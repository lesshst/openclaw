#!/usr/bin/env bash
set -euo pipefail
LABEL="ai.openclaw.gateway-src"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
UID_NUM="$(id -u)"

launchctl bootout "gui/$UID_NUM/$LABEL" 2>/dev/null || true
launchctl disable "gui/$UID_NUM/$LABEL" 2>/dev/null || true
rm -f "$PLIST"
echo "uninstalled $LABEL"

#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/gw-common.sh"

launchctl bootout "gui/$UID_NUM" "$PLIST" 2>/dev/null || launchctl bootout "$TARGET" 2>/dev/null || true
launchctl disable "$TARGET" 2>/dev/null || true
rm -f "$PLIST"
echo "uninstalled $LABEL"

#!/usr/bin/env bash
set -euo pipefail
DIR="/Users/lizhibo/.openclaw/workspace/tmp-openclaw-src/scripts"
"$DIR/gw-stop.sh"
sleep 1
"$DIR/gw-start.sh"
"$DIR/gw-status.sh"

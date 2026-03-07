#!/usr/bin/env bash
set -euo pipefail
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/gw-common.sh"

if [[ "$LABEL" != "$OFFICIAL_LABEL" ]] && [[ -n "$(launchctl_dump "$OFFICIAL_TARGET")" ]]; then
  echo "competing launchd service is loaded ($OFFICIAL_LABEL)" >&2
  echo "stop it first: openclaw gateway stop" >&2
  echo "or: launchctl bootout $OFFICIAL_TARGET" >&2
  exit 1
fi

"$SCRIPT_DIR/gw-stop.sh"
sleep 1
"$SCRIPT_DIR/gw-start.sh"

#!/usr/bin/env bash
set -euo pipefail

. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/gw-common.sh"

require_dist_entry

if [[ -z "$NODE_BIN" ]]; then
  echo "node not found in PATH" >&2
  echo "set OPENCLAW_GATEWAY_NODE_BIN or install Node before using gw-ha-install.sh" >&2
  exit 1
fi

ROOT_XML="$(xml_escape "$ROOT")"
LABEL_XML="$(xml_escape "$LABEL")"
PATH_XML="$(xml_escape "$PATH_VALUE")"
HOME_XML="$(xml_escape "$HOME")"
ALL_PROXY_XML="$(xml_escape "$ALL_PROXY_VALUE")"
HTTP_PROXY_XML="$(xml_escape "$HTTP_PROXY_VALUE")"
HTTPS_PROXY_XML="$(xml_escape "$HTTPS_PROXY_VALUE")"
NO_PROXY_XML="$(xml_escape "$NO_PROXY_VALUE")"
NODE_XML="$(xml_escape "$NODE_BIN")"
DIST_ENTRY_XML="$(xml_escape "$DIST_ENTRY")"
PORT_XML="$(xml_escape "$PORT")"
LOG_OUT_XML="$(xml_escape "$LOG_OUT")"
LOG_ERR_XML="$(xml_escape "$LOG_ERR")"

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL_XML</string>

  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/env</string>
    <string>-i</string>
    <string>PATH=$PATH_XML</string>
    <string>HOME=$HOME_XML</string>
    <string>ALL_PROXY=$ALL_PROXY_XML</string>
    <string>HTTP_PROXY=$HTTP_PROXY_XML</string>
    <string>HTTPS_PROXY=$HTTPS_PROXY_XML</string>
    <string>NO_PROXY=$NO_PROXY_XML</string>
    <string>$NODE_XML</string>
    <string>$DIST_ENTRY_XML</string>
    <string>gateway</string>
    <string>--bind</string>
    <string>loopback</string>
    <string>--port</string>
    <string>$PORT_XML</string>
  </array>

  <key>WorkingDirectory</key>
  <string>$ROOT_XML</string>

  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>ThrottleInterval</key>
  <integer>5</integer>

  <key>StandardOutPath</key>
  <string>$LOG_OUT_XML</string>
  <key>StandardErrorPath</key>
  <string>$LOG_ERR_XML</string>
</dict>
</plist>
EOF

echo "installed launchd plist: $PLIST"

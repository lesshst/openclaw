#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/lizhibo/.openclaw/workspace/tmp-openclaw-src"
PLIST="$HOME/Library/LaunchAgents/ai.openclaw.gateway-src.plist"
LOG_OUT="/tmp/openclaw-gateway-src.log"
LOG_ERR="/tmp/openclaw-gateway-src.err.log"

mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>ai.openclaw.gateway-src</string>

  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/env</string>
    <string>-i</string>
    <string>PATH=/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin</string>
    <string>HOME=$HOME</string>
    <string>ALL_PROXY=</string>
    <string>HTTP_PROXY=http://127.0.0.1:7897</string>
    <string>HTTPS_PROXY=http://127.0.0.1:7897</string>
    <string>/usr/local/bin/node</string>
    <string>dist/index.js</string>
    <string>gateway</string>
    <string>--port</string>
    <string>18789</string>
  </array>

  <key>WorkingDirectory</key>
  <string>$ROOT</string>

  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>ThrottleInterval</key>
  <integer>5</integer>

  <key>StandardOutPath</key>
  <string>$LOG_OUT</string>
  <key>StandardErrorPath</key>
  <string>$LOG_ERR</string>
</dict>
</plist>
EOF

# Prefer Homebrew node path if available
if command -v node >/dev/null 2>&1; then
  NODE_PATH="$(command -v node)"
  /usr/bin/sed -i '' "s#<string>/usr/local/bin/node</string>#<string>${NODE_PATH//\//\\/}</string>#" "$PLIST"
fi

echo "installed launchd plist: $PLIST"

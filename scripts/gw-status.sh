#!/usr/bin/env bash
set -euo pipefail
lsof -nP -iTCP:18789 -sTCP:LISTEN || echo "not listening on 18789"

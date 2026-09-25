#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
APP="$ROOT/build/Pretype.app"
PATTERN="$APP/Contents/MacOS/Pretype"

if [[ "${1:-}" == "--test" || "${1:-}" == "-t" ]]; then
  swift test -q
fi

pkill -f "$PATTERN$" 2>/dev/null || true
SIGNING_MODE=${SIGNING_MODE:-} "$ROOT/Scripts/package_app.sh" release
open "$APP"

for _ in {1..10}; do
  if pgrep -f "$PATTERN$" >/dev/null 2>&1; then
    echo "Pretype is running."
    exit 0
  fi
  sleep 0.4
done
echo "ERROR: Pretype exited immediately; check Console.app crash reports." >&2
exit 1

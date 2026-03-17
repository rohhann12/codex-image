#!/bin/zsh
set -euo pipefail

AGENT_ID="com.codex.pastepath"
PLIST_PATH="$HOME/Library/LaunchAgents/$AGENT_ID.plist"

launchctl bootout "gui/$(id -u)/$AGENT_ID" >/dev/null 2>&1 || true
osascript -e 'tell application "PastePath" to quit' >/dev/null 2>&1 || true
rm -f "$PLIST_PATH"

echo "Removed LaunchAgent: $PLIST_PATH"

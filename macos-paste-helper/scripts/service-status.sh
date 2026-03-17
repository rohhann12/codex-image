#!/bin/zsh
set -euo pipefail

AGENT_ID="com.codex.pastepath"

echo "LaunchAgent plist:"
ls -l "$HOME/Library/LaunchAgents/$AGENT_ID.plist" 2>/dev/null || echo "not installed"
echo
echo "launchctl print:"
launchctl print "gui/$(id -u)/$AGENT_ID" 2>/dev/null || echo "service not loaded"

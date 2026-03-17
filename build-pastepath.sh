#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$ROOT_DIR/macos-paste-helper"
MODE="${1:-}"
APP_BUNDLE="$APP_DIR/dist/PastePath.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/macos-paste-helper"
LOG_PATH="$HOME/Library/Logs/PastePath.log"

if [[ ! -d "$APP_DIR" ]]; then
  echo "macos-paste-helper directory not found."
  exit 1
fi

cd "$APP_DIR"
./scripts/build-release.sh

echo
echo "PastePath built successfully."
echo "App: $APP_BUNDLE"
echo "Zip: $APP_DIR/dist/PastePath.zip"
echo "Log: $LOG_PATH"

if [[ "$MODE" == "--install-service" ]]; then
  echo
  ./scripts/install-launch-agent.sh
  exit 0
fi

if [[ "$MODE" == "--uninstall-service" ]]; then
  echo
  ./scripts/uninstall-launch-agent.sh
  exit 0
fi

if [[ "$MODE" == "--service-status" ]]; then
  echo
  ./scripts/service-status.sh
  exit 0
fi

if [[ "$MODE" == "--run" ]]; then
  if [[ ! -x "$APP_BINARY" ]]; then
    echo "Built app binary not found: $APP_BINARY"
    exit 1
  fi

  echo
  echo "Running PastePath in the foreground."
  echo "Logs will stream in this terminal and also be written to $LOG_PATH"
  echo "Press Ctrl+C to stop the app."
  echo

  exec "$APP_BINARY"
fi

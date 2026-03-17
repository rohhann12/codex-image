#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/dist/PastePath.app"
ICON_FILE="$ROOT_DIR/assets/PastePath.icns"

cd "$ROOT_DIR"
./scripts/generate-icns.sh
swift build -c release

BUILD_BIN="$(find "$ROOT_DIR/.build" -path '*/release/macos-paste-helper' -type f | head -n 1)"
if [[ -z "$BUILD_BIN" ]]; then
  echo "Could not locate release binary"
  exit 1
fi

mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>macos-paste-helper</string>
  <key>CFBundleIdentifier</key>
  <string>com.codex.pastepath</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleIconFile</key>
  <string>PastePath.icns</string>
  <key>CFBundleName</key>
  <string>PastePath</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>PastePath uses Apple Events to detect the active terminal session.</string>
</dict>
</plist>
PLIST

cp "$BUILD_BIN" "$APP_DIR/Contents/MacOS/macos-paste-helper"
cp "$ICON_FILE" "$APP_DIR/Contents/Resources/PastePath.icns"
chmod +x "$APP_DIR/Contents/MacOS/macos-paste-helper"

echo "Built app: $APP_DIR"

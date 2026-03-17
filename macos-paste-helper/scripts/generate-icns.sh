#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$ROOT_DIR/.tmp/icon"
ICONSET_DIR="$TMP_DIR/PastePath.iconset"
BASE_PNG="$TMP_DIR/PastePath-1024.png"
OUTPUT_ICNS="$ROOT_DIR/assets/PastePath.icns"

rm -rf "$TMP_DIR"
mkdir -p "$ICONSET_DIR"
mkdir -p "$ROOT_DIR/assets"

swift "$ROOT_DIR/scripts/generate-icon.swift" "$BASE_PNG"

for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$BASE_PNG" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
done

for size in 32 64 256 512 1024; do
  base_size=$((size / 2))
  sips -z "$size" "$size" "$BASE_PNG" --out "$ICONSET_DIR/icon_${base_size}x${base_size}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"
echo "Generated icns at $OUTPUT_ICNS"

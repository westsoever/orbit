#!/usr/bin/env bash
# Regenerate macOS AppIcon PNGs from Resources/orbit-icon.svg
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SVG="$ROOT/OrbitAccessApp/Resources/orbit-icon.svg"
GEN="$ROOT/OrbitAccessApp/Resources/AppIcon-gen"
DEST="$ROOT/OrbitAccessApp/Resources/Assets.xcassets/AppIcon.appiconset"

mkdir -p "$GEN"
qlmanage -t -s 1024 -o "$GEN" "$SVG" >/dev/null 2>&1
SRC="$GEN/orbit-icon.svg.png"

for size in 16 32 64 128 256 512 1024; do
  sips -z "$size" "$size" "$SRC" --out "$DEST/icon_${size}.png" >/dev/null
done

echo "App icons written to $DEST"

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
TMP_DERIVED="$(mktemp -d /tmp/clipipi-derived.XXXXXX)"
trap 'rm -rf "$TMP_DERIVED"' EXIT

cd "$ROOT"

echo "Building Clipipi (Release)..."
xcodebuild -scheme Clipipi -configuration Release -derivedDataPath "$TMP_DERIVED" build -quiet

APP="$TMP_DERIVED/Build/Products/Release/Clipipi.app"
if [[ ! -d "$APP" ]]; then
  echo "Build failed: $APP not found" >&2
  exit 1
fi

pkill -x Clipipi 2>/dev/null || true
rm -rf /Applications/Clipipi.app
cp -R "$APP" /Applications/

# 清掉專案內多餘副本，避免和 /Applications 混淆
rm -rf "$ROOT/build"

echo "Installed: /Applications/Clipipi.app"
sleep 0.5
open /Applications/Clipipi.app || true
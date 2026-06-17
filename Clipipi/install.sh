#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
TMP_DERIVED="$(mktemp -d /tmp/clipipi-derived.XXXXXX)"
trap 'rm -rf "$TMP_DERIVED"' EXIT

cd "$ROOT"

TEAM_ID="${DEVELOPMENT_TEAM:-}"
if [[ -f "$ROOT/Local.xcconfig" ]]; then
  TEAM_ID="$(grep -E '^DEVELOPMENT_TEAM' "$ROOT/Local.xcconfig" | sed 's/.*=[[:space:]]*//' | tr -d '[:space:]')"
fi

XCODE_ARGS=(
  -scheme Clipipi
  -configuration Release
  -derivedDataPath "$TMP_DERIVED"
  build
  -quiet
)

if [[ -n "$TEAM_ID" && "$TEAM_ID" != "YOUR_TEAM_ID_HERE" ]]; then
  echo "Building Clipipi (Release, signed)..."
  XCODE_ARGS+=(
    DEVELOPMENT_TEAM="$TEAM_ID"
    CODE_SIGN_IDENTITY="Apple Development"
  )
else
  echo "Building Clipipi (Release, adhoc)..."
  echo "⚠️  未設定 DEVELOPMENT_TEAM：每次 build 後需重新授予輔助使用權限。"
  echo "   請複製 Local.xcconfig.example → Local.xcconfig 並填入 Team ID。"
fi

xcodebuild "${XCODE_ARGS[@]}"

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
codesign -dv /Applications/Clipipi.app 2>&1 | grep -E 'Identifier=|TeamIdentifier=|Signature=' || true

sleep 0.5
open /Applications/Clipipi.app || true
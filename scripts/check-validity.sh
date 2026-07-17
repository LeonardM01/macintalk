#!/usr/bin/env bash
# 1) Export/build your app first
# ./scripts/export-app.sh with SKIP_NOTARY=1 (or your own build path)

APP="build/export/MacinTalk.app"
DMG="build/dmg/MacinTalk-1.0.dmg"
TEAM="R58UQ3LPDX"

echo "== codesign info =="
codesign -dv --verbose=4 "$APP" 2>&1 | rg "Authority=|Timestamp=|TeamIdentifier=|flags="

echo "== strict verify =="
codesign --verify --deep --strict --verbose=2 "$APP"

echo "== gatekeeper pre-notary (should say Unnotarized Developer ID) =="
spctl --assess --type execute --verbose=4 "$APP" || true

echo "== team check =="
codesign -dvv "$APP" 2>&1 | rg "TeamIdentifier=$TEAM"

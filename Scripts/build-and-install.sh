#!/usr/bin/env bash
# build-and-install.sh
# Builds Dual Meet Mixer (Release) and installs into ~/Applications
# so you can launch it via Spotlight without opening Xcode.

set -euo pipefail
cd "$(dirname "$0")/.."

echo "[1/3] Generating Xcode project…"
xcodegen generate

echo "[2/3] Building Release configuration…"
xcodebuild -project DualMeetMixer.xcodeproj \
    -scheme DualMeetMixer \
    -configuration Release \
    -derivedDataPath ./build \
    clean build 2>&1 | tail -15

APP_SRC="./build/Build/Products/Release/DualMeetMixer.app"
INSTALL_DIR="$HOME/Applications"
APP_DST="$INSTALL_DIR/DualMeetMixer.app"

if [ ! -d "$APP_SRC" ]; then
    echo "Build did not produce $APP_SRC — check the output above."
    exit 1
fi

echo "[3/3] Installing to ${APP_DST}…"
mkdir -p "$INSTALL_DIR"
rm -rf "$APP_DST"
cp -R "$APP_SRC" "$APP_DST"

# Strip the quarantine attribute so Gatekeeper doesn't ask on first launch.
xattr -dr com.apple.quarantine "$APP_DST" 2>/dev/null || true

echo ""
echo "Installed: $APP_DST"
echo ""
echo "Launch options:"
echo "  • Spotlight (⌘Space, type 'Dual Meet Mixer')"
echo "  • Finder (in ~/Applications)"
echo "  • Command line: open '$APP_DST'"
echo ""
echo "Note: this is an LSUIElement (menu-bar) app — no Dock icon."
echo "Look for the mic icon in the menu bar at the top-right of the screen."

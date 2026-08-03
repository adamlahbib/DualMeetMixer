#!/usr/bin/env bash
# install-blackhole-b.sh
# Builds and installs a second BlackHole 2ch instance with the device name "BlackHole-B".
# Requires Xcode command-line tools and admin password.

set -euo pipefail

DEVICE_NAME="BlackHole-B"
BUNDLE_ID="audio.existential.BlackHole-B"
TMP_DIR="$(mktemp -d)"
trap "rm -rf $TMP_DIR" EXIT

echo "[1/4] Cloning BlackHole source…"
git clone --depth 1 https://github.com/ExistentialAudio/BlackHole.git "$TMP_DIR/BlackHole"

cd "$TMP_DIR/BlackHole"

echo "[2/4] Building with custom name…"
# CoreAudio HAL dedupes by device UID, not bundle ID. UIDs are constructed from
# kDriver_Name in BlackHole.c (e.g., kBox_UID = kDriver_Name "%ich" "_UID"),
# so overriding kDriver_Name cascades into unique UIDs. We also override
# kDevice_Name so the user-visible name is "BlackHole-B" instead of the
# computed default "BlackHole-B 2ch".
xcodebuild -project BlackHole.xcodeproj \
    -configuration Release \
    -target BlackHole \
    PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
    GCC_PREPROCESSOR_DEFINITIONS='$(inherited) kDriver_Name=\"'$DEVICE_NAME'\" kDevice_Name=\"'$DEVICE_NAME'\" kPlugIn_BundleID=\"'$BUNDLE_ID'\" kNumber_Of_Channels=2' \
    SYMROOT="$TMP_DIR/build" \
    CONFIGURATION_BUILD_DIR="$TMP_DIR/build/Release" \
    DEVELOPMENT_TEAM="" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    MACOSX_DEPLOYMENT_TARGET=13.0

echo "[3/4] Installing to /Library/Audio/Plug-Ins/HAL/${DEVICE_NAME}.driver…"
sudo rm -rf "/Library/Audio/Plug-Ins/HAL/${DEVICE_NAME}.driver"
sudo cp -R "$TMP_DIR/build/Release/BlackHole.driver" "/Library/Audio/Plug-Ins/HAL/${DEVICE_NAME}.driver"

echo "[4/4] Restarting Core Audio…"
# launchctl kickstart is blocked by SIP on modern macOS. killall works because
# launchd respawns coreaudiod automatically.
sudo killall coreaudiod 2>/dev/null || sudo launchctl kickstart -k system/com.apple.audio.coreaudiod

echo "Done. Verify with: system_profiler SPAudioDataType | grep -i blackhole"

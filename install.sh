#!/bin/bash
# MacSweep Installer Helper
# Handles macOS Gatekeeper quarantine automatically

set -e

DMG_DIR="$HOME/Downloads"
APP_NAME="MacSweep"
APP_DEST="/Applications/${APP_NAME}.app"

echo "╔══════════════════════════════════════════╗"
echo "║        MacSweep Installer Helper         ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Find the DMG in Downloads
DMG_PATH=$(find "$DMG_DIR" -name "MacSweep-Installer*.dmg" 2>/dev/null | sort | tail -1)

if [ -z "$DMG_PATH" ]; then
    echo "❌ Could not find MacSweep DMG in ~/Downloads"
    echo "   Please download it first from:"
    echo "   https://github.com/MehmedHunjra/MacSweep/releases"
    exit 1
fi

echo "✅ Found DMG: $(basename "$DMG_PATH")"
echo ""

# Remove quarantine from the DMG
echo "🔓 Removing macOS quarantine from DMG..."
xattr -d com.apple.quarantine "$DMG_PATH" 2>/dev/null || true

# Mount the DMG
echo "💿 Mounting DMG..."
MOUNT_POINT=$(hdiutil attach "$DMG_PATH" -nobrowse -noautoopen 2>/dev/null | grep "Apple_HFS" | awk '{$1=$2=""; print}' | sed 's/^ *//')

if [ -z "$MOUNT_POINT" ]; then
    echo "❌ Failed to mount DMG"
    exit 1
fi

echo "✅ Mounted at: $MOUNT_POINT"
echo ""

# Remove old version if exists
if [ -d "$APP_DEST" ]; then
    echo "🗑  Removing old version..."
    rm -rf "$APP_DEST"
fi

# Copy app to Applications
echo "📦 Installing MacSweep to /Applications..."
cp -a "${MOUNT_POINT}/${APP_NAME}.app" "/Applications/"

# Remove quarantine from installed app
echo "🔓 Removing quarantine from installed app..."
xattr -cr "$APP_DEST" 2>/dev/null || true

# Unmount DMG
hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║  ✅ MacSweep installed successfully!     ║"
echo "║                                          ║"
echo "║  Open MacSweep from /Applications        ║"
echo "║  or Spotlight (⌘Space → MacSweep)        ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Open MacSweep
open "$APP_DEST"

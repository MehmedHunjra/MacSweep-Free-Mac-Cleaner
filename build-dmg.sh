#!/bin/bash
# ──────────────────────────────────────────────────────────────
# MacSweep DMG Builder
# Creates a professional branded .dmg installer with a
# drag-to-Applications UI, custom background, and icon layout.
# ──────────────────────────────────────────────────────────────
set -euo pipefail

# ── Config ───────────────────────────────────────────────────
APP_NAME="MacSweep"
DMG_NAME="MacSweep-Installer"
VERSION=$(defaults read "$(pwd)/MacSweep/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "3.3")
DMG_FINAL="${DMG_NAME}-v${VERSION}.dmg"
DMG_TEMP="${DMG_NAME}-temp.dmg"
VOLUME_NAME="${APP_NAME} ${VERSION}"
BACKGROUND="dmg-resources/background.png"
ICON="MacSweep/AppIcon.icns"

# Window size must match the background image
WIN_W=660
WIN_H=400

# Icon positions (centered on each half of the window)
APP_X=165
APP_Y=175
APPS_LINK_X=495
APPS_LINK_Y=175

# ── Paths ────────────────────────────────────────────────────
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${PROJECT_DIR}/build/Build/Products/Debug"
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"
OUTPUT_DIR="${PROJECT_DIR}/dist"
STAGING_DIR=$(mktemp -d)

# ── Preflight ────────────────────────────────────────────────
echo "╔══════════════════════════════════════════════════════════╗"
echo "║           MacSweep DMG Builder v${VERSION}                    ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Build the app if not already built
if [ ! -d "$APP_PATH" ]; then
    echo "📦 Building ${APP_NAME}..."
    xcodebuild -project "${PROJECT_DIR}/MacSweep.xcodeproj" \
               -scheme MacSweep \
               -configuration Debug \
               -derivedDataPath "${PROJECT_DIR}/build" \
               build \
               2>&1 | tail -5
    echo ""
fi

if [ ! -d "$APP_PATH" ]; then
    # Try DerivedData paths
    ALT_PATH="${HOME}/Library/Developer/Xcode/DerivedData/Build/Products/Debug/${APP_NAME}.app"
    if [ -d "$ALT_PATH" ]; then
        APP_PATH="$ALT_PATH"
    else
        echo "❌ Build failed — ${APP_NAME}.app not found."
        echo "   Tried: ${APP_PATH}"
        echo "   Tried: ${ALT_PATH}"
        exit 1
    fi
fi

echo "✅ App found: ${APP_PATH}"
echo ""

# ── Stage DMG contents ───────────────────────────────────────
echo "📂 Staging DMG contents..."
cp -a "$APP_PATH" "${STAGING_DIR}/${APP_NAME}.app"

# Remove quarantine attributes so macOS Gatekeeper doesn't block the app
xattr -cr "${STAGING_DIR}/${APP_NAME}.app" 2>/dev/null || true
echo "🔓 Quarantine attributes removed from app bundle"

ln -s /Applications "${STAGING_DIR}/Applications"

# Background (hidden .background folder — standard macOS DMG pattern)
mkdir -p "${STAGING_DIR}/.background"
cp "${PROJECT_DIR}/${BACKGROUND}" "${STAGING_DIR}/.background/background.png"

echo "   ├── ${APP_NAME}.app"
echo "   ├── Applications → /Applications"
echo "   └── .background/background.png"
echo ""

# ── Create writable DMG ─────────────────────────────────────
echo "💿 Creating DMG image..."
# Clean up any leftover temp DMGs
rm -f "${OUTPUT_DIR}/${DMG_TEMP}" "${OUTPUT_DIR}/${DMG_FINAL}" 2>/dev/null || true
mkdir -p "${OUTPUT_DIR}"

# Calculate required size (app size + 20MB headroom)
APP_SIZE_KB=$(du -sk "${STAGING_DIR}/${APP_NAME}.app" | awk '{print $1}')
DMG_SIZE_KB=$((APP_SIZE_KB + 20480))

hdiutil create \
    -srcfolder "${STAGING_DIR}" \
    -volname "${VOLUME_NAME}" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    -size "${DMG_SIZE_KB}k" \
    "${OUTPUT_DIR}/${DMG_TEMP}" \
    > /dev/null 2>&1

echo "✅ Writable DMG created"
echo ""

# ── Mount and configure window layout ───────────────────────
echo "🎨 Applying branded layout..."

MOUNT_POINT=$(hdiutil attach -readwrite -noverify -noautoopen "${OUTPUT_DIR}/${DMG_TEMP}" | grep "Apple_HFS" | awk '{$1=$2=""; print}' | sed 's/^ *//')

# Give Finder time to mount
sleep 2

# Apply custom icon if available
if [ -f "${PROJECT_DIR}/${ICON}" ]; then
    cp "${PROJECT_DIR}/${ICON}" "${MOUNT_POINT}/.VolumeIcon.icns"
    SetFile -c icnC "${MOUNT_POINT}/.VolumeIcon.icns" 2>/dev/null || true
    SetFile -a C "${MOUNT_POINT}" 2>/dev/null || true
fi

# AppleScript to configure the DMG window layout
echo "   Configuring Finder window..."
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        delay 1
        
        -- Set window properties
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {100, 100, $((100 + WIN_W)), $((100 + WIN_H))}
        
        -- Configure icon view options
        set viewOptions to icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 80
        set text size of viewOptions to 12
        set background picture of viewOptions to file ".background:background.png"
        
        -- Position icons
        set position of item "${APP_NAME}.app" of container window to {${APP_X}, ${APP_Y}}
        set position of item "Applications" of container window to {${APPS_LINK_X}, ${APPS_LINK_Y}}
        
        close
        open
        
        -- Refresh
        delay 1
        
        close
    end tell
end tell
APPLESCRIPT

echo "✅ Layout applied"
echo ""

# Hide background folder
SetFile -a V "${MOUNT_POINT}/.background" 2>/dev/null || true

# Ensure .DS_Store is written
sync
sleep 2

# ── Unmount and compress ─────────────────────────────────────
echo "📀 Compressing final DMG..."
hdiutil detach "${MOUNT_POINT}" -quiet -force 2>/dev/null || true
sleep 1

hdiutil convert \
    "${OUTPUT_DIR}/${DMG_TEMP}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${OUTPUT_DIR}/${DMG_FINAL}" \
    > /dev/null 2>&1

rm -f "${OUTPUT_DIR}/${DMG_TEMP}"
rm -rf "${STAGING_DIR}"

# ── Done! ────────────────────────────────────────────────────
FINAL_SIZE=$(du -h "${OUTPUT_DIR}/${DMG_FINAL}" | awk '{print $1}')

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  ✅ DMG Created Successfully!                           ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  📦 File: ${DMG_FINAL}"
echo "║  📏 Size: ${FINAL_SIZE}"
echo "║  📁 Path: ${OUTPUT_DIR}/${DMG_FINAL}"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "🎉 Ready to distribute!"

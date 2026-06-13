#!/bin/bash
set -euo pipefail

# ============================================================
# RingGlow DMG Installer Builder
# Creates a professional drag-to-install DMG for macOS
# ============================================================

APP_NAME="RingGlow"
VERSION="1.0"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${VERSION}"
DMG_FINAL="${BUILD_DIR}/${DMG_NAME}.dmg"
DMG_TEMP="${BUILD_DIR}/${DMG_NAME}-temp.dmg"
VOLUME_NAME="${APP_NAME} ${VERSION}"
MOUNT_POINT="/Volumes/${VOLUME_NAME}"
STAGING_DIR="${BUILD_DIR}/dmg-staging"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}==> $1${NC}"; }
ok()    { echo -e "${GREEN}==> $1${NC}"; }
error() { echo -e "${RED}ERROR: $1${NC}" >&2; exit 1; }

# ---- Step 1: Verify app bundle exists ----
if [ ! -d "${APP_BUNDLE}" ]; then
    info "App bundle not found. Building..."
    ./build.sh
fi

[ -d "${APP_BUNDLE}" ] || error "App bundle not found: ${APP_BUNDLE}"

# ---- Step 2: Generate background image ----
info "Generating DMG background..."
python3 "${SCRIPTS_DIR}/generate-dmg-background.py" "${BUILD_DIR}"
DMG_BG="${BUILD_DIR}/dmg-background.png"
[ -f "${DMG_BG}" ] || error "Background image generation failed"

# ---- Step 3: Prepare staging directory ----
info "Preparing staging directory..."
rm -rf "${STAGING_DIR}"
mkdir -p "${STAGING_DIR}"

# Copy app bundle
cp -R "${APP_BUNDLE}" "${STAGING_DIR}/"

# Create Applications symlink (the key to drag-to-install)
ln -s /Applications "${STAGING_DIR}/Applications"

# Copy background into hidden .background folder
mkdir -p "${STAGING_DIR}/.background"
cp "${DMG_BG}" "${STAGING_DIR}/.background/background.png"

# ---- Step 4: Unmount any existing volume ----
if [ -d "${MOUNT_POINT}" ]; then
    info "Unmounting existing volume..."
    hdiutil detach "${MOUNT_POINT}" -force 2>/dev/null || true
fi

# ---- Step 5: Remove old DMG ----
rm -f "${DMG_TEMP}" "${DMG_FINAL}"

# ---- Step 6: Create temporary DMG ----
info "Creating temporary DMG..."
hdiutil create \
    -volname "${VOLUME_NAME}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDRW \
    -fs HFS+ \
    "${DMG_TEMP}"

# ---- Step 7: Mount and customize ----
info "Mounting DMG for customization..."
hdiutil attach "${DMG_TEMP}" -readwrite -noverify -noautoopen \
    -mountpoint "${MOUNT_POINT}"

# Wait for mount
sleep 1

# ---- Step 8: Apply Finder settings via AppleScript ----
info "Applying Finder window settings..."
osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "${VOLUME_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 120, 860, 520}
        set theViewOptions to icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 96
        set position of item "${APP_NAME}.app" of container window to {160, 200}
        set position of item "Applications" of container window to {500, 200}
        set background picture of theViewOptions to file ".background:background.png"
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
APPLESCRIPT

# ---- Step 9: Unmount ----
info "Unmounting DMG..."
hdiutil detach "${MOUNT_POINT}" -force

# ---- Step 10: Compress to final DMG ----
info "Compressing DMG (this may take a moment)..."
hdiutil convert "${DMG_TEMP}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${DMG_FINAL}"

rm -f "${DMG_TEMP}"

# ---- Step 11: Clean up staging ----
rm -rf "${STAGING_DIR}"

# ---- Done ----
DMG_SIZE=$(du -h "${DMG_FINAL}" | cut -f1)
ok "DMG installer created successfully!"
echo ""
echo "  📦 File: ${DMG_FINAL}"
echo "  📏 Size: ${DMG_SIZE}"
echo ""
echo "  To install: Open the DMG and drag RingGlow to Applications"
echo ""

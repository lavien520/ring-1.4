#!/bin/bash
set -euo pipefail

APP_NAME="RingGlow"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Cleaning build directory..."
rm -rf "${BUILD_DIR}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

echo "==> Compiling Swift sources..."
swiftc -O \
    -target arm64-apple-macos13.0 \
    -o "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" \
    Sources/*.swift \
    -framework Cocoa

echo "==> Copying Info.plist..."
cp Info.plist "${APP_BUNDLE}/Contents/"

if [ -d "fonts" ] && [ "$(ls -A fonts)" ]; then
    echo "==> Copying fonts..."
    cp fonts/*.ttf "${APP_BUNDLE}/Contents/Resources/"
fi

echo "==> Build complete: ${APP_BUNDLE}"

# Auto-install hooks if not already configured
HOOK_SCRIPT="${SCRIPT_DIR}/hooks/ring-hook.js"
SETTINGS_FILE="${HOME}/.claude/settings.json"

if [ -f "${HOOK_SCRIPT}" ] && command -v node &>/dev/null; then
    if [ ! -f "${SETTINGS_FILE}" ] || ! grep -q '"hooks"' "${SETTINGS_FILE}" 2>/dev/null; then
        echo "==> Installing Claude Code hooks..."
        "${SCRIPT_DIR}/hooks/install-hooks.sh"
    else
        # Check if Ring hooks specifically are present
        if ! grep -q 'ring-hook' "${SETTINGS_FILE}" 2>/dev/null; then
            echo "==> Installing Claude Code hooks..."
            "${SCRIPT_DIR}/hooks/install-hooks.sh"
        else
            echo "==> Claude Code hooks already configured"
        fi
    fi
else
    echo "==> Skipping hook installation (Node.js not found or hook script missing)"
fi

echo "    Run with: open ${APP_BUNDLE}"

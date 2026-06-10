#!/bin/bash
set -euo pipefail

APP_NAME="RingGlow"
BUILD_DIR="build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"

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

echo "==> Build complete: ${APP_BUNDLE}"
echo "    Run with: open ${APP_BUNDLE}"

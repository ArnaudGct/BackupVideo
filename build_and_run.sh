#!/bin/bash
set -e

APP_NAME="BackupVideo"
BUILD_DIR=".build/debug"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MAC_OS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"

echo "⏳ Compilation du projet avec Swift Package Manager..."
swift build

echo "📦 Création du bundle macOS (.app)..."
mkdir -p "$MAC_OS"
mkdir -p "$RESOURCES"

cp "${BUILD_DIR}/${APP_NAME}" "$MAC_OS/"
cp "AppIcon.icns" "$RESOURCES/"

cat > "$CONTENTS/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.arnaudgct.${APP_NAME}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
EOF

echo "🚀 Lancement de l'application..."
open "${APP_BUNDLE}"

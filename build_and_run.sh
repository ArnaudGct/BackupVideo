#!/bin/bash
set -e

APP_NAME="BackupVideo"
BUILD_DIR=".build/debug"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS="${APP_BUNDLE}/Contents"
MAC_OS="${CONTENTS}/MacOS"
RESOURCES="${CONTENTS}/Resources"
COMPATIBLE_SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk"

if [ -d "$COMPATIBLE_SDK" ]; then
    export SDKROOT="$COMPATIBLE_SDK"
    echo "🧰 SDK de compilation : macOS 26.5 (compatible macOS 27)"
fi

export CLANG_MODULE_CACHE_PATH="$(pwd)/.build/clang-module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$(pwd)/.build/swift-module-cache"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$SWIFTPM_MODULECACHE_OVERRIDE"

echo "⏳ Compilation du projet avec Swift Package Manager..."
swift build

echo "📦 Création du bundle macOS (.app)..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MAC_OS"
mkdir -p "$RESOURCES"

cp "${BUILD_DIR}/${APP_NAME}" "$MAC_OS/"
chmod +x "${MAC_OS}/${APP_NAME}"

if command -v vtool >/dev/null 2>&1; then
    PATCHED_EXECUTABLE="${MAC_OS}/${APP_NAME}.patched"
    xcrun vtool \
        -set-build-version macos 14.0 26.5 \
        -replace \
        -output "$PATCHED_EXECUTABLE" \
        "${MAC_OS}/${APP_NAME}"
    mv "$PATCHED_EXECUTABLE" "${MAC_OS}/${APP_NAME}"
    chmod +x "${MAC_OS}/${APP_NAME}"
    echo "🎨 Apparence native moderne activée"
fi

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
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

echo "✍️ Signature ad-hoc de l'application..."
xattr -cr "$APP_BUNDLE"
codesign --force --deep --sign - "$APP_BUNDLE"

echo "🚀 Lancement de l'application..."
open "${APP_BUNDLE}"

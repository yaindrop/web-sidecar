#!/bin/bash
set -e

APP_NAME="WebSidecar"
BUNDLE_ID="com.yaindrop.websidecar"
OUTPUT_DIR=".build/release"
APP_BUNDLE="$OUTPUT_DIR/$APP_NAME.app"
EXECUTABLE_NAME="WebSidecarApp" # Matches the target name in Package.swift
ICON_SOURCE="../../app_icon.png"
STATUS_ICON_SOURCE="../../favicon.png"

echo "Building $APP_NAME..."
swift build -c release

echo "Creating App Bundle..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy frontend
if [ -d "../frontend/dist" ]; then
    echo "Copying Frontend..."
    rm -rf "$APP_BUNDLE/Contents/Resources/public"
    cp -r "../frontend/dist" "$APP_BUNDLE/Contents/Resources/public"
else
    echo "Error: Frontend dist not found. Please run 'pnpm build' in packages/frontend."
    exit 1
fi

# Copy and rename executable
cp "$OUTPUT_DIR/$EXECUTABLE_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Status Icon
if [ -f "$STATUS_ICON_SOURCE" ]; then
    echo "Processing Status Icon..."
    # Create 22pt icon (standard and @2x)
    sips -z 22 22 "$STATUS_ICON_SOURCE" --out "$APP_BUNDLE/Contents/Resources/status_icon.png" > /dev/null
    sips -z 44 44 "$STATUS_ICON_SOURCE" --out "$APP_BUNDLE/Contents/Resources/status_icon@2x.png" > /dev/null
else
    echo "Warning: $STATUS_ICON_SOURCE not found."
fi

# Process Icon
if [ -f "$ICON_SOURCE" ]; then
    echo "Processing App Icon..."
    ICONSET_DIR="WebSidecar.iconset"
    mkdir -p "$ICONSET_DIR"

    # Resize images
    sips -z 16 16     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" > /dev/null
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" > /dev/null
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" > /dev/null
    sips -z 64 64     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" > /dev/null
    sips -z 128 128   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" > /dev/null
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" > /dev/null
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" > /dev/null
    sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" > /dev/null

    # Create icns
    iconutil -c icns "$ICONSET_DIR"
    cp WebSidecar.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    
    # Cleanup
    rm -rf "$ICONSET_DIR"
    rm WebSidecar.icns
    echo "Icon processed."
else
    echo "Warning: $ICON_SOURCE not found. App will use default icon."
fi

# Copy Info.plist
echo "Copying Info.plist..."
cp "Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Ad-hoc signing to run locally (required for arm64)
echo "Signing..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Done! App is at $APP_BUNDLE"
echo "You can open it with: open $APP_BUNDLE"

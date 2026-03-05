#!/bin/bash
set -e

# Build
swift build 2>&1

# Create .app bundle
APP_DIR=".build/seeport.app/Contents"
mkdir -p "$APP_DIR/MacOS"
mkdir -p "$APP_DIR/Resources"
mkdir -p "$APP_DIR/Frameworks"

# Copy executable
cp .build/arm64-apple-macosx/debug/seeport "$APP_DIR/MacOS/seeport"

# Copy Info.plist
cp Sources/seeport/Resources/Info.plist "$APP_DIR/Info.plist"

# Copy Sparkle.framework into app bundle
SPARKLE_SRC=$(find .build -path "*/artifacts/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework" -print -quit 2>/dev/null)
if [ -z "$SPARKLE_SRC" ]; then
    SPARKLE_SRC=$(find .build -name "Sparkle.framework" -path "*/macos*" -print -quit 2>/dev/null)
fi
if [ -n "$SPARKLE_SRC" ]; then
    cp -R "$SPARKLE_SRC" "$APP_DIR/Frameworks/"
    echo "Sparkle.framework copied to app bundle"
else
    echo "Warning: Sparkle.framework not found, skipping"
fi

echo "App bundle created at .build/seeport.app"

# Ad-hoc code sign (deep to include frameworks)
codesign --force --deep --sign - .build/seeport.app

# Run the app
open .build/seeport.app

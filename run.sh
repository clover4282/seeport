#!/bin/bash
set -e

# Build
swift build 2>&1

# Create .app bundle
APP_DIR=".build/seeport.app/Contents"
mkdir -p "$APP_DIR/MacOS"
mkdir -p "$APP_DIR/Resources"

# Copy executable
cp .build/arm64-apple-macosx/debug/seeport "$APP_DIR/MacOS/seeport"

# Copy Info.plist
cp Sources/seeport/Resources/Info.plist "$APP_DIR/Info.plist"

echo "App bundle created at .build/seeport.app"

# Ad-hoc code sign
codesign --force --sign - .build/seeport.app

# Run the app
open .build/seeport.app

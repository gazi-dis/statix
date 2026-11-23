#!/usr/bin/env bash
set -e

# ==============================================================================
# Statix Build Script - Universal macOS Menu Bar Resource Monitor
# Supports both Apple Silicon (arm64, M1/M2/M3/M4) and Intel (x86_64)
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="Statix"
BUILD_DIR="build"
DIST_DIR="dist"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "=========================================="
echo " Building $APP_NAME (Universal Binary)"
echo " Architectures: arm64 (Apple Silicon) + x86_64 (Intel)"
echo "=========================================="

# 1. Clean previous builds
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$DIST_DIR" "$MACOS_DIR" "$RESOURCES_DIR/web"

# 2. Generate assets if needed
if [ ! -f "assets/AppIcon.icns" ] || [ ! -f "assets/menubar_icon.png" ]; then
    echo "==> Generating application icons..."
    clang -O2 -framework Cocoa tools/generate_icons.m -o tools/gen_icons
    ./tools/gen_icons assets
    python3 tools/pack_icns.py assets assets/AppIcon.icns
fi

# 3. Source files
SOURCES="src/main.m src/AppDelegate.m src/SystemMonitor.m"
FRAMEWORKS="-framework Cocoa -framework WebKit -framework IOKit -lproc"
MIN_MACOS="11.0"
CFLAGS="-O3 -fobjc-arc -Wall -Wno-deprecated-declarations -mmacosx-version-min=$MIN_MACOS"

# 4. Compile arm64 (Apple Silicon M1/M2/M3/M4)
echo "==> Compiling arm64 slice..."
clang $CFLAGS -target arm64-apple-macos$MIN_MACOS $FRAMEWORKS $SOURCES -o "$BUILD_DIR/${APP_NAME}_arm64"

# 5. Compile x86_64 (Intel)
echo "==> Compiling x86_64 slice..."
clang $CFLAGS -target x86_64-apple-macos$MIN_MACOS $FRAMEWORKS $SOURCES -o "$BUILD_DIR/${APP_NAME}_x86_64"

# 6. Create Universal Binary with lipo
echo "==> Creating Universal Binary..."
lipo -create -output "$MACOS_DIR/$APP_NAME" "$BUILD_DIR/${APP_NAME}_arm64" "$BUILD_DIR/${APP_NAME}_x86_64"
chmod +x "$MACOS_DIR/$APP_NAME"

# Verify binary architectures
echo "==> Binary verification:"
file "$MACOS_DIR/$APP_NAME"
lipo -info "$MACOS_DIR/$APP_NAME"

# 7. Copy Bundle Resources
echo "==> Packaging application bundle..."
cp "src/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "assets/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp "assets/menubar_icon.png" "$RESOURCES_DIR/menubar_icon.png"
cp "assets/menubar_icon@2x.png" "$RESOURCES_DIR/menubar_icon@2x.png"
cp -r src/web/* "$RESOURCES_DIR/web/"

# 8. Ad-hoc codesign the bundle
echo "==> Ad-hoc codesigning application bundle..."
codesign -s - --force --deep "$APP_BUNDLE"

# 9. Copy to dist
rm -rf "$DIST_DIR/$APP_NAME.app"
cp -R "$APP_BUNDLE" "$DIST_DIR/$APP_NAME.app"

# 10. Create Zip Archive for easy distribution
echo "==> Creating distribution zip archive..."
cd "$DIST_DIR"
rm -f "$APP_NAME-Universal.zip"
zip -r -q "$APP_NAME-Universal.zip" "$APP_NAME.app"
cd "$SCRIPT_DIR"

echo "=========================================="
echo " BUILD SUCCESSFUL!"
echo " App Bundle: $DIST_DIR/$APP_NAME.app"
echo " Zip Archive: $DIST_DIR/$APP_NAME-Universal.zip"
echo "=========================================="

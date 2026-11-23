#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="Statix"
DIST_DIR="dist"
DMG_NAME="$APP_NAME-Universal.dmg"
STAGING_DIR="$DIST_DIR/dmg_staging"

echo "==> Creating DMG installer for $APP_NAME..."

if [ ! -d "$DIST_DIR/$APP_NAME.app" ]; then
    echo "Error: $DIST_DIR/$APP_NAME.app not found! Run ./build.sh first."
    exit 1
fi

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# 1. Copy App to staging
cp -R "$DIST_DIR/$APP_NAME.app" "$STAGING_DIR/"

# 2. Create /Applications symlink for drag-and-drop installer
ln -s /Applications "$STAGING_DIR/Applications"

# 3. Create DMG image
rm -f "$DIST_DIR/$DMG_NAME"
hdiutil create \
    -volname "$APP_NAME Installer" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DIST_DIR/$DMG_NAME"

# 4. Clean up staging
rm -rf "$STAGING_DIR"

echo "==> DMG successfully created at $DIST_DIR/$DMG_NAME"
ls -lh "$DIST_DIR/$DMG_NAME"

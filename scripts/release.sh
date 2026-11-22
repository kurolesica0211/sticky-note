#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
./scripts/build.sh --universal
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sticky-note-package.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
PACKAGE_DIR="$STAGING_DIR/Sticky Note"
mkdir -p "$PACKAGE_DIR" dist
for NAME in "Sticky Note" "Delete Sticky Note"; do
    ditto --noextattr --norsrc "dist/$NAME.app" "$PACKAGE_DIR/$NAME.app"
    codesign --verify --deep --strict "$PACKAGE_DIR/$NAME.app"
done
cp Resources/Install.txt "$PACKAGE_DIR/Read Me.txt"
xattr -cr "$PACKAGE_DIR"
ZIP="$PROJECT_DIR/dist/Sticky-Note-$VERSION-universal.zip"
DMG="$PROJECT_DIR/dist/Sticky-Note-$VERSION-universal.dmg"
ditto -c -k --keepParent "$PACKAGE_DIR" "$ZIP"
ln -sfn /Applications "$PACKAGE_DIR/Applications"
hdiutil create -volname "Sticky Note $VERSION" -srcfolder "$PACKAGE_DIR" -ov -format UDZO "$DMG"
rm "$PACKAGE_DIR/Applications"
hdiutil verify "$DMG"
cd dist
shasum -a 256 "$(basename "$ZIP")" "$(basename "$DMG")" > SHA256SUMS.txt
printf 'Release packages ready in %s/dist\n' "$PROJECT_DIR"

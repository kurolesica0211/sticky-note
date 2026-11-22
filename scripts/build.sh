#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_DIR/.build/module-cache"
if [[ "${1:-}" == "--universal" ]]; then
    ARCHITECTURES=(arm64 x86_64)
else
    ARCHITECTURES=("$(uname -m)")
fi
for ARCH in "${ARCHITECTURES[@]}"; do
    for PRODUCT in StickyNote DeleteStickyNote; do
        swift build -c release --product "$PRODUCT" --triple "$ARCH-apple-macosx14.0" \
            --scratch-path ".build/release-$ARCH" --cache-path .build/cache --disable-sandbox
    done
done
mkdir -p .build/AppIcon.iconset
swift scripts/make-icon.swift .build/AppIcon.iconset
iconutil -c icns .build/AppIcon.iconset -o .build/AppIcon.icns
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sticky-note-build.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
for PRODUCT in StickyNote DeleteStickyNote; do
    if [[ "$PRODUCT" == "StickyNote" ]]; then
        NAME="Sticky Note"; PLIST="Resources/Info.plist"
    else
        NAME="Delete Sticky Note"; PLIST="Resources/DeleteInfo.plist"
    fi
    # Sign outside cloud-managed folders, which can re-add Finder metadata.
    APP_PATH="$STAGING_DIR/$NAME.app"
    mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
    BINARIES=()
    for ARCH in "${ARCHITECTURES[@]}"; do
        BIN_DIR="$(swift build -c release --triple "$ARCH-apple-macosx14.0" --scratch-path ".build/release-$ARCH" --show-bin-path)"
        BINARIES+=("$BIN_DIR/$PRODUCT")
    done
    lipo -create "${BINARIES[@]}" -output "$APP_PATH/Contents/MacOS/$PRODUCT"
    chmod +x "$APP_PATH/Contents/MacOS/$PRODUCT"
    cp "$PLIST" "$APP_PATH/Contents/Info.plist"
    cp .build/AppIcon.icns "$APP_PATH/Contents/Resources/AppIcon.icns"
    xattr -cr "$APP_PATH"
    codesign --force --sign - "$APP_PATH"
    codesign --verify --deep --strict "$APP_PATH"
    mkdir -p "$PROJECT_DIR/dist"
    ditto --noextattr --norsrc "$APP_PATH" "$PROJECT_DIR/dist/$NAME.app"
    printf 'Built %s (%s)\n' "$PROJECT_DIR/dist/$NAME.app" "$(lipo -archs "$APP_PATH/Contents/MacOS/$PRODUCT")"
done

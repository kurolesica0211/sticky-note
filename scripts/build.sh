#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_DIR/.build/module-cache"
swift build -c release --cache-path .build/cache --disable-sandbox
APP_PATH="$PROJECT_DIR/dist/Sticky Note.app"
mkdir -p "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources" .build/AppIcon.iconset
cp .build/release/StickyNote "$APP_PATH/Contents/MacOS/StickyNote"
cp Resources/Info.plist "$APP_PATH/Contents/Info.plist"
swift scripts/make-icon.swift .build/AppIcon.iconset
iconutil -c icns .build/AppIcon.iconset -o "$APP_PATH/Contents/Resources/AppIcon.icns"
xattr -cr "$APP_PATH"
codesign --force --sign - "$APP_PATH"
printf 'Built %s\n' "$APP_PATH"

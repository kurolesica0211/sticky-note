#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
export CLANG_MODULE_CACHE_PATH="$PROJECT_DIR/.build/module-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PROJECT_DIR/.build/module-cache"
swift run --cache-path .build/cache --disable-sandbox NoteCoreChecks
swift build --product StickyNote --scratch-path .build/editor-checks --cache-path .build/cache --disable-sandbox -Xswiftc -DEDITOR_CHECKS
.build/editor-checks/debug/StickyNote

#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
"$PROJECT_DIR/scripts/build.sh"
if pgrep -x StickyNote >/dev/null; then
    printf 'Quit Sticky Note from its menu bar menu, then run this script again.\n' >&2
    exit 1
fi
mkdir -p "$HOME/Applications"
for NAME in "Sticky Note" "Delete Sticky Note"; do
    DESTINATION="$HOME/Applications/$NAME.app"
    ditto "$PROJECT_DIR/dist/$NAME.app" "$DESTINATION"
    xattr -cr "$DESTINATION"
    codesign --verify --deep --strict "$DESTINATION"
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DESTINATION"
    mdimport "$DESTINATION"
    printf 'Installed %s\n' "$DESTINATION"
done
printf 'Open Spotlight and type Sticky Note or Delete Sticky Note.\n'

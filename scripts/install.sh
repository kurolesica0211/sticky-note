#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
"$PROJECT_DIR/scripts/build.sh"
DESTINATION="$HOME/Applications/Sticky Note.app"
if pgrep -x StickyNote >/dev/null; then
    printf 'Quit Sticky Note from its menu bar menu, then run this script again.\n' >&2
    exit 1
fi
mkdir -p "$HOME/Applications"
ditto "$PROJECT_DIR/dist/Sticky Note.app" "$DESTINATION"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DESTINATION"
mdimport "$DESTINATION"
printf 'Installed %s\nOpen Spotlight and type Sticky Note.\n' "$DESTINATION"

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$SCRIPT_DIR"
APPLET_ID="org.fredde.casaos.homelab"
TARGET="$HOME/.local/share/plasma/plasmoids/$APPLET_ID"

echo "→ Installing CasaOS Homelab plasmoid from $PACKAGE_DIR"

# Clean up any broken symlinks left over from a previous repo location.
if [ -L "$TARGET" ] && [ ! -e "$TARGET" ]; then
    echo "  Removing dangling symlink at $TARGET"
    rm -f "$TARGET"
fi

if kpackagetool6 -t Plasma/Applet -u "$PACKAGE_DIR" 2>/dev/null; then
    echo "  Upgraded existing installation."
else
    kpackagetool6 -t Plasma/Applet -i "$PACKAGE_DIR"
    echo "  Installed."
fi

echo
echo "→ Reload Plasma to pick up the changes:"
echo "    kquitapp6 plasmashell && kstart plasmashell"
echo
echo "→ Then add the widget:"
echo "    right-click the panel → Add Widgets → search 'CasaOS Homelab'"
echo
echo "→ Configure server URL, username, and password via right-click → Configure."

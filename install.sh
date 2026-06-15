#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$SCRIPT_DIR"

echo "Installing CasaOS Homelab plasmoid..."
if kpackagetool6 -t Plasma/Applet -u "$PACKAGE_DIR" 2>/dev/null; then
    echo "Upgraded existing installation."
else
    kpackagetool6 -t Plasma/Applet -i "$PACKAGE_DIR"
    echo "Installed."
fi

echo ""
echo "Installed. Add the widget:"
echo "  Right-click panel → Add Widgets → search 'CasaOS Homelab'"
echo ""
echo "Then configure your server URL, username, and password."

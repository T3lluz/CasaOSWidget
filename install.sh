#!/usr/bin/env bash
# CasaOS Homelab — KDE Plasma 6 widget installer.
#
# Usage:
#   ./install.sh                         # install / upgrade
#   ./install.sh --uninstall             # remove the widget
#
# Remote (curl-piped) usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/T3lluz/CasaOSWidget/main/install.sh)
#   bash <(curl -fsSL https://raw.githubusercontent.com/T3lluz/CasaOSWidget/main/install.sh) --uninstall

set -euo pipefail

APPLET_ID="org.fredde.casaos.homelab"
APPLET_NAME="CasaOS Homelab"
REPO_URL="https://github.com/T3lluz/CasaOSWidget.git"
REPO_BRANCH="main"
TARGET="$HOME/.local/share/plasma/plasmoids/$APPLET_ID"

# ---- pretty printing ---------------------------------------------------------
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
    C_BOLD="$(tput bold)"; C_DIM="$(tput dim)"; C_RESET="$(tput sgr0)"
    C_OK="$(tput setaf 2)"; C_WARN="$(tput setaf 3)"; C_ERR="$(tput setaf 1)"; C_INFO="$(tput setaf 6)"
else
    C_BOLD=""; C_DIM=""; C_RESET=""; C_OK=""; C_WARN=""; C_ERR=""; C_INFO=""
fi

say()  { printf "%s→%s %s\n"    "$C_INFO" "$C_RESET" "$*"; }
ok()   { printf "%s✓%s %s\n"    "$C_OK"   "$C_RESET" "$*"; }
warn() { printf "%s!%s %s\n"    "$C_WARN" "$C_RESET" "$*"; }
err()  { printf "%s✗%s %s\n"    "$C_ERR"  "$C_RESET" "$*" >&2; }
hdr()  { printf "\n%s%s%s\n"    "$C_BOLD" "$*" "$C_RESET"; }

# ---- argument parsing --------------------------------------------------------
ACTION="install"
for arg in "$@"; do
    case "$arg" in
        -u|--uninstall|--remove)
            ACTION="uninstall"
            ;;
        -h|--help)
            cat <<EOF
${C_BOLD}CasaOS Homelab installer${C_RESET}

  ${C_BOLD}install.sh${C_RESET}                Install or upgrade the widget.
  ${C_BOLD}install.sh --uninstall${C_RESET}    Remove the widget.
  ${C_BOLD}install.sh --help${C_RESET}         Show this help.
EOF
            exit 0
            ;;
        *)
            err "Unknown option: $arg (try --help)"
            exit 2
            ;;
    esac
done

# ---- environment checks ------------------------------------------------------
require_kpackagetool() {
    if command -v kpackagetool6 >/dev/null 2>&1; then
        KPT="kpackagetool6"
    elif command -v kpackagetool5 >/dev/null 2>&1; then
        warn "kpackagetool6 not found, falling back to kpackagetool5 (Plasma 5 only — Plasma 6 is recommended)."
        KPT="kpackagetool5"
    else
        err "Neither kpackagetool6 nor kpackagetool5 is installed."
        err "Install your distro's Plasma SDK package (e.g. 'plasma-sdk', 'kf6-kpackage', or 'plasma-framework')."
        exit 1
    fi
}

# ---- locate package source ---------------------------------------------------
# When invoked as `bash <(curl …)` $BASH_SOURCE is /dev/fd/63 or similar, so we
# can't trust a script-relative path. We probe for metadata.json next to the
# script; if it isn't there, we shallow-clone the repo into a temp dir.
locate_package() {
    local script_dir=""
    if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
        script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi
    if [ -n "$script_dir" ] && [ -f "$script_dir/metadata.json" ]; then
        PACKAGE_DIR="$script_dir"
        PACKAGE_TEMP=""
        return
    fi
    if [ -f "$PWD/metadata.json" ] && [ -d "$PWD/contents" ]; then
        PACKAGE_DIR="$PWD"
        PACKAGE_TEMP=""
        return
    fi

    if ! command -v git >/dev/null 2>&1; then
        err "git is required to fetch the widget from $REPO_URL."
        err "Install git or clone the repo manually and run install.sh from inside it."
        exit 1
    fi

    PACKAGE_TEMP="$(mktemp -d -t casaos-widget-XXXXXX)"
    trap 'rm -rf "$PACKAGE_TEMP"' EXIT
    say "Fetching ${APPLET_NAME} from $REPO_URL"
    git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" "$PACKAGE_TEMP" >/dev/null
    PACKAGE_DIR="$PACKAGE_TEMP"
}

# ---- actions -----------------------------------------------------------------
do_install() {
    hdr "Installing ${APPLET_NAME}"
    require_kpackagetool
    locate_package

    say "Source:  $PACKAGE_DIR"
    say "Target:  $TARGET"

    # Clean up a dangling symlink left over from a previous repo location.
    if [ -L "$TARGET" ] && [ ! -e "$TARGET" ]; then
        warn "Removing dangling symlink at $TARGET"
        rm -f "$TARGET"
    fi

    if "$KPT" -t Plasma/Applet -u "$PACKAGE_DIR" >/dev/null 2>&1; then
        ok "Upgraded existing installation."
    else
        "$KPT" -t Plasma/Applet -i "$PACKAGE_DIR"
        ok "Installed."
    fi

    hdr "Next steps"
    cat <<EOF
  ${C_BOLD}1.${C_RESET} Reload Plasma so it picks up the new widget:
       ${C_DIM}kquitapp6 plasmashell && kstart plasmashell${C_RESET}

  ${C_BOLD}2.${C_RESET} Right-click your panel → ${C_BOLD}Add Widgets${C_RESET} → search ${C_BOLD}${APPLET_NAME}${C_RESET}.

  ${C_BOLD}3.${C_RESET} Right-click the widget → ${C_BOLD}Configure${C_RESET} and enter your
     CasaOS URL, username, and password.

  ${C_DIM}Uninstall later with:${C_RESET}
       ${C_DIM}bash <(curl -fsSL https://raw.githubusercontent.com/T3lluz/CasaOSWidget/$REPO_BRANCH/install.sh) --uninstall${C_RESET}
EOF
}

do_uninstall() {
    hdr "Removing ${APPLET_NAME}"
    require_kpackagetool

    local removed=0

    if "$KPT" -t Plasma/Applet -l 2>/dev/null | grep -qx "$APPLET_ID"; then
        if "$KPT" -t Plasma/Applet -r "$APPLET_ID" >/dev/null 2>&1; then
            ok "Removed via $KPT."
            removed=1
        else
            warn "$KPT reported the package was registered but could not remove it."
        fi
    fi

    if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
        rm -rf "$TARGET"
        ok "Deleted $TARGET"
        removed=1
    fi

    if [ "$removed" -eq 0 ]; then
        warn "${APPLET_NAME} was not installed for this user — nothing to do."
        return
    fi

    hdr "Next steps"
    cat <<EOF
  Reload Plasma to drop the widget from any panels:
       ${C_DIM}kquitapp6 plasmashell && kstart plasmashell${C_RESET}
EOF
}

case "$ACTION" in
    install)   do_install   ;;
    uninstall) do_uninstall ;;
esac

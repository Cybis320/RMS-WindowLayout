#!/bin/bash
# install.sh — deploy the RMS window-layout system on a station.
#
# What it does:
#   1. Installs dependencies (devilspie2, x11-utils, dconf-cli)
#   2. Imports the "StartCapture" gnome-terminal profile (fixed size/font)
#   3. Copies the layout scripts to ~/.config/devilspie2/
#   4. Installs autostart entries for devilspie2 and the layout watcher
#   5. Creates a "Realign Windows" desktop shortcut
#   6. Generates the initial layout and starts devilspie2 + the watcher
#
# Re-running it is safe (idempotent): existing pieces are refreshed in place.
#
# Usage: ./install.sh [chars_wide] [font_pixel_width]
#   chars_wide       - terminal column count   (default 229)
#   font_pixel_width - pixel width per char     (default 6)

set -u

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config/devilspie2"
AUTOSTART_DIR="$HOME/.config/autostart"
DESKTOP_DIR="$HOME/Desktop"
PROFILE_NAME="StartCapture"
PROFILES_PATH="/org/gnome/terminal/legacy/profiles:"

echo "=== RMS Window Layout Installer ==="
echo ""

# ---------------------------------------------------------------------------
# 1. Dependencies
# ---------------------------------------------------------------------------
need=()
command -v devilspie2 >/dev/null 2>&1 || need+=(devilspie2)
command -v xprop      >/dev/null 2>&1 || need+=(x11-utils)
command -v xdpyinfo   >/dev/null 2>&1 || need+=(x11-utils)
command -v dconf      >/dev/null 2>&1 || need+=(dconf-cli)
# de-duplicate
if [ ${#need[@]} -gt 0 ]; then
    mapfile -t need < <(printf '%s\n' "${need[@]}" | sort -u)
    echo "Installing dependencies: ${need[*]}"
    sudo apt-get update -qq || true
    sudo apt-get install -y "${need[@]}"
else
    echo "All dependencies already present."
fi

mkdir -p "$CONFIG_DIR" "$AUTOSTART_DIR"

# ---------------------------------------------------------------------------
# 2. Import the gnome-terminal "StartCapture" profile
# ---------------------------------------------------------------------------
# Portable UUID: /proc is always present on Linux; uuidgen (uuid-runtime) is not.
gen_uuid() {
    if [ -r /proc/sys/kernel/random/uuid ]; then
        cat /proc/sys/kernel/random/uuid
    elif command -v uuidgen >/dev/null 2>&1; then
        uuidgen
    else
        echo ""   # signal failure to caller
    fi
}

# Find the UUID of an existing profile whose visible-name is $PROFILE_NAME (if any).
find_profile_uuid() {
    local uuid name
    while read -r uuid; do
        [ -z "$uuid" ] && continue
        name="$(dconf read "$PROFILES_PATH/:$uuid/visible-name" 2>/dev/null || true)"
        if [ "$name" = "'$PROFILE_NAME'" ]; then echo "$uuid"; return 0; fi
    done < <(dconf list "$PROFILES_PATH/" 2>/dev/null | sed -n 's#^:\(.*\)/$#\1#p')
    return 1
}

import_profile() {
    if ! command -v dconf >/dev/null 2>&1; then
        echo "  WARNING: dconf not available — terminal profile NOT imported." >&2
        return
    fi
    if ! command -v gnome-terminal >/dev/null 2>&1; then
        echo "  Note: gnome-terminal not installed — importing the profile anyway." >&2
    fi

    # Already have a profile named "$PROFILE_NAME"? Just refresh its settings.
    local existing
    if existing="$(find_profile_uuid)"; then
        echo "  Terminal profile '$PROFILE_NAME' already exists (refreshing settings)."
        dconf load "$PROFILES_PATH/:$existing/" < "$REPO_DIR/profiles/StartCapture.dconf"
        return
    fi

    local new
    new="$(gen_uuid)"
    if [ -z "$new" ]; then
        echo "  ERROR: could not generate a UUID (no /proc/sys/kernel/random/uuid or uuidgen)." >&2
        echo "         Profile NOT imported. Install 'uuid-runtime' and re-run." >&2
        return
    fi

    dconf load "$PROFILES_PATH/:$new/" < "$REPO_DIR/profiles/StartCapture.dconf"

    local list
    list="$(dconf read "$PROFILES_PATH/list" 2>/dev/null || true)"
    if [ -z "$list" ] || [ "$list" = "@as []" ]; then
        dconf write "$PROFILES_PATH/list" "['$new']"
    else
        # turn  ['a', 'b']  into  ['a', 'b', 'NEW']
        dconf write "$PROFILES_PATH/list" "${list%]*}, '$new']"
    fi

    # Verify it actually landed in the profile list (the part that makes it
    # visible in Preferences and resolvable via --profile=StartCapture).
    if find_profile_uuid >/dev/null && dconf read "$PROFILES_PATH/list" | grep -q "$new"; then
        echo "  Created terminal profile '$PROFILE_NAME' ($new)."
    else
        echo "  ERROR: profile import did not take — '$PROFILE_NAME' is not in the profile list." >&2
        echo "         Check: dconf read $PROFILES_PATH/list" >&2
    fi
}
echo "Importing terminal profile..."
import_profile

# ---------------------------------------------------------------------------
# 3. Copy layout scripts
# ---------------------------------------------------------------------------
echo "Installing layout scripts to $CONFIG_DIR..."
install -m 0755 "$REPO_DIR/bin/generate_layout.sh"    "$CONFIG_DIR/generate_layout.sh"
install -m 0755 "$REPO_DIR/bin/realign_windows.sh"    "$CONFIG_DIR/realign_windows.sh"
install -m 0755 "$REPO_DIR/bin/rms-layout-watcher.sh" "$CONFIG_DIR/rms-layout-watcher.sh"
install -m 0644 "$REPO_DIR/desktop/RealignWindows.desktop" "$CONFIG_DIR/RealignWindows.desktop"
chmod +x "$CONFIG_DIR/RealignWindows.desktop"

# ---------------------------------------------------------------------------
# 4. Autostart entries (devilspie2 daemon + layout watcher)
# ---------------------------------------------------------------------------
echo "Installing autostart entries to $AUTOSTART_DIR..."
install -m 0644 "$REPO_DIR/desktop/devilspie2.desktop"         "$AUTOSTART_DIR/devilspie2.desktop"
install -m 0644 "$REPO_DIR/desktop/rms-layout-watcher.desktop" "$AUTOSTART_DIR/rms-layout-watcher.desktop"

# ---------------------------------------------------------------------------
# 5. Desktop shortcut
# ---------------------------------------------------------------------------
if [ -d "$DESKTOP_DIR" ]; then
    ln -sf "$CONFIG_DIR/RealignWindows.desktop" "$DESKTOP_DIR/RealignWindows.desktop"
    # Mark trusted so GNOME launches it without the "Untrusted" prompt
    gio set "$DESKTOP_DIR/RealignWindows.desktop" metadata::trusted true 2>/dev/null || true
    echo "Desktop shortcut: $DESKTOP_DIR/RealignWindows.desktop"
fi

# ---------------------------------------------------------------------------
# 6. Generate layout and (re)start daemon + watcher
# ---------------------------------------------------------------------------
echo ""
echo "Generating initial layout..."
"$CONFIG_DIR/generate_layout.sh" "$@" || {
    echo "Layout generation failed (no station .desktop files yet?)." >&2
    echo "Set up your station autostart entries, then run install.sh again." >&2
}

if [ -n "${DISPLAY:-}" ]; then
    echo "Starting devilspie2 and the layout watcher..."
    pkill devilspie2 2>/dev/null || true
    sleep 0.5
    devilspie2 >/dev/null 2>&1 &
    disown

    pkill -f rms-layout-watcher.sh 2>/dev/null || true
    sleep 0.5
    setsid "$CONFIG_DIR/rms-layout-watcher.sh" >/dev/null 2>&1 &
    disown
fi

echo ""
echo "=== Installation complete ==="
echo "  • devilspie2 and the layout watcher auto-start on login."
echo "  • The watcher re-aligns windows after reboot or GRMSUpdater restarts."
echo "  • Use the 'Realign Windows' desktop shortcut to re-apply manually."
echo "  • Watcher log: $CONFIG_DIR/watcher.log"

#!/bin/bash
# uninstall.sh — remove the RMS window-layout system.
# Leaves the gnome-terminal "StartCapture" profile in place by default
# (pass --remove-profile to delete it too).

set -u

CONFIG_DIR="$HOME/.config/devilspie2"
AUTOSTART_DIR="$HOME/.config/autostart"
DESKTOP_DIR="$HOME/Desktop"
PROFILE_NAME="StartCapture"
PROFILES_PATH="/org/gnome/terminal/legacy/profiles:"

echo "=== RMS Window Layout Uninstaller ==="

# Stop running processes
pkill -f rms-layout-watcher.sh 2>/dev/null || true
pkill devilspie2 2>/dev/null || true

# Remove autostart + shortcut + scripts
rm -f "$AUTOSTART_DIR/rms-layout-watcher.desktop"
rm -f "$AUTOSTART_DIR/devilspie2.desktop"
rm -f "$DESKTOP_DIR/RealignWindows.desktop"
rm -f "$CONFIG_DIR/generate_layout.sh" \
      "$CONFIG_DIR/realign_windows.sh" \
      "$CONFIG_DIR/rms-layout-watcher.sh" \
      "$CONFIG_DIR/RealignWindows.desktop" \
      "$CONFIG_DIR/rms_stations.lua" \
      "$CONFIG_DIR/watcher.log" \
      "$CONFIG_DIR/.watcher.lock"
rmdir "$CONFIG_DIR" 2>/dev/null || true
echo "Removed scripts, autostart entries, and desktop shortcut."

if [ "${1:-}" = "--remove-profile" ] && command -v dconf >/dev/null 2>&1; then
    while read -r uuid; do
        [ -z "$uuid" ] && continue
        name="$(dconf read "$PROFILES_PATH/:$uuid/visible-name" 2>/dev/null || true)"
        if [ "$name" = "'$PROFILE_NAME'" ]; then
            dconf reset -f "$PROFILES_PATH/:$uuid/"
            list="$(dconf read "$PROFILES_PATH/list" 2>/dev/null || true)"
            # drop this uuid from the list, tidy stray commas/spaces
            list="${list//\'$uuid\'/}"
            list="$(printf '%s' "$list" | sed -E "s/,[[:space:]]*,/,/g; s/\[[[:space:]]*,/[/; s/,[[:space:]]*\]/]/")"
            dconf write "$PROFILES_PATH/list" "$list"
            echo "Removed terminal profile '$PROFILE_NAME' ($uuid)."
        fi
    done < <(dconf list "$PROFILES_PATH/" 2>/dev/null | sed -n 's#^:\(.*\)/$#\1#p')
fi

echo "Done. (devilspie2 package not removed — apt remove devilspie2 if desired.)"

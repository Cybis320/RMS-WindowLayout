#!/bin/bash
# Regenerate devilspie2 layout and restart the daemon.
# Can be run from desktop shortcut, command line, or the layout watcher.
# Usage: realign_windows.sh [chars_wide] [font_pixel_width]

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Regenerate the layout
"$SCRIPT_DIR/generate_layout.sh" "$@"

# Restart devilspie2, apply twice to overcome window manager fighting placement
pkill devilspie2 2>/dev/null
sleep 0.5
devilspie2 &
disown
sleep 1.5

# Second pass — kill and restart so it re-applies to all existing windows
pkill devilspie2 2>/dev/null
sleep 0.5
devilspie2 &
disown

echo "devilspie2 restarted with new layout (applied twice)."

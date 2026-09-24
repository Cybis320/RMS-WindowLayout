#!/bin/bash
# Kept so the old one-liner keeps working:
#
#   curl -fsSL https://raw.githubusercontent.com/Cybis320/RMS-WindowLayout/master/bootstrap.sh | bash
#
# It now hands over to install.sh, which installs into ~/source/CC_Utils/window_layout
# (moving an existing ~/source/RMS-WindowLayout clone there). RMS_WL_DIR is still
# honored as the checkout location.

set -eu

[ -n "${RMS_WL_DIR:-}" ] && export CC_DEST="$RMS_WL_DIR"

SELF="${BASH_SOURCE[0]:-}"
if [ -n "$SELF" ] && [ -f "$(dirname "$SELF")/install.sh" ]; then
    exec bash "$(dirname "$SELF")/install.sh" "$@"
fi
curl -fsSL https://raw.githubusercontent.com/Cybis320/RMS-WindowLayout/master/install.sh | bash -s -- "$@"

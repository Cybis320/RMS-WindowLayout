#!/bin/bash
# One-line installer bootstrap for RMS-WindowLayout.
#
#   curl -fsSL https://raw.githubusercontent.com/Cybis320/RMS-WindowLayout/master/bootstrap.sh | bash
#
# Clones the repo (or updates an existing clone), then runs install.sh.
# Any arguments are forwarded to install.sh, e.g. to tune terminal width:
#
#   curl -fsSL .../bootstrap.sh | bash -s -- 229 6
#
# Override the clone location with RMS_WL_DIR (default: ~/source/RMS-WindowLayout).

set -eu

REPO_URL="https://github.com/Cybis320/RMS-WindowLayout.git"
DEST="${RMS_WL_DIR:-$HOME/source/RMS-WindowLayout}"

if ! command -v git >/dev/null 2>&1; then
    echo "git is required. Install it first:  sudo apt-get install -y git" >&2
    exit 1
fi

if [ -d "$DEST/.git" ]; then
    echo "Updating existing clone in $DEST..."
    git -C "$DEST" pull --ff-only
else
    echo "Cloning RMS-WindowLayout into $DEST..."
    mkdir -p "$(dirname "$DEST")"
    git clone "$REPO_URL" "$DEST"
fi

cd "$DEST"
exec ./install.sh "$@"

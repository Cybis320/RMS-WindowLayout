#!/usr/bin/env bash
#
# One-line install / update of the RMS window layout into ~/source/CC_Utils/window_layout:
#
#   curl -fsSL https://raw.githubusercontent.com/Cybis320/RMS-WindowLayout/master/install.sh | bash
#   curl -fsSL .../install.sh | bash -s -- 229 6      # terminal columns, font px
#
# Same command on every CC RMS utility. Idempotent: re-run it any time.
# Overrides: CC_DEST (checkout), CC_BRANCH, CC_REPO_URL.
#
set -euo pipefail

REPO_URL="${CC_REPO_URL:-https://github.com/Cybis320/RMS-WindowLayout.git}"
BRANCH="${CC_BRANCH:-master}"
DEST="${CC_DEST:-$HOME/source/CC_Utils/window_layout}"
SETUP="scripts/setup.sh"

# Run from a checkout (./install.sh): set up that checkout as is.
SELF="${BASH_SOURCE[0]:-}"
if [ -n "$SELF" ] && [ -f "$SELF" ]; then
    HERE="$(cd "$(dirname "$SELF")" && pwd)"
    if [ -f "$HERE/$SETUP" ]; then
        exec bash "$HERE/$SETUP" "$@"
    fi
fi

# Piped from curl: clone or update the checkout, then run its setup.
command -v git >/dev/null 2>&1 || { echo "git is required: sudo apt-get install -y git" >&2; exit 1; }
# Older installs lived at $HOME/source/RMS-WindowLayout; move that checkout (with any local files
# in it) into CC_Utils instead of leaving a second copy behind.
OLD="$HOME/source/RMS-WindowLayout"
if [ ! -e "$DEST" ] && [ -d "$OLD/.git" ]; then
    echo "Moving $OLD -> $DEST"
    mkdir -p "$(dirname "$DEST")"
    mv "$OLD" "$DEST"
fi
if [ -d "$DEST/.git" ]; then
    echo "Updating $DEST"
    if ! { git -C "$DEST" fetch --quiet origin "$BRANCH" \
            && git -C "$DEST" merge --ff-only --quiet "origin/$BRANCH"; }; then
        echo "WARNING: could not fast-forward $DEST (offline, or local changes); using it as is." >&2
    fi
else
    echo "Cloning $REPO_URL -> $DEST"
    mkdir -p "$(dirname "$DEST")"
    git clone --quiet --branch "$BRANCH" "$REPO_URL" "$DEST"
fi
if [ ! -f "$DEST/$SETUP" ]; then
    echo "ERROR: $DEST predates this installer and could not be updated." >&2
    echo "       See: git -C $DEST status   (then re-run this command)" >&2
    exit 1
fi
exec bash "$DEST/$SETUP" "$@"

#!/bin/bash
# Run by the cc-utils hourly updater after it pulls new code: as the user,
# unattended, with no display. Refreshes the installed scripts and launchers.
#
# Deliberately NOT done here: apt packages, the terminal profile, regenerating
# the layout (it may have been generated with custom columns/font), and
# restarting devilspie2 or the watcher. The running watcher keeps its old code
# until the next login; re-run install.sh to apply everything at once.
set -eu

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Uninstalled (or never installed) on this box: leave it that way.
[ -f "$HOME/.config/devilspie2/rms-layout-watcher.sh" ] || exit 0

"$REPO_DIR/scripts/install-files.sh" --unattended

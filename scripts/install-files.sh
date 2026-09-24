#!/bin/bash
# install-files.sh -- put the layout scripts and launchers in place.
#
#   install-files.sh              (setup.sh) install / overwrite everything
#   install-files.sh --unattended (post-update.sh) refresh only files still
#                                 exactly as shipped: a file someone edited in
#                                 place (the README invites tuning the watcher
#                                 entry and generate_layout.sh) is left alone
#
# Only files whose content changed are rewritten. Scripts are replaced
# atomically (new inode) because the layout watcher is a long-running bash
# script: bash reads its script as it goes, so rewriting it in place would
# corrupt the running copy. Launchers are rewritten in place so the Desktop
# shortcut keeps its GNOME "trusted" mark.

set -eu

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="$HOME/.config/devilspie2"
AUTOSTART_DIR="$HOME/.config/autostart"
UNATTENDED=0
[ "${1:-}" = "--unattended" ] && UNATTENDED=1
CC_TOOL=window_layout
# shellcheck source=../cc-utils/lib.sh
. "$REPO_DIR/cc-utils/lib.sh"

mkdir -p "$CONFIG_DIR" "$AUTOSTART_DIR"

# Launchers carry the checkout's icon.png (absolute path) in the shared style.
render_entry() { sed "s|^Icon=.*|Icon=$REPO_DIR/icon.png|"; }

# True when installed file $1 is byte-identical to some committed version of
# repo path $2, as installed (raw, or for launchers also icon-rendered).
shipped() {
    local dst="$1" path="$2" have c
    [ -f "$dst" ] || return 0
    have="$(git hash-object "$dst")"
    for c in $(git -C "$REPO_DIR" log --format=%H -- "$path"); do
        [ "$(git -C "$REPO_DIR" rev-parse -q --verify "$c:$path" 2>/dev/null)" = "$have" ] && return 0
        case "$path" in
            *.desktop)
                [ "$(git -C "$REPO_DIR" show "$c:$path" 2>/dev/null | render_entry | git hash-object --stdin)" = "$have" ] \
                    && return 0 ;;
        esac
    done
    return 1
}

customized() {
    if [ "$UNATTENDED" = "1" ] && ! shipped "$1" "$2"; then
        echo "  kept $1 (edited locally; re-run install.sh to replace it)"
        return 0
    fi
    return 1
}

put_script() {
    local src="$REPO_DIR/bin/$1" dst="$CONFIG_DIR/$1" tmp
    cmp -s "$src" "$dst" && return 0
    customized "$dst" "bin/$1" && return 0
    tmp="$(mktemp "$dst.XXXXXX")"
    cp "$src" "$tmp" && chmod 0755 "$tmp" && mv -f "$tmp" "$dst"
    echo "  updated $dst"
}

put_entry() {
    local dst="$2/$1"
    [ -f "$dst" ] && render_entry <"$REPO_DIR/desktop/$1" | cmp -s - "$dst" && return 0
    customized "$dst" "desktop/$1" && return 0
    render_entry <"$REPO_DIR/desktop/$1" | cc_write_if_changed "$dst" || true
    echo "  updated $dst"
}

put_script generate_layout.sh
put_script realign_windows.sh
put_script rms-layout-watcher.sh
put_entry RealignWindows.desktop "$CONFIG_DIR"
chmod +x "$CONFIG_DIR/RealignWindows.desktop"
put_entry devilspie2.desktop "$AUTOSTART_DIR"
put_entry rms-layout-watcher.desktop "$AUTOSTART_DIR"

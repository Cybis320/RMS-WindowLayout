#!/bin/bash
# rms-layout-watcher.sh — re-apply the RMS window layout whenever a station or
# utility window (re)appears: after login/reboot autostart, after
# GRMSUpdater.sh restarts the stations, or after a manual relaunch.
#
# It is deliberately decoupled from RMS: it watches the X11 window list and
# reacts to *new* windows whose title matches an entry in the generated
# rms_stations.lua layout. When a new one shows up it waits for the burst to
# settle (so all 6 stations coalesce into a single realign) and then calls
# realign_windows.sh, which regenerates the layout and re-applies devilspie2.
#
# Uses only xprop (x11-utils) — no wmctrl/xdotool dependency.
#
# Tunables (override via environment):
#   RMS_LAYOUT_POLL      seconds between window-list polls            (default 3)
#   RMS_LAYOUT_DEBOUNCE  quiet seconds after the last new window      (default 6)
#   RMS_LAYOUT_STARTUP   delay before the initial apply at login      (default 12)

set -u

CONFIG_DIR="$HOME/.config/devilspie2"
REALIGN="$CONFIG_DIR/realign_windows.sh"
LUA="$CONFIG_DIR/rms_stations.lua"
LOG="$CONFIG_DIR/watcher.log"
LOCK="$CONFIG_DIR/.watcher.lock"

POLL=${RMS_LAYOUT_POLL:-3}
DEBOUNCE=${RMS_LAYOUT_DEBOUNCE:-6}
STARTUP=${RMS_LAYOUT_STARTUP:-12}

# --- single instance ------------------------------------------------------
exec 9>"$LOCK"
if ! flock -n 9; then
    echo "$(date '+%F %T') another watcher instance is already running — exiting" >> "$LOG"
    exit 0
fi

log() { echo "$(date '+%F %T') $*" >> "$LOG"; }

# Trim the log so it can't grow without bound across reboots.
if [ -f "$LOG" ] && [ "$(wc -l < "$LOG" 2>/dev/null || echo 0)" -gt 2000 ]; then
    tail -n 500 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"
fi
log "watcher starting (poll=${POLL}s debounce=${DEBOUNCE}s)"

# --- wait for the X server ------------------------------------------------
until xset q >/dev/null 2>&1; do sleep 3; done

# Titles the layout cares about, as exact strings (keys of the lua positions
# table). Re-read every poll so adding stations + a realign is picked up live.
relevant_titles() {
    [ -f "$LUA" ] || return 0
    grep -oP '(?<=\[")[^"]+(?="\])' "$LUA" 2>/dev/null
}

# Currently-open window titles that exactly match a relevant title, sorted.
# Returns non-zero (without output) if the X window list can't be read, so a
# transient query failure isn't mistaken for "every window closed".
current_relevant() {
    local titles ids id name
    titles="$(relevant_titles)"
    [ -z "$titles" ] && return 0
    # _NET_CLIENT_LIST(WINDOW): window id # 0x..., 0x..., ...
    ids="$(xprop -root _NET_CLIENT_LIST 2>/dev/null | sed 's/.*# //; s/,//g')"
    [ -z "$ids" ] && return 1
    for id in $ids; do
        name="$(xprop -id "$id" _NET_WM_NAME 2>/dev/null | sed -n 's/^_NET_WM_NAME[^"]*"\(.*\)"$/\1/p')"
        [ -z "$name" ] && name="$(xprop -id "$id" WM_NAME 2>/dev/null | sed -n 's/^WM_NAME[^"]*"\(.*\)"$/\1/p')"
        [ -z "$name" ] && continue
        grep -qxF "$name" <<<"$titles" && echo "$name"
    done | sort -u
}

# --- initial apply at login ----------------------------------------------
sleep "$STARTUP"
log "initial realign"
"$REALIGN" >/dev/null 2>&1
prev="$(current_relevant)"
log "initial station windows: $(echo $prev)"

# --- main loop ------------------------------------------------------------
pending=0
while sleep "$POLL"; do
    # Skip the cycle if the window list can't be read right now (transient).
    cur="$(current_relevant)" || continue

    if [ "$cur" != "$prev" ]; then
        # Anything present now that wasn't before == a (re)started window.
        new="$(comm -13 <(printf '%s\n' "$prev") <(printf '%s\n' "$cur") 2>/dev/null | grep -v '^$')"
        if [ -n "$new" ]; then
            log "new window(s): $(echo $new) — scheduling realign"
            pending=$DEBOUNCE
        fi
        prev="$cur"
    fi

    if [ "$pending" -gt 0 ]; then
        pending=$(( pending - POLL ))
        if [ "$pending" -le 0 ]; then
            log "realigning after settle"
            "$REALIGN" >/dev/null 2>&1
            pending=0
            prev="$(current_relevant)"
        fi
    fi
done

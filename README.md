# RMS Window Layout

Neatly tile the terminal windows of a multi-camera [RMS](https://github.com/CroatianMeteorNetwork/RMS)
station so every capture window lands in a fixed, predictable spot — and **stays
there automatically** after a reboot or after `GRMSUpdater.sh` restarts the
stations.

It combines three pieces:

1. A **gnome-terminal profile** (`StartCapture`) that gives every capture window
   a fixed size and font, so they tile cleanly.
2. A **[devilspie2](https://www.nongnu.org/devilspie2/) layout** generated from
   your station autostart entries and your screen size — one row per station,
   utilities and plots stacked to the side.
3. A small **layout watcher** that re-applies the layout whenever a station
   window (re)appears, with no changes to RMS itself.

## Quick start

```bash
git clone <this-repo> RMS-WindowLayout
cd RMS-WindowLayout
./install.sh
```

That's it. The installer pulls dependencies, imports the terminal profile, lays
out the windows, and arms everything to run on login. Re-running `install.sh`
is safe and just refreshes the install.

Optional tuning of terminal width (column count and pixel-per-char):

```bash
./install.sh 229 6      # chars_wide font_pixel_width  (these are the defaults)
```

## How auto-realign works

The watcher (`rms-layout-watcher.sh`, started from autostart) polls the X11
window list with `xprop` and reacts only to *new* windows whose title matches an
entry in the generated layout (e.g. `US005A`…`US005F`, `ChronyMon`,
`Pyranometer`). When one shows up it waits for the burst to settle — so all six
stations coming up at once coalesce into a single realign — then runs
`realign_windows.sh`, which regenerates the layout and re-applies devilspie2
twice (the second pass beats the window manager fighting placement).

This covers every restart path uniformly:

| Trigger                          | What happens |
|----------------------------------|--------------|
| **Reboot / login**               | Autostart launches devilspie2 + the watcher; the watcher does one initial align, then catches each station window as it opens. |
| **`GRMSUpdater.sh` restart**     | GRMSUpdater relaunches the stations in new terminals; the watcher sees the new windows and realigns once they're all up. |
| **Manual relaunch of a station** | Same — the new window is detected and the layout re-applied. |
| **Manual, on demand**            | Double-click the **Realign Windows** desktop shortcut. |

The realign trigger needs **no changes to RMS** — the watcher reacts purely to
windows appearing.

### Recommended: tell GRMSUpdater which terminal profile to use

The watcher fixes window *position and size*, but on the `GRMSUpdater.sh`
restart path the terminals still inherit gnome-terminal's *default* profile
unless told otherwise (the login autostart entries pass `--profile=StartCapture`,
but GRMSUpdater historically did not). That means GRMSUpdater-restarted windows
can come up with the wrong font/colors/column-fit.

If your RMS includes the GRMSUpdater `--profile` flag, add it to the capture
user's cron so restarts match the login look:

```cron
0 2 * * * /home/<user>/source/RMS/Scripts/MultiCamLinux/GRMSUpdater.sh \
          --term gnome-terminal --profile StartCapture --force
```

It's safe to pass everywhere: gnome-terminal warns and falls back to its default
if the `StartCapture` profile is missing, and other terminals (`lxterminal`,
`kitty`, `foot`, `tmux`) ignore it.

## What gets installed

| Path | Purpose |
|------|---------|
| `~/.config/devilspie2/generate_layout.sh`     | Builds `rms_stations.lua` from autostart `.desktop` files + screen size. |
| `~/.config/devilspie2/realign_windows.sh`     | Regenerates layout and restarts devilspie2 (used by the shortcut and watcher). |
| `~/.config/devilspie2/rms-layout-watcher.sh`  | Background watcher that triggers realign on new station windows. |
| `~/.config/devilspie2/rms_stations.lua`       | Generated layout (positions per window title). |
| `~/.config/autostart/devilspie2.desktop`      | Starts the devilspie2 daemon on login. |
| `~/.config/autostart/rms-layout-watcher.desktop` | Starts the watcher on login. |
| `~/Desktop/RealignWindows.desktop`            | Manual "Realign Windows" shortcut. |
| gnome-terminal profile `StartCapture`         | Fixed window size/font for capture terminals. |

The watcher logs to `~/.config/devilspie2/watcher.log`.

## Requirements

- A station whose capture terminals are launched with a **distinct
  `--title`** (e.g. `gnome-terminal --profile=StartCapture --title=US005A …`),
  which is the standard RMS multi-cam autostart pattern. The layout keys off
  those titles.
- X11 (the layout tooling uses `xprop` / `xdpyinfo` / `devilspie2`; Wayland is
  not supported).
- Installed automatically if missing: `devilspie2`, `x11-utils`, `dconf-cli`.

## Customizing

- **Stations / utilities**: add the station's autostart `.desktop` (with a
  `--title`), then run `~/.config/devilspie2/generate_layout.sh` and click
  *Realign Windows* (or just re-run `./install.sh`).
- **Watcher timing**: override env vars in
  `~/.config/autostart/rms-layout-watcher.desktop`:
  `RMS_LAYOUT_POLL`, `RMS_LAYOUT_DEBOUNCE`, `RMS_LAYOUT_STARTUP`.
- **Layout math** (gaps, top-bar height, utility column): edit
  `generate_layout.sh`.

## Uninstall

```bash
./uninstall.sh                  # remove scripts, autostart, shortcut
./uninstall.sh --remove-profile # also delete the StartCapture terminal profile
```

The `devilspie2` package itself is left installed.

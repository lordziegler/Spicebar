# Spicebar

> *"He who controls the spice controls the universe."*
> — Baron Vladimir Harkonnen

A waybar configuration for [niri](https://github.com/YaLTeR/niri), built for the **Imperator** theme — an amber CRT aesthetic inspired by ten thousand years of Corrino imperial records and my personal touch.

The bar is minimal by design. Everything earns its place on the screen.

---

#### Showcase

![Waybar with Coat of Arms](assets/screenshots/idle.png)

![Waybar with Active Pomodoro Timer](assets/screenshots/pomodoro-work.png)

![Waybar with Active Rest Pomodoro Timer](assets/screenshots/pomodoro-break.png)
---
## Features

### Pomodoro — the coat of arms transforms

The left anchor of the bar is a coat of arms image at rest.
Click it and it becomes a timer. The coat of arms does not disappear — it *becomes* something useful.

- **Left click** — start / pause
- **Right click** — reset
- **Middle click** — skip phase

| Phase | Indicator | Duration |
|---|---|---|
| Work | barley icon · gold glow | 25 min |
| Short break | coffee icon · green glow | 5 min |
| Long break | coffee icon · green glow | 15 min |

State is stored as a timestamp file (`/tmp/.pomodoro`). No daemon. No background process. The remaining time is computed from `duration − (now − start_epoch)` on every poll.

### Planetary workspaces

Workspaces are mapped to astronomical symbols. The active planet glows gold.

| Workspace | Symbol | Body |
|---|---|---|
| 1 | ☉ | Sun |
| 2 | ☽ | Moon |
| 3 | ♂ | Mars |
| 4 | ☿ | Mercury |
| 5 | ♃ | Jupiter |
| 6 | ♄ | Saturn |
| 7 | ♅ | Uranus |
| 8 | ♆ | Neptune |
| 9 | ♇ | Pluto |
| 10 | ⊕ | Earth |

Icons use layered `text-shadow` to simulate stroke weight — the symbols are inherently thin glyphs; the shadows give them presence without changing the font.

### Modules — right to left

| Module | Notes |
|---|---|
| CPU | 4-core bar graph using block characters (`▏▎▍▌▋▊█`) |
| Network | WiFi / ethernet / disconnected via `nm-connection-editor` |
| Bluetooth | `blueman-manager` on click |
| PulseAudio | Volume icon; `pavucontrol` on click |
| SwayNC | Notification count + DND toggle |
| Battery | Icon-only with warning/critical blink. Left-click opens the power profile manager (floating TUI); right-click toggles percentage display |
| Clock | `HH:MM`; left-click for full date; **right-click opens calendar** |
| Power | `wlogout` layer-shell |

### Otium / Officium — vault anchor

A permanent module between the pomodoro and the music player. Reads the first open task (`- [ ]`) from the Obsidian vault and displays it. When there are no pending tasks it shows ♁ alone.

- **Left click** — open Obsidian vault
- **Middle click** — GitHub contributions graph (floating Kitty window)
- **Right click** — weather dashboard via wttr.in (floating Kitty window, auto-detects location by IP)

### Canticulum — MPRIS

Music module. Only visible when a player is active. Shows play/pause icon + artist — title. Collapses to zero width when nothing is playing.

- **Left click** — play / pause
- **Right click** — next track
- **Middle click** — toggle compact mode (icon only)
- **Scroll** — next / previous track

### Calendar — Outlook.com via calcurse

Right-click the clock to open `calcurse` in a floating Kitty terminal. Events are synced from Outlook.com every 30 minutes via a systemd user timer — no persistent daemon. Open tasks from the Obsidian vault (`02-Areae/Vita/`) are written to the calcurse todo list on every open.

Colors are applied as Kitty overrides using the Imperator palette — no calcurse color config needed.

### Power — power-profiles-daemon

Left-click the battery icon to open a floating Kitty window with a small `fzf`-based
TUI: a header with current charge/status/time-remaining (via `upower`), and a picker
for the three `power-profiles-daemon` profiles (Performance / Balanced / Power Saver),
marking the active one. Selecting a different profile applies it immediately via
`powerprofilesctl set` and fires a notification.

Right-click keeps the previous behavior — toggling the battery percentage in the bar.

---

## Installation

```bash
# 1. Run the bootstrap script (handles symlinks, systemd timer, and initial sync)
bash setup.sh
```

`setup.sh` will:
- Install missing packages via `sudo pacman -S --needed`
- Symlink all configs to their target locations under `~/.config/`
- Prompt for your Outlook.com ICS URL on first run and save it to `~/.config/vdirsyncer/secrets` (mode 600, never committed)
- Generate the vdirsyncer config and write the calcurse conf
- Enable and start the `vdirsyncer.timer` systemd user unit
- Run the initial calendar sync
- Inject the niri floating window rules into `~/.config/niri/rules.kdl` if not already present
- Restart waybar

**Getting your Outlook.com ICS URL:**
1. Go to [outlook.live.com](https://outlook.live.com) → ⚙️ Settings → View all Outlook settings
2. Calendar → Shared calendars → Publish a calendar
3. Select your calendar → Publish → copy the **ICS** link

---

## Dependencies

| Package | Role |
|---|---|
| `waybar` | The bar itself |
| `niri` | Compositor — provides `niri/workspaces` |
| `swaync` + `swaync-client` | Notification center |
| `playerctl` | MPRIS media control |
| `nm-connection-editor` | Network manager GUI |
| `blueman` | Bluetooth manager GUI |
| `pavucontrol` | PulseAudio volume GUI |
| `wlogout` | Power menu |
| `notify-send` | Pomodoro phase notifications |
| `calcurse` | TUI calendar (calendar feature) |
| `vdirsyncer` | iCal sync from Outlook.com (calendar feature) |
| `gh` | GitHub CLI — contributions graph |
| `curl` | Weather dashboard via wttr.in |
| `power-profiles-daemon` | Power profile switching (battery left-click) |
| `fzf` | TUI picker for the power profile manager |
| `upower` | Battery status (percentage, state, time remaining) |
| `kitty` | Terminal for floating windows |
| `obsidian` | Vault — task display in otium (optional, AUR) |
| JetBrains Mono Nerd Font | Primary font |
| Symbols Nerd Font | Icon glyphs (wifi, battery, bluetooth…) |

---

## Fonts

All icons that require precise glyph control are wrapped in `<span font='Symbols Nerd Font N'>` Pango markup. This forces monochrome rendering and makes them respect the CSS `color` property — preventing the system emoji font from overriding them with color glyphs.

The Pango approach is used consistently for:
- Network, bluetooth, pulseaudio, battery icons in `config.jsonc`
- Pomodoro phase icons output by `pomodoro.sh`
- SwayNC bell icon output by `swaync.sh`

---

## Palette

Drawn from the Imperator theme. Defined as `@define-color` variables at the top of `style.css`.

```
bar background    rgba(14, 12, 8, 0.68)   frosted — compositor blurs behind it
foreground        #D4A843                  amber CRT phosphor
accent gold       #FFD700                  active elements
muted             #a89984                  inactive / disconnected
power red         #fb4934                  critical states
```

---

## Part of Imperator

The amber palette, the CRT aesthetic, and the planetary motif run through every component.

---

## Acknowledgements

**[vdawg-git/space_dots](https://github.com/vdawg-git/space_dots)** — the waybar layout and module philosophy here drew direct inspiration from this configuration. The approach of treating each module as a deliberate design decision, not a default, comes from studying that work.

---

## Bibliography

- [Waybar wiki](https://github.com/Alexays/Waybar/wiki) — module reference and configuration format
- [Niri window rules](https://github.com/YaLTeR/niri/wiki/Configuration:-Window-Rules) — floating window configuration
- [vdirsyncer docs](https://vdirsyncer.pimutils.org/) — CalDAV/iCal sync daemon
- [calcurse manual](https://calcurse.org/files/manual.html) — TUI calendar configuration and import format
- [wttr.in](https://wttr.in/:help) — terminal weather service
- [Pango markup](https://docs.gtk.org/Pango/pango_markup.html) — `<span>` font and color control used throughout `config.jsonc`
- [vdawg-git/space_dots](https://github.com/vdawg-git/space_dots) — waybar dotfiles that inspired this configuration

# Spicebar

> *"He who controls the spice controls the universe."*
> — Baron Vladimir Harkonnen

A waybar configuration for [niri](https://github.com/YaLTeR/niri), built for the **Imperator** theme — an amber CRT aesthetic inspired by ten thousand years of Corrino imperial records and my personal touch.

The bar is minimal by design. Everything earns its place on the screen.

---

#### Showcase

![Waybar with Coat of Arms](<Screenshot 2026-06-23 20-25-05.png>)

![Waybar with Active Pomodoro Timer](<Screenshot 2026-06-23 20-11-53.png>)

![Waybar with Active Rest Pomodoro Timer](<Screenshot 2026-06-23 20-24-47.png>)
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
| Battery | Icon-only with warning/critical blink |
| Clock | `HH:MM`; left-click for full date; **right-click opens calendar** |
| Power | `wlogout` layer-shell |

### MPRIS

Media module on the left. Shows artist — title with play/pause/next/prev on scroll and click.

### Calendar — Outlook.com via khal

Right-click the clock to open `khal interactive` in a floating Kitty terminal. Events are synced from Outlook.com every 30 minutes via a systemd user timer — no persistent daemon.

Colors inherit from Kitty's Gruvbox Hard Dark theme. No palette is hardcoded.

---

## Installation

```bash
# 1. Run the bootstrap script (handles symlinks, systemd timer, and initial sync)
bash setup.sh
```

`setup.sh` will:
- Verify that `khal` and `vdirsyncer` are installed (`sudo pacman -S khal vdirsyncer`)
- Prompt for your Outlook.com iCal URL on first run and save it to `~/.config/vdirsyncer/secrets` (mode 600, never committed)
- Symlink all configs to their target locations under `~/.config/`
- Enable and start the `vdirsyncer.timer` systemd user unit
- Run the initial calendar sync

**Getting your Outlook.com iCal URL:**
1. Go to [outlook.live.com](https://outlook.live.com) → ⚙️ Settings → View all Outlook settings
2. Calendar → Shared calendars → Publish a calendar
3. Select your calendar → Publish → copy the **ICS** link

**Niri floating window rule** — add to `~/.config/niri/rules.kdl` (or equivalent):
```kdl
window-rule {
    match app-id="khal-float"
    open-floating true
    default-column-width { fixed 900; }
    default-window-height { fixed 550; }
}
```

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
| `khal` | TUI calendar (calendar feature) |
| `vdirsyncer` | iCal sync from Outlook.com (calendar feature) |
| `kitty` | Terminal for calendar floating window |
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

The amber palette, the CRT aesthetic, and the planetary motif run through every componen.

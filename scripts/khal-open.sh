#!/usr/bin/env bash
# Opens calcurse in a floating Kitty window using the synced Outlook calendars.
# Remaps ANSI colors inside this window to the Imperator palette instead of
# relying on calcurse's internal color scheme (which hardcodes red for dark mode).

DATA_DIR="$HOME/.local/share/calcurse-outlook"

if ! command -v calcurse &>/dev/null; then
    notify-send -u critical "Calendar" "calcurse not found — install with: sudo pacman -S calcurse"
    exit 1
fi

if [[ ! -d "$DATA_DIR" || ! -f "$DATA_DIR/apts" ]]; then
    notify-send -u normal "Calendar" "No events yet — run setup.sh to sync"
fi

# color1/9  = ANSI red   → amber  (borders, text, status bar highlight)
# color6/14 = ANSI cyan  → muted gold  (calendar day headers)
# color3/11 = ANSI yellow → bright gold (selected date — already close)
exec kitty \
    --app-id khal-float \
    --title "Calendar" \
    --override "background=#0E0C08" \
    --override "foreground=#D4A843" \
    --override "color1=#D4A843" \
    --override "color9=#FFD700" \
    --override "color6=#C8960C" \
    --override "color14=#F0B030" \
    --override "color3=#FFD700" \
    --override "color11=#FFD700" \
    calcurse -D "$DATA_DIR"

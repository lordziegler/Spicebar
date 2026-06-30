#!/usr/bin/env bash
# Opens calcurse in a floating Kitty window using the synced Outlook calendars.

DATA_DIR="$HOME/.local/share/calcurse-outlook"

if ! command -v calcurse &>/dev/null; then
    notify-send -u critical "Calendar" "calcurse not found — install with: sudo pacman -S calcurse"
    exit 1
fi

if [[ ! -d "$DATA_DIR" || ! -f "$DATA_DIR/apts" ]]; then
    notify-send -u normal "Calendar" "No events yet — run setup.sh to sync"
fi

exec kitty --app-id khal-float --title "Calendar" calcurse -D "$DATA_DIR"

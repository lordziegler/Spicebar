#!/usr/bin/env bash
# Opens khal interactive in a floating Kitty window.
# Notifies if khal is not installed or no calendars are synced yet.

if ! command -v khal &>/dev/null; then
    notify-send -u critical "Calendar" "khal not found — install with: sudo pacman -S khal"
    exit 1
fi

if [[ ! -f "$HOME/.config/khal/config" ]]; then
    notify-send -u critical "Calendar" "khal config not found — run setup.sh"
    exit 1
fi

if [[ ! -d "$HOME/.calendars/outlook" || -z "$(ls -A "$HOME/.calendars/outlook" 2>/dev/null)" ]]; then
    notify-send -u normal "Calendar" "No events — run setup.sh to sync Outlook"
fi

exec kitty --app-id khal-float --title "Calendar" khal interactive

#!/usr/bin/env bash
# Imports all vdirsyncer ICS files into a dedicated calcurse data directory.
# Called automatically after vdirsyncer sync.

DATA_DIR="$HOME/.local/share/calcurse-outlook"
CALENDARS_DIR="$HOME/.calendars"

mkdir -p "$DATA_DIR"

# Reset appointments (read-only view — source of truth is Outlook)
> "$DATA_DIR/apts"

# Import every .ics event file from all calendar directories
for dir in "$CALENDARS_DIR"/*/; do
    for ics in "$dir"*.ics; do
        [[ -f "$ics" ]] && calcurse -D "$DATA_DIR" --import "$ics" 2>/dev/null
    done
done

#!/usr/bin/env bash
# Imports all vdirsyncer ICS files into a dedicated calcurse data directory.
# Called automatically after vdirsyncer sync.

DATA_DIR="$HOME/.local/share/calcurse-outlook"
CALENDARS_DIR="$HOME/.calendars"

mkdir -p "$DATA_DIR"

# Reset appointments (read-only view — source of truth is Outlook)
> "$DATA_DIR/apts"

# Import every .ics file. Strip Microsoft Windows TZID (e.g. "SA Pacific Standard
# Time") so calcurse treats times as floating/local — the ICS timezone matches the
# system zone, so the raw times are correct without conversion.
tmp=$(mktemp)
for dir in "$CALENDARS_DIR"/*/; do
    for ics in "$dir"*.ics; do
        [[ -f "$ics" ]] || continue
        sed 's/;TZID=[^:]*//g' "$ics" > "$tmp"
        calcurse -D "$DATA_DIR" --import "$tmp" 2>/dev/null || true
    done
done
rm -f "$tmp"

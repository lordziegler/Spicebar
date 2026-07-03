#!/usr/bin/env bash
# Imports all vdirsyncer ICS files into a dedicated calcurse data directory.
# Called automatically after vdirsyncer sync.

DATA_DIR="$HOME/.local/share/calcurse-outlook"
CALENDARS_DIR="$HOME/.calendars"

mkdir -p "$DATA_DIR"

# Reset appointments (read-only view — source of truth is Outlook)
> "$DATA_DIR/apts"

# Import every .ics file with two preprocessing steps:
# 1. Drop RECURRENCE-ID exception blocks — calcurse imports them as standalone events
#    on top of the master recurring entry, creating duplicates on modified days.
# 2. Strip Windows TZID names — calcurse doesn't recognise "SA Pacific Standard Time"
#    and would subtract the local offset a second time; floating times are correct.
tmp=$(mktemp)
for dir in "$CALENDARS_DIR"/*/; do
    for ics in "$dir"*.ics; do
        [[ -f "$ics" ]] || continue
        tr -d '\r' < "$ics" | awk '
            /^BEGIN:VEVENT$/ { buf="BEGIN:VEVENT\n"; skip=0; next }
            buf && /RECURRENCE-ID/  { skip=1 }
            buf && /^END:VEVENT$/   { if (!skip) printf "%sEND:VEVENT\n", buf; buf=""; next }
            buf                     { buf=buf $0 "\n"; next }
            { print }
        ' | sed 's/;TZID=[^:]*//g' > "$tmp"
        calcurse -D "$DATA_DIR" --import "$tmp" 2>/dev/null || true
    done
done
rm -f "$tmp"

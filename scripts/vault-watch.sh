#!/usr/bin/env bash
# Watches the Obsidian vault for .md changes and signals waybar to refresh otium.
VAULT="$HOME/Documents/Cerebrum_Secundum"

inotifywait -q -m -r -e modify,create,delete,moved_to \
    --include '\.md$' \
    "$VAULT/01-Incepta" "$VAULT/02-Areae/Vita" 2>/dev/null \
    | while IFS= read -r _; do
        pkill -RTMIN+14 waybar 2>/dev/null || true
    done

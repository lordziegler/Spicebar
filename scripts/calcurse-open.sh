#!/usr/bin/env bash
# Opens calcurse in a floating Kitty window using the synced Outlook calendars.
# Remaps ANSI colors inside this window to the Imperator palette instead of
# relying on calcurse's internal color scheme (which hardcodes red for dark mode).

DATA_DIR="$HOME/.local/share/calcurse-outlook"
VAULT="$HOME/Documents/Cerebrum-Secundum"

if ! command -v calcurse &>/dev/null; then
    notify-send -u critical "Calendar" "calcurse not found — install with: sudo pacman -S calcurse"
    exit 1
fi

if [[ ! -d "$DATA_DIR" || ! -f "$DATA_DIR/apts" ]]; then
    notify-send -u normal "Calendar" "No events yet — run setup.sh to sync"
fi

# Import from current ICS on disk (fast, ~0.3s) — correct timezone + dedup
"$(dirname "$0")/calcurse-import.sh" 2>/dev/null
# Background sync from Outlook (~3s network) — data ready for the next open
(vdirsyncer sync 2>/dev/null && "$(dirname "$0")/calcurse-import.sh" 2>/dev/null) &
disown

# Sync todos from Obsidian daily notes → calcurse todo file (read-only, overwrite each open)
grep -r --include="*.md" -h -- "- \[ \]" "$VAULT/02-Areae/Vita" 2>/dev/null \
    | sed 's/^[[:space:]]*- \[ \] //' \
    | sed 's/ 📅 [0-9-]*//' \
    | sed 's/\[\[//g; s/\]\]//g' \
    | sed 's/ #[^ ]*//g' \
    | sed '/^[[:space:]]*$/d' \
    | while IFS= read -r task; do printf '[0]%s\n' "$task"; done \
    > "$DATA_DIR/todo"

# color1/9  = ANSI red   → amber  (borders, text, status bar highlight)
# color6/14 = ANSI cyan  → muted gold  (calendar day headers)
# color3/11 = ANSI yellow → bright gold (selected date — already close)
exec kitty \
    --app-id calcurse-float \
    --title "Calendar" \
    --override "background=#0E0C08" \
    --override "foreground=#D4A843" \
    --override "background_opacity=0.55" \
    --override "background_blur=64" \
    --override "color1=#D4A843" \
    --override "color9=#FFD700" \
    --override "color6=#C8960C" \
    --override "color14=#F0B030" \
    --override "color3=#FFD700" \
    --override "color11=#FFD700" \
    calcurse -D "$DATA_DIR"

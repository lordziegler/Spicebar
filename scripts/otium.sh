#!/usr/bin/env bash
# Otium — vault/task display independiente de canticulum

VAULT="$HOME/Documents/Cerebrum_Secundum"
ICON="♁"

RAW=$(grep -r --include="*.md" -h "- \[ \]" \
    --exclude-dir=".obsidian" --exclude-dir="05-Formae" --exclude-dir="06-Archivum" \
    "$VAULT/01-Incepta" "$VAULT/02-Areae" 2>/dev/null | head -1)

if [[ -z "$RAW" ]]; then
    printf '{"text":"%s","class":"otium","tooltip":"Cerebrum Secundum · Nulla officia"}\n' \
        "$ICON"
    exit 0
fi

TASK=$(printf '%s' "$RAW" \
    | sed 's/^[[:space:]]*- \[ \] //' \
    | sed 's/ 📅 [0-9-]*//' \
    | sed 's/\[\[//g; s/\]\]//g' \
    | sed 's/ #[^ ]*//g' \
    | cut -c1-42)
[[ "${#TASK}" -ge 42 ]] && TASK="${TASK%?}…"

printf '{"text":"%s  %s","class":"officium","tooltip":"Officium · %s"}\n' \
    "$ICON" "$TASK" "$TASK"

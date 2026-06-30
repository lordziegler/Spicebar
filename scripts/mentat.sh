#!/usr/bin/env bash
# Mentat — dual widget: música activa → canticulum / silencio → officium

VAULT="$HOME/Documents/Cerebrum_Secundum"
PLAY_ICON="<span font='Symbols Nerd Font 14'></span>"
PAUS_ICON="<span font='Symbols Nerd Font 14'></span>"
TASK_ICON="♁"

STATUS=$(playerctl status 2>/dev/null || echo "Stopped")

if [[ "$STATUS" == "Playing" || "$STATUS" == "Paused" ]]; then
    ARTIST=$(playerctl metadata artist 2>/dev/null)
    TITLE=$(playerctl metadata title 2>/dev/null)
    ALBUM=$(playerctl metadata album 2>/dev/null)
    PLAYER=$(playerctl metadata --format "{{playerName}}" 2>/dev/null)

    if [[ "$STATUS" == "Playing" ]]; then
        ICON="$PLAY_ICON"; CLS="canticulum"
    else
        ICON="$PAUS_ICON"; CLS="canticulum-pausa"
    fi

    # Trunca solo el contenido visible — el span del icón queda intacto
    CONTENT=$(printf "%s — %s" "$ARTIST" "$TITLE" | cut -c1-38)
    [[ "${#CONTENT}" -ge 38 ]] && CONTENT="${CONTENT%?}…"
    printf '{"text":"%s  %s","class":"%s","tooltip":"%s · %s"}\n' \
        "$ICON" "$CONTENT" "$CLS" "$PLAYER" "$ALBUM"
    exit 0
fi

# Silencio — busca en proyectos activos primero, luego áreas periódicas
RAW=$(grep -r --include="*.md" -h "- \[ \]" \
    --exclude-dir=".obsidian" --exclude-dir="05-Formae" --exclude-dir="06-Archivum" \
    "$VAULT/01-Incepta" "$VAULT/02-Areae" 2>/dev/null | head -1)

if [[ -z "$RAW" ]]; then
    printf '{"text":"","class":"otium","tooltip":"Nulla officia · Pax Corrino"}\n'
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
    "$TASK_ICON" "$TASK" "$TASK"

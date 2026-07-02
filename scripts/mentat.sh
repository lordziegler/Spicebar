#!/usr/bin/env bash
# Mentat — canticulum: MPRIS cuando hay música, invisible cuando no

PLAY_ICON="<span font='Symbols Nerd Font 14'></span>"
PAUS_ICON="<span font='Symbols Nerd Font 14'></span>"

MODE=$(cat "$HOME/.local/state/waybar/mentat-mode" 2>/dev/null || echo "expanded")
STATUS=$(playerctl status 2>/dev/null || echo "Stopped")

if [[ "$STATUS" != "Playing" && "$STATUS" != "Paused" ]]; then
    printf '{"text":"","class":"hidden"}\n'
    exit 0
fi

if [[ "$STATUS" == "Playing" ]]; then
    ICON="$PLAY_ICON"; CLS="canticulum"
else
    ICON="$PAUS_ICON"; CLS="canticulum-pausa"
fi

_esc() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }
ARTIST=$(_esc "$(playerctl metadata artist 2>/dev/null)")
TITLE=$(_esc "$(playerctl metadata title 2>/dev/null)")
ALBUM=$(_esc "$(playerctl metadata album 2>/dev/null)")
PLAYER=$(_esc "$(playerctl metadata --format '{{playerName}}' 2>/dev/null)")

if [[ "$MODE" == "compact" ]]; then
    printf '{"text":"%s","class":"%s-compact","tooltip":"%s — %s"}\n' \
        "$ICON" "$CLS" "$ARTIST" "$TITLE"
else
    CONTENT=$(printf "%s — %s" "$ARTIST" "$TITLE" | cut -c1-38)
    [[ "${#CONTENT}" -ge 38 ]] && CONTENT="${CONTENT%?}…"
    printf '{"text":"%s  %s","class":"%s","tooltip":"%s · %s"}\n' \
        "$ICON" "$CONTENT" "$CLS" "$PLAYER" "$ALBUM"
fi

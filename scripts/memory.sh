#!/bin/bash
# RAM bars — 4 chars × 25% each; click toggles to icon + exact value

STATE=/tmp/.mem_show
SIG=12

if [[ "$1" == "toggle" ]]; then
    [[ -f "$STATE" ]] && rm -f "$STATE" || touch "$STATE"
    n=$(( $(kill -l SIGRTMIN) + SIG ))
    pkill -"$n" waybar 2>/dev/null || true
    exit 0
fi

ICON="󰍛"

read pct used total <<< $(awk '
    /MemTotal/    { t=$2 }
    /MemAvailable/{ a=$2 }
    END { printf "%d %.1f %.1f", (t-a)*100/t, (t-a)/1048576, t/1048576 }
' /proc/meminfo)

if [[ -f "$STATE" ]]; then
    TEXT="<span font='JetBrainsMonoNL Nerd Font Propo 14'>$ICON</span> ${used}G"
else
    # 6 niveles en vez de 8, y el tope es ▊ (3/4 de celda) en vez de █ (4/4).
    # Con █ la barra se cerraba en un rectángulo macizo — sin aire a la derecha
    # se pierde la lectura de "barra" y, con el glow encima, queda una mancha.
    # ▊ deja siempre un carril libre, así que se sigue leyendo como barra llena.
    ICONS=("▏" "▎" "▍" "▌" "▋" "▊")
    MAX=$(( ${#ICONS[@]} - 1 ))
    BARS=4
    result=""
    per=$(( 100 / BARS ))
    for (( i=0; i<BARS; i++ )); do
        fill=$(( pct - i * per ))
        if   (( fill <= 0   )); then result+="${ICONS[0]}"
        elif (( fill >= per )); then result+="${ICONS[MAX]}"
        else result+="${ICONS[ fill * MAX / per ]}"
        fi
    done
    TEXT="$result"
fi

printf '{"text":"%s","tooltip":"RAM %s / %s GiB  (%d%%)"}\n' \
    "$TEXT" "$used" "$total" "$pct"

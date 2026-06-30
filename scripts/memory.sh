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
    TEXT="<span font='Symbols Nerd Font 14'>$ICON</span> ${used}G"
else
    ICONS=("▏" "▎" "▍" "▌" "▋" "▊" "█" "█")
    BARS=4
    result=""
    per=$(( 100 / BARS ))
    for (( i=0; i<BARS; i++ )); do
        fill=$(( pct - i * per ))
        if   (( fill <= 0  )); then result+="${ICONS[0]}"
        elif (( fill >= per )); then result+="${ICONS[7]}"
        else result+="${ICONS[ fill * 7 / per ]}"
        fi
    done
    TEXT="$result"
fi

printf '{"text":"%s","tooltip":"RAM %s / %s GiB  (%d%%)"}\n' \
    "$TEXT" "$used" "$total" "$pct"

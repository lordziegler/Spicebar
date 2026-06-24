#!/bin/bash
# custom battery — click toggles percentage; no daemon

STATE=/tmp/.battery_pct
SIG=10  # SIGRTMIN+10

I0="󰁺"
I1="󰁻"
I2="󰁼"
I3="󰁽"
I4="󰁾"
I5="󰁿"
I6="󰂀"
I7="󰂁"
I8="󰂂"
I9="󰁹"
CHARGING="󰂄"

BAT=$(ls /sys/class/power_supply/ 2>/dev/null | grep -E '^BAT' | sort | head -1)

if [[ "${1}" == "toggle" ]]; then
    [[ -f "$STATE" ]] && rm -f "$STATE" || touch "$STATE"
    n=$(( $(kill -l SIGRTMIN) + SIG ))
    pkill -"$n" waybar 2>/dev/null || true
    exit 0
fi

if [[ -z "$BAT" ]]; then
    printf '{"text":"no bat","class":"critical","tooltip":"No battery"}\n'
    exit 0
fi

CAP=$(cat /sys/class/power_supply/$BAT/capacity 2>/dev/null || echo 0)
STATUS=$(cat /sys/class/power_supply/$BAT/status 2>/dev/null || echo "Unknown")

if [[ "$STATUS" == "Charging" || "$STATUS" == "Full" ]]; then
    RAW="$CHARGING"
elif (( CAP >= 95 )); then RAW="$I9"
elif (( CAP >= 85 )); then RAW="$I8"
elif (( CAP >= 75 )); then RAW="$I7"
elif (( CAP >= 65 )); then RAW="$I6"
elif (( CAP >= 55 )); then RAW="$I5"
elif (( CAP >= 45 )); then RAW="$I4"
elif (( CAP >= 35 )); then RAW="$I3"
elif (( CAP >= 25 )); then RAW="$I2"
elif (( CAP >= 15 )); then RAW="$I1"
else RAW="$I0"
fi

ICON="<span font='Symbols Nerd Font 16'>$RAW</span>"

[[ -f "$STATE" ]] && TEXT="$ICON ${CAP}%" || TEXT="$ICON"

if [[ "$STATUS" == "Charging" ]]; then CLS="charging"
elif (( CAP <= 10 )); then CLS="critical"
elif (( CAP <= 25 )); then CLS="warning"
else CLS="normal"
fi

printf '{"text":"%s","class":"%s","tooltip":"Battery: %s%%\\n%s"}\n' "$TEXT" "$CLS" "$CAP" "$STATUS"

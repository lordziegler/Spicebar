#!/bin/bash
# CPU temperature — icon-only by default; click toggles exact reading

STATE=/tmp/.temp_show
SIG=11

if [[ "$1" == "toggle" ]]; then
    [[ -f "$STATE" ]] && rm -f "$STATE" || touch "$STATE"
    n=$(( $(kill -l SIGRTMIN) + SIG ))
    pkill -"$n" waybar 2>/dev/null || true
    exit 0
fi

EMPTY=""   # < 45°C
QTR=""   # 45-55°C
HALF=""   # 55-65°C
TQT=""   # 65-75°C
FULL=""   # > 75°C

# El índice de hwmon NO es estable entre reinicios: si el kernel renumera,
# leer /sys/class/hwmon/hwmon5 devuelve vacío -> TEMP=0 -> el icono se queda
# clavado en "cool" en silencio. Se resuelve por NOMBRE del sensor.
HWMON=""
for h in /sys/class/hwmon/hwmon*; do
    [[ "$(cat "$h/name" 2>/dev/null)" == "coretemp" ]] && { HWMON="$h"; break; }
done
# Reserva: acpitz sirve si no hay coretemp (p.ej. AMD -> k10temp; ajústalo aquí)
[[ -z "$HWMON" ]] && for h in /sys/class/hwmon/hwmon*; do
    [[ "$(cat "$h/name" 2>/dev/null)" == "acpitz" ]] && { HWMON="$h"; break; }
done

RAW=$(cat "$HWMON/temp1_input" 2>/dev/null || echo 0)
TEMP=$(( RAW / 1000 ))

if   (( TEMP >= 75 )); then ICON="$FULL";  CLS="critical"
elif (( TEMP >= 65 )); then ICON="$TQT";   CLS="hot"
elif (( TEMP >= 55 )); then ICON="$HALF";  CLS="warm"
elif (( TEMP >= 45 )); then ICON="$QTR";   CLS="mild"
else                        ICON="$EMPTY"; CLS="cool"
fi

SPAN="<span font='JetBrainsMonoNL Nerd Font Propo 14'>$ICON</span>"
if [[ -f "$STATE" ]]; then
    TEXT="$SPAN ${TEMP}°"
else
    TEXT="$SPAN"
fi

printf '{"text":"%s","class":"%s","tooltip":"CPU: %d°C"}\n' \
    "$TEXT" "$CLS" "$TEMP"

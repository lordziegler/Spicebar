#!/usr/bin/env bash
# Abre khal interactive en una ventana flotante de Kitty.
# Si khal no está instalado o no hay calendarios sincronizados, notifica.

if ! command -v khal &>/dev/null; then
    notify-send -u critical "Calendar" "khal no encontrado — ejecuta: sudo pacman -S khal"
    exit 1
fi

if [[ ! -f "$HOME/.config/khal/config" ]]; then
    notify-send -u critical "Calendar" "Config de khal no encontrada — ejecuta setup.sh"
    exit 1
fi

if [[ ! -d "$HOME/.calendars/outlook" || -z "$(ls -A "$HOME/.calendars/outlook" 2>/dev/null)" ]]; then
    notify-send -u normal "Calendar" "Sin eventos — ejecuta setup.sh para sincronizar Outlook"
fi

exec kitty --app-id khal-float --title "Calendar" khal interactive

#!/usr/bin/env bash
# Abre el gestor de wifi que corresponda al backend que esté MANDANDO ahora.
#
# Existe porque el icono de waybar apuntaba fijo a `impala`, y cuando impala se
# desinstaló (tras el intento fallido de migrar a iwd) el botón quedó muerto.
# Así el clic siempre hace algo, se use iwd o NetworkManager.

if systemctl is-active --quiet iwd && command -v impala >/dev/null; then
    exec kitty --class=impala-tui -e impala
elif systemctl is-active --quiet NetworkManager; then
    if command -v nm-connection-editor >/dev/null; then
        exec nm-connection-editor
    else
        exec kitty --class=impala-tui -e nmtui
    fi
else
    notify-send "Red" "Ningún gestor de red activo (ni iwd ni NetworkManager)" -u critical
fi

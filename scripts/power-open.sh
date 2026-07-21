#!/usr/bin/env bash
# Floating power profile manager — power-profiles-daemon + battery status.
# Bound to left-click on the battery icon (custom/battery).
exec kitty \
    --app-id power-float \
    --title "Power" \
    bash "$HOME/.config/waybar/scripts/power-menu.sh"

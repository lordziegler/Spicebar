#!/usr/bin/env bash
# Floating power profile manager — power-profiles-daemon + battery status.
# Bound to left-click on the battery icon (custom/battery).
exec kitty \
    --app-id power-float \
    --title "Power" \
    --override "background=#0E0C08" \
    --override "foreground=#D4A843" \
    --override "background_opacity=0.55" \
    --override "background_blur=64" \
    bash "$HOME/.config/waybar/scripts/power-menu.sh"

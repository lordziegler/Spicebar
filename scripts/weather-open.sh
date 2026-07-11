#!/usr/bin/env bash
exec kitty \
    --app-id weather-float \
    --title "Weather" \
    --override "background=#0E0C08" \
    --override "foreground=#D4A843" \
    --override "background_opacity=0.55" \
    --override "background_blur=64" \
    --override "font_size=9.0" \
    bash "$HOME/.config/waybar/scripts/weather.sh"

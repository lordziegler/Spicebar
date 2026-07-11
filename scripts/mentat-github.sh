#!/usr/bin/env bash
exec kitty \
    --app-id github-float \
    --title "GitHub Contributions" \
    --override "background=#0E0C08" \
    --override "foreground=#FFD700" \
    --override "background_opacity=0.55" \
    --override "background_blur=64" \
    --override "font_size=9.0" \
    bash "$HOME/.config/waybar/scripts/github-graph.sh"

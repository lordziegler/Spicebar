#!/usr/bin/env bash
exec kitty \
    --app-id khal-float \
    --title "GitHub Contributions" \
    --override "background=#0E0C08" \
    --override "foreground=#D4A843" \
    bash "$HOME/.config/waybar/scripts/github-graph.sh"

#!/usr/bin/env bash
# Middle-click on mentat: collapse MPRIS to icon / expand to full text.
# State absent  = expanded (artist — title shown when playing)
# State "compact" = icon only when music is playing
STATE="$HOME/.local/state/waybar/mentat-mode"
mkdir -p "$(dirname "$STATE")"
if [[ "$(cat "$STATE" 2>/dev/null)" == "compact" ]]; then
    rm -f "$STATE"
else
    printf 'compact' > "$STATE"
fi
pkill -RTMIN+13 waybar 2>/dev/null || true

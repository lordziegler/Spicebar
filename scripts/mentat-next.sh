#!/usr/bin/env bash
STATUS=$(playerctl --ignore-player=kdeconnect status 2>/dev/null || echo "Stopped")
if [[ "$STATUS" == "Playing" || "$STATUS" == "Paused" ]]; then
    playerctl --ignore-player=kdeconnect next
else
    obsidian "obsidian://open?vault=Cerebrum_Secundum&file=01-Incepta" &
fi

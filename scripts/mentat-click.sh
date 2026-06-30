#!/usr/bin/env bash
STATUS=$(playerctl status 2>/dev/null || echo "Stopped")
if [[ "$STATUS" == "Playing" || "$STATUS" == "Paused" ]]; then
    playerctl play-pause
else
    obsidian "obsidian://open?vault=Cerebrum_Secundum" &
fi

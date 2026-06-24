#!/bin/bash
count=$(swaync-client -c 2>/dev/null || echo 0)
dnd=$(swaync-client -p 2>/dev/null || echo false)
bell=$(printf '\xef\x83\xb3')      # U+F0F3 nf-fa-bell
slash=$(printf '\xef\x87\xb6')     # U+F1F6 nf-fa-bell-slash
if [ "$dnd" = "true" ]; then
    printf '{"text":"%s","class":"dnd"}\n' "$slash"
elif [ "$count" -gt 0 ]; then
    printf '{"text":"%s %s","class":"notification"}\n' "$bell" "$count"
else
    printf '{"text":"%s","class":"none"}\n' "$bell"
fi

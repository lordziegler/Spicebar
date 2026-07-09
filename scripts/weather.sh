#!/usr/bin/env bash
# Weather dashboard — wttr.in, detección automática por IP, caché 30 min

CACHE="/tmp/.wttr-cache"
MAX_AGE=1800

if [[ -f "$CACHE" ]] && (( $(date +%s) - $(stat -c %Y "$CACHE") < MAX_AGE )); then
    cat "$CACHE"
else
    curl -s --max-time 10 'wttr.in' | tee "$CACHE" || {
        printf "\n  Error: no se pudo conectar con wttr.in\n\n"
    }
fi

printf "\n"
read -rn1

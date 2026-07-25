#!/bin/bash
# Bluetooth status for waybar — icon-only by default; right-click toggles the device name.
# on-click (blueman-manager) is wired in config.jsonc; on-click-right runs this with "toggle".

STATE=/tmp/.bt_show
SIG=15

if [[ "$1" == "toggle" ]]; then
    [[ -f "$STATE" ]] && rm -f "$STATE" || touch "$STATE"
    n=$(( $(kill -l SIGRTMIN) + SIG ))
    pkill -"$n" waybar 2>/dev/null || true
    exit 0
fi

ICON=$(printf '\xef\x8a\x94')  # U+F294 nf-fa-bluetooth_b
SPAN="<span font='JetBrainsMonoNL Nerd Font Propo 16'>$ICON</span>"

# Escapes text pulled from device/controller names before it lands in JSON or pango markup.
_esc() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' \
                            -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}

SHOW=$(bluetoothctl show 2>/dev/null)

if ! grep -q "Powered: yes" <<< "$SHOW"; then
    printf '{"text":"%s","class":"disabled","tooltip":"Bluetooth off"}\n' "$SPAN"
    exit 0
fi

CTRL_ALIAS=$(_esc "$(grep "Alias:" <<< "$SHOW" | head -1 | cut -d' ' -f2-)")
CTRL_ADDR=$(head -1 <<< "$SHOW" | awk '{print $2}')

mapfile -t CONNECTED < <(bluetoothctl devices Connected 2>/dev/null | cut -d' ' -f3-)
COUNT=${#CONNECTED[@]}

if (( COUNT == 0 )); then
    printf '{"text":"%s","tooltip":"%s %s\\n0 connected"}\n' "$SPAN" "$CTRL_ALIAS" "$CTRL_ADDR"
    exit 0
fi

TOOLTIP_DEVICES=""
for d in "${CONNECTED[@]}"; do
    TOOLTIP_DEVICES+="  $(_esc "$d")\\n"
done

printf -v TOOLTIP '%s\\n%d connected\\n\\n%s' "$CTRL_ALIAS" "$COUNT" "${TOOLTIP_DEVICES%\\n}"

if [[ -f "$STATE" ]]; then
    TEXT="$SPAN $(_esc "${CONNECTED[0]}")"
else
    TEXT="$SPAN"
fi

printf '{"text":"%s","class":"connected","tooltip":"%s"}\n' "$TEXT" "$TOOLTIP"

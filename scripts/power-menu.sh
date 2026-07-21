#!/usr/bin/env bash
# Power profile switcher for power-profiles-daemon, with a battery status
# header. Runs inside the power-float Kitty window (see power-open.sh).
set -uo pipefail

BAT_DEV=$(upower -e 2>/dev/null | grep -m1 'BAT')

battery_status() {
    if [[ -z "$BAT_DEV" ]]; then
        echo "No battery detected"
        return
    fi
    local info state pct timeleft
    info=$(upower -i "$BAT_DEV" 2>/dev/null)
    state=$(awk -F': +' '/^ *state:/{print $2}' <<<"$info")
    pct=$(awk -F': +' '/^ *percentage:/{print $2}' <<<"$info")
    timeleft=$(awk -F': +' '/^ *time to (empty|full):/{print $2}' <<<"$info")
    if [[ -n "$timeleft" ]]; then
        printf '%s · %s · %s remaining\n' "$pct" "$state" "$timeleft"
    else
        printf '%s · %s\n' "$pct" "$state"
    fi
}

if ! command -v powerprofilesctl &>/dev/null; then
    echo "power-profiles-daemon is not installed."
    echo "Install with: sudo pacman -S power-profiles-daemon"
    read -rn1
    exit 1
fi

mapfile -t RAW < <(powerprofilesctl list | grep -E '^\*? *[a-z-]+:$')

NAMES=()
LABELS=()
CURRENT=""
for line in "${RAW[@]}"; do
    name=$(sed -E 's/^\*? *//; s/:$//' <<<"$line")
    NAMES+=("$name")
    if [[ "${line:0:1}" == "*" ]]; then
        CURRENT="$name"
        LABELS+=("● ${name}  (current)")
    else
        LABELS+=("  ${name}")
    fi
done

SELECTED=$(printf '%s\n' "${LABELS[@]}" | fzf \
    --height=~100% --layout=reverse --border=rounded \
    --header="$(battery_status)" \
    --color="bg:#0E0C08,bg+:#1a1608,fg:#D4A843,fg+:#FFD700,hl:#FFD700,hl+:#FFD700,border:#4a3c14,header:#a89984,prompt:#FFD700,pointer:#FFD700" \
    --prompt="⚡ " --pointer="▶" --no-info)

[[ -z "$SELECTED" ]] && exit 0

TARGET=$(sed -E 's/^[● ]*//; s/  \(current\)$//' <<<"$SELECTED")

if [[ "$TARGET" != "$CURRENT" ]]; then
    powerprofilesctl set "$TARGET"
    notify-send "Power" "Profile set to ${TARGET}"
fi

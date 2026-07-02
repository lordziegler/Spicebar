#!/usr/bin/env bash
# Spicebar setup — installs deps, links configs, syncs calendars, and restarts waybar.
# Usage: bash setup.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAYBAR_DIR="$HOME/.config/waybar"

# ── 0. Install packages ────────────────────────────────────────────────
# obsidian is AUR — install separately with paru/yay if needed
PKGS=(waybar kitty playerctl swaync blueman pavucontrol wlogout libnotify
      curl github-cli calcurse vdirsyncer nm-connection-editor)

MISSING=()
for pkg in "${PKGS[@]}"; do
    pacman -Qi "$pkg" &>/dev/null || MISSING+=("$pkg")
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "Installing: ${MISSING[*]}"
    sudo pacman -S --needed "${MISSING[@]}"
fi

# ── 1. Check hard dependencies ─────────────────────────────────────────
need() { command -v "$1" &>/dev/null && return; echo "Missing: $1 — install with: sudo pacman -S $2" >&2; exit 1; }
need waybar    waybar
need kitty     kitty
need systemctl systemd

CALENDAR=true
command -v calcurse   &>/dev/null || { echo "Warning: calcurse not found — calendar disabled (sudo pacman -S calcurse vdirsyncer)"; CALENDAR=false; }
command -v vdirsyncer &>/dev/null || CALENDAR=false

# ── 2. Create destination ──────────────────────────────────────────────
mkdir -p "$WAYBAR_DIR"

# ── 3. Link helper (backs up real files, then symlinks) ────────────────
lnk() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    [[ -e "$dst" && ! -L "$dst" ]] && mv "$dst" "${dst}.bak" && echo "  Backup: ${dst}.bak"
    ln -sf "$src" "$dst"
    echo "  → $dst"
}

if [[ "$(realpath "$REPO_DIR")" != "$(realpath "$WAYBAR_DIR" 2>/dev/null)" ]]; then
    echo "Linking waybar configs..."
    lnk "$REPO_DIR/scripts"      "$WAYBAR_DIR/scripts"
    lnk "$REPO_DIR/assets"       "$WAYBAR_DIR/assets"
    lnk "$REPO_DIR/config.jsonc" "$WAYBAR_DIR/config.jsonc"
    echo "Generating style.css..."
    tmp=$(mktemp)
    sed "s|/home/[^/]*/|$HOME/|g" "$REPO_DIR/style.css" > "$tmp"
    mv "$tmp" "$WAYBAR_DIR/style.css"
    echo "  → $WAYBAR_DIR/style.css"
else
    echo "  (repo is ~/.config/waybar/ — skipping symlinks and style.css regeneration)"
fi

# ── 4. Calendar (optional) ─────────────────────────────────────────────
if [[ "$CALENDAR" == true ]]; then
    SECRETS="$HOME/.config/vdirsyncer/secrets"
    VDIR_CFG="$HOME/.config/vdirsyncer/config"
    CAL_DATA="$HOME/.local/share/calcurse-outlook"

    # Collect calendar URLs if secrets file is missing or empty
    if [[ ! -s "$SECRETS" ]]; then
        mkdir -p "$(dirname "$SECRETS")"
        echo ""
        echo "Enter your Outlook.com ICS calendar URLs."
        echo "(outlook.live.com → Settings → Calendar → Shared calendars → Publish → ICS link)"
        echo "Enter a name and URL for each calendar. Leave the name blank to finish."
        echo ""
        > "$SECRETS"
        while true; do
            read -rp "  Calendar name (e.g. personal, work — blank to finish): " CAL_NAME
            [[ -z "$CAL_NAME" ]] && break
            read -rp "  ICS URL for $CAL_NAME: " CAL_URL
            [[ -z "$CAL_URL" ]] && break
            CAL_SLUG=$(printf '%s' "$CAL_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
            printf '%s=%s\n' "$CAL_SLUG" "$CAL_URL" >> "$SECRETS"
            echo "  → saved $CAL_SLUG"
        done
        chmod 600 "$SECRETS"
        echo "  → $SECRETS"
    fi

    # Generate vdirsyncer config (one pair per calendar)
    echo "Generating vdirsyncer config..."
    {
        echo "[general]"
        echo "status_path = \"$HOME/.local/share/vdirsyncer/status/\""
        echo ""
        while IFS='=' read -r name url; do
            [[ "$name" =~ ^[[:space:]]*#.*$ || -z "$name" ]] && continue
            mkdir -p "$HOME/.calendars/$name"
            printf '[pair %s]\n'           "$name"
            printf 'a = "%s_remote"\n'     "$name"
            printf 'b = "%s_local"\n'      "$name"
            printf 'collections = null\n\n'
            printf '[storage %s_remote]\n' "$name"
            printf 'type = "http"\n'
            printf 'url = "%s"\n\n'        "$url"
            printf '[storage %s_local]\n'  "$name"
            printf 'type = "filesystem"\n'
            printf 'path = "%s/.calendars/%s/"\n' "$HOME" "$name"
            printf 'fileext = ".ics"\n\n'
        done < "$SECRETS"
    } > "$VDIR_CFG"
    echo "  → $VDIR_CFG"

    # Write calcurse config (only confirmed-valid keys; colors via kitty overrides)
    mkdir -p "$CAL_DATA"
    printf '%s\n' \
        'general.autosave=yes' \
        'general.confirmquit=no' \
        'general.firstdayofweek=monday' \
        'general.systemdialogs=no' \
        'appearance.layout=1' \
        'appearance.notifybar=yes' \
        > "$CAL_DATA/conf"
    echo "  → $CAL_DATA/conf"

    mkdir -p "$HOME/.local/share/vdirsyncer/status"

    # Link systemd units
    echo "Linking calendar systemd units..."
    lnk "$REPO_DIR/systemd/vdirsyncer.service" "$HOME/.config/systemd/user/vdirsyncer.service"
    lnk "$REPO_DIR/systemd/vdirsyncer.timer"   "$HOME/.config/systemd/user/vdirsyncer.timer"

    systemctl --user daemon-reload
    systemctl --user enable --now vdirsyncer.timer
    echo "  → timer active"

    echo "Discovering collections..."
    yes | vdirsyncer discover 2>&1 || true
    echo "Syncing and importing calendars..."
    vdirsyncer sync && "$REPO_DIR/scripts/calcurse-import.sh" && echo "  → sync complete" \
        || echo "  → sync failed (re-run: vdirsyncer sync)"
fi

# ── 5. Niri window rules ───────────────────────────────────────────────
NIRI_RULES="$HOME/.config/niri/rules.kdl"
if [[ -f "$NIRI_RULES" ]] && grep -q "calcurse-float" "$NIRI_RULES"; then
    echo "Niri rules already present — skipping"
else
    echo "Injecting niri window rules..."
    mkdir -p "$(dirname "$NIRI_RULES")"
    cat "$REPO_DIR/niri/waybar-floats.kdl" >> "$NIRI_RULES"
    echo "  → $NIRI_RULES"
    niri msg action load-config-file "$HOME/.config/niri/config.kdl" 2>/dev/null \
        && echo "  → niri config reloaded" \
        || echo "  → reload niri manually to apply window rules"
fi

# ── 6. Restart waybar ─────────────────────────────────────────────────
echo "Restarting waybar..."
pkill waybar 2>/dev/null || true
sleep 0.3
waybar &>/dev/null &
disown
echo "  → waybar running (pid $!)"

echo ""
echo "Done."

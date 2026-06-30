#!/usr/bin/env bash
# Spicebar setup — links configs, generates style.css, and sets up calendar sync.
# Usage: bash setup.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAYBAR_DIR="$HOME/.config/waybar"

# ── 1. Check dependencies ──────────────────────────────────────────────
need() { command -v "$1" &>/dev/null && return; echo "Missing: $1 — install with: sudo pacman -S $2" >&2; exit 1; }
need waybar   waybar
need kitty    kitty
need systemctl systemd

CALENDAR=true
command -v khal        &>/dev/null || { echo "Warning: khal not found — calendar disabled (sudo pacman -S khal vdirsyncer)"; CALENDAR=false; }
command -v vdirsyncer  &>/dev/null || CALENDAR=false

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

echo "Linking waybar configs..."
lnk "$REPO_DIR/scripts" "$WAYBAR_DIR/scripts"
lnk "$REPO_DIR/assets"  "$WAYBAR_DIR/assets"

# ── 4. Generate style.css (only if repo ≠ waybar dir) ─────────────────
if [[ "$(realpath "$REPO_DIR")" != "$(realpath "$WAYBAR_DIR" 2>/dev/null)" ]]; then
    echo "Generating style.css..."
    tmp=$(mktemp)
    sed "s|/home/[^/]*/|$HOME/|g" "$REPO_DIR/style.css" > "$tmp"
    mv "$tmp" "$WAYBAR_DIR/style.css"
    echo "  → $WAYBAR_DIR/style.css"
    lnk "$REPO_DIR/config.jsonc" "$WAYBAR_DIR/config.jsonc"
else
    echo "  (style.css: repo is ~/.config/waybar/ — skipping regeneration)"
fi

# ── 5. Calendar (optional) ─────────────────────────────────────────────
if [[ "$CALENDAR" == true ]]; then
    SECRETS="$HOME/.config/vdirsyncer/secrets"
    VDIR_CFG="$HOME/.config/vdirsyncer/config"
    KHAL_CFG="$HOME/.config/khal/config"

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
            # Slugify: lowercase, spaces → underscores
            CAL_SLUG=$(printf '%s' "$CAL_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
            printf '%s=%s\n' "$CAL_SLUG" "$CAL_URL" >> "$SECRETS"
            echo "  → saved $CAL_SLUG"
        done
        chmod 600 "$SECRETS"
        echo "  → $SECRETS"
    fi

    # Generate vdirsyncer config from secrets (one pair per calendar)
    echo "Generating vdirsyncer config..."
    {
        echo "[general]"
        echo "status_path = \"$HOME/.local/share/vdirsyncer/status/\""
        echo ""
        while IFS='=' read -r name url; do
            [[ "$name" =~ ^[[:space:]]*#.*$ || -z "$name" ]] && continue
            mkdir -p "$HOME/.calendars/$name"
            printf '[pair %s]\n' "$name"
            printf 'a = "%s_remote"\n' "$name"
            printf 'b = "%s_local"\n' "$name"
            printf 'collections = null\n'
            printf '\n'
            printf '[storage %s_remote]\n' "$name"
            printf 'type = "http"\n'
            printf 'url = "%s"\n' "$url"
            printf '\n'
            printf '[storage %s_local]\n' "$name"
            printf 'type = "filesystem"\n'
            printf 'path = "%s/.calendars/%s/"\n' "$HOME" "$name"
            printf 'fileext = ".ics"\n'
            printf '\n'
        done < "$SECRETS"
    } > "$VDIR_CFG"
    echo "  → $VDIR_CFG"

    # Generate khal config with one [[calendar]] section per entry
    echo "Generating khal config..."
    {
        echo "[calendars]"
        while IFS='=' read -r name url; do
            [[ "$name" =~ ^[[:space:]]*#.*$ || -z "$name" ]] && continue
            printf '[[%s]]\n' "$name"
            printf 'path = %s/.calendars/%s/\n' "$HOME" "$name"
            printf 'color = yellow\n'
            printf 'readonly = true\n'
            printf '\n'
        done < "$SECRETS"
        echo "[sqlite]"
        echo "path = $HOME/.local/share/khal/khal.db"
        echo ""
        echo "[locale]"
        echo "timeformat = %H:%M"
        echo "dateformat = %d/%m/%Y"
        echo "datetimeformat = %d/%m/%Y %H:%M"
        echo "firstweekday = 0"
        echo ""
        echo "[view]"
        echo "theme = dark"
    } > "$KHAL_CFG"
    echo "  → $KHAL_CFG"

    mkdir -p "$HOME/.local/share/vdirsyncer/status" "$HOME/.local/share/khal"

    # Link systemd units
    echo "Linking calendar systemd units..."
    lnk "$REPO_DIR/systemd/vdirsyncer.service" "$HOME/.config/systemd/user/vdirsyncer.service"
    lnk "$REPO_DIR/systemd/vdirsyncer.timer"   "$HOME/.config/systemd/user/vdirsyncer.timer"

    systemctl --user daemon-reload
    systemctl --user enable --now vdirsyncer.timer
    echo "  → timer active"

    echo "Syncing calendars..."
    vdirsyncer sync && echo "  → sync complete" || echo "  → sync failed (re-run: vdirsyncer sync)"
fi

# ── 6. Manual step ────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────────────────────────"
echo "MANUAL STEP: Add this to ~/.config/niri/config.kdl"
echo "────────────────────────────────────────────────────────────"
/bin/cat "$REPO_DIR/niri/khal-float.kdl"
echo ""
echo "Then: killall waybar && waybar &"

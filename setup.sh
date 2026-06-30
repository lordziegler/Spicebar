#!/usr/bin/env bash
# Bootstrap de Spicebar — enlaza configs, genera style.css y activa el sync de calendario.
# Uso: bash setup.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAYBAR_DIR="$HOME/.config/waybar"

# ── 1. Verificar dependencias ─────────────────────────────────────────
need() { command -v "$1" &>/dev/null && return; echo "Falta: $1 — instalar con: sudo pacman -S $2" >&2; exit 1; }
need waybar  waybar
need kitty   kitty
need systemctl systemd

# Opcionales — solo necesarios para el calendario
CALENDAR=true
command -v khal        &>/dev/null || { echo "Aviso: khal no instalado — calendario desactivado (sudo pacman -S khal vdirsyncer)"; CALENDAR=false; }
command -v vdirsyncer  &>/dev/null || CALENDAR=false

# ── 2. Crear destino ──────────────────────────────────────────────────
mkdir -p "$WAYBAR_DIR"

# ── 3. Función de enlace (hace backup si existe un archivo real) ───────
lnk() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    [[ -e "$dst" && ! -L "$dst" ]] && mv "$dst" "${dst}.bak" && echo "Backup: ${dst}.bak"
    ln -sf "$src" "$dst"
    echo "  → $dst"
}

echo "Enlazando configs de waybar..."
lnk "$REPO_DIR/config.jsonc"  "$WAYBAR_DIR/config.jsonc"
lnk "$REPO_DIR/scripts"       "$WAYBAR_DIR/scripts"
lnk "$REPO_DIR/assets"        "$WAYBAR_DIR/assets"
lnk "$REPO_DIR/khal"          "$HOME/.config/khal"

# ── 4. Generar style.css con $HOME real (no se puede usar ~ en url() CSS) ──
# Solo si el repo NO es ya el directorio de waybar (evita autosobrescritura)
if [[ "$(realpath "$REPO_DIR")" != "$(realpath "$WAYBAR_DIR" 2>/dev/null)" ]]; then
    echo "Generando style.css..."
    tmp=$(mktemp)
    sed "s|__HOME__|$HOME|g" "$REPO_DIR/style.css" > "$tmp"
    mv "$tmp" "$WAYBAR_DIR/style.css"
    echo "  → $WAYBAR_DIR/style.css"
else
    echo "  (style.css: el repo es ~/.config/waybar/, no se regenera)"
fi

# ── 5. Calendario (opcional) ──────────────────────────────────────────
if [[ "$CALENDAR" == true ]]; then
    SECRETS="$HOME/.config/vdirsyncer/secrets"

    if [[ ! -f "$SECRETS" ]]; then
        mkdir -p "$(dirname "$SECRETS")"
        echo ""
        echo "Introduce tu URL iCal de Outlook.com:"
        echo "(outlook.live.com → Configuración → Calendario → Calendarios"
        echo " compartidos → Publicar un calendario → Obtener enlace ICS)"
        echo ""
        read -rp "URL: " ICAL_URL
        printf 'OUTLOOK_ICAL_URL=%s\n' "$ICAL_URL" > "$SECRETS"
        chmod 600 "$SECRETS"
        echo "  → $SECRETS"
    fi

    mkdir -p "$HOME/.calendars/outlook" "$HOME/.local/share/vdirsyncer/status" "$HOME/.local/share/khal"

    echo "Enlazando configs de calendario..."
    lnk "$REPO_DIR/vdirsyncer/config"          "$HOME/.config/vdirsyncer/config"
    lnk "$REPO_DIR/systemd/vdirsyncer.service" "$HOME/.config/systemd/user/vdirsyncer.service"
    lnk "$REPO_DIR/systemd/vdirsyncer.timer"   "$HOME/.config/systemd/user/vdirsyncer.timer"

    systemctl --user daemon-reload
    systemctl --user enable --now vdirsyncer.timer
    echo "  → timer activo"

    # shellcheck source=/dev/null
    source "$SECRETS"; export OUTLOOK_ICAL_URL
    echo "Sincronizando calendario..."
    vdirsyncer discover --yes && vdirsyncer sync
    echo "  → sync completado"
fi

# ── 6. Instrucciones manuales ─────────────────────────────────────────
echo ""
echo "────────────────────────────────────────────────────────────"
echo "PASO MANUAL: Añade esto a ~/.config/niri/rules.kdl"
echo "────────────────────────────────────────────────────────────"
cat "$REPO_DIR/niri/khal-float.kdl"
echo ""
echo "Luego: killall waybar && waybar &"

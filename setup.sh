#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 1. Verificar dependencias ─────────────────────────────────────────
need() {
    command -v "$1" &>/dev/null && return
    echo "Falta: $1 — instalar con: sudo pacman -S $2" >&2
    exit 1
}
need khal khal
need vdirsyncer vdirsyncer
need kitty kitty
need systemctl systemd

# ── 2. Crear archivo de secretos si no existe ─────────────────────────
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
    echo "Secretos guardados en $SECRETS"
fi

# ── 3. Crear directorios de datos ─────────────────────────────────────
mkdir -p "$HOME/.calendars/outlook"
mkdir -p "$HOME/.local/share/vdirsyncer/status"
mkdir -p "$HOME/.local/share/khal"

# ── 4. Enlazar configs ────────────────────────────────────────────────
link_config() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [[ -e "$dst" && ! -L "$dst" ]]; then
        mv "$dst" "${dst}.bak"
        echo "Backup: ${dst}.bak"
    fi
    ln -sf "$src" "$dst"
    echo "Enlazado: $dst"
}

link_config "$REPO_DIR/khal/config"                "$HOME/.config/khal/config"
link_config "$REPO_DIR/vdirsyncer/config"          "$HOME/.config/vdirsyncer/config"
link_config "$REPO_DIR/systemd/vdirsyncer.service" "$HOME/.config/systemd/user/vdirsyncer.service"
link_config "$REPO_DIR/systemd/vdirsyncer.timer"   "$HOME/.config/systemd/user/vdirsyncer.timer"

# ── 5. Activar timer ──────────────────────────────────────────────────
systemctl --user daemon-reload
systemctl --user enable --now vdirsyncer.timer
echo "Timer activo: vdirsyncer.timer"

# ── 6. Sync inicial ───────────────────────────────────────────────────
# shellcheck source=/dev/null
source "$SECRETS"
export OUTLOOK_ICAL_URL
echo "Ejecutando sync inicial..."
vdirsyncer discover --yes
vdirsyncer sync
echo "Sync completado. Eventos en ~/.calendars/outlook/"

# ── 7. Instrucciones manuales ─────────────────────────────────────────
echo ""
echo "────────────────────────────────────────────────────────────"
echo "PASO MANUAL: Añade esto a ~/.config/niri/config.kdl"
echo "────────────────────────────────────────────────────────────"
cat "$REPO_DIR/niri/khal-float.kdl"
echo ""
echo "Luego recarga waybar (killall waybar && waybar &) o reinicia"
echo "la sesión para activar el click derecho en el reloj."
echo "Prueba: click derecho en el reloj → Kitty flotante con khal."

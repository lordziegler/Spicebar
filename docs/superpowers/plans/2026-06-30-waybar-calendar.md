# Waybar Calendar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Añadir click derecho en el reloj de waybar que abre `khal interactive` en Kitty flotante, sincronizado con Outlook.com vía vdirsyncer.

**Architecture:** vdirsyncer descarga el iCal de Outlook.com cada 30 min via systemd --user timer y escribe `.ics` locales. `khal` lee esos archivos. Un click derecho en el reloj de waybar lanza `kitty --class khal-float khal interactive`. La URL iCal vive en `~/.config/vdirsyncer/secrets` (gitignoreado); el repo solo guarda `secrets.example`.

**Tech Stack:** bash, khal, vdirsyncer, systemd --user, kitty, niri window rules, waybar custom module config.

## Global Constraints

- Ningún secreto (URL iCal) en el repo. Solo en `~/.config/vdirsyncer/secrets`, modo 600.
- Todos los paths en configs usan `~` o `%h`, nunca rutas absolutas hardcodeadas.
- Los archivos del repo se enlazan simbólicamente al destino con `setup.sh`, no se copian.
- Compatible con cualquier máquina Arch/CachyOS; `setup.sh` verifica deps antes de actuar.
- Paleta: Gruvbox Hard Dark. `khal` usa `color = bright yellow` (ANSI 11) heredado de Kitty.

---

### Task 1: Configs de khal y vdirsyncer + .gitignore

**Files:**
- Create: `khal/config`
- Create: `vdirsyncer/config`
- Create: `vdirsyncer/secrets.example`
- Modify: `.gitignore` (crear si no existe)

**Interfaces:**
- Produces: `khal/config` leído por Task 4 (setup.sh); `vdirsyncer/config` leído por systemd service (Task 2)

- [ ] **Step 1: Crear `khal/config`**

```ini
[calendars]
[[outlook]]
path = ~/.calendars/outlook/
color = bright yellow

[sqlite]
path = ~/.local/share/khal/khal.db

[locale]
timeformat = %H:%M
dateformat = %d/%m/%Y
datetimeformat = %d/%m/%Y %H:%M
firstweekday = 0

[view]
theme = dark
```

- [ ] **Step 2: Crear `vdirsyncer/config`**

```ini
[general]
status_path = "~/.local/share/vdirsyncer/status/"

[pair outlook]
a = "outlook_remote"
b = "outlook_local"
collections = [null]

[storage outlook_remote]
type = "http"
url = "$OUTLOOK_ICAL_URL"

[storage outlook_local]
type = "filesystem"
path = "~/.calendars/outlook/"
fileext = ".ics"
```

- [ ] **Step 3: Crear `vdirsyncer/secrets.example`**

```
# Copia este archivo a ~/.config/vdirsyncer/secrets y rellena el valor.
# Obtén la URL en: outlook.live.com → Configuración → Calendario →
# Calendarios compartidos → Publicar un calendario → Obtener enlace ICS
OUTLOOK_ICAL_URL=https://outlook.live.com/owa/calendar/XXXXXXXX/XXXXXXXX/calendar.ics
```

- [ ] **Step 4: Actualizar `.gitignore`**

Añadir al final (crear el archivo si no existe):

```
# Secretos de vdirsyncer — nunca subir al repo
vdirsyncer/secrets
**/secrets
```

- [ ] **Step 5: Verificar sintaxis**

```bash
# khal valida su config al arrancar
khal --config khal/config printcalendars 2>&1 || true
# Esperado: error de "path not found" (normal, aún no hay sync) o lista vacía.
# Error fatal indica config malformada.
```

- [ ] **Step 6: Commit**

```bash
git add khal/config vdirsyncer/config vdirsyncer/secrets.example .gitignore
git commit -m "feat: add khal and vdirsyncer configs"
```

---

### Task 2: Systemd user units

**Files:**
- Create: `systemd/vdirsyncer.service`
- Create: `systemd/vdirsyncer.timer`

**Interfaces:**
- Consumes: `~/.config/vdirsyncer/config` (enlazado por setup.sh, Task 4), `~/.config/vdirsyncer/secrets`
- Produces: sync automático cada 30 min; escribe `.ics` en `~/.calendars/outlook/`

- [ ] **Step 1: Crear `systemd/vdirsyncer.service`**

```ini
[Unit]
Description=Sync Outlook calendar (one-shot)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
EnvironmentFile=%h/.config/vdirsyncer/secrets
ExecStart=/usr/bin/vdirsyncer sync
```

- [ ] **Step 2: Crear `systemd/vdirsyncer.timer`**

```ini
[Unit]
Description=Sync Outlook calendar every 30 min

[Timer]
OnBootSec=2min
OnUnitActiveSec=30min

[Install]
WantedBy=timers.target
```

- [ ] **Step 3: Verificar sintaxis de los units**

```bash
systemd-analyze verify systemd/vdirsyncer.service 2>&1 || true
systemd-analyze verify systemd/vdirsyncer.timer 2>&1 || true
# Esperado: sin output (ok) o advertencias menores sobre rutas no existentes.
# Errores de parsing = unit malformado.
```

- [ ] **Step 4: Commit**

```bash
git add systemd/vdirsyncer.service systemd/vdirsyncer.timer
git commit -m "feat: add systemd user units for vdirsyncer sync"
```

---

### Task 3: Niri window rule + modificación de waybar config

**Files:**
- Create: `niri/khal-float.kdl`
- Modify: `config.jsonc` (añadir `on-click-right` al módulo `clock`)

**Interfaces:**
- Consumes: módulo `clock` existente en `config.jsonc`
- Produces: click derecho en reloj abre `kitty --class khal-float khal interactive`; Niri lo presenta flotante

- [ ] **Step 1: Crear `niri/khal-float.kdl`**

```kdl
// Pegar dentro del bloque raíz de ~/.config/niri/config.kdl
window-rule {
    match app-id="khal-float"
    open-floating true
    default-column-width { fixed 900; }
    default-window-height { fixed 550; }
}
```

- [ ] **Step 2: Añadir `on-click-right` al módulo `clock` en `config.jsonc`**

Localizar el bloque `"clock"` (línea ~165) y añadir la línea marcada:

```jsonc
"clock": {
    "format":     "{:%H:%M}",
    "format-alt": "{:%H:%M  %a %d %b %Y}",
    "tooltip-format": "<tt><small>{calendar}</small></tt>",
    "on-click-right": "kitty --class khal-float --title 'Calendar' khal interactive"
},
```

- [ ] **Step 3: Verificar JSON válido**

```bash
python3 -c "
import re, json
txt = open('config.jsonc').read()
txt = re.sub(r'//[^\n]*', '', txt)   # strip comments
json.loads(txt)
print('JSON válido')
"
# Esperado: JSON válido
```

- [ ] **Step 4: Commit**

```bash
git add niri/khal-float.kdl config.jsonc
git commit -m "feat: open khal on clock right-click, add niri float rule"
```

---

### Task 4: setup.sh (bootstrap reproducible)

**Files:**
- Create: `setup.sh`

**Interfaces:**
- Consumes: todos los archivos creados en Tasks 1-3
- Produces: máquina nueva funcional con un solo comando: `bash setup.sh`

- [ ] **Step 1: Crear `setup.sh`**

```bash
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
echo "────────────────────────────────────────────"
echo "PASO MANUAL: Añade esto a ~/.config/niri/config.kdl"
echo "────────────────────────────────────────────"
cat "$REPO_DIR/niri/khal-float.kdl"
echo ""
echo "Luego recarga waybar (o reinicia la sesión) para activar el click derecho en el reloj."
echo "Prueba: click derecho en el reloj → debería abrirse khal en Kitty."
```

- [ ] **Step 2: Hacer ejecutable**

```bash
chmod +x setup.sh
```

- [ ] **Step 3: Verificar sintaxis del script**

```bash
bash -n setup.sh
echo "Sintaxis OK"
# Esperado: Sintaxis OK (sin output de error)
```

- [ ] **Step 4: Commit final**

```bash
git add setup.sh
git commit -m "feat: add setup.sh for reproducible bootstrap"
```

---

## Verificación end-to-end (post-setup)

Tras ejecutar `bash setup.sh` en una máquina con los deps instalados:

1. `systemctl --user status vdirsyncer.timer` → `active (waiting)`
2. `ls ~/.calendars/outlook/` → archivos `.ics` presentes
3. `khal list` → eventos de Outlook visibles en terminal
4. Recargar waybar → click derecho en reloj → ventana Kitty flotante con `khal interactive`
5. Niri: la ventana debe aparecer flotante sin tocar keybindings

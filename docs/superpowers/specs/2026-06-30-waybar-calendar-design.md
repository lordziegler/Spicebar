# Waybar — Clock → Calendar flotante (Outlook.com + khal)

**Fecha:** 2026-06-30  
**Estado:** aprobado  
**Scope:** módulo `clock` de waybar + pipeline de sync iCal de Outlook personal

---

## Objetivo

Al hacer click derecho en el reloj de waybar, se abre `khal interactive` en una ventana flotante de Kitty, mostrando eventos del calendario de Outlook.com sincronizados localmente. El click izquierdo conserva su comportamiento original (alternar formato de fecha).

---

## Arquitectura

```
Outlook.com iCal URL (privada, gitignoreada)
        ↓  cada 30 min via systemd --user timer
   vdirsyncer sync
        ↓  escribe archivos .ics individuales
~/.calendars/outlook/
        ↓  lee al abrir
   khal interactive
        ↑
kitty --class khal-float
        ↑
clock on-click-right (waybar)
```

Sin daemon permanente. `khal` sólo vive mientras el terminal está abierto.

---

## Componentes

### 1. Secretos (gitignoreado)

`~/.config/vdirsyncer/secrets` — **nunca se sube al repo**:
```
OUTLOOK_ICAL_URL=https://outlook.live.com/owa/calendar/.../calendar.ics
```

Cómo obtener la URL:  
`outlook.live.com` → Configuración → Ver toda la configuración de Outlook → Calendario → Calendarios compartidos → Publicar un calendario → Obtener enlace ICS.

El repo incluye `vdirsyncer/secrets.example` como plantilla sin valor real.

---

### 2. vdirsyncer (`vdirsyncer/config`)

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

`$OUTLOOK_ICAL_URL` es expandido por vdirsyncer desde el entorno del proceso. El servicio systemd lo inyecta via `EnvironmentFile`.

---

### 3. Systemd user units (`systemd/`)

**`vdirsyncer.service`:**
```ini
[Unit]
Description=Sync Outlook calendar (one-shot)

[Service]
Type=oneshot
EnvironmentFile=%h/.config/vdirsyncer/secrets
ExecStart=/usr/bin/vdirsyncer sync
```

**`vdirsyncer.timer`:**
```ini
[Unit]
Description=Sync Outlook calendar every 30 min

[Timer]
OnBootSec=2min
OnUnitActiveSec=30min

[Install]
WantedBy=timers.target
```

---

### 4. khal (`khal/config`)

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

`color = bright yellow` usa el color ANSI 11 del terminal, que en Kitty con tema Gruvbox Hard Dark mapea al amber/gold del tema Imperator. Todos los demás colores los hereda de Kitty — sin hardcodear la paleta.

---

### 5. Waybar (`config.jsonc` — diff)

```diff
 "clock": {
     "format":     "{:%H:%M}",
     "format-alt": "{:%H:%M  %a %d %b %Y}",
-    "tooltip-format": "<tt><small>{calendar}</small></tt>"
+    "tooltip-format": "<tt><small>{calendar}</small></tt>",
+    "on-click-right": "kitty --class khal-float --title 'Calendar' khal interactive"
 }
```

---

### 6. Niri window rule (`niri/khal-float.kdl`)

Se entrega como fragmento separado para que el usuario lo incluya en `~/.config/niri/config.kdl`:

```kdl
window-rule {
    match app-id="khal-float"
    open-floating true
    default-column-width { fixed 900; }
    default-window-height { fixed 550; }
}
```

---

## Inventario de archivos del repo

```
waybar/
├── config.jsonc                      # modificado: +on-click-right en clock
├── khal/
│   └── config                        # nuevo
├── vdirsyncer/
│   ├── config                        # nuevo
│   └── secrets.example               # nuevo (plantilla sin URL real)
├── systemd/
│   ├── vdirsyncer.service            # nuevo
│   └── vdirsyncer.timer              # nuevo
├── niri/
│   └── khal-float.kdl                # nuevo (fragmento de window rule)
├── setup.sh                          # nuevo (ver abajo)
└── .gitignore                        # modificado: +secrets
```

---

## setup.sh (bootstrap reproducible)

El script hace el setup completo en una máquina nueva:

1. Verifica dependencias (`khal`, `vdirsyncer`) e indica cómo instalarlas si faltan.
2. Crea `~/.config/vdirsyncer/secrets` si no existe, solicitando la URL iCal interactivamente.
3. Crea los directorios necesarios (`~/.calendars/outlook/`, `~/.local/share/vdirsyncer/status/`).
4. Enlaza simbólicamente (o copia) los archivos de config al destino correcto.
5. Copia los units de systemd a `~/.config/systemd/user/` y habilita el timer.
6. Ejecuta `vdirsyncer discover && vdirsyncer sync` para el primer sync.
7. Imprime instrucciones para añadir la window rule de Niri.

---

## Dependencias

| Paquete | Repo | Uso |
|---|---|---|
| `khal` | `extra` | TUI calendar |
| `vdirsyncer` | `extra` | sync iCal → filesystem |

Ambos en los repos oficiales de Arch/CachyOS (`pacman -S khal vdirsyncer`).

---

## Reproducibilidad

- Ningún secreto va al repo. La URL iCal vive sólo en `~/.config/vdirsyncer/secrets`.
- Todos los paths usan `~` o `%h` (systemd), no rutas absolutas.
- `setup.sh` automatiza el bootstrap completo en cualquier máquina.
- Los fragmentos de Niri y los units de systemd son autocontenidos.
- Compatible con cualquier distro Arch-based; `setup.sh` puede extenderse para otras.

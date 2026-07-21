#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════
#  SPICEBAR · setup
#  Instala dependencias, despliega configs, activa servicios y VERIFICA.
#
#  Uso:
#     bash setup.sh                 instalación completa
#     bash setup.sh --no-calendar   sin el pipeline vdirsyncer→calcurse (no interactivo)
#     bash setup.sh --check         solo verifica, no toca nada
#
#  Idempotente: puedes relanzarlo siempre.
# ══════════════════════════════════════════════════════════════════════════
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WAYBAR_DIR="$HOME/.config/waybar"
UNIT_DIR="$HOME/.config/systemd/user"

CALENDAR=true
CHECK_ONLY=false
for arg in "$@"; do
    case "$arg" in
        --no-calendar) CALENDAR=false ;;
        --check)       CHECK_ONLY=true ;;
        -h|--help)     sed -n '2,11p' "$0"; exit 0 ;;
        *) echo "Opción desconocida: $arg" >&2; exit 1 ;;
    esac
done

ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
err()  { printf '  \033[31m✗\033[0m %s\n' "$*"; }
hdr()  { printf '\n\033[1m── %s\033[0m\n' "$*"; }

# ══════════════════════════════════════════════════════════════════════════
#  DEPENDENCIAS
#
#  Esta lista está DERIVADA DEL CÓDIGO — de los comandos que invocan realmente
#  scripts/*.sh y los on-click de config.jsonc — no escrita de memoria.
#  Si añades un módulo que llame a un binario nuevo, añádelo aquí o el
#  instalador mentirá sobre su éxito.
# ══════════════════════════════════════════════════════════════════════════

# Sin esto la barra NO funciona.
#   ttf-jetbrains-mono-nerd: TODOS los iconos de la barra son glifos Nerd Font.
#   Sin la fuente no ves iconos: ves cuadraditos (tofu). Es la dependencia que
#   más se olvida y la que peor resultado da.
PKGS_CORE=(
    waybar
    ttf-jetbrains-mono-nerd
)

# Módulos de la barra. Cada uno anotado con QUIÉN lo usa.
PKGS_MODULES=(
    playerctl              # custom/mentat  — control MPRIS
    jq                     # github-graph.sh, weather.sh — parseo JSON
    github-cli             # custom/github  — racha de contribuciones (gh)
    curl                   # weather.sh
    swaync                 # custom/swaync  — swaync-client
    blueman                # bluetooth      — blueman-manager
    pwvucontrol            # pulseaudio     — clic izq. (mezclador PipeWire GTK4)
    wireplumber            # pulseaudio     — clic der. = mute (wpctl)
    wlogout                # custom/power
    libnotify              # notify-send    — avisos de varios scripts
    kitty                  # ventanas flotantes (calcurse, TUIs)
    inotify-tools          # vault-watch.sh — inotifywait. Sin esto el servicio
                           #                  arranca y muere en 200ms sin vigilar nada.
    power-profiles-daemon  # battery left-click — power-menu.sh (powerprofilesctl)
    fzf                    # battery left-click — selector TUI de power-menu.sh
    upower                 # battery left-click — cabecera de estado en power-menu.sh
)

# Módulo network → scripts/wifi-menu.sh, que elige gestor según el backend ACTIVO.
# Se instalan los dos clientes para que el clic funcione con iwd o NetworkManager.
PKGS_NETWORK=(
    impala                 # si manda iwd
    nm-connection-editor   # si manda NetworkManager
)

# Pipeline de calendario (opcional: --no-calendar lo salta).
PKGS_CALENDAR=(
    calcurse
    vdirsyncer
)

# Fuera de los repos oficiales: solo se avisa, no se instala.
PKGS_MANUAL=(
    obsidian               # custom/otium — abre el vault (AUR o Flatpak)
)

# ══════════════════════════════════════════════════════════════════════════

if [[ "$CHECK_ONLY" == false ]]; then
    hdr "1/6 · Paquetes"

    WANT=("${PKGS_CORE[@]}" "${PKGS_MODULES[@]}" "${PKGS_NETWORK[@]}")
    [[ "$CALENDAR" == true ]] && WANT+=("${PKGS_CALENDAR[@]}")

    MISSING=()
    for pkg in "${WANT[@]}"; do
        pacman -Qq "$pkg" &>/dev/null || MISSING+=("$pkg")
    done

    if (( ${#MISSING[@]} )); then
        echo "  Instalando: ${MISSING[*]}"
        sudo pacman -S --needed "${MISSING[@]}"
    else
        ok "los ${#WANT[@]} paquetes ya están"
    fi

    for pkg in "${PKGS_MANUAL[@]}"; do
        command -v "$pkg" &>/dev/null \
            || warn "$pkg no está — otium no podrá abrir el vault (paru -S $pkg)"
    done

    # ══════════════════════════════════════════════════════════════════════
    hdr "2/6 · Configs"

    # Enlaza, no copia: editar la config viva ES editar el repo.
    lnk() {
        local src="$1" dst="$2"
        mkdir -p "$(dirname "$dst")"
        if [[ -e "$dst" && ! -L "$dst" ]]; then
            mv "$dst" "${dst}.bak"
            warn "había un fichero real en $dst → guardado como ${dst}.bak"
        fi
        ln -sfn "$src" "$dst"
        ok "$(basename "$dst")"
    }

    if [[ "$(realpath "$REPO_DIR")" == "$(realpath "$WAYBAR_DIR" 2>/dev/null || echo /nonexistent)" ]]; then
        ok "el repo YA es ~/.config/waybar — nada que enlazar"
    else
        mkdir -p "$WAYBAR_DIR"
        # style.css y colors.css se ENLAZAN como todo lo demás. Antes se generaban
        # con un sed porque style.css llevaba /home/ziegler/ incrustado; ahora usa
        # ruta relativa (GTK resuelve url() respecto al propio CSS), así que el
        # estilo es transportable y el repo vuelve a ser la única fuente de verdad.
        for f in scripts assets config.jsonc style.css colors.css; do
            lnk "$REPO_DIR/$f" "$WAYBAR_DIR/$f"
        done
    fi

    # ══════════════════════════════════════════════════════════════════════
    hdr "3/6 · Servicios systemd (--user)"

    mkdir -p "$UNIT_DIR"

    # waybar-vault.service refresca el módulo otium cuando cambian las tareas del
    # vault. Existía en systemd/ pero el instalador NUNCA lo desplegaba, así que
    # no llegó a correr en ninguna instalación.
    ln -sfn "$REPO_DIR/systemd/waybar-vault.service" "$UNIT_DIR/waybar-vault.service"
    ok "waybar-vault.service enlazado"

    if [[ "$CALENDAR" == true ]]; then
        ln -sfn "$REPO_DIR/systemd/vdirsyncer.service" "$UNIT_DIR/vdirsyncer.service"
        ln -sfn "$REPO_DIR/systemd/vdirsyncer.timer"   "$UNIT_DIR/vdirsyncer.timer"
        ok "vdirsyncer.service + .timer enlazados"
    fi

    systemctl --user daemon-reload
    systemctl --user enable --now waybar-vault.service >/dev/null 2>&1 \
        && ok "waybar-vault.service activo" \
        || warn "waybar-vault.service no arrancó (systemctl --user status waybar-vault)"

    # ══════════════════════════════════════════════════════════════════════
    if [[ "$CALENDAR" == true ]]; then
        hdr "4/6 · Calendario (vdirsyncer → calcurse)"

        SECRETS="$HOME/.config/vdirsyncer/secrets"
        VDIR_CFG="$HOME/.config/vdirsyncer/config"
        CAL_DATA="$HOME/.local/share/calcurse-outlook"

        if [[ ! -s "$SECRETS" ]]; then
            mkdir -p "$(dirname "$SECRETS")"
            echo
            echo "  Pega tus URLs ICS de Outlook.com."
            echo "  (outlook.live.com → Configuración → Calendario → Calendarios compartidos → Publicar → ICS)"
            echo "  Nombre vacío para terminar."
            echo
            : > "$SECRETS"
            while true; do
                read -rp "    Nombre (p.ej. personal, trabajo — vacío = fin): " CAL_NAME
                [[ -z "$CAL_NAME" ]] && break
                read -rp "    URL ICS de $CAL_NAME: " CAL_URL
                [[ -z "$CAL_URL" ]] && break
                CAL_SLUG=$(printf '%s' "$CAL_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')
                printf '%s=%s\n' "$CAL_SLUG" "$CAL_URL" >> "$SECRETS"
            done
            chmod 600 "$SECRETS"
        fi

        if [[ -s "$SECRETS" ]]; then
            {
                echo "[general]"
                echo "status_path = \"$HOME/.local/share/vdirsyncer/status/\""
                echo
                while IFS='=' read -r name url; do
                    [[ "$name" =~ ^[[:space:]]*#.*$ || -z "$name" ]] && continue
                    mkdir -p "$HOME/.calendars/$name"
                    printf '[pair %s]\na = "%s_remote"\nb = "%s_local"\ncollections = null\n\n' "$name" "$name" "$name"
                    printf '[storage %s_remote]\ntype = "http"\nurl = "%s"\n\n' "$name" "$url"
                    printf '[storage %s_local]\ntype = "filesystem"\npath = "%s/.calendars/%s/"\nfileext = ".ics"\n\n' "$name" "$HOME" "$name"
                done < "$SECRETS"
            } > "$VDIR_CFG"
            ok "config de vdirsyncer generada"

            mkdir -p "$CAL_DATA" "$HOME/.local/share/vdirsyncer/status"
            printf '%s\n' \
                'general.autosave=no' 'general.confirmquit=no' \
                'general.firstdayofweek=sunday' 'general.systemdialogs=no' \
                'appearance.layout=1' 'appearance.notifybar=yes' \
                > "$CAL_DATA/conf"
            ok "config de calcurse escrita"

            systemctl --user enable --now vdirsyncer.timer >/dev/null 2>&1 && ok "vdirsyncer.timer activo"

            yes | vdirsyncer discover &>/dev/null || true
            if vdirsyncer sync &>/dev/null && "$REPO_DIR/scripts/calcurse-import.sh" &>/dev/null; then
                ok "calendarios sincronizados"
            else
                warn "la sincronización falló — reintenta con: vdirsyncer sync"
            fi
        else
            warn "sin calendarios configurados — el reloj no abrirá calcurse"
        fi
    fi

    # ══════════════════════════════════════════════════════════════════════
    hdr "5/6 · Reglas de ventana de niri"

    NIRI_RULES="$HOME/.config/niri/rules.kdl"
    if [[ ! -f "$NIRI_RULES" ]]; then
        warn "no existe ~/.config/niri/rules.kdl — despliega niri primero"
    elif grep -q "calcurse-float" "$NIRI_RULES"; then
        ok "ya presentes"
    else
        cat "$REPO_DIR/niri/waybar-floats.kdl" >> "$NIRI_RULES"
        ok "inyectadas en $NIRI_RULES"
        niri msg action load-config-file "$HOME/.config/niri/config.kdl" &>/dev/null || true
    fi

    # ══════════════════════════════════════════════════════════════════════
    hdr "6/6 · Arrancando waybar"
    pkill -x waybar 2>/dev/null || true
    sleep 0.4
    setsid waybar &>/dev/null &
    disown
    sleep 1.5
fi

# ══════════════════════════════════════════════════════════════════════════
#  VERIFICACIÓN — comprueba lo que el código REALMENTE necesita.
#  Si algo falta, sale con código 1. El instalador no miente sobre su éxito.
# ══════════════════════════════════════════════════════════════════════════
hdr "Verificación"
FAIL=0

# La fuente: sin ella la barra son cuadraditos, aunque todo lo demás funcione.
#
# grep -c y no grep -q, a propósito: con `set -o pipefail`, `grep -q` sale al
# primer match, fc-list recibe SIGPIPE y muere con 141, y pipefail propaga ese
# fallo — la tubería "falla" AUNQUE haya encontrado la fuente. grep -c consume
# toda la entrada y no dispara SIGPIPE.
FONT_HITS=$(fc-list 2>/dev/null | grep -ci 'JetBrainsMonoNL.*Nerd' || true)
if (( FONT_HITS > 0 )); then
    ok "fuente Nerd Font presente ($FONT_HITS variantes)"
else
    err "FALTA la fuente JetBrainsMonoNL Nerd — la barra mostrará tofu (□□□)"
    FAIL=1
fi

# Cada binario que invocan los scripts y los on-click.
MISSING_BIN=()
for c in waybar playerctl jq gh curl swaync-client blueman-manager \
         pwvucontrol wpctl wlogout notify-send kitty inotifywait \
         powerprofilesctl fzf upower; do
    command -v "$c" &>/dev/null || MISSING_BIN+=("$c")
done
if (( ${#MISSING_BIN[@]} )); then
    err "faltan binarios: ${MISSING_BIN[*]}"
    FAIL=1
else
    ok "todos los binarios de los módulos presentes"
fi

# El clic del icono de wifi necesita el cliente del backend ACTIVO.
if systemctl is-active --quiet iwd; then
    command -v impala &>/dev/null && ok "red: iwd + impala" \
        || { err "manda iwd pero falta impala"; FAIL=1; }
elif systemctl is-active --quiet NetworkManager; then
    command -v nm-connection-editor &>/dev/null && ok "red: NetworkManager + nm-connection-editor" \
        || { err "manda NetworkManager pero falta nm-connection-editor"; FAIL=1; }
else
    warn "ningún gestor de red activo — el clic del icono de wifi no hará nada"
fi

# Configs desplegadas Y APUNTANDO AL REPO (no copias sueltas que se desincronizan).
for f in config.jsonc style.css colors.css scripts assets; do
    if [[ -L "$WAYBAR_DIR/$f" ]]; then
        :
    elif [[ -e "$WAYBAR_DIR/$f" ]]; then
        warn "$f existe pero NO es symlink — editarlo no tocará el repo"
    else
        err "falta $WAYBAR_DIR/$f"
        FAIL=1
    fi
done
(( FAIL == 0 )) && ok "configs enlazadas al repo"

# Servicios.
systemctl --user is-active --quiet waybar-vault.service \
    && ok "waybar-vault.service corriendo" \
    || warn "waybar-vault.service parado (otium no se autorrefrescará)"

# Y la barra, ¿está viva?
if pgrep -x waybar >/dev/null; then
    ok "waybar corriendo"
else
    err "waybar NO está corriendo"
    FAIL=1
fi

echo
if (( FAIL )); then
    printf '\033[31m✗ Instalación INCOMPLETA — revisa los ✗ de arriba.\033[0m\n'
    exit 1
fi
printf '\033[32m✓ Spicebar operativa.\033[0m\n'

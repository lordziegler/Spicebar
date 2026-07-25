#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════
#  SPICEBAR · red — iwd + impala en Landsraad (RTL8821CE)
#
#  Uso:
#     sudo bash setup-network.sh --check      solo verifica, no toca nada
#     sudo bash setup-network.sh --fix-driver SOLO arregla el autoarranque del
#                                             driver wifi (el bug de verdad).
#                                             No cambia de backend. Sin riesgo.
#     sudo bash setup-network.sh              --fix-driver + migra a iwd, CON
#                                             auto-rollback de seguridad
#     sudo bash setup-network.sh --confirm    hace permanente la migración
#     sudo bash setup-network.sh --rollback   vuelve a NetworkManager
#
#  Idempotente: puedes relanzarlo siempre.
#
#  ── EL BUG QUE ESTE SCRIPT EXISTE PARA MATAR ──────────────────────────────
#  /etc/modprobe.d/rtw88_8821ce.conf contenía 'blacklist rtw88_8821ce': ponía en
#  lista negra el ÚNICO driver de la tarjeta. udev no lo cargaba al arrancar, así
#  que tras cada reinicio no existía wlan0 y NINGÚN gestor de red (ni iwd, ni
#  NetworkManager, ni impala) veía radio alguna.
#
#  Engañaba porque 'modprobe rtw88_8821ce' a mano SÍ funciona (el nombre
#  explícito se salta el blacklist), lo que hacía parecer que el culpable era el
#  gestor de red. No lo era. Ver files/modprobe.d/rtw88.conf para la historia
#  completa.
# ══════════════════════════════════════════════════════════════════════════
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILES="$HERE/files"
SELF="$HERE/$(basename "${BASH_SOURCE[0]}")"

ROLLBACK_MIN=10          # minutos hasta el auto-rollback si no confirmas
PCI_WIFI="0000:02:00.0"  # RTL8821CE
WIFI_MOD="rtw88_8821ce"

ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
err()  { printf '  \033[31m✗\033[0m %s\n' "$*"; }
hdr()  { printf '\n\033[1m── %s\033[0m\n' "$*"; }

MODE="migrate"
case "${1:-}" in
    --check)       MODE="check" ;;
    --fix-driver)  MODE="fixdriver" ;;
    --confirm)     MODE="confirm" ;;
    --rollback)    MODE="rollback" ;;
    "")            MODE="migrate" ;;
    -h|--help)     sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "Opción desconocida: $1" >&2; exit 1 ;;
esac

# --check es solo lectura: no exige sudo, para que diagnosticar sea barato.
if [ "$MODE" != "check" ] && [ "${EUID}" -ne 0 ]; then
    echo "Ejecútalo con sudo (o usa --check, que no necesita permisos)." >&2
    exit 1
fi

net_up() { ip route get 1.1.1.1 >/dev/null 2>&1; }

# ══════════════════════════════════════════════════════════════════════════
#  ⚠ NUNCA uses 'productor | grep -q' en este script.
#
#  Con 'set -o pipefail', grep -q sale al PRIMER match, el productor recibe
#  SIGPIPE, muere con 141, y pipefail propaga ese 141 como fallo de la
#  tubería — AUNQUE el match existiera. O sea: la comprobación te dice "no
#  encontrado" precisamente PORQUE sí estaba.
#
#  Ya mordió aquí: 'modprobe -c | grep -q blacklist' informaba de que el
#  arranque estaba sano mientras el blacklist seguía activo. Un verificador que
#  miente es peor que no tener verificador.
#
#  Por eso: capturar la salida en una variable y filtrar con here-string (<<<),
#  que no es una tubería y no puede dar SIGPIPE.
# ══════════════════════════════════════════════════════════════════════════

# ¿Hay una regla blacklist EFECTIVA? Se mira la config ya fusionada de todos los
# /etc/modprobe.d y /usr/lib/modprobe.d, no un archivo suelto.
has_blacklist() {
    local cfg; cfg=$(modprobe -c 2>/dev/null)
    grep -qE "^blacklist[[:space:]]+${WIFI_MOD}\$" <<<"$cfg"
}

module_loaded() {
    local out; out=$(lsmod 2>/dev/null)
    grep -qE "^${WIFI_MOD}[[:space:]]" <<<"$out"
}

# ¿Se cargará el driver solo en el próximo arranque?
# Reproduce lo que hace udev: resolver el modalias PCI de la tarjeta a un
# módulo, respetando las reglas de modprobe.d.
# Devuelve 0 si el arranque está sano.
driver_autoloads() {
    local modalias resolved
    modalias=$(cat "/sys/bus/pci/devices/$PCI_WIFI/modalias" 2>/dev/null) || return 1
    resolved=$(modprobe -R "$modalias" 2>/dev/null | head -1)
    [ "$resolved" = "$WIFI_MOD" ] || return 1
    has_blacklist && return 1
    return 0
}

# Segunda red: systemd-modules-load hace modprobe POR NOMBRE, y el nombre
# explícito se salta cualquier blacklist. Si esto existe, el wifi arranca aunque
# el blacklist vuelva.
forced_at_boot() { grep -qxF "$WIFI_MOD" /etc/modules-load.d/*.conf 2>/dev/null; }

report() {
    hdr "Driver wifi (la causa raíz)"
    if driver_autoloads; then
        ok "udev cargará $WIFI_MOD al arrancar (sin blacklist)"
    else
        err "$WIFI_MOD NO se autocargará → arrancarás SIN wlan0"
        modprobe -c 2>/dev/null | grep -E "^blacklist[[:space:]]+${WIFI_MOD}\$" \
            | sed 's/^/      regla efectiva: /'
        grep -rlE "^blacklist[[:space:]]+${WIFI_MOD}" /etc/modprobe.d/ 2>/dev/null \
            | sed 's/^/      viene de: /'
    fi
    forced_at_boot && ok "además está forzado en modules-load.d (red de seguridad)" \
                   || warn "sin red de seguridad en modules-load.d"
    module_loaded && ok "cargado AHORA (wlan0 existe)" \
                  || err "NO cargado ahora"

    hdr "Backend"
    local a_iwd a_nm
    a_iwd=$(systemctl is-active iwd 2>/dev/null)
    a_nm=$(systemctl is-active NetworkManager 2>/dev/null)
    echo "      iwd            : $a_iwd / $(systemctl is-enabled iwd 2>/dev/null)"
    echo "      NetworkManager : $a_nm / $(systemctl is-enabled NetworkManager 2>/dev/null)"
    if [ "$a_iwd" = active ] && [ "$a_nm" = active ]; then
        err "LOS DOS activos — se pelearán por wlan0"
    elif [ "$a_iwd" = active ]; then
        ok "manda iwd (impala funcionará)"
    elif [ "$a_nm" = active ]; then
        ok "manda NetworkManager (impala NO funcionará: necesita iwd)"
    else
        err "ningún gestor activo"
    fi

    hdr "Conectividad"
    net_up && ok "hay ruta a internet" || err "SIN ruta a internet"
    if getent hosts archlinux.org >/dev/null 2>&1; then
        ok "el DNS resuelve"
    else
        err "el DNS NO resuelve"
    fi
    [ -n "$(ip -br addr show wlan0 2>/dev/null)" ] && ip -br addr show wlan0 | sed 's/^/      /'
}

# ══════════════════════════════════════════════════════════════════════════
#  EL ARREGLO DE VERDAD. Independiente del backend: deja el arranque sano
#  tanto si te quedas en NetworkManager como si migras a iwd.
# ══════════════════════════════════════════════════════════════════════════
fix_driver() {
    hdr "Arreglando el autoarranque del driver wifi"

    # 1. Quitar TODO blacklist del driver, venga del archivo que venga.
    local found=0
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        found=1
        if [ "$(grep -cvE '^[[:space:]]*(#|$)' "$f")" -eq 1 ]; then
            # El archivo no contiene nada más que el blacklist: fuera entero.
            rm -f "$f"
            ok "eliminado $f (solo contenía el blacklist)"
        else
            sed -i -E "/^blacklist[[:space:]]+${WIFI_MOD}[[:space:]]*$/d" "$f"
            ok "línea de blacklist borrada de $f"
        fi
    done < <(grep -rlE "^blacklist[[:space:]]+${WIFI_MOD}" /etc/modprobe.d/ 2>/dev/null)
    [ "$found" -eq 0 ] && ok "no había ningún blacklist (ya estaba sano)"

    # 2. Opciones de estabilidad del chip + el aviso de no volver a hacerlo.
    install -Dm644 "$FILES/modprobe.d/rtw88.conf" /etc/modprobe.d/rtw88.conf
    ok "/etc/modprobe.d/rtw88.conf (opciones de estabilidad + aviso)"

    # 3. Red de seguridad: forzar la carga por nombre en el arranque.
    install -Dm644 "$FILES/modules-load.d/rtw88.conf" /etc/modules-load.d/rtw88.conf
    ok "/etc/modules-load.d/rtw88.conf (carga forzada)"

    # 4. Cargarlo ya, si no lo está.
    module_loaded || { modprobe "$WIFI_MOD" && ok "módulo cargado ahora"; }

    # 5. VERIFICAR. Sin esto el script estaría mintiendo sobre su éxito.
    if driver_autoloads; then
        ok "VERIFICADO: el próximo arranque tendrá wlan0"
        return 0
    else
        err "el blacklist SIGUE activo — algo lo está reponiendo"
        err "revisa: modprobe -c | grep $WIFI_MOD"
        return 1
    fi
}

# ── Nombre de archivo de red para iwd ─────────────────────────────────────
# iwd acepta el SSID tal cual si solo tiene [A-Za-z0-9-_ ]; en cualquier otro
# caso exige hex con prefijo '='. Sin esto, un SSID con tilde o '.' se guarda con
# un nombre que iwd luego no reconoce, y la red "desaparece" sin decir por qué.
iwd_name() {
    local ssid="$1"
    if [[ "$ssid" =~ ^[A-Za-z0-9_\ -]+$ ]]; then
        printf '%s' "$ssid"
    else
        # od y no xxd: xxd viene de vim y puede no estar. od es coreutils.
        printf '=%s' "$(printf '%s' "$ssid" | od -An -tx1 | tr -d ' \n')"
    fi
}

migrate_networks() {
    hdr "Migrando redes de NetworkManager a iwd"
    mkdir -p /var/lib/iwd
    chmod 700 /var/lib/iwd
    shopt -s nullglob
    local n=0
    for f in /etc/NetworkManager/system-connections/*.nmconnection; do
        # Solo wifi WPA-PSK. Ethernet, bluetooth y WPA-Enterprise no aplican.
        grep -qE '^type=wifi$' "$f" || continue
        local ssid psk keymgmt
        ssid=$(sed -n 's/^ssid=//p' "$f" | head -1)
        psk=$(sed -n 's/^psk=//p' "$f" | head -1)
        keymgmt=$(sed -n 's/^key-mgmt=//p' "$f" | head -1)
        [ -z "$ssid" ] && continue

        if [ "$keymgmt" = "wpa-eap" ]; then
            warn "'$ssid' es WPA-Enterprise — configúrala a mano en impala"
            continue
        fi
        if [ -z "$psk" ]; then
            # psk-flags=1 → NM la guarda en el llavero, no en disco.
            warn "'$ssid' no tiene la clave en disco — reconéctala desde impala"
            continue
        fi

        local target="/var/lib/iwd/$(iwd_name "$ssid").psk"
        ( umask 077; printf '[Security]\nPassphrase=%s\n' "$psk" > "$target" )
        chmod 600 "$target"
        ok "'$ssid'"
        n=$((n+1))
    done
    echo "      → $n redes migradas"
    [ "$n" -eq 0 ] && warn "ninguna red migrada: tendrás que conectarte a mano desde impala"

    # Los perfiles de NM se quedan INTACTOS a propósito: son la red de seguridad
    # del rollback. No cuestan nada y te salvan si iwd falla.
    ok "los perfiles de NetworkManager quedan intactos (para el rollback)"
}

deploy_iwd_config() {
    hdr "Configuración de iwd, cable y DNS"
    install -Dm644 "$FILES/iwd/main.conf" /etc/iwd/main.conf
    ok "/etc/iwd/main.conf (con el workaround EAPOL de rtw88)"

    install -Dm644 "$FILES/systemd-network/20-wired.network" /etc/systemd/network/20-wired.network
    ok "/etc/systemd/network/20-wired.network (el cable, vía systemd-networkd)"

    install -Dm644 "$FILES/resolved.conf.d/dns-over-tls.conf" /etc/systemd/resolved.conf.d/dns-over-tls.conf
    ok "/etc/systemd/resolved.conf.d/dns-over-tls.conf (esquiva el bloqueo de UDP/53)"

    # Basura de la migración anterior: metía ruido en cada arranque.
    if [ -e /etc/systemd/system/iwd.service.d/debug.conf ]; then
        rm -f /etc/systemd/system/iwd.service.d/debug.conf
        rmdir /etc/systemd/system/iwd.service.d 2>/dev/null
        ok "quitado el drop-in de depuración de iwd (spam en el journal)"
    fi
    systemctl reset-failed iwd-rollback.service 2>/dev/null && ok "limpiado el iwd-rollback fallido"

    systemctl daemon-reload
    systemctl restart systemd-resolved
}

do_rollback() {
    hdr "ROLLBACK → NetworkManager"
    systemctl stop iwd-rollback.timer 2>/dev/null
    systemctl stop iwd.service systemd-networkd.service 2>/dev/null
    systemctl disable iwd.service systemd-networkd.service 2>/dev/null

    # 'mask', no solo 'disable': iwd se autoactiva por D-Bus en cuanto algo lo
    # llame (impala, o el icono de waybar), y entonces se pelea con NM por
    # wlan0. Eso ya pasó una vez.
    systemctl mask iwd.service 2>/dev/null
    rm -f /etc/systemd/network/20-wired.network

    systemctl unmask NetworkManager.service 2>/dev/null
    systemctl enable --now NetworkManager.service >/dev/null 2>&1

    # OJO: el driver NO se toca. El arreglo del blacklist es independiente del
    # backend y debe sobrevivir al rollback — si no, volverías al bug original.
    ok "NetworkManager de vuelta (el arreglo del driver se mantiene)"

    echo "      esperando reconexión (hasta 45 s)..."
    for _ in $(seq 1 45); do
        if net_up; then sleep 2; ok "conectado"; ip -br addr show wlan0 | sed 's/^/      /'; return 0; fi
        sleep 1
    done
    warn "sigue sin conectar — conéctate a mano con: nmtui"
    return 1
}

# ══════════════════════════════════════════════════════════════════════════
case "$MODE" in

check)
    report
    echo
    driver_autoloads && echo "El arranque está sano." \
                     || echo -e "\033[31mEl arranque está ROTO: reinicia y te quedas sin wifi.\033[0m"
    ;;

fixdriver)
    fix_driver || exit 1
    echo
    echo "Listo. El wifi ya sobrevivirá al reinicio, con el backend que sea."
    ;;

rollback)
    do_rollback
    ;;

confirm)
    if ! net_up; then
        err "No tienes ruta a internet. NO confirmo una migración rota."
        err "Fuerza el rollback:  sudo bash $SELF --rollback"
        exit 1
    fi
    hdr "Confirmando la migración"
    systemctl stop iwd-rollback.timer 2>/dev/null
    systemctl reset-failed iwd-rollback.service 2>/dev/null
    ok "auto-rollback cancelado"

    systemctl enable iwd.service >/dev/null 2>&1
    systemctl disable NetworkManager.service >/dev/null 2>&1
    systemctl enable systemd-networkd.service >/dev/null 2>&1
    ok "iwd arranca solo · NetworkManager no · networkd cubre el cable"
    warn "NetworkManager sigue INSTALADO: el rollback siempre es posible"
    echo
    report
    echo
    echo "✅ iwd manda. El icono de wifi de waybar abre impala."
    echo "   Para volver atrás:  sudo bash $SELF --rollback"
    ;;

migrate)
    hdr "Comprobaciones previas"
    net_up || { err "No hay red. Conéctate antes de migrar."; exit 1; }
    ok "hay red"
    for p in iwd impala; do
        pacman -Qq "$p" &>/dev/null || { err "falta el paquete '$p' (pacman -S $p)"; exit 1; }
    done
    ok "iwd e impala instalados"

    # PASO 1 — el arreglo real. Si esto falla, migrar sería suicida: iwd
    # arrancaría sin radio, exactamente como la última vez.
    fix_driver || { err "No sigo: sin driver al arrancar, iwd no tendría radio."; exit 1; }

    migrate_networks
    deploy_iwd_config

    hdr "Armando el auto-rollback ($ROLLBACK_MIN min)"
    systemctl stop iwd-rollback.timer 2>/dev/null
    systemd-run --unit=iwd-rollback --on-active="${ROLLBACK_MIN}min" \
        --description="Auto-rollback a NetworkManager si iwd falla" \
        /bin/bash "$SELF" --rollback >/dev/null
    ok "si no confirmas, NetworkManager vuelve solo en $ROLLBACK_MIN min"
    warn "no te puedes quedar tirado: pase lo que pase, recuperas red"

    hdr "Cambio de guardia → iwd"
    systemctl unmask iwd.service 2>/dev/null
    # NM solo se PARA (no se deshabilita) para que el rollback sea trivial.
    systemctl stop NetworkManager.service wpa_supplicant.service 2>/dev/null
    sleep 2
    systemctl start systemd-networkd.service 2>/dev/null
    systemctl start iwd.service
    echo "      esperando a que iwd conecte (hasta 60 s)..."

    connected=0
    for _ in $(seq 1 60); do
        if net_up; then connected=1; break; fi
        sleep 1
    done

    if [ "$connected" -eq 1 ]; then
        sleep 2
        hdr "iwd CONECTÓ"
        report
        echo
        echo "  ══════════════════════════════════════════════════════════════"
        echo "  PRUÉBALO AHORA (navegador, y abre impala desde el icono)."
        echo
        echo "  Si va bien, HAZLO PERMANENTE — tienes $ROLLBACK_MIN minutos:"
        echo "      sudo bash $SELF --confirm"
        echo
        echo "  Si NO haces nada, NetworkManager vuelve solo. Sin riesgo."
        echo "  ══════════════════════════════════════════════════════════════"
    else
        err "iwd NO conectó"
        echo
        echo "  Motivo (últimas líneas del journal):"
        journalctl -u iwd --since "-2min" --no-pager 2>/dev/null \
            | grep -iE 'fail|error|denied|refus|timeout|handshake|eapol' | tail -8 | sed 's/^/      /'
        echo
        echo "  NO HAGAS NADA: NetworkManager vuelve solo en unos minutos."
        echo "  O fuérzalo ya:  sudo bash $SELF --rollback"
        exit 1
    fi
    ;;
esac

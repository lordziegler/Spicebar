# Red · iwd + impala

El módulo `network` de la barra abre **impala** al hacer clic. impala habla
*solo* con **iwd** (es su backend nativo), así que la barra y el backend de red
van juntos: si iwd no manda, el icono no puede abrir impala. Por eso esta
carpeta vive aquí.

```bash
sudo bash network/setup-network.sh --check       # diagnóstico, no toca nada
sudo bash network/setup-network.sh --fix-driver  # solo el arreglo del driver (sin riesgo)
sudo bash network/setup-network.sh               # migra a iwd, con auto-rollback
sudo bash network/setup-network.sh --confirm     # hace permanente la migración
sudo bash network/setup-network.sh --rollback    # vuelve a NetworkManager
```

---

## ⚠ La trampa: NUNCA pongas en blacklist `rtw88_8821ce`

Este portátil (Landsraad, HP con **Realtek RTL8821CE**) se quedó sin wifi tras
cada reinicio por **una sola línea**:

```
/etc/modprobe.d/rtw88_8821ce.conf:   blacklist rtw88_8821ce
```

Esa línea pone en lista negra **el único driver que tiene la tarjeta**. Se suele
añadir cuando vas a instalar el driver alternativo `rtl8821ce-dkms`… pero si el
DKMS no llega a instalarse, el blacklist queda huérfano: bloquea el driver bueno
sin poner nada a cambio.

### Por qué engaña tantísimo

Es un fallo diseñado para hacerte perder horas mirando al sitio equivocado:

1. **Un blacklist NO descarga lo que ya está cargado.** Si lo escribes con el
   módulo ya en memoria, todo sigue funcionando perfectamente… hasta el
   siguiente reinicio. La bomba queda armada con retardo, y cuando estalla ya no
   asocias la causa con el cambio.

2. **Un blacklist solo bloquea la carga por *modalias*** — que es justo como
   udev autocarga los drivers al arrancar. Así que arrancas sin `wlan0`.

3. **Pero `modprobe rtw88_8821ce` por nombre explícito SÍ funciona**, porque el
   nombre explícito se salta el blacklist. Tu arreglo manual funciona al
   instante, y eso te convence de que el culpable es *otro*.

Esa asimetría — **no carga solo, sí carga a mano** — es la firma inequívoca de
un blacklist. Si algún día vuelves a verla, mira `modprobe.d` **antes** que
nada.

### El daño colateral

Sin `wlan0`, **ningún** gestor de red ve radio alguna. Eso hizo que iwd,
NetworkManager e impala parecieran culpables por turnos, y llevó a "arreglar"
cosas que nunca estuvieron rotas: se migró el backend, se enmascaró iwd, se
desinstaló impala, se persiguió un `eno1` sin cable… Todo ruido. **iwd nunca
falló: nunca tuvo radio que gestionar.**

### Cómo saber si el arranque está sano

```bash
sudo bash network/setup-network.sh --check
```

O a mano, reproduciendo lo que hace udev:

```bash
# ¿el modalias de la tarjeta resuelve al driver?
modprobe -R "$(cat /sys/bus/pci/devices/0000:02:00.0/modalias)"   # → rtw88_8821ce

# ¿hay un blacklist EFECTIVO? (mira la config fusionada, no un archivo suelto)
modprobe -c | grep '^blacklist rtw88_8821ce'                      # → NO debe salir nada
```

---

## Qué instala `setup-network.sh`

| Archivo | Para qué |
|---|---|
| `/etc/modprobe.d/rtw88.conf` | Opciones de estabilidad del chip, y el aviso de no volver a blacklistear. |
| `/etc/modules-load.d/rtw88.conf` | Red de seguridad: fuerza la carga **por nombre**, que se salta cualquier blacklist futuro. |
| `/etc/iwd/main.conf` | Config de iwd, con el workaround EAPOL imprescindible en esta tarjeta. |
| `/etc/systemd/network/20-wired.network` | El cable (`eno1`), vía systemd-networkd: iwd solo hace wifi. |
| `/etc/systemd/resolved.conf.d/dns-over-tls.conf` | DNS-over-TLS, porque la red de casa descarta el DNS por UDP/53. |

### `ControlPortOverNL80211=false`

Sin esto, iwd **no conecta** en esta tarjeta: falla con `connect-failed,
status: 1` mientras wpa_supplicant conecta sin problema. Con el método moderno
de puerto de control (nl80211), los paquetes EAPOL del handshake WPA2 de 4 vías
no llegan al router en el driver `rtw88`. Esto fuerza el método antiguo.

Si algún día cambias de tarjeta wifi, esta línea sobra.

### Las opciones de `modprobe.d/rtw88.conf`

`disable_aspm=y`, `disable_msi=y`, `disable_lps_deep=y` no son cosmética: sin
ellas la tarjeta genera tormentas de `PCIe Bus Error ... RxErr` y sufre cortes
intermitentes.

---

## Seguridad de la migración

El portátil **no tiene cable**: el wifi es la única vía. Por eso
`setup-network.sh` nunca te puede dejar tirado:

- **Arregla el driver ANTES de migrar**, y aborta si el arreglo no se verifica.
  Migrar a iwd sin driver es exactamente lo que falló la última vez: iwd
  arrancaba sin radio.
- **Arma un auto-rollback de 10 minutos** antes de tocar el backend. Si iwd
  falla y no puedes ni teclear, NetworkManager vuelve solo. Solo tienes que
  esperar.
- **No desinstala NetworkManager** ni borra sus perfiles: son la red de
  seguridad del rollback, y no cuestan nada.
- **El rollback NO deshace el arreglo del driver.** Ese arreglo es independiente
  del backend y debe sobrevivir siempre; si no, volverías al bug original.

## Volver a NetworkManager

```bash
sudo bash network/setup-network.sh --rollback
```

Deja iwd **masked**, no solo `disable`. Es a propósito: iwd se autoactiva por
D-Bus en cuanto algo lo llame (impala, o el propio icono de la barra), y
entonces se pelea con NetworkManager por `wlan0`. Ya pasó una vez.

El icono de la barra lo detecta solo: si manda NetworkManager, abre
`nm-connection-editor` en vez de impala (ver `scripts/wifi-menu.sh`).

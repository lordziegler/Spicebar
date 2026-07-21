# Waybar Retrofuturista — Changelog

## [sin versión] — 2026-07-20

### Battery: gestor de perfiles de energía en left-click
- **Nuevo** `custom/battery.on-click` → `power-open.sh`: abre una ventana Kitty
  flotante (`app-id power-float`) con `power-menu.sh`, un selector `fzf` de los
  tres perfiles de `power-profiles-daemon` (Performance / Balanced / Power
  Saver), con cabecera de estado de batería (`upower`: % / estado / tiempo
  restante). Marca el perfil activo y aplica el elegido con
  `powerprofilesctl set`.
- El toggle de porcentaje que antes vivía en left-click (`battery.sh toggle`)
  pasa a **right-click**.
- **niri**: nueva regla flotante `power-float` (400×230, compacta: solo 3
  opciones + header). Añadida a `niri/waybar-floats.kdl` y a las reglas vivas.
- **Dependencias nuevas**: `power-profiles-daemon`, `fzf`, `upower`.

## [prototipo-v1] — 2026-07-10

Refactor de Spicebar hacia el prototipo **retrofuturista mejorado**
(«Imperator CRT»): ámbar fosforescente sobre Corrino casi-negro, islas
flotantes con rim dorado y glow de tubo catódico. Compositor: **niri**.

### Cambios en `config.jsonc`
- **Reestructurado a tres islas** mediante `group/` nativo de waybar:
  - `group/sinistra` (izq): `custom/pomodoro` · `custom/otium` · `custom/mentat`
  - `niri/workspaces` (centro): planetas orbitando
  - `group/dextra` (der): `custom/github` · `group/vitals` · `clock` · `custom/power`
- **Nuevo drawer de sistema** `group/vitals`: la bandeja (cpu, memory, temp,
  network, bluetooth, pulseaudio, swaync, battery) queda oculta tras un asa
  (`custom/tray-toggle`) y se despliega al pasar el ratón. Nativo, sin hacks.
- **Añadido** `custom/github` (racha de contribuciones, `github-graph.sh`, 30 min).
- **Añadido** `custom/tray-toggle` (asa del drawer).
- Barra: `height` 30 → **34**, `margin` `6px 10px 0 10px`, `spacing` 0.
- Corregido glyph inválido de red desconectada: `a` (5 dígitos, JSON
  lo parseaba como `` + `a`) → par subrogado válido `󰖪`
  (nf-md-wifi_off, U+F05AA).
- **niri**: se mantiene `niri/workspaces` (no había módulos sway/hyprland que
  sustituir). Sin cambios de `layer`/`position` (`top`/`top`).
- Todos los scripts custom preservados intactos; ningún módulo eliminado.

### Cambios en `style.css` (reescrito)
- `@import "./colors.css"` al inicio; **cero hex hardcodeados** salvo los
  `rgba()` de glow (derivados de un token) y la ruta del escudo del pomodoro.
- Islas (`#sinistra`, `#dextra`, `#workspaces`): cristal esmerilado con
  degradado, **rim dorado superior + hairline inferior**, esquinas rectas
  (HUD), `box-shadow` con glow sutil al hover.
- Workspaces planetarios: inactivo `@rf-accent-warm` al 62 %, activo
  `@rf-accent` con subrayado dorado (`inset box-shadow`) y text-shadow glow.
- `transition: 0.15s ease` en módulos y estados hover/active diferenciados.
- Cubiertos **todos** los estados que emiten los scripts: pomodoro
  (idle/work/break/longbreak + variantes -paused), temp (cool→critical),
  battery (charging/warning/critical), mentat (canticulum/-pausa/-compact),
  otium (otium/officium), swaync (notification/none/dnd).
- `#custom-pomodoro.idle` conserva la ruta absoluta a `ziegler.png` a
  propósito: `setup.sh` la reescribe con `sed` al desplegar.

### Variables en `colors.css` (nuevo)
- **Paleta**: Imperator CRT, extraída de `Imperator-palette.md`. Familias
  oro/ámbar sobre fondo Corrino:
  - fondo `#0E0C08` (Deep Void) → hover `#241C0C`, con alpha para el blur.
  - texto base `#D4A843`, muted `#B8860B`, subtle `#8A7040`.
  - acento `#FFD700` (Golden Signal), warm `#F0B030` (Solar Flare).
  - estados: warning `#C8960C`, critical `#FF6B2B`, success `#8DB87A`,
    info `#5B8DA8`, number `#D48840`.
- **Fuente**: `"JetBrainsMono Nerd Font"`, fallback `"Symbols Nerd Font"`,
  `monospace`; 13 px, weight 600.
- **Nota técnica**: GTK 3 CSS no soporta `:root`/`var()`/`color-mix()`, así
  que los tokens se expresan con `@define-color` (equivalente funcional del
  esquema `--rf-*` pedido). Sin esta adaptación waybar no parsearía el CSS.

### Compatibilidad niri
- Módulos niri usados: `niri/workspaces` (IPC nativo, verificado
  «Niri IPC starting» en el log de arranque).
- Sin issues conocidos. Waybar v0.15.0 arranca sin errores de CSS ni de
  config; barra configurada 1346×34 en `eDP-1`.

### Otros
- **Scripts hechos ejecutables** (`chmod +x scripts/*.sh`, 644 → 755). Estaban
  a 644, por lo que waybar los invocaba con «Permission denied» y los módulos
  custom quedaban vacíos. Cambio reversible, sin tocar el contenido; necesario
  para una barra funcional. Todos tienen shebang correcto.
- Deploy replicando `setup.sh`: `config.jsonc` symlinkeado; `style.css` **y**
  el nuevo `colors.css` generados con `sed 's|/home/[^/]*/|$HOME/|g'` hacia
  `~/.config/waybar/` (necesario para reescribir la ruta de `ziegler.png` y
  para que `@import "./colors.css"` resuelva junto al `style.css` desplegado).

### Compactación (pegar arriba + menos área)
- Barra **pegada al borde superior**: `margin` `6px 10px 0 10px` → `0` (ya no
  flota) y `height` 34 → 26 (mínimo). Antes reservaba 40px de zona exclusiva.
- Como el contenido forzaba la altura real (iconos 16-18px), se **encogió el
  contenido**: iconos `Symbols Nerd Font` 15/16/18 → **14**; `rise` de
  pulseaudio 1500 → 400; glifos otium/officium 20 → 15px; asa del drawer
  15 → 14px; márgenes verticales de workspaces (`2px`→0) y de `.vital` (`3px`→0).
- Resultado: altura real **31px flush-to-top** (≈22 % menos de área vertical).

### Restauración del look de la primera versión (v1)
A petición del usuario se recuperaron los **tamaños, glow, iconos y colores**
de la primera waybar, manteniendo la estructura de islas + drawer + pegada
arriba. La base ámbar es común a ambas versiones; lo que se revirtió:
- **Iconos** (glifos `Symbols Nerd Font` de v1): bluetooth `U+F294` (antes
  `F293`), ethernet `F1E6`, desconectado reutiliza el de wifi `F1EB`, mute
  `U+EEE8`, cpu `F2DB`. Tamaños 16px (iconos), 18px (swaync).
- **Tamaños**: planetas 20px (`min-width` 32), otium/officium 20px, reloj
  17px, power 18px, módulos base 16px, mentat 13px.
- **Glow en 2-3 capas** de v1 en módulos, workspaces, reloj y power.
- **Colores gruvbox de v1** (tokens en `colors.css`): bluetooth aqua
  `#83a598` / conectado verde `#8ec07c`, rojo power/crítico `#fb4934`,
  naranja batería/temp `#fe8019`, inactivo `#a89984`.
- `height` 26 → 35 (coincide con el alto real del contenido; sin warnings).
  Sigue pegada al borde superior (`margin: 0`).

### Vuelta a la disposición plana de la v1 (todo visible)
El usuario confirmó (con capturas) que prefiere la **disposición espacial de la
primera versión**: barra plana, sin islas ni drawer, con **todos los módulos
del sistema siempre visibles** (en el rediseño quedaban ocultos tras el asa ≡,
por eso "no se veían los colores ni la disposición"). Requisito explícito:
**CPU siempre visible**.
- `config.jsonc`: restaurada la disposición v1 (flat, sin `group/*` ni drawer):
  - izq: pomodoro · otium · mentat · **temp · memory**
  - centro: workspaces
  - der: **cpu** · network · bluetooth · pulseaudio · swaync · battery · clock · power
  - Eliminados `group/sinistra`, `group/dextra`, `group/vitals`,
    `custom/tray-toggle` y `custom/github` (no existían en v1).
- `style.css`: cuerpo de la v1 (fondo de barra plano `@bar-bg`, sin chrome de
  islas), con `@import "./colors.css"` al inicio.
- `colors.css`: ahora contiene la paleta v1 (gruvbox hard dark) como tokens.
- `height` 30 → 33 (alto real del contenido; sin warnings). Pegada arriba
  (`margin: 0`). Scripts siguen ejecutables; `github-graph.sh` se conserva
  aunque su módulo ya no se use.

### Síntesis final: islas + asa + v1 (CPU siempre visible)
Estado definitivo pedido por el usuario: conservar la **versión reciente con
islas, asa (drawer) y funcionalidades** (github incluido), tomando de la v1
sólo los **tamaños** y **parte de la disposición**.
- Estructura: islas `group/sinistra` · `niri/workspaces` · `group/dextra`,
  con el drawer `group/vitals` y su asa `custom/tray-toggle` (≡). Se mantiene
  `custom/github` y todas las funcionalidades.
- **CPU siempre visible**: `cpu` se sacó del drawer a `group/dextra`
  (`github · cpu · [drawer] · clock · power`). El resto del sistema (memory,
  temp, network, bluetooth, pulseaudio, swaync, battery) sigue en el drawer.
- **Tamaños v1**: planetas 20px (`min-width` 32), otium 20px, reloj 17px,
  power/swaync 18px, módulos 16px, mentat 13px; glow en 2-3 capas.
- **Colores v1** (tokens `rf-*` en `colors.css`): base ámbar + acentos gruvbox
  (bluetooth aqua `#83a598`/verde `#8ec07c`, rojo `#fb4934`, naranja `#fe8019`).
- **Iconos v1**: bluetooth `U+F294`, ethernet `F1E6`, mute `EEE8`, cpu `F2DB`.
- `height` 35, pegada arriba (`margin: 0`). Sin errores ni warnings.

### Fuera islas: barra plana v1 + drawer/asa + CPU visible
El usuario reportó que con islas se veía "sobrepuesto", los colores no se
conservaban y los iconos del workspace no salían como en la v1. Decisión:
**quitar las islas** y volver al render plano de la v1 (que se veía bien),
conservando lo demás.
- `style.css`: **base = cuerpo plano de la v1** (fondo de barra `@bar-bg`, sin
  chrome de islas, `#workspaces` transparente, fuente `JetBrainsMonoNL Nerd
  Font Mono` → planetas idénticos a la v1). Encima se AÑADE sólo:
  `#custom-github`, el asa `#custom-tray-toggle` y separador `#vitals .vital`.
- `colors.css`: paleta v1 con nombres v1 (`fg`, `accent-gold`, `solar-flare`,
  `power-red`, `muted`, `wb-*`…), consumida por `@import`.
- `config.jsonc`: disposición plana (sin `group/sinistra` ni `group/dextra`).
  Se conserva el drawer `group/vitals` con su asa (≡) y `custom/github`.
  **CPU siempre visible** en `modules-right` (`github · cpu · [drawer] ·
  clock · power`); memory/temp/network/bt/pulse/swaync/battery en el drawer.
- `height` 33, pegada arriba. Sin errores ni warnings de CSS.
- Nota de proceso: `cat` está aliaseado a `bat`, que llegó a inyectar códigos
  ANSI en el CSS; los archivos se reconstruyen ahora con Python/Write.

### Pulido: tooltip · glow · centrado de iconos · (frosted glass)
- **Tooltip tema Imperator**: `tool-*` en `colors.css` pasan de gris genérico
  a ámbar CRT — fondo `rgba(20,15,8,0.96)`, texto `#D4A843`, filo dorado
  `rgba(255,215,0,0.42)`; `border-radius` 10 → 4px.
- **Glow de workspaces reforzado**: text-shadow en 3 capas más intenso
  (0 0 4/12/28px), `opacity` 0.72 → 0.88; activo con halo dorado fuerte +
  `box-shadow` que hace brillar el subrayado.
- **Iconos: recorte y centrado**: `min-height: 0` en el reset; celdas
  uniformes centradas (`min-width` + padding simétrico) en los iconos del
  drawer y del sistema; `rise` de pulseaudio 1500 → 400 (estaba descentrando
  el volumen hacia arriba); swaync 18 → 16px para que no sobresalga/corte.
- **Frosted glass**: NO es posible en niri — niri 26.04 no implementa blur
  (`layer-rule { blur { } }` → "unexpected node"). Se mantiene el panel
  translúcido `bar-bg rgba(14,12,8,0.68)` (el wallpaper se transparenta), que
  es lo más cercano sin un compositor con desenfoque.

### Workspaces sólo-glow · simetría de iconos · tokens de estado
- **Workspaces sin cuadrícula**: la caja que se veía no era el `box-shadow`
  sino el **fondo y borde que GTK pinta por defecto en todo `button`**. Se
  neutraliza en `#workspaces button` (`background: transparent; border: none;
  border-radius: 0`), y el `:hover` cambia su recuadro (`@wb-hvr-bg` +
  `border-radius: 6px`) por un halo dorado. Estado activo y hover se marcan
  ahora **sólo con glow**, como officium.
- **Espaciado armónico de iconos**: los glifos tienen anchos de avance
  distintos (wifi ≠ bluetooth ≠ volumen), así que un padding igual da huecos
  desiguales. Se usa **celda de ancho fijo** — `min-width: 22px` — idéntica
  para `#cpu`, el asa y todos los hijos del drawer, de modo que el glifo se
  centra dentro de ella. `#vitals .vital` (1 id + 1 clase) gana en
  especificidad a los `#id` de la v1, así que anula sus `margin-left: 8px`
  asimétricos sin tocarlos.
  Hacen falta **padding Y margin**, no sólo uno: `padding 9px` da aire DENTRO
  de la celda y `margin 3px` separa las celdas ENTRE sí. Un primer intento con
  `margin: 0` dejó las celdas pegadas y varios iconos Nerd Font —cuya tinta es
  más ancha que su avance— se invadieron visualmente (wifi/bluetooth
  solapados). El margen de la v1 no era decorativo: era lo que lo evitaba.
- **Cero hex hardcodeados en `style.css`** (requisito de la spec original):
  los colores de estado heredados de la v1 pasan a `colors.css` como
  `@state-warn` `@state-hot` `@state-ok` `@state-info`. Los `rgba()` dentro de
  los `text-shadow` se quedan: GTK3 no tiene `color-mix()`/`alpha()`, así que
  no se pueden derivar de un token.

### Iconos solapados — causa raíz: la fuente, no el espaciado
- Síntoma: bluetooth aparecía dibujado ENCIMA de wifi, y ni subir el padding ni
  el margin lo corregía.
- Los spans del config pedían `Symbols Nerd Font`, **familia que no está
  instalada**: fontconfig caía a `JetBrainsMonoNL Nerd Font` (variante **NF**).
  En NF los iconos de wifi (`U+F1EB`) y volumen (`U+F028`) declaran **avance
  600 pero su tinta llega a 1154** → se derraman **+554 unidades (≈12px a
  16pt) sobre el vecino**. Bluetooth no derrama, por eso siempre era el que
  "recibía" el solape. Ningún padding puede taparlo: el derrame es casi tan
  ancho como el icono entero.
- Por qué la v1 no lo enseñaba: tenía ~24px de hueco (padding 8+8 + margin 8),
  suficiente para absorber los ~12px de derrame. El bug llevaba ahí desde el
  principio; comprimir las celdas para hacerlas simétricas sólo lo destapó.
- **Arreglo**: los 19 spans (config.jsonc + 5 scripts) pasan a
  `JetBrainsMonoNL Nerd Font Propo` (**NFP**), única variante instalada cuyo
  avance (1154) coincide con la tinta. Mono (**NFM**) también encaja pero
  achica el icono a una celda. Con el avance correcto el glifo ya cabe en su
  caja y `min-width: 26px` puede centrarlo de verdad → simetría real, no
  huecos grandes que disimulan.

### Drawer por clic · lenguaje único de estado inactivo · temp robusto
- **Drawer sin hover**: `click-to-reveal: true`. El asa (≡) abre y cierra con
  clic; ya no se despliega al rozarla. Se elimina también la regla
  `#custom-tray-toggle:hover` — un realce al pasar el ratón prometería una
  interacción que ya no existe. Tooltip actualizado ("clic para desplegar").
- **Un solo ámbar para el reposo** (`@idle` en `colors.css`, = el de
  `#custom-swaync.none`): asa del drawer, mpris en pausa y workspaces no
  activos comparten ahora color, opacidad (0.7) y glow suave. Antes cada uno
  iba por su cuenta — el asa en `@solar-flare`, el mpris en gris `@muted`
  (que se salía del tema). El dorado brillante `@accent-gold` queda reservado
  a lo ACTIVO, así el foco se lee solo.
  `#custom-otium` conserva `@solar-flare` a propósito: es el módulo de
  referencia del glow, no un estado de reposo.
- **Temperatura — dinámica hoy, frágil mañana**: `temp.sh` emite las 5 clases
  (`cool/mild/warm/hot/critical`) y el CSS las colorea todas — verificado en
  vivo (48°C → `mild`). Pero el sensor estaba **hardcodeado a `hwmon5`**, y el
  índice de hwmon NO es estable entre reinicios: si el kernel renumera, la
  lectura sale vacía → `TEMP=0` → el icono se queda clavado en `cool` en
  silencio, para siempre. Ahora se resuelve por **nombre** (`coretemp`, con
  `acpitz` de reserva).

### Vuelta al hover · filo del workspace activo · contraste del mpris
- **Drawer de nuevo por hover** (`click-to-reveal: false`) y se restaura el
  realce `#custom-tray-toggle:hover`, que confirma que el asa responde.
- **Asa sin tooltip** (`"tooltip": false`): el bocadillo "Sistema — …" tapaba
  la barra y el drawer ya se explica solo al desplegarse.
- **Línea inferior del workspace activo**: `border-bottom: 2px solid
  @accent-gold`, tal y como la define la paleta Imperator. El filo se reserva
  **en todos los botones** (`2px solid transparent` en los inactivos): si sólo
  lo llevara el activo, sería 2px más alto que sus vecinos y el planeta daría
  un salto vertical al cambiar de workspace.
- **Contraste del mpris**: activo e inactivo eran **el mismo color** (`@fg`) y
  sólo variaba la opacidad → misma tinta, luminancia casi idéntica, 1.00:1
  entre estados. Ahora contrastan por luminancia sin salir de la familia ámbar:
  `@mpris-on #F0B030` (Solar Flare) vs `@mpris-off #8A7040` (Tarnished Signal,
  el color que la paleta reserva a "inactive labels"). Medido: **2.45:1 entre
  estados**, y el inactivo mantiene **4.16:1 contra el fondo**, por encima del
  mínimo de ~4:1 que la propia paleta exige a los estados inactivos. La pausa
  va a `opacity: 1`: el color ya carga el atenuado, y bajarla además lo hacía
  ilegible.

### Glow del drawer — por color real y por estado
- **mpris revertido** a sus colores originales (`@fg` .88 reproduciendo,
  `@muted` .65 en pausa). Se retiran los tokens `@mpris-on` / `@mpris-off`.
- **El glow del drawer estaba mal de dos maneras**:
  1. *Recortado*. El `GtkRevealer` que envuelve a los hijos del drawer los
     recorta a su asignación, y los halos anchos (14–26px) se salían de la
     caja del icono y quedaban cortados — de ahí que el cajón se viera plano.
     Todos pasan a ser **compactos e intensos** (3/6/9px, alfa alto): caben
     dentro de la celda y sobreviven al recorte.
  2. *Ámbar fijo*. Una única regla daba halo ámbar a TODOS los iconos, así que
     el bluetooth cian, el volumen silenciado o la batería cargando brillaban
     en ámbar aunque su tinta fuera otra.
- Ahora **cada estado lleva su halo del color de su icono**, y los módulos
  dinámicos cambian de halo al cambiar de estado: temperatura
  (gris→ámbar→amarillo→naranja→rojo), batería (ámbar / naranja / rojo /
  verde al cargar), bluetooth (azul → verde conectado → sin halo si apagado),
  red y volumen (gris al desconectar/silenciar), notificaciones (dorado con
  avisos, gris en no-molestar) y el asa (ámbar → dorado al hover).
  Funciona por especificidad: las reglas de estado (1 id + 1 clase) ganan a
  las de base (1 id), sin `!important`.
- Verificado con un script que compara el RGB de cada halo contra el color
  declarado de su selector: **43 selectores, 0 desviaciones**.

### RAM — barras que no se cierran en bloque
- `memory.sh` usaba 8 niveles cuyo tope era `█`. Consecuencia: **a partir del
  25% la primera barra saltaba a bloque macizo** y ya no se despegaba; a 100%
  eran cuatro bloques pegados, un muro sólido en vez de una barra.
- Ahora **6 niveles** (`▏▎▍▌▋▊`) con tope en `▊` = **3/4 de celda**: siempre
  queda un carril libre a la derecha, así que la barra llena se sigue leyendo
  como barra. A 100% da `▊▊▊▊`, no `████`.
- **Glow de la RAM = el de la CPU**, exactamente (`0 0 3px` alfa .9 + `0 0 10px`
  alfa .45). Ambos dibujan barras de bloque, así que brillan igual. Lo que sí
  se descarta es el halo de 3 capas de los iconos: los caracteres de bloque
  tienen mucha más tinta que un glifo y ese halo se acumulaba sobre sí mismo
  hasta fundir las cuatro barras en una mancha.

### Frosted glass — SÍ existe. Cómo se hace (y por qué tardé tanto)
niri **sí** soporta blur, vía `ext_background_effect_manager_v1` (el protocolo
nuevo y estándar de Wayland). Requiere DOS piezas:

```kdl
// theme.kdl — DEFINE el efecto (no lo activa en nada por sí solo)
blur {
    on
    passes 3        // más pasadas = más suave y más GPU
    offset 5.0      // sube el radio efectivo
    noise 0.03      // rompe el banding
    saturation 1.1  // recupera el color que el desenfoque apaga
}

// rules.kdl — lo PIDE para una superficie concreta
layer-rule {
    match namespace="waybar"
    background-effect {
        blur true
    }
}
```

- El nodo que faltaba es **`background-effect`**, no `blur` suelto dentro de la
  `layer-rule` (eso sí da `unexpected node`, y por eso lo di por imposible).
- **Kitty no necesita regla**: pide el blur él mismo por el protocolo. Waybar y
  swaync no saben hacerlo, así que hay que imponérselo desde `rules.kdl`.
- Las `layer-rule` se aplican **al crear la superficie** → hay que reiniciar
  waybar tras tocarlas.
- **El bloque `blur` es global**: kitty, waybar y swaync comparten desenfoque.
  Lo único que los diferenciaba era la opacidad.

**Lección de método** (dos conclusiones erróneas seguidas, la misma causa):
declaré "niri no tiene blur" tras buscar las cadenas `blur` y `kde` en los
globales de Wayland y en el binario. El protocolo se llama
`ext_background_effect_manager_v1` — **no contiene ninguna de las dos**. El dato
estaba en mi propio volcado y lo descartó el filtro. Una prueba negativa sólo
demuestra la ausencia de *lo que buscaste*, no la del fenómeno.

### Frosted glass — igualado a kitty en toda la sesión
- Alfa **0.55 en todo**, el mismo de `background_opacity` de kitty:
  waybar (`@bar-bg`), swaync (`@glass` 0.90 → 0.55, `@glass2` 0.92 → 0.58) y
  los flotantes de github y clima (`background_opacity` 0.96 → 0.55).
- `mentat-github.sh` y `weather-open.sh` llevaban `background_blur=0` — el blur
  **desactivado a mano**. Ahora `background_blur=64`, como kitty.
- `layer-rule` de blur añadidas para `swaync-control-center` y
  `swaync-notification-window` (namespaces sacados de `niri msg layers`).
- Bajar de 0.68 a 0.55 no compromete la legibilidad justamente **porque hay
  blur**: el desenfoque borra el detalle del fondo que competía con el texto.
  Sin blur detrás, ese alfa sería ilegible.

### Backup
- Ruta del backup: `~/Projects/Imperator-dotfiles/Spicebar.bak.20260710_200703`
  (incluye snapshot del `style.css` desplegado previo en `.deployed-style.css.bak`).

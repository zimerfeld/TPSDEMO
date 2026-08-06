---
tipo: sistema
projeto: ZIMARO
lang: es-ES
atualizado: 2026-08-05
---

# 🚪 Salas simultáneas (servidor multinivel)

> Permite al host ejecutar **varios niveles al mismo tiempo** y gestionarlos (iniciar/parar/reiniciar,
> **observar** y **jugar** en cada uno) sin que dejar uno de ellos desmonte el servidor. El rol (Host/Cliente) se
> elige en `playonline` (dos botones) y la **sala se elige ANTES** de `chooseplayer` — solo entonces el
> jugador aparece en ella. Relacionado: [[🌐 multiplayer (ES)\|multiplayer]], [[🛰️ hospedagem-online (ES)\|hospedagem-online]],
> [[🎬 fluxo-de-cenas (ES)\|fluxo-de-cenas]].
>
> 🧪 **Para validar en campo:** ver [[🧪 teste-salas-multiplayer (ES)\|teste-salas-multiplayer]] (script loopback → LAN → internet).
> ✅ **VALIDADO en 2 PC reales (2026-08-05)** vía **playit.gg** (túnel UDP `zimaro.playit.game:44000` → host `192.168.0.211:44000`), tras corregir la **congelación del enemigo en el cliente** — ver la sección *Congelación del enemigo en el cliente* abajo (release `202608051826`).

---

## Arquitectura

- **`RoomManager`** (`autoload/room_manager.gd`, autoload persistente): cada "sala" es un nivel
  ejecutándose dentro de un **`SubViewport` con su propio `World3D`** (`own_world_3d = true`). Esto aísla
  **física, navegación y `WorldEnvironment`** — sin un World3D separado, dos niveles ocuparían el mismo
  espacio y los entornos chocarían (solo 1 `WorldEnvironment` por World3D es válido).
- Al vivir en el autoload, las salas **sobreviven al cambio de escena** (incluido ir a `chooseplayer` y
  volver) → el peer ENet **no** se cierra al navegar; solo en **"Back"** de las sesiones, que llama a
  `RoomManager.stop_all()` + cierra el peer y vuelve a `playonline` (ya no hay `_exit_tree → stop_all`).
- **Renderizado bajo demanda (optimización):** los SubViewports se quedan en `UPDATE_DISABLED`; solo la
  sala **observada/jugada** pasa a `UPDATE_ALWAYS`. La **simulación de enemigos corre en TODAS** las salas,
  independientemente del renderizado → no pagas GPU por salas que nadie está viendo.
- API: `start_room(level_path) -> id`, `stop_room(id)`, `restart_room(id) -> new_id`, `get_rooms()`,
  `stop_all()`. **`stop_room` y `restart_room` llaman al mismo `_close_room(id, reason)`** (enum
  `CloseReason.{STOPPED, RESTARTED, SILENT}`), que notifica a los clientes de la sala ANTES de liberarla con
  el RPC apropiado al motivo: **STOPPED → `notify_room_closed`** ("The level was stopped by the host"),
  **RESTARTED → `notify_room_restarted`** ("The level was restarted by the host"). **el host juega:**
  `host_spawn_in_room(id, variant_id)` / `host_leave_room()`; **el cliente sale:** `client_leave_room(id)`
  (+ RPC `leave_room`); señales `rooms_changed`, `room_closed(id)` y **`room_restarted(id)`**. Marcadores
  del flujo "Play" (invertido): `pending_play_room` / `pending_play_level` / `pending_play_return`.

## Flujo y pantallas — rol elegido en `playonline`

En `playonline`, debajo de Port/Address, hay dos botones: **"Manage Rooms"** (Host → abre
`host_session`) y **"Join Rooms"** (Cliente → abre `client_session`). **"Play"** (host o cliente) siempre pasa por `chooseplayer`
ANTES de hacer spawn: establece `pending_play_room`/`return`, va al selector de personaje y, al volver, el
`_ready` de la sesión consume el marcador y entra en modo de juego (spawn + oculta el panel + captura el
ratón). Durante el juego la **sesión sigue siendo la escena raíz** (solo oculta el panel).

- **SERVIDOR (`scenes2D/host_session/`, solo servidor)** — `_on_manage_rooms_pressed` crea el servidor
  ENet y cambia a `host_session.tscn` (peer mantenido, **sin sala al cargar**). UI: desplegable de nivel
  (**1.º elemento "Select…"**) + **Start Room**; por sala **Play / Spectate / Restart /
  Stop**; **Back** (desmonta el servidor y vuelve a `playonline`).
  - **Spectate:** la textura del SubViewport a pantalla completa, ratón **CAPTURADO**, ratón empujado a la sala
    (`viewport.push_input`) → la cámara libre (`register_room_level`) mira alrededor; **ESC** sale del
    modo espectador.
  - **Play:** `chooseplayer` → `host_spawn_in_room` hace spawn de un jugador **host (peer 1)** en la sala y
    **apaga su cámara libre** (de lo contrario ambos leerían el `Input` global); la cámara del jugador pasa a
    `current` en el SubViewport (renderizado a pantalla completa, solo se empuja el ratón). **ESC** abre una
    ventana `FloatingDialog.confirm` ("Disconnect and go back to management ?") → `host_leave_room` y vuelve a la cuadrícula.
  - **Stop:** termina **solo esa sala**; los clientes que jugaban en ella reciben `notify_room_closed`,
    ven **"The level was stopped by the host"** y vuelven al explorador `client_session`. Las demás salas continúan.
  - **Restart:** recrea el nivel desde cero (`restart_room` = `_close_room(RESTARTED)` + `start_room`); los
    clientes de la sala reciben `notify_room_restarted`, ven **"The level was restarted by the host"** y vuelven
    al explorador (la sala recreada reaparece en la lista para reingresar). El **host vuelve a la cuadrícula con el ratón
    VISIBLE** (estado idéntico a "Start Room") — `_on_restart_room` reingresa en la sala recreada solo si
    estaba observando/jugando ESTA sala. Antes, el reinicio podía dejar la pantalla en un estado sin ratón/respawn.
- **CLIENTE (`scenes2D/client_session/`, solo cliente — NUEVO)** — `_on_join_rooms_pressed` conecta y,
  en `connected_to_server`, abre `client_session.tscn`. Solicita `request_room_list` y lista
  **#id — nivel (N jugadores) + Play** (el botón **solo aparece si hay una sala**). **Play:**
  `chooseplayer` → `client_join_room` espeja la sala como un **Node plano** (renderiza en la **ventana
  principal**, sin SubViewport) y envía `join_room`; el servidor hace spawn del jugador. **ESC** → confirmar →
  `client_leave_room` (despawn en el servidor + elimina el espejo, **sin cerrar el peer**) y vuelve al
  explorador. **Back** cierra el peer y vuelve a `playonline`.

## Ruta determinista (replicación)

Servidor y cliente colocan la sala en `/root/RoomManager/Room<id>/Level/...` (el nodo de nivel renombrado a
`"Level"`) → el `MultiplayerSpawner` del nivel replica de la misma forma. **Asimetría intencional:** en el servidor
`Room<id>` es un `SubViewport` (su propio World3D, varias salas aisladas + observación); en el cliente es un
`Node` plano (una sola sala, renderiza en la ventana principal). La ruta en string es la misma → la replicación coincide.

## Aislamiento por sala (interest management)

`RoomManager._apply_room_visibility` añade **solo un *filtro de visibilidad*** (veta a quien no esté en la
sala) en cada `MultiplayerSynchronizer` de todo lo que entra en los `SpawnedNodes` de la sala (enemigos, balas,
jugadores): solo replica a peers cuyo `_peer_room[peer] == room_id`. Cuando un peer entra,
`_refresh_room_visibility` llama a `update_visibility()` → los spawns ya existentes (enemigos) se le
(re)envían.

> ⚠️ **NO pongas `public_visibility = false`.** En el motor,
> `MultiplayerSynchronizer.is_visible_to(peer)` es: `¿pasan todos los filtros?` **Y**
> `peer_visibility.has(0) or peer_visibility.has(peer)` — donde `has(0)` es `public_visibility`.
> Los filtros **solo VETAN** (devolver `true` no concede visibilidad por sí solo). Con
> `public_visibility = false` el sincronizador se vuelve **invisible para TODOS** → **nada se replica al
> cliente** (su jugador sin cámara/nivel, otros jugadores y el enemigo no aparecen). Mantener el default
> (`true`) hace funcionar el filtro: en la sala = visible, fuera = vetado. **Bug corregido el 2026-06-24**
> (`feature/spawnplayer2`): era la causa de "el nivel no se muestra en `client_session`" y de que jugadores/
> enemigo no sincronizaran. Las *partes* de muerte del `red_robot` nacen `public_visibility=false` a
> propósito (solo sincronizan al explotar, vía `part.gd`) — preservado: solo reciben el filtro.

## Congelación del enemigo en el cliente = stall de render (corregido, VALIDADO 2 PCs 2026-08-05)

Síntoma: el cliente entra en la sala del host y los enemigos aparecen **parados**; el disparo acierta pero **no
detecta colisión**. Reproducido en un **harness headless de 2 procesos** con el `RoomManager` REAL: el
**núcleo del netcode de sala es correcto** — replicación, filtro de visibilidad, interpolación
(`net_transform`) e incluso la **colisión server-side dentro del SubViewport** funcionan (la bala mató a los
enemigos en la prueba). El fallo solo aparece con el **cliente RENDERIZANDO**: al materializar las ~16
entidades del template **de una vez**, el bucle principal **se traba varios segundos** (compilación de
shader/pipeline en la GPU + construcción de los `LimbColliders` de los `red_robot` en la CPU, en el mismo
frame). En **hardware gráfico débil** ese stall (a) hace que el enemigo "se congele" en pantalla y (b)
**agota el timeout POR DEFECTO de ENet (mín 5 s) → la conexión CAE**; y como **ningún handler trataba
`server_disconnected`** (solo existía `connection_failed` en la conexión inicial), el cliente quedaba
**atrapado en la sala congelada** y, desconectado, el disparo no llegaba al servidor → "no detecta
colisión". El `StabilityGuard` **no lo detecta**: corre en `_process` (ni siquiera se llama durante el frame
trabado) y el gatillo de FPS exige 10 muestras seguidas, no 1 pico gigante.

**Correcciones (release `202608051826`, validada en 2 PCs vía playit.gg el 2026-08-05):**
- **Spawn GRADUAL** de las entidades del template (1/frame de física) en vez de todo de una vez —
  `TemplateManagerBase.apply_active_gradual()` (refactorizado `_apply_template` en `_plan_template`
  [salta el camino muerto vía `ResourceLoader.exists`] + `_spawn_job`), usada por
  `RoomManager._ensure_template_spawned`.
- **Timeout de ENet TOLERANTE** (limit 32, mín 20 s, máx 40 s) aplicado a cada peer que conecta —
  `RoomManager._apply_peer_timeout` en `_on_peer_connected` — un stall de render ya no derriba la
  conexión. *(Validado en el harness: un stall de 3,7 s NO cayó y el sync se recuperó.)*
- **`client_session` trata `server_disconnected`** (`_on_server_lost`): avisa "La conexión con el host se
  perdió" y vuelve a `playonline`, en vez de una sala congelada.
- **Whitelist DINÁMICA del `MultiplayerSpawner`** — nuevo `SpawnableLibrary.configure(spawner)`
  (`effects_shared/spawnable_library.gd`), llamado en el `_ready` de `level_1`/`level_2`: recorre `library3D`
  en **orden lexicográfico determinista** (los índices coinciden entre peers) → cualquier modelo de template,
  **incluidos los nuevos** (`humanoide/jogador/monstro/mulher`), se replica al cliente. Antes la whitelist era
  fija en el `.tscn` y solo tenía los modelos antiguos.
- **`StabilityGuard` aflojado** (2026-08-05): `col_pairs` **16000/40000**, `node` **20000/45000**,
  `vram_warn` **3072** (crit 5120), `fps_crit_frames` **20** (10 s), `physics_throttle_tps` **45** —
  holgura para el host multisala y tolera el hitch de carga sin estrangular la física. Ver la sección abajo.

⏳ **Queda** un *hitch de carga en la 1.ª entrada a la sala* (~1,6–2,6 s), **no fatal**: el timeout
tolerante de ENet lo sobrevive y el handler de `server_disconnected` recupera de forma limpia.

> ⚠️ **EL PRECALENTAMIENTO NO LO RESUELVE — medido el 2026-08-05, NO reexplorar.** Se probaron cinco
> enfoques con medición cold-cache: warm de entidades en SubViewport (~25%, ruido); warm de entidades en
> el viewport RAÍZ (sin ganancia); warm del **LEVEL** en SubViewport (**0%**); warm del **LEVEL** en el
> viewport raíz (**0%**); y una cola repartiendo los builds de `LimbColliders` (~40 ms, insignificante).
> **Todos revertidos, nada publicado.** Desglose del coste (level_1, cold cache): render inicial del
> **ambiente/suelo del level ≈ 2336 ms (86%)**, entidades ≈ 400 ms, colliders ≈ 40 ms. **Por qué falla:**
> el coste está ligado a que el level pase a ser la **escena ACTIVA con setup completo**
> (`apply_graphics_settings` + shadow atlas + render buffers + occlusion **en la ventana real**) — todo
> pre-render offscreen dio **0 ms de stall**, es decir no reproduce el coste y por tanto no lo adelanta.
> **No es one-time:** con shader cache de disco caliente baja de ~2,6 s a ~1,6 s, pero **no llega a
> cero** (setup del 1.er render 3D de la ventana, por lanzamiento).
> ✅ **RESUELTO con la PANTALLA DE "CARGANDO"** (autoload `LoadingScreen`, 2026-08-05) — ver la sección
> *Pantalla de Cargando* abajo. En resumen: el arranque carga un level **DE VERDAD** (activación completa)
> y lo descarta, pagando por adelantado el setup **global** del renderer (**2473 ms → 602 ms en la entrada
> siguiente, −76%**); y cada entrada en level/sala pasa a estar **cubierta** por la pantalla. **La clave:**
> el warm fallaba porque el `_ready` con meta `warmup` retornaba ANTES de
> `Settings.apply_graphics_settings(...)` — solo la activación COMPLETA reproduce (y por tanto adelanta) el
> coste. La branch `feature/salas-prewarm-shaders` quedó sin propósito.

Ver [[salas-freeze-render-stall]] en la memoria.

## Pantalla de "Cargando" (`LoadingScreen`) — 2026-08-05

> 🖱️ **GOTCHA del cursor (2026-08-06).** El prepago del arranque instancia el `level_1` como
> observador, y la `spectator_camera` **capturaba el ratón** en el `_ready`. Capturar y soltar en unos
> pocos fotogramas deja el puntero **sin redibujar** en Windows: `Input.get_mouse_mode()` vuelve a
> `VISIBLE` (medido: `0` durante todo el arranque, incluso 3 s después) y aun así **el cursor no
> aparece** — solo vuelve en el siguiente cambio de modo. La cura no es reforzar el
> `set_mouse_mode(VISIBLE)` al final (eso trata el síntoma): es **no capturar**. El indicador
> **`LoadingScreen.preloading`** lo consultan `spectator_camera` y `player_input` — durante el prepago
> nadie juega, así que nadie captura. Medido después: modos vistos en el arranque = solo `[0]` (antes
> `[0, 2]`). El texto de la pantalla es **"Preparando os gráficos"** (el fragmento "para la primera
> partida" se quitó el 2026-08-06).

Autoload **`LoadingScreen`** (`autoload/loading_screen.gd`), un `CanvasLayer` (layer 200,
`PROCESS_MODE_ALWAYS`) con fondo opaco + "Cargando..." — textos canónicos en pt, traducidos por el
[[locale]] vía `scenes2D/loading/Resources/loading.{pt,en,es}.json`. **Dos papeles:**

1. **`run_startup_preload()`** — llamado en `main.gd._ready` antes del menú. Instancia un level **DE
   VERDAD** (`level_1`), lo deja vivo ~6 frames y lo descarta. Es la **activación completa** que paga
   por adelantado el setup **global** del renderer. Medido (cold cache): **2473 ms aquí → la entrada
   siguiente en una sala baja a 602 ms (−76%)**. `spectator_host = true` (sin jugador controlado → sin
   captura de ratón) y `set_process_input(false)` en el level (ESC no dispara el `LevelExit`). **Headless**
   (servidor dedicado, sin GPU) y `-- nopreload` lo saltan.
2. **`cover(action)`** — cubre la pantalla ANTES de **cada** entrada y solo la revela con el cuadro listo:
   muestra la pantalla, deja **2 frames PINTAR** (si no, el stall se comería el frame de la propia pantalla
   y el jugador vería la ventana congelada), ejecuta la `action` (la activación pesada) y espera
   `SETTLE_FRAMES`. Conectado en: **`levels.gd`** (entrada en level offline), **`client_session`** (entrar en
   la sala) y **`host_session._set_observing` / `_set_playing`** (observar/jugar una sala). Medido: entrada
   cubierta = **896 ms enmascarados** (validado con captura de pantalla durante la cobertura).

> ⚠️ Solo la **activación completa** paga el coste — `cover`/preload NO pueden convertirse en un "warm"
> offscreen (SubViewport o viewport raíz dan **0 ms de stall**: no reproducen el coste, por tanto no adelantan nada).
> Ver la medición en la sección *Congelación del enemigo en el cliente*.

## Pantalla negra en el cliente (level_base/level_2) — StabilityGuard (2026-06-24, `feature/spawnplayer2`)

> ⤴ **Valores actualizados el 2026-08-05** (ver la sección *Congelación del enemigo en el cliente*): `col_pairs`
> 16000/40000, `node` 20000/45000, `vram_warn` 3072, `fps_crit_frames` 20, `physics_throttle_tps` 45.
> Los límites de abajo (8000/25000 etc.) son el **histórico** de la calibración original del 2026-06-24.

> 🗑️ **Nota histórica (2026-07-01):** el nivel `level_base` fue **ELIMINADO** del proyecto en la
> reestructuración `feature/restrutu` (escena, `.ogg` y todas las referencias en `levels`/`host_session`/`playonline`/
> `music_manager`). El registro de abajo se conserva como **contexto** para la calibración del `StabilityGuard`: los
> ~3066 pares de colisión / ~1.2 GB de VRAM que motivaron los límites actuales se aplican a **cualquier nivel 3D real**
> (hoy `level_1`/`level_2`) — la lección no ha cambiado, solo el ejemplo. La sala por defecto del servidor headless
> pasó a ser `level_1` (`DEFAULT_ROOM_LEVEL`).

Síntoma: al entrar como CLIENTE en una sala **Level Base** (y, con una de esas salas corriendo en el servidor,
también **Level 2**), la pantalla se ponía **negra** — ni siquiera aparecía el escenario. **Causa:** el `StabilityGuard`
(autoload siempre activo) entraba en **EMERGENCIA** porque level_base tiene **~3066 pares de colisión** de
geometría estática y el límite crítico era **600**; `_apply_emergency` hacía `get_tree().paused = true`,
que en un servidor/cliente **congela el MultiplayerSpawner/Synchronizer y los RPC** → el jugador del cliente
no aparece (sin cámara = pantalla negra) y nada sincroniza. En el SERVIDOR, pausar congela TODAS las salas → por eso
Level 2 (simple) también se rompía cuando había un Level Base corriendo al lado. Level 1 (suelo plano,
pocos pares) nunca lo activaba → solo él funcionaba.

**Soluciones:**
- `stability_guard.gd`: límites recalibrados a valores reales de juego 3D (level_base usa ~3066
  pares de colisión Y ~1198 MB de VRAM — ambos NORMALES y que activaban el guard): `col_pairs` 8000/25000,
  `node` 12000/30000, **`vram` 2560/5120 MB**. Y `_apply_emergency` **nunca pausa en una sesión ONLINE**
  (solo estrangula la física + registra logs) — pausar rompe el netcode de todos los peers. La pausa + overlay siguen
  aplicándose en solo/offline (donde no hay red que romper). ⚠️ Incluso SIN pausar, la EMERGENCIA/THROTTLE baja
  la física a 30 tps en el servidor (juego lento para todos), así que los límites NO deben activarse en juego
  normal — de ahí la recalibración. Validado: host iniciando/observando una sala level_base se mantiene **NORMAL**.
- `level_base.tscn`: `_spawnable_scenes` convertidos de UIDs → **rutas explícitas** (como level_1),
  eliminando el riesgo de que un UID no se resuelva en el MultiplayerSpawner (lo que silenciaría el spawn).

**Pulido de UI (2026-06-24):** `host_session`/`client_session` ahora aplican el **tema del proyecto**
(`res://themes/ui_theme.tres`, el mismo que playonline/menu) a la raíz → botones/labels/desplegables con el
aspecto cyberpunk. ⚠️ `ui_theme.tres` solo estiliza **Button/Label** (no da fondo), así que `_make_panel` fue
reescrito (`_panel` pasó a ser un `Control`, ya no un `PanelContainer`): **fondo con la textura cyberpunk del menú**
(`menu_surreal_training_bg.png`) + velo oscuro, pero con IDENTIDAD propia por escena (factor decisivo
host × cliente): **HOST = gradiente CÁLIDO (ámbar)** + anillos de "radar" EXPANDIÉNDOSE hacia fuera (el servidor emite /
es la fuente); **CLIENTE = gradiente FRÍO (cian)** + anillos CONTRAYÉNDOSE hacia dentro (se conecta al servidor). Los
anillos vienen del shader `res://themes/session_signal_bg.gdshader` (uniforms `ring_color` + `dir` ±1 + `aspect`),
ensamblado por el helper `_make_signal_layer(color, dir)`. Un azul marino plano se veía "sin color" — de ahí la textura rica. Además: **pantalla completa** (márgenes + título centrado);
**contenido/listas en un VBox centrado de ancho máximo 900** (HBox `ALIGNMENT_CENTER`); **botón Back
200×50 centrado abajo** (ya no a todo el ancho). Todo dentro de `_panel`, oculto mientras se observa/
juega (entonces el SubViewport/nivel llena la pantalla). `_make_back_button` eliminado (el botón Back se ensambla en `_make_panel`).

**Persistencia de playonline:** TODAS las opciones persisten y se recargan — Port e IP/Dominio
(`_prefill_last_used`: lee `online/last_port|last_address`, escrito en CUALQUIER cambio vía
`_on_port_changed`/`_on_address_changed`, sin contaminar el historial; fallback al inicio del historial,
luego el default); interpolación/rate/render del host (`NetConfig`, sección `netopt`); idioma (`Locale`,
`game/language`).

**Desplegables de historial (Port/IP) — corrección 2026-06-25:** los `OptionButton` `PortHistory`/
`AddressHistory` **reflejan el valor actual del campo** y **mantienen la selección** — antes, `_fill_history`
forzaba `selected = 0` ("Select...") y los handlers de selección también reiniciaban a 0, así que el
desplegable nunca mostraba ni mantenía el valor almacenado. Ahora: `_ready` llama a `_prefill_last_used()`
**antes** de `_refresh_history()`; `_fill_history(option, key, current)` llama a `_select_in_history` para
dejar seleccionado el elemento igual al valor actual (o "Select..." si no está en el historial); los
`_on_*_history_item_selected` **ya no reinician** a 0; y `_on_port_changed`/`_on_address_changed`
resincronizan el desplegable mientras se teclea. (Fijar `.selected` por código no dispara `item_selected` → sin
recursión.) El valor en sí ya persistía en `online/last_port|last_address` — lo que faltaba era que el desplegable
**espejara** ese valor.

**HUD de debug de level_base (ELIMINADO):** la `Label` "Debug" (script `debug.gd`, mostraba FPS/VSync/
Memory/Online/Multiplayer ID) era legado de `level_base.tscn` (no existía en level_1/2), aparecía por
defecto y era redundante con el **Performance HUD**. Fue **borrada** de `level_base.tscn` (nodo +
ext_resource) y los archivos `debug.gd`/`debug.gd.uid` borrados. No la generé yo — era código abandonado.

## Ventanas de confirmación estandarizadas + fondos de pantalla animados (2026-06-24)

**Diálogos (reescritos 2026-06-25):** TODAS las ventanas de confirmación/aviso (Quit, Resolution, Restore,
Disconnect host/cliente, avisos de sesión, guardar/reasociar/eliminar en la pantalla Models y errores de
`CrashHandler`) se construyen sobre el **control 2D reutilizable `FloatingWindow`**
(`controls2D/floating_window/`, `class_name FloatingWindow`) mediante el helper **`FloatingDialog`**
(`themes/floating_dialog.gd`, `confirm()/alert()`). Es un `Control` (no el `Window`/`ConfirmationDialog` nativo):
**título centrado** (el espaciador izquierdo espeja al ×), **botones de ancho uniforme**, **× de cierre estándar**
(mismo aspecto negro opaco que los paneles Damage/AI), **fondo modal** que oscurece y bloquea el
resto de la UI, **ESC = cancelar**, **Enter = confirmar** (el botón OK enfocado), **foco devuelto** al
control anterior al cerrar y **arrastre por la barra de título**. Va en un `CanvasLayer` (capa 128) encima — cubre
2D y 3D — y se auto-libera al cerrar. Textos pasados EN BRUTO (claves canónicas): la ventana traduce vía Locale
(SKIP_GROUP + meta `loc_key`) y **se actualiza al cambiar de idioma**. ESC lo consume la ventana (el descendiente
añadido en último lugar) antes del `_input` de la pantalla, para que el fondo no navegue junto. El antiguo `UIDialogs`
(`themes/ui_dialogs.gd`, que solo estilizaba los diálogos nativos) fue **ELIMINADO**. La misma base sirve para
cualquier ventana flotante futura (el export `remember_position_key` guarda/restaura la posición en Settings).

**Ventana de error NO DESTRUCTIVA (`CrashHandler`, 2026-07-02):** la ventana de error global ya no es
fatal. × / ESC / el botón **"Back"** solo CIERRAN y devuelven el foco a la escena que llamó (el `FloatingWindow`
ya restaura `_prev_focus` en `close()`); con `retry_callback` también hay **"Try Again"** (re-ejecuta).
Antes, el botón era "Close Game" y `CrashHandler` conectaba `canceled/confirmed → get_tree().quit()` — un
error de puerto/conexión desde `playonline` (o incluso una **validación de la pantalla Models**) apagaba todo el juego.
Motivo: un error de puerto/conexión/validación es recuperable — el jugador ajusta y reintenta, sin perder la sesión.

**Colores de los botones (default del tema, 2026-06-25):** los styleboxes compartidos (`scenes2D/menu/button_*.tres`,
usados vía `ui_theme.tres` en todas las pantallas) fueron estandarizados — un botón **sin foco = fondo GRIS**
(`button_normal`), **con foco = fondo NEGRO** (`button_focus`, overlay opaco), texto **blanco opaco** en todos los
estados (hover = gris claro, pressed = casi negro). **Hover y foco** traen de vuelta el efecto **neón**:
**borde blanco** + **sombra blanca humeante** (`shadow_size`), dando el brillo de luz neón alrededor del
control. Los **botones × de cierre de ventana** siguen su propia regla, `FloatingWindow.style_close_button(btn)`
(aplicada al × del FloatingWindow Y a los paneles Damage/AI): **sin foco = GRIS, con foco/hover = ROJO
OSCURECIDO**, texto blanco.

**Fondos animados:** cada pantalla 2D ganó su propio shader `canvas_item` (en `themes/backgrounds/`,
aplicado como `ShaderMaterial` en el nodo `Background/Bg` de la escena, sobre la base azul marino) que **evoca la función
de la pantalla** — `levels_bg` (una cuadrícula de nivel en perspectiva), `playonline_bg` (una red de nodos SUTIL, solo en los bordes — el
centro se queda calmo/marino para que los textos del formulario sean LEGIBLES; reescrito 2026-06-25 porque la 1.ª
versión iluminaba el centro y dificultaba la lectura), `settings_bg` (ecualizador + sliders),
`developer_bg` (blueprint + barrido horizontal). Barato (matemática
por píxel, sin texturas) → sin coste relevante en una pantalla de menú. Las sesiones host/cliente siguen usando el
`session_signal_bg` (anillos de radar) — ver *Pulido de UI*.

## Optimización seleccionable antes de la sala — `NetConfig` (2026-06-24)

Autoload **`NetConfig`** (`autoload/net_config.gd`, persiste en `Settings`/sección `netopt`) + un selector en la
pantalla **playonline** (3 desplegables ESTÁTICOS en el `.tscn` — columnas `HostColumn`/`BothColumn`/`ClientColumn`
con `HostRenderModes`/`SyncRates`/`Interpolations` (renombrados del antiguo `*Picker` en el barrido de nombres del 2026-07-03
— OptionButton en plural, sin abreviación), `tab_order` 6/7/8 antes de los botones Host/Cliente;
el código solo puebla elementos/selección y conecta — `_build_optimization_options`/`_setup_opt_picker`, 2026-06-30,
antes se ensamblaban en tiempo de ejecución). Son prefs LOCALES (no replicadas) — cada lado ajusta lo que controla:
- **Smoothing ↔ Response** — retardo de interpolación de los modelos remotos: Smooth 100 ms / **Balanced
  60 ms (default)** / Responsive 35 ms. Aplicado en `NetInterp.render_delay_ms` (ahora un `static var`).
- **Sync rate** — 30 / 60 Hz. Válido en AMBOS lados, cada uno en la dirección que envía: el
  SERVIDOR fija `replication_interval = 1/Hz` en los sincronizadores de las entidades (`_apply_room_visibility`,
  broadcast servidor→clientes); el CLIENTE dueño lo fija en su propio `InputSynchronizer` (`apply_authority`,
  subida de su input). No necesitan coincidir — controlan flujos distintos.
- **Host render** — Windowed (observa salas) / **Pure server** (ninguna sala renderiza → libera GPU;
  Spectate/Play en el host están desactivados). Leído por `host_session._render_only`.
Regla del proyecto ([[optimize-when-adding-scene-elements]]): trade-offs explícitos (respuesta × suavidad/
ancho de banda/FPS) sin comprometer la experiencia; el default Balanced ya es más rápido que el antiguo fijo de 100 ms.

**Alcance explícito en pantalla (2026-06-24):** el selector se ensambla en **3 columnas** alineadas con los botones
de abajo, con una insignia de alcance coloreada: **HOST ONLY** (Host render, izquierda/naranja, sobre "Manage
Rooms"), **HOST + CLIENT** (Sync rate, centro/verde) y **CLIENT ONLY** (Smoothing↔Response,
derecha/cian, sobre "Join Rooms") + una pista del trade-off interpolación×Hz. Localizado PT/EN: las
**Labels** usan texto canónico (pt) y el auto-localizador [[locale]] traduce/retraduce; los **elementos del OptionButton**
(que Locale salta) los retraduce `_relocalize_options` en `language_changed`.
⚠️ No pases `tr_key()` al fijar el texto de una Label que el auto-localizador cubre — almacenaría el canónico
equivocado si la escena nace en EN (el idioma se persiste) y la label no volvería a pt.

## Modos de render del host (pregunta del usuario)

- **Headless** (`--headless`): GPU ociosa — ideal para muchas salas; solo CPU/RAM. (La tarjeta AMD
  de 8GB no pesa aquí; lo que importa es CPU single-thread + RAM + red.)
- **Windowed**: renderiza solo la sala observada (las demás solo simulan) → el coste de GPU no se multiplica.

## Estado / pendientes

- ✅ **Fase 1 (validada en una sola instancia):** servidor persistente, salas aisladas simulando en
  paralelo, cuadrícula de gestión, observación por sala.
- ✅ **Fase 2 (lado servidor validado en una sola instancia; red REAL pendiente 2 PCs):** spawn del
  jugador **por sala** (`RoomManager`, aislado del `NetSpawn` de nivel único), **join del cliente** a una sala
  (`request_room_list`/`join_room`), espejo de sala en el cliente, **visibilidad por peer**. Corregido
  `criatura_alada._find_player` (busca en sus propios `SpawnedNodes`, no en `current_scene`).
- ✅ **Fase 3 — reorganización del flujo (parse/load validado; juego interactivo pendiente):** rol Host/Cliente
  vía dos botones en `playonline`; `host_session` pasó a ser **solo servidor** y el
  `client_session` nació (solo cliente); **sala elegida antes de `chooseplayer`** (marcadores
  `pending_play_*`); **el host juega dentro de la sala** (`host_spawn_in_room`, cámara libre apagada);
  **ESC** con confirmación para desconectar; **Stop** notifica a los clientes de la sala (`notify_room_closed`)
  y los envía a `client_session`; **Back** de las sesiones desmonta el peer y vuelve a `playonline`.
- ✅ **Interest management corregido (2026-06-24, `feature/spawnplayer2`):** `_apply_room_visibility`
  fijaba `public_visibility = false`, que hacía TODO invisible para todos los peers (los filtros solo vetan) —
  por eso `client_session` no veía el nivel/cámara y jugadores/enemigo no sincronizaban. Ahora solo
  añade el filtro (mantiene `public_visibility` en el default `true`). Ver la sección *Aislamiento por sala*.
- ✅ **Prueba A (loopback `127.0.0.1`, 2 instancias) VALIDADA en campo (2026-07-02):** `playonline` local
  OK; el cliente entra y aparece en la sala (escenario, no gris), el host muestra "(1 connection)", replicación
  cliente↔host. **El netcode está probado** — solo falta el transporte de red real (Prueba B/C). Ver
  [[🧪 teste-salas-multiplayer (ES)\|teste-salas-multiplayer]].
- ✅ **Guarda de carrera de "Play" en el cliente (2026-07-02):** al volver de `chooseplayer`, el
  `client_session` revalida vía `server_room_list()` que la sala aún existe (el autoload `RoomManager`
  sigue recibiendo `receive_room_list` durante la selección de personaje). Si el host DETUVO/reinició la sala
  entretanto, NO hace spawn en una sala muerta: vuelve al explorador con el aviso "The room is no longer
  available" (helper `_server_has_room`). Evita la escena vacía de entrar en una sala que ya no corre.
- ✅ **Red REAL entre 2 PC VALIDADA (2026-08-05):** probado vía **playit.gg** (túnel UDP), tras
  corregir la **congelación del enemigo en el cliente** (stall de render + timeout de ENet + falta de
  handler `server_disconnected`) — ver la sección *Congelación del enemigo en el cliente* (release
  `202608051826`).
- ✅ **Hitch de 1.ª entrada: RESUELTO** (2026-08-05) por la **pantalla de "Cargando"** (`LoadingScreen`):
  el arranque paga por adelantado el setup global del renderer (−76% en la entrada siguiente) y cada entrada
  en level/sala está cubierta por la pantalla. **El precalentamiento offscreen fue medido y descartado**
  (5 enfoques, todos 0–25%); **no reexplorar** sin leer esa medición.
- ⏳ **Pendientes:**
  `enemy_health_bar.get_shared(get_tree().current_scene)` (HUD del enemigo) sigue siendo global —
  en el cliente con 1 sala a pantalla completa funciona; en el host observando/jugando puede aparecer en el lugar equivocado.
  Ver [[🌐 multiplayer (ES)\|multiplayer]].

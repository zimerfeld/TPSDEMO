---
tipo: fluxo
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-07
---

# 🎬 Flujo de escenas

`main.tscn` (Node, `main.gd`) es un **router** Y la **pantalla de inicio**: instancia
cada pantalla como hijo de sí mismo (no usa `SceneTree.change_scene`), reaccionando a las
señales `replace_main_scene` y `quit`. Por esto, `get_tree().current_scene` permanece
`main` durante todo el juego.

La apertura vive en el subárbol `StartScreen` (hijo de la raíz, ya montado en
`main.tscn`): un robot 3D (`player.glb`) sobre un **pedestal** como fondo + un overlay 2D
(título/lectura/estado). Tras `minimum_wait_time` (~2 s) `main.gd` hace fade y cambia
`StartScreen` por el menú. Ya no existe `StartScreens/StartScreen.tscn` (eliminado).
`StartScreen` entra en el grupo `no_debug_overlay` (sin tooltips de debug).

```
main.tscn (main.gd — router + start screen: robot on pedestal + overlay)
   └─► menu.tscn (menu.gd)
          ├─► Play Offline ─► chooseplayer.tscn ─► levels.tscn ─┬─► level_1.tscn
          │     (online_mode=false)                             └─► level_2.tscn   (loads the level directly)
          ├─► Play Online ──► chooseplayer.tscn ─► levels.tscn ─► playonline.tscn ─► chosen level
          │     (online_mode=true)                 (choose level)   (Host/Connect)
          ├─► settings.tscn (UI: settings.gd)
          ├─► developer.tscn ─┬─► models.tscn   (3D model viewer)
          │                   └─► controls.tscn (2D controls viewer)
          └─► Quit → quit
```

(`Exported.tscn` / la galería "Exported" ya no existe — el botón se eliminó de la pantalla
de modelos. `cyberpunkhud` es una escena de vista previa independiente, fuera del flujo de navegación.)

---

## Carpetas

- **scenes2D/** (pantallas + UI): `main` (router), `menu`, `chooseplayer`, `levels`, `settings`, `developer`, `playonline`, `controls` (visor 2D) y `controls2D/` (widgets de HUD reutilizables: crosshair, minimap_panel, vitals_panel, pause_menu, scanlines, cyberpunk_hud, …)
- **scenes3D/** (niveles + herramientas 3D): `level_1`, `level_2`, `models` (visor)
- **library3D/** (assets 3D por tipo): `characters`, `propulsores`, `structures`, `weapons`, + `geometry`/`textures` (soporte)
- **effects_shared/** (helpers compartidos entre personajes): `limb_colliders.gd`, `body_parts.gd`, `weapon_parts.gd` + assets de blast/shadow
- **autoload/**: `crash_handler`, `player_selection`, `debug_overlay` (**Settings** vive en `scenes2D/settings/config.gd`)
- **themes/**: temas (`ui_theme.tres`, `cyberpunk.tres`) · **addons/**: plugin `godot_ai` (MCP) · **ZIMARO/**: este vault

## Autoloads

- **Settings** → `scenes2D/settings/config.gd` (gestor de configuración: `config_file`, `DEFAULTS`, `save_settings()`)
- **CrashHandler** → popup de error global **NO DESTRUCTIVO** (2026-07-02): × / ESC / el botón **"Back"** solo
  CIERRAN la ventana y devuelven el foco a la escena que llamó — ya **no cierran el juego** (un error de puerto/conexión/
  validación es recuperable). Con `retry_callback`, también muestra **"Try Again"** (reintenta la acción).
  Antes, el botón era "Close Game" y ×/ESC hacían `get_tree().quit()`; esto incluso mataba el juego en una
  simple validación de la pantalla Models (`models.gd`, "bone is already a Member") — corregido a la vez.
- **PlayerSelection** → personaje elegido
- **DebugOverlay** → overlays de debug (ver más abajo)
- **UINav** → `autoload/ui_nav.gd` (navegación por teclado de las pantallas 2D: `focus_first`, `first_focusable`, `cancel_active_edit` — ver [[#Navegación por teclado y ESC]])

---

## main.gd

- Punto de entrada (`run/main_scene`)
- `change_scene_to_packed()` elimina los hijos e instancia la nueva pantalla
- Conecta `quit` → `go_to_main_menu()` y `replace_main_scene` → cambio de escena (si la pantalla tiene la señal)

## Pantallas (UI)

- **menu** — Play (→ chooseplayer), Settings (→ settings), Developer Mode (→ developer), **Play Online** (misma secuencia que offline: chooseplayer → levels → playonline), Quit. **Los botones "Play Offline" y "Play Online" solo se diferencian en el flag `PlayerSelection.online_mode`** — ambos abren `chooseplayer`; es la pantalla `levels` la que, viendo el flag, carga el nivel directamente (offline) o abre `playonline` (online). La etiqueta "Play Offline" viene de la localización (`menu.*.json`, clave `"PLAY"`). En `_ready` (antes de mostrar la pantalla) **lee del disco y aplica TODAS las configuraciones** (2026-06-16): `Settings.load_settings()` + `apply_graphics_settings()` + `apply_window_resolution()` (redimensiona la ventana a la resolución guardada si está en modo Windowed) + `apply_audio_settings()` (Music/SFX mute).
- **settings** — `config.gd` (autoload **Settings**) + `settings.gd` (UI). Pestañas Display / Resolution / Antialiasing / Lighting / Effects / Audio / **Debug**. **Sin botón "Apply" (2026-06-16):** cada opción **persiste + aplica al instante** al cambiar (señal `ButtonGroup.pressed` → `_apply_settings`). La **resolución de vídeo** es aparte: se confirma en un diálogo (Yes/No) — "Yes" aplica y fija el modo Windowed (de lo contrario el siguiente apply volvería a fullscreen y lo deshacería), "No" devuelve el desplegable a la selección persistida. La ventana está **limitada al área utilizable de la pantalla** (`screen_get_usable_rect`) y centrada, de modo que una resolución mayor que el monitor (4K/8K) no empuja la ventana — ni la barra de botones del footer — fuera del área visible (`_apply_video_resolution` / `Settings.apply_window_resolution`). Un botón **Reset** (a la derecha de Back, 2026-06-16): misma confirmación Yes/No → `Settings.reset_to_defaults()` (reescribe todo con `DEFAULTS`, una línea base de hardware común) + recarga los controles + aplica al instante. `DEFAULTS` es la única fuente: también se aplica cuando no hay configuración guardada (load_settings lo rellena). Solo **Back** sale de la pantalla. **Valores por defecto clave (2026-06-23):** Display Mode = **Exclusive Fullscreen**, FPS Limit = **60**, Resolution Scale = **Balanced** (`1/1.7`), Scale Filter = **Bilinear**, Bloom = **Off**, Volumetric Fog = **Off**. **Scale Filter (2026-06-23):** opciones **Bilinear · AMD FSR 1.0 · AMD FSR 2.2** (MetalFX solo en macOS). FSR 2.2 fue **re-añadido** y se **eliminó** la reversión silenciosa a Bilinear en `load_settings` — todas las opciones persisten. ⚠️ FSR 2.2 puede provocar "Texture dimensions exceed device maximum" con una escala de supersampling (Native); con el default Balanced (downscale) es el uso correcto. **TAA × temporal upscaler (2026-06-26):** `use_taa` se aplica como `taa AND not Settings.is_temporal_upscaler(scaling_3d_mode)` — **FSR 2 / MetalFX Temporal** ya hacen AA temporal y son incompatibles con TAA (el motor apagaría TAA y emitiría un warning), así que `config.gd` (`apply_graphics_settings`) y `settings.gd` garantizan la exclusividad mediante el helper `Settings.is_temporal_upscaler()`.
- **developer** — **(rehecho 2026-06-23)** solo **General** (FPS HUD · Health Monitor) + **Debug 2D** (columna única: Debug 2D · Show TYPE · Show Name · Show ID · **Show Tab** ← nuevo, debajo de Show ID: tooltip blanco con el índice de Tab/foco de cada control 2D) + botones **3D Models** / **2D Controls**. La **columna Debug 3D entera** y el **panel de vista previa 3D** fueron **eliminados** — la inspección 3D (Mesh, Skeleton Lines, miembros, etc.) migró a la pantalla **Models** (con sus propios toggles sobre la vista previa). El overlay global ya no aplica overlays 3D en levels/chooseplayer (solo Debug 2D). Ver [[🐞 debug-overlay (ES)\|debug-overlay]] y [[🗿 biblioteca-de-modelos (ES)\|biblioteca-de-modelos]].
- **models** — navegador/extractor de modelos 3D: Category → Model → Mesh (mallas distintas), vista previa rotable, "Save as 3D scene" (extrae a `library/extracted/`) y un botón "Exported". Detalles en [[🗿 biblioteca-de-modelos (ES)\|biblioteca-de-modelos]]
- **Exported** (`library/extracted/Exported.tscn`) — una galería que muestra todas las escenas de `library/extracted/` una al lado de otra; vuelve a models
- **chooseplayer** — elige el personaje (un modelo 3D que gira) → levels
- **levels** — Level 1 / Level 2, carga asíncrona. `_select_level()` se ramifica: **offline** carga el nivel directamente; **online** (`PlayerSelection.online_mode`) guarda la ruta en `PlayerSelection.level_path` y abre `playonline`. Cada fila tiene un botón **template** que abre el **Template Manager** (`scenes2D/level_templates/level_template_dialog.gd`, renombrado desde "Level Templates" en 2026-06-29; antes una `Window` nativa, **ahora un controlador sobre `FloatingWindow`** — hereda el tema 2D y Debug 2D funciona sobre él). La misma ventana la abre la pantalla `host_session`. Cada **entrada** de spawn tiene un campo **"Entry name"** (2026-07-01) que renombra el texto mostrado en el desplegable `Entries` (ex-`EntryPicker`); vacío → etiqueta automática `"N. faction model xN"`. El nombre se guarda por entrada en `LevelTemplateManager` (clave `name`).
- **playonline** — solo **Host / Connect** (puerto + dirección). **No hay selector de nivel**: el nivel ya se eligió en la pantalla `levels` (flujo online) y llega en `PlayerSelection.level_path`; el servidor dedicado headless recurre a `level_1` (`DEFAULT_ROOM_LEVEL`, que entra directamente aquí y abre una sala). **Los niveles son jugables online** — `level_1` y `level_2` ganaron `MultiplayerSpawner` + `PlayerSpawnpoints` (ver [[🌐 multiplayer (ES)\|multiplayer]]).

---

## Navegación por teclado y ESC

Centralizada en el autoload **UINav** (`autoload/ui_nav.gd`), aplicada por **todas** las pantallas 2D
(`menu`, `settings`, `levels`, `chooseplayer`, `controls`, `developer`, `playonline`,
`host_session`, `client_session`):

- **Flechas del teclado** — Godot ya mapea `ui_up/down/left/right` a las flechas y calcula los
  vecinos de foco; solo faltaba el **foco inicial**. Cada pantalla enfoca el 1er control focable en
  `_ready` (deferred). `UINav.focus_first(self)` (1º en orden de árbol) y `UINav.focus_tab_one(self)`
  (cabeza del anillo, vía `tab_one_control`) son equivalentes para pantallas (sin `last` movido).
- **Foco en Tab = 1 al abrir (2026-06-29)** — **cada UI y ventana** empieza con el **control Tab = 1**
  enfocado: las pantallas llaman `UINav.focus_tab_one(self)`; el `FloatingWindow` enfoca en `_grab_initial_focus`
  el `UINav.tab_one_control(self, _close_button)` (1º del contenido/footer, NUNCA la ×, que es la última).
  `tab_one_control(root, last)` = cabeza del anillo = `collect_focusables(root)` menos `last`, 1er elemento.
- **Orden de Tab de `menu` (2026-06-29)** — la secuencia deseada
  **Play (1) → PlayOnline (2) → Settings (3) → Developer (4) → Quit (5) → Portuguese (6) → English (7)
  → Debug 2D (8)** es el **orden mismo** del árbol (los 5 botones de `MenuColumn`, luego la `LangBar` de la barra `Actions`
  y por último el **toggle `Debug2D`** que el DebugOverlay inyecta al FINAL de `Actions`). Ahora
  `menu.gd` **conecta el anillo** con `UINav.wire_tab_ring(self)` (helper `_wire_tab_order`) en `_ready`
  (deferred), como `levels` y las sesiones — cerrando `1 → … → 8 → 1` con incrementos de 1.
  **No** hay `focus_next`/`focus_previous` en el `.tscn` (un intento previo de fijar el anillo en los 5
  botones EXCLUÍA idioma/Debug2D — fue revertido); el anillo se construye en tiempo de ejecución para incluir el inyectado
  `Debug2D` y respetar el idioma activo (que se queda deshabilitado/fuera del anillo). Se **reconecta** cuando el
  DebugOverlay inyecta el toggle en `Actions` (señal `child_entered_tree`) y cuando un botón de idioma
  se habilita/deshabilita (`_update_language_buttons`). Foco inicial en Tab = 1 vía `UINav.focus_tab_one`.
- **Helpers de navegación `UINav` — ver [[🔁 navegacao-tab (ES)\|navegacao-tab]]** — una nota dedicada con la tabla de
  cada helper (`wire_tab_ring`, `focus_tab_one`, `tab_one_control`, `focus_first`, `first_focusable`,
  `collect_focusables`, `cancel_active_edit`), la **matriz escena×helper**, la explicación del `TAB: -`
  de Debug 2D y la lista de otros helpers del proyecto (FloatingDialog/FloatingWindow/Locale/CrashHandler).
- **Anillo de Tab compartido — `UINav.wire_tab_ring(root, last=null)` (2026-06-29)** — un único helper
  que recoge **todos** los controles focables bajo `root` en **orden de árbol** (= orden de lectura: cada
  control de arriba abajo y, dentro de una fila/HBox, de izquierda a derecha) vía `collect_focusables` y
  conecta `focus_next`/`focus_previous` en un **anillo cerrado** `1 → 2 → … → N → 1`. Garantiza **índices de Tab
  incrementando de 1** (la línea "Tab" de [[🐞 debug-overlay (ES)\|debug-overlay]]). El parámetro **`last`** (opcional):
  si se da, ese control va al **FINAL del anillo** (índice más alto) — usado por la × de las ventanas flotantes.
  Reaplicable cuando cambia el conjunto de focables (toggle inyectado, un botón que se habilita/deshabilita).
- **Foco contenido en las ventanas flotantes — × ÚLTIMA (2026-06-29)** — `FloatingWindow.wire_focus_ring()`
  (pública) delega en `UINav.wire_tab_ring(self, _close_button)`: el anillo es `content → footer → ×
  (Close) → 1º`, con la **× siempre ÚLTIMA** (mayor valor de Tab de la ventana), aunque la × venga ANTES en
  el árbol. Se monta en `popup_centered` (footer ya creado); el owner reconecta vía `_win.wire_focus_ring()` al
  habilitar/deshabilitar campos. Incluye **cualquier control focable** del contenido (OptionButton/LineEdit/
  SpinBox), no solo el footer. Sin el anillo, Tab **se fugaba a la UI de fondo** y la **× nunca se alcanzaba**.
  Para que la **numeración** de Debug 2D refleje esto, `DebugOverlay._tab_chain_start` empieza a contar **después
  de la ×** cuando hay una ventana flotante abierta (el fondo se suprime), de modo que la × obtiene el **mayor** `TAB: n`.
  Se aplica a cada `FloatingDialog` (p. ej. "Quit Zimaro ?") y a las ventanas **Template Manager** /
  **Music Manager**. Los botones del footer tienen un **nombre por rol** (antes `@Button@…`):
  `confirm` → **`Yes`/`No`**, `alert` → **`Ok`** (el TEXTO sigue traducido; solo se nombró el nodo).
- **Orden de Tab de `levels` (2026-06-29)** — la pantalla conecta el anillo con `UINav.wire_tab_ring(self)` en
  `_ready` (deferred): **Level 1 (1) → Template 1 (2) → Level 2 (3) → Template 2 (4) → Back (5) →
  Portuguese (6) → English (7) → Debug 2D (8)**, orden de lectura. *(La fila **Level Base** se
  eliminó el 2026-07-01 junto con el nivel — ver [[🚪 salas (ES)\|salas]].)*
  Se reconecta cuando el DebugOverlay **inyecta el toggle `Debug2D`** en `Actions` (señal `child_entered_tree`)
  y cuando un botón de idioma **se habilita/deshabilita** (el idioma activo se queda fuera del anillo).
- **Orden de Tab de `playonline` (2026-06-29)** — la pantalla conecta el anillo con `UINav.wire_tab_ring(self)`
  (helper `_wire_tab_order`) en `_ready` (deferred), orden de lectura: **Player name (1) → Port/spin (2)
  → Port history (3) → IP/Domain (4) → IP history (5) → optimización: Host render (6),
  Sync rate (7), Smoothing↔Response (8) → Manage Rooms (9) → Join Rooms (10) → Back (11)
  → Portuguese (12) → English (13) → Debug 2D (14)**. Las 3 columnas de optimización se crean en
  `_build_optimization_options` ANTES de conectar el anillo, así que ya entran en la secuencia. Se reconecta cuando el
  DebugOverlay **inyecta el toggle `Debug2D`** en `Actions` (señal `child_entered_tree`) y cuando un botón de idioma
  **se habilita/deshabilita** (`_update_language_buttons`). Foco inicial en Tab = 1 vía
  `UINav.focus_tab_one`. (Antes, la pantalla solo hacía `manage_rooms_button.grab_focus()`, sin anillo explícito.)
- **Tab + Debug 2D en `host_session` / `client_session` (2026-06-29; estático en 2026-06-30)** — antes
  eran pantallas montadas ENTERAMENTE en código. **Ahora el andamiaje fijo es ESTÁTICO en el `.tscn`** (panel con
  textura/velo/shader `SignalLayer`, título, `StartRow` con los pickers en el host, lista, barra **`Actions`** +
  **`Back`** — renombrado desde `BackButton` en la limpieza de nombres del 2026-07-03, junto con
  `ManageTemplates`/`Start`/`Levels`/`Templates`); el código solo puebla los pickers, monta las
  **filas de sala** dinámicas (`_refresh_rooms`)
  y ajusta el `aspect` del shader. El DebugOverlay inyecta el `Debug2D` en `Actions`. El **`tab_order` se numera
  por CÓDIGO** en `_rewire_tab` (no se puede fijar en el `.tscn` porque el número de salas varía): los controles del grid
  → los botones habilitados de cada fila de sala (los deshabilitados quedan fuera) → **Back** → **Debug 2D**; foco
  inicial en Tab = 1. `collect_focusables` ignora `is_queued_for_deletion()` (filas recién liberadas).
- **Anillo de Tab en las pantallas restantes — `chooseplayer` / `settings` / `developer` / `controls` (2026-06-29)**
  — las cuatro pantallas que aún usaban solo `UINav.focus_first` pasaron al estándar `focus_tab_one` +
  `_wire_tab_order` (→ `UINav.wire_tab_ring(self)`), reconectando en el `child_entered_tree` de `Actions`
  (toggle Debug 2D) y en `_update_language_buttons`. Casos extra: **`settings`** reconecta en
  `TabContainer.tab_changed` (solo los focables de la pestaña VISIBLE entran en el anillo); **`developer`** reconecta en
  `_update_subrows_enabled` (los sub-toggles de Debug 2D entran/salen del anillo con el maestro). Con esto,
  **todas las pantallas completas** conectan el anillo — se convierte en una regla del proyecto (`CLAUDE.md`). Solo queda el
  overlay `pause_menu` (opcional). Detalles/matriz en [[🔁 navegacao-tab (ES)\|navegacao-tab]].
- **Regla ESC** (acción `quit`, mapeada a Esc + el Select del mando) — siempre **interrumpe primero el
  llenado de un campo/selección** antes de retroceder de pantalla. En el `_input` de cada pantalla:
  `if UINav.cancel_active_edit(get_viewport(), <fallback>): consume y RETURN`. `cancel_active_edit`
  finaliza la edición si el foco es un `LineEdit` (incluido el editor interno de un `SpinBox` — p. ej. la IP/puerto
  de `playonline`), devolviendo el foco al `fallback`. **Solo el 2º ESC** (sin ningún campo en edición) navega
  hacia atrás. El desplegable de un `OptionButton` ya se cierra con ESC de forma nativa (su propio popup).
- **Confirmación de salida en el menú** — `menu._on_quit_pressed` (el botón Quit **y** ESC) abre una
  ventana `FloatingDialog.confirm` central **"Quit Zimaro ?"** (Yes/No); solo cierra el juego con "Yes". Las
  cadenas están en `menu.*.json` (`"Deseja sair do Zimaro ?"`, `"Sair do jogo"`); Yes/No reutilizan la
  tabla global `Locale` (de `settings.*.json`).
- **Abandonar la partida (ESC en un nivel, 2026-07-07)** — centralizado en el helper `LevelExit`
  (`scenes3D/level_exit.gd`), llamado desde el `_input` de `level_1`/`level_2` en la acción `quit`.
  **Offline** (`PlayerSelection.online_mode == false`): abre un `FloatingDialog.confirm`
  **"Leave the match?"** (Yes/No) y **pausa la partida** (`get_tree().paused = true`; el diálogo recibe
  `process_mode = ALWAYS` para seguir respondiendo mientras está en pausa). **Yes** → despausa y emite
  `replace_main_scene(levels.tscn)` (vuelve a la pantalla de niveles); **No / × / ESC** → despausa, recaptura
  el ratón y **reanuda la partida** donde se dejó. **Online** (salas host/client): mantiene el antiguo
  comportamiento — ESC libera el ratón y emite `quit` (→ menú principal). Las cadenas
  (`"Abandonar a partida"`, `"Abandonar a partida ?"`) viven en `levels.*.json`; Yes/No reutilizan la tabla
  global `Locale`.

---

## Señales entre escenas

| Señal | Emitida por | Recibida por |
|---|---|---|
| `replace_main_scene(scene)` | menu, settings, chooseplayer, developer, models, Exported, levels, **level_1/level_2 (offline: Leave → levels)** | `main.gd` → cambio de escena |
| `quit` | chooseplayer, developer, **level_1/level_2 (online: ESC → menú)** | `main.gd` → `go_to_main_menu()` |

---

## Relacionado

- [[🧭 main-gd (ES)\|main-gd]]
- [[🌐 multiplayer (ES)\|multiplayer]]
- [[📄 formatacao (ES)\|formatacao]]

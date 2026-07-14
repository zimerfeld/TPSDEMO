---
tipo: backlog
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-07
---

# 🗂️ Backlog priorizado — ZIMARO

> **Punto de retomada entre sesiones.** Esta nota es autosuficiente: léela al inicio de una
> nueva conversación para saber **qué está en curso, qué falta y en qué orden atacarlo**.
> Enlazada con [[🏠 Home (ES)|Inicio]]. Cada elemento apunta a la nota de sistema donde vive el contexto detallado.
>
> **Convención de estado:** 🟡 en curso · 🔴 sin empezar · 🟢 hecho (a la espera de validación) · ⚪ opcional
>
> **Reglas que aplican al retomar (ver `CLAUDE.md` / `REGRAS.md`):** nunca hacer commit/publicar — dejarlo
> para que el usuario lo revise; cerrar el juego y el editor de Godot antes de tocar el código; al final de una
> tarea con impacto para el usuario, actualizar los READMEs (`.md`/`.en-US`/`.pt-BR`) **y** este cofre; ejecutar
> `build_windows.ps1` al final; eliminar errores/advertencias tras compilar.

**Última revisión:** 2026-07-08 · **Rama activa:** `feature/locomocao-realista-inimigos`

---

## 🟢 Locomoción realista + suavizado + Sistema de Facciones — LISTO para revisión (2026-07-08)

Rama `feature/locomocao-realista-inimigos` (partiendo de `develop`). `.exe` reconstruido; importación headless sin
errores/advertencias. **Sin commit** (a la espera de revisión).

- **Locomoción terrestre sin deslizamiento:** zancada de `Walk` medida en tiempo de ejecución (~0,8 m/s), cadencia mediante un
  nuevo nodo `AnimationNodeTimeScale`, las piernas encaran la dirección de avance (desplazamiento por root-motion),
  velocidades de la IA reducidas. Ver [[🤖 inimigos (ES)|enemigos]].
- **Anti-jitter:** rumbo suavizado (`move_dir_response`), `body_turn_rate` 7→5, el strafe se mantiene 1,6–3 s.
- **Sistema de facciones (en tiempo de ejecución, por instancia):** nuevo `effects_shared/factions.gd`. Sin fuego amigo
  (la bala atraviesa a los aliados), objetivos por facción, neutrales dinámicos (~8 s). Ver [[⚔️ facções (ES)|facciones]].
- **El bot aliado orbita al jugador más cercano sin colisionar** (`player_bot_ai`): ancla en el humano más cercano,
  órbita (radio + tangencial), excepción de colisión bot↔ancla. Ver [[🎮 player (ES)|jugador]].
- ✅ **Separación entre varios bots aliados (2026-07-08):** `player_bot_ai._separation` (dirección estilo boids)
  empuja a cada aliado lejos de los demás dentro de `separation_radius` → se reparten por la
  órbita sin amontonarse. Ver [[🎮 player (ES)|jugador]] / [[⚔️ facções (ES)|facciones]].

---

## 🟢 Colisión de controles en PT + actualización del `.exe` de la release — PUBLICADO (2026-07-07)

Tres frentes en una sesión, todos hechos:

1. **Corrección de la colisión de los controles ("Quick reference") en PT.** La landing page
   (`index.html`, **zimaro.zimerfeld.com** vía GitHub Pages) forzaba el contenedor de las pills a
   `display:block` en PT (`html[data-lang="pt"] .block.lang-pt{display:block}`), volviendo las
   `.pill` **inline** — y el padding vertical inline solapaba los fondos entre
   líneas. **Corrección CSS de 1 línea:** `html[data-lang="pt"] .pills.lang-pt.block{display:flex}`
   restaura flex/wrap solo en PT. Enviado como hotfix directamente a `main` (commit `4d79896`);
   Pages redesplegado en vivo. (La plantilla idéntica de ZIMMY tenía el mismo bug — corregido allí también.)
2. **`.exe` de la release actualizado.** El asset `ZIMARO.exe` de la release **`202606251203`** fue
   reemplazado (`gh release upload … --clobber`): **587 MB → 166 MB** (nuevo build), y la
   release fue **publicada** (`--draft=false`) — había sido un borrador, invisible al público.
3. **Higiene de git.** Se eliminó el commit `com exe` del historial (exe de 174 MB, que GitHub
   rechaza por superar los 100 MB); `build/windows/*.exe` está ahora en `.gitignore`; recommit
   limpio solo con iconos + `.gitignore` (`8fec39b`, subido a `develop`).
4. **Nueva release con la etiqueta de hoy + título limpio.** Creada la release **`202607072141`**
   (`gh release create … --title "202607072141"`), ahora **Latest**: título = solo la etiqueta (sin
   "ZIMARO v0.1.0"), notas EN/PT reutilizadas sin el encabezado de versión, `ZIMARO.exe` (166 MB)
   adjunto. La antigua `202606251203` se **mantuvo** por elección.

**Procedimiento documentado en el cofre:** [[📦 Atualizar Asset da Release (GitHub) (ES)|Actualizar el Asset de la Release (GitHub)]]
(PT/EN/ES) bajo 🚀 Operación — cómo intercambiar/publicar el binario con `gh` (saltándose git), y cómo
crear una **nueva release con una nueva etiqueta** (título = solo la etiqueta).

---

## 🟢 Landing page — salto de línea de título/subtítulo en PT — PUBLICADO (2026-07-07)

La landing page (`index.html`, servida en **zimaro.zimerfeld.com** vía GitHub Pages) comparte una plantilla i18n
con la regla `html[data-lang="pt"] .lang-pt{display:inline}`, que forzaba a **todos** los elementos portugueses
a `inline` — incluidos `h2`/`h3` — haciendo que el título/subtítulo colapsara sobre el texto siguiente cuando
el sitio se abre en PT (EN estaba bien, ya que `h2`/`h3` son `block` por defecto). **Corrección CSS de 1 línea:**
`html[data-lang="pt"] h2.lang-pt,html[data-lang="pt"] h3.lang-pt{display:block}` — restaura el salto solo
en los títulos/subtítulos PT, sin efecto en EN. Enviado vía GitFlow (release `develop`→`main`; la corrección ya
estaba en `develop` de una sesión anterior — solo faltaba la promoción a producción) + tag
**`202607071915pt-heading-break`**; `CNAME` preservado; deploy de GitHub Pages verificado en vivo.

> [!note] A diferencia de los elementos de código-del-juego de abajo
> Este es un ajuste aislado de **contenido-de-página** y ya fue **publicado** (con la autorización del usuario) —
> a diferencia de los elementos de código P0.x, que siguen la regla de "no hacer commit" y esperan revisión.

---

## 🟢 P0.5 — Template Manager funcionando en el .exe — LISTO para revisión (2026-07-03)

Playtest de extremo a extremo en el **.exe exportado** (menu → chooseplayer → levels → Template Manager →
plantilla "Arena Fable" (enemigo Red Robot ×3) → partida en solitario en Level 1 con spawn, combate, muerte y
respawn a ~60 FPS). **3 bugs encontrados y corregidos** (detalles en
[[🧩 templates-de-level (ES)|plantillas-de-nivel]]):

1. **Dropdown de modelos vacío en el build** — el escaneo de `DirAccess` no resolvía los archivos
   `*.tscn.remap` de la exportación (`level_template_manager.gd`, helper `_logical_name` igual al de la pantalla Models).
2. **"Save and Use In This Level" no activaba una nueva plantilla** (el id generado no volvía
   al diálogo; un Save repetido lo duplicaba) — `level_template_dialog.gd` ahora conserva el id de `upsert_template`.
3. **El nombre de la plantilla se perdía** al Añadir/Quitar una Entry — `text_changed` ahora lo escribe directamente.

READMEs (3) + cofre actualizados; `build_windows.ps1` ejecutado (531 MB, sin errores). **Espera el
commit/publicación del usuario.** Pulido sugerido (no hecho): filtrar las escenas de soporte (bullet/impact_effect) fuera del
dropdown de modelos; sufijo automático para nombres de plantilla repetidos.

---

## 🟢 P0.6 — Entorno visual de los levels (cielo + fog + rejilla neón) — LISTO para revisión (2026-07-03)

Elemento 1 del plan de rendimiento/atractivo, **aprobado por el usuario e implementado**: cielo
procedural con identidad por nivel (**Level 1 cian / Level 2 ámbar**), fog exponencial de distancia y un
**suelo de rejilla neón emisiva** (shader compartido `themes/level_grid_floor.gdshader`, matemática pura — sin
texturas/pasadas). El objetivo de rendimiento del proyecto quedó registrado en `CLAUDE.md` (mín. 60 FPS con
hardware gráfico mínimo) y **validado en el `.exe`: 60 FPS en ambos niveles, incluso en
combate**. Detalles: [[🌌 ambiente-dos-levels (ES)|entorno-de-los-niveles]]. READMEs (3) actualizados. El exe
bajó de 531→174 MB porque el usuario movió archivos no usados a propósito (confirmado). **Espera commit.**

---

## 🟢 P0 — Cerrar la reestructuración en curso (`feature/restrutu`) — LISTO para revisión (2026-07-01)

**Estado:** trabajo terminado y validado; **espera el commit/publicación del usuario** (regla: no hacer commit).
Hecho en esta sesión: se buscaron referencias huérfanas a `level_base` (ninguna en el código); se eliminaron las
**claves de localización huérfanas** `"Level Base"` en `scenes2D/levels/Resources/levels.{en,pt}.json`;
se confirmó la eliminación completa del **filtro Prefix** en `models.gd` (sin restos); validación
headless en Godot 4.6.2 → el **editor importa limpio** (los autoloads compilan sin errores) y el
**juego corre 300 frames sin error de script/runtime** (solo los avisos benignos `ObjectDB leaked` /
`resources still in use` de `--quit-after`, normales en el cierre forzado); los READMEs
(`.md`/`.en-US`/`.pt-BR`) ya reflejan `structures` + el miembro fallback **CORPO** y la eliminación
de `level_base.ogg`; cofre sincronizado ([[🏠 Home (ES)|Inicio]], [[🎬 fluxo-de-cenas (ES)|flujo-de-escenas]]
orden de Tab de la pantalla `levels`, [[🚪 salas (ES)|salas]] nota histórica,
[[📄 formatacao (ES)|formato]]). **Solo falta:** ejecutar `build_windows.ps1` (hecho al final de
la sesión) y la **publicación por el usuario**.

<details><summary>Contexto original de la reestructuración (referencia)</summary>

Rama de reestructuración con muchos cambios aún sin commit. Llevada a un estado consistente, testeable y
revisable.

- **Cofre movido y renombrado** `OBSIDIAN/CLAUDE/` → `OBSIDIAN/` → `ZIMARO/` (renombrado al nombre del proyecto; la raíz del cofre ahora es `C:\GODOT\ZIMARO\ZIMARO`,
  índice en `000-INDEX.md`). Los archivos aparecen como `D` (path antiguo) + `??` (path nuevo) en git.
- **Sistema de plantillas de level** en construcción: `scenes2D/level_templates/level_template_dialog.gd`,
  `library3D/structures/` (nuevo, sin trackear), más `scenes3D/models/`, `levels`, `net_spawn`,
  `player_selection`, `host_session`, `stability_guard`, `music_manager`. Relacionado con las memorias
  *"las salas nacen limpias"* (nada pre-spawneado; enemigos solo vía plantilla) y *"miembro fallback CORPO"*.
- **Audio:** `audios/level_base.ogg` eliminado (+ `.import`); comprobar que `MusicManager`/asignaciones
  por escena ya no referencian ese archivo. Ver [[🔊 audio (ES)|audio]].

**Cierre:** ejecutar el juego y confirmar que abre sin errores (menu → level → models → salas); cero
errores/avisos; actualizar los 3 READMEs + notas del cofre afectadas; `build_windows.ps1`; **dejarlo para que el
usuario haga commit/publique** (no hacer commit). Sistemas: [[🚪 salas (ES)|salas]],
[[🗿 biblioteca-de-modelos (ES)|biblioteca-de-modelos]].

</details>

---

## 🟢 P0.7 — Cascada de carpetas + Scenery Manager + reparación de reorganización (2026-07-03)

Sesión grande, todo validado en el juego en el `.exe` (166 MB, 60 FPS) — **espera el commit del usuario**:

- **Reparación de la reorganización de carpetas del usuario** (characters → enemies/players/NPCs; eliminación de
  `structures/` y de la carpeta de soporte `characters/player/`): restaurados desde git SOLO los assets en
  uso (player.glb + materials/textures, audio/, bullet/, malla de muzzle, limb_config) EN
  `characters/players/player/`; reescritos los paths antiguos en **72 archivos** (los preloads de script no usan UID
  y se estaban rompiendo); los `_spawnable_scenes` de los levels limpiados (structures fuera, sceneries dentro);
  `user://level_templates.json` migrado.
- **Navegación en cascada** en el Template Manager (characters) y el nuevo **Scenery Manager**
  (sceneries) — ver [[🧩 templates-de-level (ES)|plantillas-de-nivel]]. La pantalla `levels` con 2
  botones por level (Tab renumerado 1-9); el scenery "Palco Neon" (4 box + 3 sphere + 2 pill)
  validado en el suelo Y en una sala online.
- **Velocidad del enemigo terrestre calibrada según estándares del mundo real** (investigación: caminar ~1,4 m/s, trotar ~3,
  correr 4,5): red_robot strafe 4,25→**2,4**, pressure 5,2→**3,2**, flee 6,0→**3,8** +
  **aceleración suave** (`manual_accel` 6/s) en el movimiento manual — sin deslizamiento, con peso.
- **ManageTemplates (host_session) corregido** (botón renombrado desde `ManageTemplatesButton` en el
  barrido del 2026-07-03): alerta cuando no hay level seleccionado (antes un return silencioso = "botón roto");
  validado alojando una sala en **127.0.0.1:4383**.
- **Pantalla `levels` en una grid responsive**: `GridContainer` de 3 columnas (Level fijo 300 px | Template |
  Scenery), las columnas del manager con `SIZE_EXPAND_FILL` **dividiendo el resto de la pantalla mitad y
  mitad**, espaciado uniforme de 16 px en ambas filas. Ver [[📐 layout-responsivo (ES)|layout-responsivo]].
- **`build_windows.ps1` endurecido**: borra `.godot/exported/` antes de cada exportación — la caché no
  se invalida cuando cambia un `.tscn` y el exe se enviaba con una **escena obsoleta** (costó un ciclo de
  diagnóstico con sondas headless y marcadores en el binario). Ver [[🚀 Build Windows (Prod) (ES)|Build Windows (Prod)]].

---

## 🟢 P0.10 — Reparación de reorganización de carpetas (refs → paths planos) — LISTO para revisión (2026-07-03)

El proyecto estaba en una **reorganización de carpetas a medio terminar**: los archivos de personajes volvieron a los
paths **planos** (`characters/player/`, `red_robot/`, `criatura_alada/`, `playera/`), pero muchas referencias
todavía apuntaban a los paths reorganizados (`characters/players/…`, `characters/enemies/…`).
Los de `uid://` resolvían, pero los **de string puro se rompían**: los `_spawnable_scenes` de
`level_1`/`level_2` (los personajes no spawneaban) y el `load(player.glb)` de `chooseplayer` (la pantalla
de selección de personaje fallaba). Detectado vía los errores de recurso en el build (presentes desde el 1er
build de la sesión — **preexistentes**, no del auto-fit). **Corregido** con 4 reescrituras de path en
**24 archivos** (~101 ocurrencias): `players/player/→player/`, `players/playera/→playera/`,
`enemies/red_robot/→red_robot/`, `enemies/criatura_alada/→criatura_alada/`. **Preservado a propósito**
`enemies/enemy_health_bar.gd` (el único archivo que genuinamente se quedó en `enemies/`, referenciado por
red_robot/criatura). Validado headless (sin errores de recurso) + rebuild. **Espera commit.**

---

## 🟢 P0.9 — Auto-fit de cápsula de locomoción por modelo — LISTO para revisión (2026-07-03)

El **bloqueo físico** entre personajes dejó de usar una cápsula por defecto (0,5×2,0) igual para todos
y pasó a ser **proporcional al modelo**, derivada de las mismas cajas de miembros que `LimbColliders`
ya mide — manteniendo **1 shape por personaje** (barata, estable, determinista para el netcode).
Nuevo método `LimbColliders.fit_locomotion_capsule` (radio = footprint torso+piernas; altura = extensión
vertical; base anclada en el suelo; no-op si no hay miembros → preserva la cápsula del autor).
Conectado en `player.gd` y `red_robot.gd` tras `build_for`. La criatura_alada (voladora, sin
`LimbColliders` en gameplay) conserva su cápsula del autor. **Validado** por una sonda headless
determinista (radio 0,250 ≠ brazos 0,575; altura 1,800; base 0,000 — 3/3 OK). Detalles:
[[🩸 dano-localizado (ES)|daño-localizado]] · [[🎮 player (ES)|jugador]]. Respondió a la pregunta del usuario
sobre usar los LimbColliders para el bloqueo físico (el daño localizado ya funcionaba así). **Espera commit.**

---

## 🟢 P0.8 — Salto variable + barrido de nombres de control — LISTO para revisión (2026-07-03)

- **Salto variable (mantener/soltar):** mantener **espacio** = animación de salto completa + distancia
  máxima (arco balístico completo, comportamiento anterior preservado); **soltar a mitad de ascenso** = corte SUAVE del salto
  (amortiguación exponencial `JUMP_CUT_DAMPING = 14.0/s` sobre la velocidad vertical — sin tirón) y la
  animación transiciona a `jump_down` en el ápice anticipado. Implementación: nuevo estado sincronizado
  `jump_held` en el `PlayerInputSynchronizer` (sembrado `true` en la RPC `jump()` para que el 1er frame no
  sea cortado por el retardo de replicación; replicado en el `SceneReplicationConfig` del InputSynchronizer), corte
  restringido a saltos reales vía el flag `_jump_active` (caer de un borde NO se amortigua). Los bots no
  saltan (IA), así que no se ven afectados. Ver [[🎮 player (ES)|jugador]].
- **Barrido de los nombres de control 2D:** hecho (detalles en el elemento P2 tachado más abajo). Dos nuevas reglas del proyecto
  en `CLAUDE.md` (no repetir Type/siglas en el Name; revisar dependencias al cambiar un
  control) y la regla global de limpieza de código muerto reforzada (tras cada adición/eliminación/modificación).
- Validación: juego headless 300 frames **sin errores**; consistencia `%UniqueName`×`.tscn` verificada
  en host_session/client_session/playonline. **Espera el commit del usuario.**

---

## 🟡 P1 — Validar las salas multijugador en una red real

Las fases 1–3 del servidor multi-level están **implementadas**. Progreso el 2026-07-01:

- ✅ **Code review del flujo de salas** (`RoomManager` + `host_session` + `client_session` + el `_ready` de los
  levels + plantilla lazy + filtros de visibilidad): **consistente, sin bugs encontrados**. Verificados los
  flujos de host-juega (`host_spawn_in_room`/`host_leave_room`), cliente-se-une (`client_join_room`/`join_room`),
  stop/restart (`notify_room_closed`/`notify_room_restarted`), aislamiento por `room_id` y el
  path de replicación determinista `/root/RoomManager/Room<id>/Level`.
- ✅ **Protocolo de prueba autosuficiente** creado: [[🧪 teste-salas-multiplayer (ES)|prueba-salas-multijugador]]
  (loopback local `127.0.0.1` → LAN → internet vía **playit.gg UDP**; puerto por defecto `4383`).
- ✅ **Prueba A (loopback `127.0.0.1`, 2 instancias) VALIDADA EN CAMPO (2026-07-02):** el host crea una sala,
  el cliente se une y spawnea (scenery, no gris), "(1 connection)", replicación cliente↔host. **Netcode
  probado.** Ajustes de UI en la misma sesión: ventana de error **no destructiva** (× / ESC / "Back" solo
  la cierran; corrige como bonus el quit accidental en la validación de la pantalla Models) + **race guard** en
  el "Play" del cliente (no spawnear en una sala parada durante `chooseplayer`).
  Ver [[🧪 teste-salas-multiplayer (ES)|prueba-salas-multijugador]] · [[🚪 salas (ES)|salas]].
- ⬜ **Falta la ejecución en campo en una red REAL** (necesita hardware/red):
  - **Prueba B/C (red real):** 2 PCs (LAN y luego internet vía playit.gg) — **depende del usuario**.

Contexto completo: [[🚪 salas (ES)|salas]] · [[🌐 multiplayer (ES)|multijugador]] · [[🛰️ hospedagem-online (ES)|alojamiento-online]].

---

## 🟡 P1.5 — IA del enemigo: comportamiento + pantalla de parametrización

Feedback del usuario (2026-07-02) sobre la IA automática actual. Dividido en **comportamiento** (código, en curso)
y **parametrización** (UI, pospuesto por decisión del usuario). Contexto: [[🤖 inimigos (ES)|enemigos]],
[[🧠 red-robot-ai-gd (ES)|red-robot-ai-gd]], `red_robot_ai.gd` / `criatura_alada_ai.gd` / `red_robot.gd`.

**Comportamiento (código) — ✅ HECHO (2026-07-02, ver [[🤖 inimigos (ES)|enemigos]] "refinamiento de IA"):**
- ✅ **El enemigo terrestre no "desliza":** `_match_locomotion_cadence` escala el `speed_scale` del
  AnimationPlayer de locomoción para que la cadencia coincida con la velocidad real (sin patinaje); fuera del modo manual
  vuelve a 1.0. Solo código (sin tocar el `.tscn`/blend tree). Tunables
  `walk_natural_speed`/`gait_speed_scale`.
- ✅ **Formación menos rígida:** `formation_cohesion` 0,55→0,32, `formation_band` 5→7 m, el heading del slot
  oscila suavemente (`formation_wander`) → orgánico.
- ✅ **Objetivo = jugador más cercano (multijugador):** `_players_in_range` + `_pick_target()` con histéresis
  (`TARGET_SWITCH_MARGIN`); cualquier enemigo dispara a cualquier jugador en rango (red_robot + criatura).
- ✅ **Altitud aérea suave/contextual:** cambio de capa interpolado (`_alt_bias`):
  amenazado→sube (escape), bombardeo inminente→baja (precisión), en otro caso crucero; tasa vertical limitada.
- ✅ **Marcado de facción (estructural):** `AIConfig.faction`/`set_faction`/`is_hostile`/`is_neutral`
  (hostil/neutral/aliado), defaults hostiles para los enemigos. **Aún sin personaje neutral** — campo listo para conectar.
- 🔴 **Lógica de comportamiento NEUTRAL (pendiente — depende de un personaje neutral):** un neutral solo se involucra
  si es AMENAZADO (le disparan) o por azar. El marcado ya existe; faltan el personaje y la lógica.

**Parametrización (UI — POSPUESTA, este es el "siguiente elemento" que mencionó el usuario):**
- 🔴 En la **ventana de IA** (Artificial Intelligence) de cada modelo, añadir un **botón junto a cada toggle**;
  al hacer clic, **cierra la ventana de IA** y abre una **ventana de parametrización** dedicada.
- 🔴 La ventana de parametrización expone los **límites**: altitud (mín/máx de vuelo), velocidad, **cadencia de disparo**, etc.
- 🔴 **Mismos estándares de estilo** que las otras ventanas (campos, botón **Back** y **× cerrar** en la esquina superior):
  Back/× **cierran la ventana y reabren la respectiva ventana de IA del modelo que la llamó**.
- La base de UI ya existe: `FloatingWindow`/`FloatingDialog` (mismo patrón modal/de estilo). Hoy los
  parámetros son `@export`s en los scripts de IA + `AIConfig` (solo toggles booleanos por ahora) → extender
  `AIConfig` para valores numéricos por modelo. Ver [[🚪 salas (ES)|salas]] (ventanas) y
  [[🧠 red-robot-ai-gd (ES)|red-robot-ai-gd]].

---

## 🔴 P2 — UI: rollouts pendientes

- **Layout responsive (containers):** migrar las pantallas 2D restantes del posicionamiento por
  offset absoluto al esqueleto `Margin → VBox → HBox` con `stretch` desactivado. **Piloto hecho: `developer`.**
  Replicar a menu/settings/chooseplayer/levels/playonline/sessions. Ver [[📐 layout-responsivo (ES)|layout-responsivo]].
- ~~**Renombrar controles 2D (barrido)**~~ — ✅ **HECHO el 2026-07-03** (todas las pantallas): sin repetir el
  Type en el Name, sin siglas de tipo, `OptionButton` en plural; `Actions` preservado (el DebugOverlay
  lo busca por nombre). Reglas registradas en el `CLAUDE.md` del proyecto. Renombrados: `BackButton→Back`
  (host/client session), `StartButton→Start`, `ManageTemplatesButton→ManageTemplates`,
  `LevelPicker→Levels`, `TemplatePicker→Templates`, `HostRenderPicker→HostRenderModes`,
  `SyncRatePicker→SyncRates`, `InterpPicker→Interpolations`, `ScopeLabel→Scope`/`OptionLabel→Caption`
  (playonline ×3 columnas), 7×`Label→Caption` (selectores de la pantalla Models), filas de sala
  (`RoomLabel→RoomInfo`, `PlayButton→Play`, `Observe/Restart/Stop` sin el sufijo Button),
  diálogo de plantilla (`ModelBox→ModelColumn`, `ModelValueLabel→ModelValue`, `CountSpin→Count`,
  `EntryPicker→Entries`, `FactionPickers→Factions`, `PlacementPicker→Placements`,
  `FolderPickers%d→Folders%d`), music manager (`ListenPicker→ListenTracks`, `TrackLabel_→Track_`,
  `TrackPicker_→Tracks_`), ventana Damage de Models (`Bone→Bones`, `Owner→Owners`).
  Todas las dependencias de código revisadas (`%`, `$`, `get_node`, señales); validación headless 300 frames sin errores.

---

## ⚪ P3 — Pulido / elementos menores pendientes

- **`pause_menu`** (overlay `Control`, 3 botones + 3 sliders): conectar `UINav.wire_tab_ring(self)` +
  `grab_focus` inicial para que no quede fuera del anillo de Tab. Es un overlay de pausa (sin cambio de escena) →
  **opcional/secundario**. Ver [[🔁 navegacao-tab (ES)|navegación-tab]] (§ Cobertura y elementos pendientes).

---

## Cómo retomar (checklist rápido)

1. Lee esta nota + [[🏠 Home (ES)|Inicio]] y las notas enlazadas desde el elemento que vayas a atacar.
2. Cierra cualquier Zimaro en ejecución y el editor de Godot **antes** de tocar el código.
3. Ataca por prioridad (P0 → P3); dentro de cada elemento, el "contexto completo" vive en la nota de sistema.
4. Al terminar: cero errores/advertencias → actualizar READMEs + cofre → `build_windows.ps1` → **dejar para revisión** (no hacer commit).

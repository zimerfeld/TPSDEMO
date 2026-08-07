---
tipo: sistema
projeto: ZIMARO
lang: es-ES
atualizado: 2026-08-06
---

# 🧩 Plantillas de nivel (Template Manager + Scenery Manager)

> Composición de spawn por nivel: personajes (Templates) y objetos de escenario (Sceneries), con
> facción, cantidad y colocación, editados en el juego en una ventana flotante y aplicados cuando el nivel
> arranca (solo o sala online). Relacionado: [[🎬 fluxo-de-cenas (ES)|Flujo de escenas]] (pantalla `levels`),
> [[🚪 salas (ES)|Salas]] (el host abre la misma ventana), memoria *"las salas nacen limpias"*.

---

## 📐 Campo "Escala (%)" (2026-08-06)

Debajo de **Cantidad**, en **ambos** gestores (Templates y Escenarios), un `SpinBox` define la escala
del modelo en **porcentaje sobre el tamaño original**:

| Valor | Efecto |
|---|---|
| `0` | tamaño natural (por defecto) |
| `+50` | una vez y media |
| `-30` | 30% más pequeño |

- Rango aceptado: **-95% a +900%**.
- Persistido en la entrada de la plantilla con la clave **`scale_percent`** (JSON en `user://`), por lo
  que se carga y puede cambiarse **en tiempo de ejecución**, sin recompilar.
- Aplicado en cada spawn en `TemplateManagerBase._configure_spawned_node`:
  `factor = 1 + scale_percent/100`, con un suelo de **0,05** (por debajo la malla se vuelve un punto y
  los colliders degeneran). El factor también queda en la meta `template_scale_factor` del nodo.

## Dos escenas + dos gestores separados (2026-07-03, refactor)

Responsabilidades **separadas** por categoría (antes: un único diálogo `LevelTemplateDialog`
parametrizado por `configure()` y un único autoload `LevelTemplateManager` — ambos ELIMINADOS):

- **UI — dos escenas `.tscn`** (raíz `ScrollContainer`, scroll vertical cuando los campos no caben):
  - `scenes2D/template_manager/template_manager.tscn` (+ `.gd`) — personajes, **con** una fila de Facción;
  - `scenes2D/scenery_manager/scenery_manager.tscn` (+ `.gd`) — escenarios, **sin** Facción.
  - Lógica común en la base `scenes2D/managers_common/template_form_base.gd` (`class_name
    TemplateFormBase extends ScrollContainer`); cada subclase solo define `_manager()`, el título y
    el nombre por defecto. La presencia/ausencia de Facción se detecta por el nodo `%Factions` (que solo
    existe en la escena de personaje). Cada escena tiene `Resources/<name>.pt.json` + `.en.json` (i18n vía Locale).
  - Abiertas por `open_over(host, level_path)`: crean el `FloatingWindow` (CanvasLayer 128),
    insertan su propio formulario en su contenido y construyen los botones del footer; al cerrar, todo el
    CanvasLayer se libera (la instancia NO se reutiliza — el llamador crea una nueva).
  - **Disposición del formulario (2026-07-03):** `New` se sitúa a la derecha del campo `Name` (ya no en la TopRow);
    la `EntryRow` (desplegable `Entries` + `Remove Entry`) viene ANTES de la `EntryNameRow` (campo
    `Entry name` + `Add Entry` a la derecha). El campo `Entry name` se **auto-rellena**
    con el cuerpo de la etiqueta del desplegable Entries (`_entry_body_text`: nombre personalizado o `_entry_auto_label`
    "faction model xN"); `_save_entry_fields` solo lo almacena como nombre PERSONALIZADO si el texto difiere de la
    etiqueta automática (de lo contrario mantiene `""` = dinámico). Footer: el botón fue renombrado — nodo `Footer_SalvarAplicar`,
    texto **"Save and Apply"** (`add_footer_button` + `save_apply.name = ...`; nueva clave i18n).
- **Datos — dos autoloads** (`autoload/template_manager_base.gd` = `TemplateManagerBase` con la
  lógica común; subclases `CharacterTemplateManager` y `SceneryTemplateManager`), cada uno en SU PROPIO
  archivo: `user://character_templates.json` y `user://scenery_templates.json`. API uniforme sin
  categoría: `templates_for_level(level)`, `active(level)`/`active_id(level)`, `set_active`,
  `upsert_template`, `remove_template`, `browse_dir`, `root_dir`, `apply_active(level, spawned)`.
- **Migración única**: en la 1.ª carga, si el archivo propio no existe, cada gestor LEE el legado
  `user://level_templates.json` y trae solo su propia categoría (`_matches_legacy`) + el mapa de activos correspondiente
  (`active_by_level` / `active_scenery_by_level`), escribiéndolos en su propio archivo.
- **Aplicación**: `level_1`/`level_2` (solo) y `RoomManager` (salas) llaman a
  `CharacterTemplateManager.apply_active` **y** `SceneryTemplateManager.apply_active`. En `level_2`,
  la criatura por defecto solo aparece si NINGUNO de los dos aplicó nada (preservando la semántica del antiguo bool).

Cada nivel tiene DOS botones a la derecha en la pantalla `levels` (Template + Scenery), con activos
independientes — un nivel ejecuta una plantilla de personaje Y un escenario al mismo tiempo (solo y salas).

**Sanación de rutas obsoletas (al cargar):** `_heal_entry_paths` reubica por `model_key`, bajo la
raíz actual, toda entrada cuyo `scene_path` ya no exista (p. ej.: datos guardados apuntando al
extinto `characters/enemies/…`) y reescribe el archivo. Sin esto, la cascada del diálogo se abría en
"Select..." en lugar de reseleccionar el modelo guardado. **Etiquetas i18n de los botones de nivel:** los
textos dinámicos "Templates/Sceneries: default" y "Template/Scenery: `<name>`" pasan por `tr_key`
(prefijos fijos traducidos; el NOMBRE de la plantilla es dato y no se traduce), en el `SKIP_GROUP` y
retraducidos en `language_changed` — claves en `scenes2D/levels/Resources/levels.{pt,en}.json`.

## Disposición del formulario y campos condicionales a la colocación (2026-07-04)

Pulido de disposición de AMBAS ventanas (mismo `TemplateFormBase`, aplicado a ambos `.tscn`):

- **Campos condicionales AGRUPADOS.** Los campos que solo aplican a un modo de colocación salieron de la
  cuadrícula principal a un `PanelContainer` **`%PlacementGroup`** (título "Placement options", nueva clave i18n en
  ambos idiomas), con un `MarginContainer` interior y un `GridContainer` de 2 columnas.
  `_apply_placement_visibility()` muestra solo los pares label+campo del modo actual (un par oculto =
  ambas celdas, para que la cuadrícula quede alineada) y el panel ENTERO se oculta cuando no hay entrada
  (`_placement_group.visible = has_entry`). Mapeo: `coordinates` → Coordinates; `random` → Random
  center + Random size; `formation` → Formation + Origin + Spacing. **Rotation Y** es general (siempre
  visible, se queda en la cuadrícula principal). Los controles ocultos salen del anillo de Tab automáticamente
  (`UINav.collect_focusables` salta los invisibles) — `_win.wire_focus_ring` se re-conecta en
  `_on_placement_selected` y al cambiar de entrada.
- **Anchuras compactas (sin sobredimensionar).** Los campos ya no se estiran con la ventana
  (`size_flags_horizontal = 0`): desplegables y campos de texto-vector **240 px**; enteros/números
  (`Count`, `Spacing`, `Rotation`) **96 px** (caben los dígitos sin desbordar). Las cuadrículas se ajustan a su contenido
  y se alinean a la izquierda, sin tocar nunca los bordes (el `FloatingWindow` ya da un margen de 16 px).
- **Cascada del modelo como columna.** `%CascadeRow` pasó a ser un `VBoxContainer` (era `HFlowContainer`), para que cada
  desplegable `Folders%d` ocupe todo el ancho y se apile verticalmente (VBox estira en el eje cruzado).
- **`ModelValue` eliminado.** La label que mostraba "Model: X (x.tscn)" desapareció (nodo + `_model_value_label`
  + `_update_model_label()` + llamadas) — limpieza de código muerto.
- **Ventana más pequeña.** `min_window_size` 1040×640 → **700×620**; el `custom_minimum_size` de las escenas
  1000×560 → **620×540**, recortando espacio horizontal inactivo.

> [!warning] `.tscn` NO usa `#` para comentarios
> Comentarios de prosa `#` DENTRO de un `.tscn` corrompen la paternidad de los nodos ("parent path … vanished", hijos sin
> padre). El formato de recursos de Godot usa `;`. Es preferible no poner comentarios en el `.tscn` (documentar aquí) —
> validado instanciando ambas escenas en headless (cada `%UniqueName` se resuelve, sin "vanished").

## Navegación en CASCADA del modelo (2026-07-03)

El antiguo desplegable único "Model" (una lista plana contaminada con bullet/impact_effect) pasó a ser una
**cascada de OptionButtons**: un desplegable por nivel de carpeta empezando desde la raíz de la categoría —
p. ej.: `[enemies] → [red_robot]` — descendiendo solo por subcarpetas que CONTIENEN un modelo a alguna
profundidad (`browse_dir`/`_dir_model`/`_dir_has_models` en el gestor). Al llegar a una
carpeta-modelo (una escena con el nombre de la carpeta), se mapean los **campos relevantes** de la entrada
(`model_key` + `scene_path`) y la label de abajo muestra "Model: X (x.tscn)". Navegar sin
terminar NO borra el modelo guardado de la entrada. La cascada se reconstruye a partir del `scene_path` al
cambiar de entrada/plantilla. El campo "Type" (character/structure) fue ELIMINADO (el tipo viene de la categoría);
`model_options`/`_collect_scene_options` pasaron a ser código muerto y se borraron.

## Biblioteca de escenarios (`library3D/sceneries/`)

`box/` (cubo magenta de 2 m), `sphere/` (esfera esmeralda r=1.2) y `pill/` (cápsula ámbar h=3) —
`StaticBody3D` + geometría volumétrica básica + material EMISIVO + su propio `OmniLight3D`
(rango 6, sin sombra — barato) + `CollisionShape3D` ajustada a la malla y `limb_config.json` con el
único miembro **BODY** (concepto LimbColliders — misma familia que `bomb`), para que la pantalla Models
pueda configurar el colisionador. Entran en los `_spawnable_scenes` de los niveles (replicables en salas). El
antiguo `structures/` salió del proyecto (limpieza del usuario); el tipo legado
"structure" se migra a "scenery" al cargar.

## ManageTemplates de host_session (2026-07-03; ex-ManageTemplatesButton)

El botón "Templates" de la cuadrícula del host "no funcionaba" cuando el selector de nivel estaba en
"Select..." — retorno SILENCIOSO. Ahora muestra una alerta (`FloatingDialog.alert`: "Select a
level first…"); con un nivel seleccionado abre el gestor con normalidad (validado hosteando en vivo
en 127.0.0.1:4383 — sala #1 creada, observada, escenario aplicado).

## Selector de ESCENARIO en host_session (2026-08-06)

La grilla del host solo tenía `Levels` + `Templates` (personajes) — la sala online nacía siempre con
el escenario **por defecto del level**, mientras el modo offline (pantalla `levels`) ya elegía los
dos. La `StartRow` ganó `Sceneries` (OptionButton) + `ManageSceneries` (botón "Cenários", abre el
`scenery_manager` en el mismo `FloatingWindow`), reflejando el par de personajes. `_on_start_pressed`
activa LOS DOS managers **antes** del `RoomManager.start_room` — es él quien aplica ambos al montar
la sala (`apply_active_gradual`), así el cliente que entra recibe el nivel completo, idéntico al del
host. Código genérico: `_refresh_picker`/`_apply_picker`/`_open_manager_dialog` reciben el
`TemplateManagerBase` de la categoría (un solo camino para las dos). Tab: Levels 1 → Templates 2 →
ManageTemplates 3 → Sceneries 4 → ManageSceneries 5 → Iniciar Sala 6 → filas de sala → Volver →
Debug 2D.

## El escenario llegaba en (0,0,0) al cliente — spawn properties de las piezas (2026-08-06)

Con el selector de escenario en el host apareció el bug: **en el cliente las 9 piezas del "Palco
Neon" nacían todas en el origen, apiladas**, mientras en el servidor estaban repartidas. Medido con
un volcado simultáneo de los dos lados (host en 44000, cliente entrando por el túnel
`zimaro.playit.game`): `Scenery_box_000` = `-11.33, 1.00, -3.55` en el servidor y `0,0,0` en el
cliente — así las nueve.

**Causa.** El `MultiplayerSpawner` transmite solo QUÉ escena instanciar y el nombre del nodo; el
`position`/`rotation`/`scale` que `_spawn_job` aplica tras el `instantiate()` no viaja en el paquete.
**Todos los modelos nacen en (0,0,0) en el cliente** — lo que cambia es quién lo CORRIGE después:

| escena | sincronizadores | resultado en el cliente |
| --- | --- | --- |
| `player.tscn` (incluido el aliado bot) | 3, con `net_transform` **y** `spawn_position` (`spawn=true`) | correcto en el mismo frame |
| `red_robot.tscn` / `criatura_alada.tscn` | 4 / 1, con `net_transform` (`spawn=true`) | correcto en el mismo frame |
| `box`/`sphere`/`pill` | **ninguno** | se quedaba en (0,0,0) para siempre |

Al ser estáticas, nada replicaba su transform tras el spawn — el error era permanente.

**Corrección.** `library3D/sceneries/scenery_piece.gd` (`class_name SceneryPiece`): `spawn_position`,
`spawn_rotation_y` y `spawn_scale` como `@export` con setter que aplica en el propio nodo, replicadas
por un `ServerSynchronizer` con `replication_mode = 0` (**solo en el spawn** — cero tráfico después,
lo correcto para un cuerpo que nunca se mueve). El `_spawn_job` copia el transform a esas properties
ANTES del `add_child` (única forma de que entren en el paquete de creación). Mismo patrón que el
`spawn_position` del player.

**Validado** con el mismo test comparativo: las nueve piezas ahora coinciden decimal a decimal entre
servidor y cliente (`7.48,1.00,10.37`, `-13.08,1.00,13.89`, …).

### Importador + generador del contrato (`scripts/scenery_contract.gd`)

Herramienta de DESARROLLO (el `res://` del `.exe` es de solo lectura, así que la preparación de las
escenas ocurre en el proyecto, nunca en runtime):

```bash
godot --headless --path . --script scripts/scenery_contract.gd             # valida e informa
godot --headless --path . --script scripts/scenery_contract.gd -- --apply  # corrige y guarda
```

- **Valida** cada `library3D/sceneries/<nombre>/<nombre>.tscn` contra el contrato y sale con código 1
  si falta algo (sirve como verificación automática).
- **Corrige** (`--apply`) añadiendo el script + `ServerSynchronizer` a las escenas que no los tengan.
- **Importa** un modelo nuevo: una carpeta con `.glb`/`.gltf` pero sin `<nombre>.tscn` recibe una
  escena generada — raíz `StaticBody3D` con el contrato, la malla instanciada y un
  `CollisionShape3D` de caja según el AABB agregado (punto de partida editable).

La regla del contrato vive en **un solo lugar** — `SceneryPiece.contract_issues()` /
`meets_contract()` / `make_spawn_config()` —, consultada por la herramienta y por el runtime, para
que la herramienta no apruebe con un criterio mientras el juego falla con otro. Por eso
`SceneryPiece` extiende `Node3D` y no `StaticBody3D`: el contrato vale para cualquier raíz 3D.

**Validación en pantalla (los DOS gestores).** El aviso aparece en el instante en que se ELIGE el
modelo en la cascada — una etiqueta ámbar bajo los desplegables: *"Atención: este modelo nace en
(0,0,0) para quien entra por la red — …"*, con lo que falta. También está la alerta al guardar (lista
los modelos problemáticos de la plantilla) y un `push_warning` por escena en `_spawn_job`, con el
comando de corrección.

Cada categoría responde por SU requisito, vía `TemplateManagerBase._node_contract_issues`:

- **escenarios** → el contrato completo de `SceneryPiece` (son estáticos: si el transform no llega en
  el paquete de spawn, nada lo corrige después);
- **personajes** → basta con replicar el transform en el spawn (`net_transform`/`spawn_position`),
  porque quien lo replica también lo corrige continuamente. Verificado por `replicates_transform()`.

El resultado se memoriza por `scene_path` (`_contract_cache`) — la cascada reconsulta en cada clic y
la comprobación instancia la escena.

**`characters/jogador/jogador.tscn` corregido (2026-08-07).** Era `Node3D` + malla GLB, sin script,
sin IA y sin sincronizador — un personaje solo por la carpeta, en la práctica una pieza estática —,
así que recibió el mismo contrato, aplicado por la propia herramienta:

```bash
godot --headless --path . --script scripts/scenery_contract.gd -- --root=res://library3D/characters --only=jogador --apply
```

De ahí los dos parámetros nuevos: **`--root=`** (apunta a otra biblioteca) y **`--only=`** (limita a
UNA carpeta — sin él, un `--apply` sobre `characters` también GENERARÍA escenas para `humanoide`,
`monstro` y `mulher`, que solo tienen `.glb` y aún no están listos para el gestor). Dos guardas
protegen las escenas con comportamiento: la herramienta **nunca sobrescribe un script existente**, e
informa `ok (replica el transform por su propio script)` para las que ya cumplen vía `net_transform`
(player, playera, red_robot, criatura_alada). Validado en red: los tres `Character_jogador_*`
coinciden exactamente entre servidor y cliente.

No se puede arreglar en runtime: las spawn properties deben existir en la ESCENA, que ambos lados
instancian — por eso la herramienta corrige y la pantalla solo avisa.

**El cliente no monta escenarios** — nunca aplica una plantilla: el servidor materializa la sala y el
`MultiplayerSpawner` la replica. "Cargar exactamente la misma información inicial" es justo lo que
garantizan las spawn properties. Regla general: **lo que sea dinámico debe repercutir en todos los
oyentes conectados** — el estado que cambia en runtime necesita replicación continua en el
`replication_config`; crear/eliminar piezas ya viaja solo por el spawner.

## Arquitectura

- **`TemplateManagerBase`** (`autoload/template_manager_base.gd`): base común de los dos autoloads.
  API: `upsert_template(t) -> id`, `remove_template(id)`, `set_active(level, id)`,
  `active(level)`/`active_id(level)`, `templates_for_level(level)`, `apply_active(level, spawned)`,
  `browse_dir(dir)`, `root_dir()`. Hooks por subclase: `_file_path`, `root_dir`, `_entry_kind`,
  `_matches_legacy`, `_install_defaults`.
  - **`CharacterTemplateManager`** → `user://character_templates.json`, raíz `characters`; sin
    plantilla guardada, instala el ejemplo "Level 2 - Aerial hunt".
  - **`SceneryTemplateManager`** → `user://scenery_templates.json`, raíz `sceneries`; sin defaults.
- **`TemplateFormBase`** (`scenes2D/managers_common/template_form_base.gd`): el controlador del formulario
  (raíz `ScrollContainer`) insertado en un `FloatingWindow` (CanvasLayer 128) — tema 2D + Debug 2D
  funcionan. Subclases: `template_manager.gd` (personajes) y `scenery_manager.gd` (escenarios),
  cada uno la raíz de su `.tscn`. Abiertas por `open_over(host, level)` desde el botón de cada fila de la
  pantalla `levels` y por `host_session` (desde 2026-08-06, LOS DOS — personajes y escenarios).
- **Entrada** de plantilla: `kind` (character/scenery), `model_key`/`scene_path`, `faction`
  (friendly/enemy/neutral — solo personajes), `count`, `placement` (coordinates/random/formation) +
  campos por cada modo, `name` (etiqueta personalizada en el desplegable `Entries`), `rotation_y`, `spacing`.
- **Aplicación**: `level_1.gd`/`level_2.gd` llaman a `apply_active` de AMBOS gestores en `_ready`
  (offline) y el `RoomManager` en la creación de la sala (online). Facción friendly → jugador `bot_controlled`
  (bots de cobertura); enemy → IA hostil.
- `browse_dir`/`_dir_model` escanean la raíz de la categoría recursivamente; solo entra la escena cuyo basename
  == nombre de la carpeta (la escena "modelo"; hermanos como `bomb.tscn` quedan fuera). Necesita el
  `_logical_name` (quitar `.remap`/`.import`) para funcionar en el `.exe` exportado.

## Bugs corregidos el 2026-07-03 (encontrados en playtest sobre el .exe)

1. **Desplegable Model VACÍO en el .exe exportado** — `_collect_scene_options` filtraba
   `file.ends_with(".tscn")`, pero en la exportación los archivos aparecen en `DirAccess` como
   `*.tscn.remap` → ningún modelo listado y era imposible ensamblar una plantilla válida en el build.
   **Solución:** helper `_logical_name` (quitar `.remap`/`.import`), mismo patrón que la pantalla Models
   (`models.gd`). ⚠️ Lección general: **todo escaneo de `DirAccess` por extensión necesita
   `_logical_name`** — el editor NO reproduce ese estado, solo el build exportado.
2. **"Save and Use in This Level" no activaba una NUEVA plantilla** — `_normalize_template` duplica
   el diccionario, así que el id generado en `upsert_template` quedaba solo en la copia; el `_template` local
   mantenía `id=""` → `set_active_template(level, "")` BORRABA el activo (la fila volvía a
   "Templates: default") y cada Save re-añadía (duplicados). **Solución:** `_save_template` ahora hace
   `_template["id"] = LevelTemplateManager.upsert_template(_template)`.
3. **El nombre tecleado se perdía** — teclear el Name y pulsar "Add/Remove Entry" hacía que
   `_refresh_template_fields` releyera el antiguo `_template["name"]` (el campo solo se leía al Guardar).
   **Solución:** `_name_edit.text_changed` escribe directamente en `_template["name"]` (igual que el
   campo "Entry name").

## Comportamientos observados (por diseño)

- `remove_template("")` es un no-op — "Remove" en una plantilla aún no guardada no afecta a la lista.
- Dos plantillas pueden tener el **mismo nombre** (el enlace es por id) — p. ej.: dos entradas "New template" en
  la lista son confusas; idea de pulido: sufijo automático ("New template 2").
- `model_options` lista TODA escena nombrada como su carpeta — incluyendo `bullet`, `impact_effect`
  (efectos/proyectiles aparecen como "modelos" elegibles). Idea de pulido: filtrar carpetas de apoyo
  o marcar categorías spawneables.

## Validación de campos (2026-07-03, .exe reconstruido)

Flujo completo en el build: Levels → Manager → plantilla **"Arena Fable"** (Red Robot × 3,
enemy, random) → "Save and Use in This Level" → la fila muestra "Template: Arena Fable" → Level 1
solo hace spawn de los 3 red robots, que combaten (daño al jugador, muerte y respawn OK) a 59–61 FPS.

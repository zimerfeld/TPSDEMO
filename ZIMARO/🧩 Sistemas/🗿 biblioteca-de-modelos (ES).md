---
tipo: sistema
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# 🗿 Biblioteca de modelos (pantalla Models)

Pantalla `scenes3D/models/models.tscn` (`models.gd`): navegador + extractor de los
modelos 3D del proyecto. Se llega vía **developer → 3D Models**; se vuelve con
"Back" (→ developer) y abre la galería con "Exported" (→ `Exported.tscn`).

## 🧭 Gizmo de ejes 3D (orientación)

Indicador de orientación estilo editor en la **esquina superior derecha**: tres ejes coloreados (X rojo, Y
verde, Z azul) con una bola y una letra en la punta, que **rotan junto con el modelo** (`_gizmo_node.rotation =
model_holder.rotation` en `_process`). Construido en código (`_setup_axis_gizmo`) en su **propio SubViewport**
(`own_world_3d`, `transparent_bg`, MSAA) con una cámara ortográfica mirando hacia -Z — para que **nunca quede
cubierto por el modelo** y sea independiente del zoom. El overlay se reposiciona cada fotograma **a la izquierda de la
columna de toggles** (`_position_gizmo_overlay`), para que no cubra ni la UI ni el modelo (centrado),
a cualquier resolución. Materiales **unshaded** (color pleno, legible sin luz). Ajustables: `_GIZMO_SIZE`,
`_GIZMO_ARM`, `_GIZMO_BALL`.

## 📚 Biblioteca de assets

Todo bajo `res://library3D/<type>/<model>/`:

- `characters/` — `player`, `players`, `red_robot`, `criatura_alada`, `demonio_*`,
  `mecha07_infantil`, `enemies/` y los **14 robots** `robot_01..07_*_{infantil,adulto}`
  (importados de `C:\GODOT\MODELOS\robos_3d_godot_infantil_adulto` en 2026-06-16; prefijo "robot")
- `propulsores/` — `forklift` (era `props/` en la versión antigua de la nota)
- `structures/` — `core`, `core_out_light`, `door`, `lights`, `props`, `structure`
- `weapons/` — `bomb`, `pistola_infantil`
- carpetas de apoyo (NO categorías): `geometry/` (materiales `.tres`), `textures/`, `extracted/` (salida)

`_scan_library()` escanea solo las **4 categorías fijas** en `const CATEGORIES`
(characters/propulsores/structures/weapons — carpetas de apoyo como geometry/textures
se ignoran a propósito). Un nuevo modelo en `library3D/<type>/<name>/` con un `.glb`
aparece solo — nada que editar en código.

> [!warning] Compatibilidad con el BUILD EXPORTADO (2026-06-21)
> En el `.exe` exportado, los archivos fuente no van en bruto en el PCK: el `.glb` se convierte en **`<name>.glb.import`** y el
> `.tscn` en **`<name>.tscn.remap`** (ambos apuntan al recurso importado). Por eso el escáner
> normaliza cada nombre con **`_logical_name()`** (quita el sufijo `.import`/`.remap` → ruta lógica,
> que `load()` resuelve en el editor Y en la exportación). Sin esto, `_find_model_file` no encontraba nada y el
> **menú Category quedaba vacío en el `.exe`** (funcionaba en el editor). Validado: editor y exportación encuentran
> los mismos 21/1/6/2 modelos.

### 📄 Tipos de archivo importables (escaneados)

El navegador reconoce **solo 3 extensiones** (case-insensitive), solo de archivos
**directamente en la carpeta del modelo** (subcarpetas como `audio/`, `bullet/` se ignoran):

| Extensión | Rol |
|---|---|
| `.glb` / `.gltf` | malla importada en bruto (glTF 2.0) — **preferida** |
| `.tscn` | escena Godot ensamblada — **fallback** |

> [!warning] Formatos como `.obj`, `.fbx`, `.dae` **no aparecen** en el navegador.
> Necesitan convertirse en `.glb`/`.gltf` (o una escena `.tscn`) primero. glTF (`.glb`/`.gltf`) es
> el formato recomendado por Godot para un modelo completo **con animación** (malla +
> esqueleto + skinning + clips); `.blend`/`.fbx`/`.dae` también animan pero dependen de
> Blender/FBX2glTF; `.obj` solo importa una malla estática.

Cada modelo resuelve **dos** rutas, por dos funciones distintas:

- **`_find_model_file()`** → `path` (la **malla**, base del catálogo de partes). Prefiere,
  en este orden: un `.glb`/`.gltf` cuyo basename **coincide con la carpeta** (p. ej.: `red_robot.glb`
  en `red_robot/`), luego cualquier `.glb`/`.gltf`, luego un `.tscn` homónimo, luego
  cualquier `.tscn`. La malla en bruto gana porque muestra la geometría **sin ejecutar el script de
  gameplay**. El criterio "nombre = carpeta" evita que una escena hermana (p. ej.: `bomb.tscn` en
  `criatura_alada/`, el proyectil) se confunda con el modelo.
- **`_find_display_file()`** → `display_path` (la escena **"Whole model"**). Prefiere
  el **`.tscn`** (carga materiales, efectos y la variante visible prevista que el `.glb` en bruto
  no tiene), cayendo a lo que `_find_model_file` resuelve (el `.glb`) cuando no hay escena.

Tras elegir un modelo, `_on_model_selected` hace `load()` de ambas rutas y
`_build_mesh_catalog` instancia la escena, escanea todos los `MeshInstance3D` y los **deduplica
por el recurso `Mesh` compartido** (`get_instance_id`) — cada malla distinta se lista una vez,
ordenada por número de colocaciones, con una marca `[skin]` (skinning/animación) o `[+col]`.

## 🖥️ Flujo de la pantalla

**Categoría → Modelo → Parte**, con **selección secuencial** (2026-06-16; el desplegable
**Prefix** fue eliminado en 2026-06-30 — al elegir la Categoría, el combo Model ya
lista **todos** los modelos de la categoría, sin filtro intermedio):
cada desplegable debajo de Category se queda **desactivado** hasta que el de arriba tiene una
elección real. Todo desplegable empieza con el placeholder **"Select..."** (elemento 0,
default — ver [[🔽 dropdowns (ES)|dropdowns]]); seleccionarlo recarga/desbloquea los
dependientes también en "Select..." y limpia el preview. El desplegable "Part" lista
`Select...`, luego `Whole model`, luego las mallas **distintas** (dedup por
recurso `Mesh` vía `get_instance_id`), etiqueta `Name (×N) [+col]/[skin]` ordenada por
uso. El preview muestra la parte seleccionada, centrada/escalada (`_fit_to_view`). Los
desplegables son `OptionButton`s nativos (no listas de botones).

Los combos **"Animation"** (`AnimationRow`) y **"Special Effects"** (`EffectsRow`, debajo de
Animation) solo aparecen cuando la Parte es **"Whole model"**:
`_populate_animations()`/`_populate_effects()` muestran las filas y
`_reset_animations()`/`_reset_effects()` las ocultan (placeholder y partes aisladas). Ambos solo
aplican al modelo ensamblado.

- **Special Effects (2026-06-18):** tras "Select...", lista la opción **"All"** (muestra
  todos los efectos) y muestra **efectos de todos los tipos** que existan — luces/luminosidad
  (y sombras), humo/partículas, decals, niebla (`FogVolume`), atractores/colisionadores de partículas
  y mallas unidas a huesos (muzzle/laser). Recolectados por `_collect_effect_nodes` vía la
  lista `_EFFECT_CLASSES` (`node.is_class(...)`, captura subclases). "All" solo se incluye **cuando hay**
  efectos; sin efectos, el combo se queda solo con el placeholder y desactivado.

> [!note] StatusLabel eliminado (2026-06-18)
> La línea de estado (la label roja que guiaba "Select a/an …" encima de los combos) fue
> **eliminada** de la pantalla — el nodo `StatusLabel` salió de la escena y todo el código de estado
> (`_set_status`/`_apply_status`/`_clear_status`/`_update_whole_model_status`/
> `_refresh_whole_model_status`, vars `_status_*` y onready huérfanos `selectors_box`/`*_row`) y las
> claves de mensaje en los JSON fueron borradas. La navegación se guía solo por el gating secuencial
> de los desplegables.

**Cascada de reset (2026-06-16):** cambiar cualquier selector reinicia **todos** los de
abajo a "Select..." y reactiva solo el hijo inmediato. Las funciones de reset
(`_reset_meshes_and_preview`, `_on_model_selected`) ahora también llaman a
`_reset_animations()`+`_reset_effects()`, para que los dos combos de abajo se unan a la
cascada (antes se quedaban "atascados" visibles al cambiar un selector de arriba).

> [!info] Sin línea de estado (2026-06-18)
> La pantalla **ya no tiene** el `StatusLabel` que mostraba prompts "Select a/an …" (categoría/
> prefix/modelo/parte/animación/efecto) ni el antiguo conteo de partes. La guía viene solo
> del gating secuencial de los desplegables (cada combo desactivado hasta que el de arriba tiene una elección real).

### 🔄 Rotación del preview

`_yaw`/`_pitch` separados → `model_holder.rotation = Vector3(_pitch, _front_yaw_base + _yaw, 0)`
(roll siempre 0, solo ejes ortogonales). `_front_yaw_base` es la **orientación frontal BASE del modelo**
antes del drag (default `DEFAULT_FRONT_YAW = PI`, el giro de 180° de la convención de frente=-Z). **Por
modelo (2026-06-21):** `_MODEL_FRONT_YAW` sobrescribe esta base — `player` y `red_robot` fueron
exportados con el **frente hacia +Z** (misma dirección que la cámara), así que el giro de 180° los mostraba desde
**atrás**; con `0.0` **se abren mirando al frente**, sin que el usuario necesite rotar. Fijado en
`_on_model_selected` (y reiniciado en `_reset_meshes_and_preview`). Al arrastrar, **ambos** ejes
llegan hasta **±180°** (2026-06-16): `_yaw` (izquierda/derecha) rota el modelo hacia su espalda y
`_pitch` (arriba/abajo) inclina el modelo boca abajo. El modelo se **nivela** antes de
la rotación: `_preview_whole_model()` pone a cero la rotación integrada de la raíz del `.glb`
(ignorando inclinaciones angulares). Arrastrar con el botón izquierdo sobre el área 3D
mueve yaw/pitch; el toggle **Rotate** activa/desactiva la rotación automática (solo yaw, sin
bloqueo — gira como un tocadiscos). La raíz `UI` tiene `mouse_filter = 2` para que el drag llegue a
`_unhandled_input`.

**Limpieza de "cruft" del preview (2026-07-03, `_strip_preview_cruft`):** algunas escenas de gameplay
llevan nodos que no pertenecen a un preview estático — `player.tscn`, por ejemplo,
embebe un rig de cámara (`CameraBase/.../Camera3D`) y una UI de juego (`Crosshair` `TextureRect`
+ un `ColorRect` de fade **anclado** a pantalla completa). Dado que los contenedores `UI` son
`mouse_filter = 2` (ignore), el drag sobre el área 3D **caía sobre ese `ColorRect`** (default
`STOP`) en lugar de llegar a `_unhandled_input` — resultado: **solo el player "no rotaba"** (los
otros modelos no tienen Control embebido). Además de eso, el `Camera3D` embebido robaba el `current`
y disparaba avisos de *Physics interpolation* cada fotograma. Solución: justo después de `_strip_scripts`,
`_preview_whole_model()` llama a `_strip_preview_cruft(instance)`, que **libera todo `Camera3D`,
`Control` y `CanvasLayer`** en el subárbol instanciado **antes** de que entre en el árbol. Una solución general
(aplica a cualquier modelo que traiga estos nodos), mantiene el preview 100% estático y pone a cero los avisos.

### 🎚️ Toggles (preferencia + persistencia)

> [!note] Nodos de toggle sin el sufijo "Toggle" (2026-06-28)
> Los nodos `CheckButton` de los toggles tuvieron el **sufijo "Toggle" eliminado del nombre** (una petición para limpiar los
> tooltips de Debug 2D): `Rotate`, `Animation`, `Effects`, `Audio`, `Colliders`, `Labels`, `SubCollider`,
> `SubMemberLabel`, `AuxHighlight` (antes `…Toggle`). Los `%`-accesores en `models.gd` siguen la pauta; las
> **variables** GDScript (`rotate_toggle`, `colliders_toggle`, …) y los métodos `_show_*` **no** cambiaron.
> **Sufijo "Check" también eliminado (2026-06-28):** los `CheckButton` cuyo nombre terminaba en "Check"
> perdieron el sufijo: `Malha`, `Osso`, `SkeletonLines`, `Type`, `Name`, `Id` (antes `…Check`). Los
> `%`-accesores en `models.gd` siguen la pauta; las variables (`malha_check`, `osso_check`, `type_check`…) y
> los métodos `_show_*` **no** cambiaron.

> [!important] Nombres de nodo → inglés descriptivo (2026-06-29)
> Renombrado de los **controles** de la pantalla Models (solo nombres de nodo; **textos mostrados y persistencia
> sin cambios**):
> - **Desplegables:** prefijo `cbo` eliminado — `cboCategory→Category`, ~~`cboPrefix→Prefix`~~
>   (el desplegable **Prefix** fue **eliminado** en 2026-06-30),
>   `cboModels→Models`, `cboMeshes→Meshes`, `cboAnimations→Animations`,
>   **`cboEffects→EffectsList`** (no pudo pasar a `Effects`: ese ya es el nodo `CheckButton` de efectos),
>   `cboMembers→Members`, `cboMemberGeo→MemberGeo`, `cboSubMembers→SubMembers`,
>   `cboSubMemberGeo→SubMemberGeo`, `cboSkeleton→Skeleton`, `cboSkeletonGeo→SkeletonGeo`.
> - **Toggles (`CheckButton`):** `Malha→Mesh`, `Colliders→MemberLimbCollider`, `Labels→MemberLabel`,
>   `SubCollider→SubMemberLimbCollider`, `AuxHighlight→SkeletonLimbCollider`, `Osso→SkeletonLabel`.
> - **Gizmo de ejes:** `AxisGizmoOverlay→AxisGizmo` (el `SubViewportContainer`).
> - **Botones/paneles de Damage e IA (sin el sufijo de tipo):** `DamageButton→Damage`, `AIButton→AI`,
>   `DamagePanel→Damage` (ventana), `CloseButton→Close`, `AICloseButton→AIClose`, `DamageTree→Limbs`.
>   **Colisión de nombres:** el botón **y** la ventana pasan a "Damage" (padres diferentes, OK como nodo), pero el
>   único `%Damage` va a la **ventana**; el **botón** se resuelve por ruta (`$UI/Actions/Damage`,
>   sin `unique_name`). `AIPanel` se dejó como estaba (no solicitado), así que `%AI` (botón) no colisiona.
> - **Footer del panel Damage rediseñado:** la sección "Add sub-member" pasó a ser un **`GridContainer` de 3 columnas**
>   (hueso · owner · botón) para que las cabeceras se alineen al MISMO ancho que los desplegables
>   de abajo. El **tooltip** del desplegable owner ("Owner member…") dejó de ser tooltip y pasó a ser una
>   **label `OwnerHint` visible a todo el ancho** encima de la sección (una nueva clave en `models.{pt,en}.json`).
>   Los controles creados en código ahora tienen un nombre (antes `@label@…`/`@optionbutton@…`): `Separator`,
>   `OwnerHint`, `AddArea` (grid), `AddTitle`/`OwnerTitle`/`Pad`, `Bone`/`Owner`/`Add`; y los elementos de la
>   lista de IA: `<key>`/`Content`/`Enabled`/`Description`.
> - **AIPanel — tooltips eliminados:** cada checkbutton de comportamiento ya muestra la descripción como una
>   **label justo debajo** de él, así que el `tooltip_text` (que duplicaba la descripción) salió del toggle **y**
>   de la `Description` — la regla "texto solo en la label de abajo, sin tooltip duplicado".
> - **Label del desplegable Mesh:** texto **"Part:" → "Mesh:"** (`Mesh:` en en; clave en
>   `models.{pt,en}.json` migrada de `Parte:` a `Malha:`).
> - **VBox `Selectors`:** perdió el `size_flags_horizontal = 3` (ya no estira toda la fila) y
>   ganó un hermano **`Spacer`** (expand-fill) antes de `Toggles`, encogiendo la columna a ~la mitad y
>   manteniendo los toggles fijos a la derecha.
>
> Los `%`-accesores en `models.gd` siguen la pauta; las **variables** GDScript (`cbo_*`, `*_check`,
> `*_toggle`) y los métodos `_show_*` **no** cambiaron.

Toggles actuales (orden/nombres en 2026-06-23): **Mesh · Rotate · Animation · Special effects · Audio ·
Member Collider · Member · Sub-member Collider · Sub-members · Skeleton Collider ·
[Skeleton · Skeleton Lines · Type · Name · ID]**. (Renombrados de "Colliders
of X" → **"Collider of X"**; `SubCollider`/`SubMemberLabel` movidos arriba, justo
**debajo de "Member"**; **"Mesh" promovido al 1.º de la lista** y **"Damage" ya no es un toggle** —
pasó a ser el **botón `DamageButton`** a la derecha de "Back", ver abajo.)

> [!note] Labels Type/Name/Id en el Skeleton y el Submiembro + exclusividad (2026-06-23)
> - **Type/Name/Id** (colores rosa/verde/amarillo de `_LABEL_LINE_COLORS`) ahora también aparecen sobre las
>   labels del **Skeleton** (`_label_aux_bones`) y del **Submiembro** (`_label_sub_member`), vía
>   `_add_tni_lines` — describiendo el ELEMENTO (clase del nodo · nombre del hueso/submiembro · id del nodo). Los
>   handlers de Type/Name/Id refrescan miembro+submiembro (`_refresh_member_overlays`) y esqueleto
>   (`_refresh_aux_labels`).
> - **Bug corregido:** la pila "Member:" ya no aparece sobre **submiembros** — `_add_member_labels`
>   salta los cuerpos `PART_*` (un elemento es un Miembro O un Submiembro, nunca ambos).
> - **Exclusividad:** `_aux_bone_candidates` ya solo ofrece huesos no-miembro (`group_of==""`) para
>   promover; `_on_sub_member_added` aún bloquea + avisa si un hueso de Miembro llega ahí.

> [!note] Prefijos de labels 3D LOCALIZADOS (2026-06-25)
> Los prefijos de `Label3D` — **"Member:" / "Sub-member:" / "Skeleton:" / "Type:" / "Name:"** (e "ID:") —
> pasan por `Locale.tr_key(...)` en la construcción (`_add_member_labels`, `_label_aux_bones`,
> `_label_sub_member`, `_add_tni_lines`), para que aparezcan traducidos en AMBOS idiomas (antes "Member/
> Skeleton/Sub-member" se quedaban en PT en el EN, y "TYPE/Name" en EN en el PT; "Submembro:" pasó a "Sub-membro:").
> Dado que `Label3D` NO pasa por el auto-traductor de Locale, `_on_language_changed` ahora llama a
> `_refresh_member_overlays()` + `_refresh_aux_labels()` para reconstruir las pilas en el nuevo idioma.
> Nuevas claves en `models.{pt,en}.json`: `Tipo:`/`Nome:` (prefijos) + los toggles `Type`/`Name`/`Skeleton Lines`.

> [!note] Esquema de color miembro × submiembro + corrección de label de submiembro (2026-07-03)
> **Colores** (el texto de cada toggle coincide con el elemento 3D que controla — constantes al principio de
> `models.gd`):
> - **Member** → colisionadores **AZUL CLARO** casi transparente (`_MEMBER_COLLIDER_FILL`, gizmo) y el
>   texto del toggle *Member Collider* (`_MEMBER_COLLIDER_COLOR`); **labels AZUL OSCURO** (`_LABEL_LINE_COLORS["Member"]`,
>   también en el toggle *Member*).
> - **Sub-member** → colisionadores **MORADO CLARO** casi transparente (`_SUB_COLLIDER_FILL`) y el texto del toggle
>   *Sub-member Collider* (`_SUB_COLLIDER_COLOR`); **labels MORADO OSCURO** (`_SUB_LBL_COLOR`, también en el toggle *Sub-members*).
> - **Skeleton (hueso independiente)** → resalte/caja **NARANJA CLARO** casi transparente (`_AUX_HL_COLOR`) y el texto
>   del toggle *Skeleton Collider* (`_AUX_HL_TEXT_COLOR`); **labels "Skeleton: …" NARANJA OSCURO**
>   (`_AUX_LBL_COLOR`, también en el toggle *Skeleton*). (2026-07-03)
> - `_add_collider_gizmos` elige el material por grupo (`PART_*` → morado; de lo contrario azul), vía el helper
>   `_make_gizmo_material(fill)`. `_apply_label_line_colors` (reescrito en un único dict/loop) pinta los 9
>   toggles con color: member/sub/skeleton (label oscura × colisionador claro) + Type/Name/ID. El antiguo verde único
>   de los colisionadores (`0.2,1.0,0.4`) y el naranja único del esqueleto (`1.0,0.6,0.1`) fueron reemplazados;
>   la clave `"Osso"` de `_LABEL_LINE_COLORS` salió (el toggle ahora usa `_AUX_LBL_COLOR`).
>
> **Tamaño de label:** miembro y submiembro comparten `_LBL_FONT_SIZE`/`_LBL_PIXEL_SIZE` (mismo
> tamaño de texto — confirmado en el .exe: "Member:" y "Sub-member:" salen idénticos).
>
> **Bug corregido:** al encender el toggle **Sub-members** (label) en el modo **"All members" → "All
> Sub-members"**, NINGUNA label aparecía — `_refresh_sub_member_labels` solo manejaba un `PART_` individual
> (el valor `ALL_SUB_MEMBERS_VALUE` no empieza por `PART_` → early return). Ahora, en este modo, etiqueta
> TODOS los submiembros (espejando el toggle de colisionador), asegura los cuerpos con `_ensure_member_colliders`
> y el clear se movió de `_label_sub_member` (llamado en bucle) al llamador (una sola vez).

> [!note] Labels encerradas por el desplegable en "Select..." (2026-07-04)
> Cada familia de labels 3D solo se muestra cuando SU desplegable tiene una elección real (≠ "Select..."), uniformemente:
> - **Sub-member** (`_refresh_sub_member_labels`) y **Skeleton** (`_refresh_aux_labels`) ya hacían
>   esto (early return con `cbo_sub_members.selected <= 0` / `cbo_skeleton.selected <= 0`).
> - **Member** era la excepción: con el desplegable Member en "Select..." la pila "Member:" se mostraba en
>   TODOS los miembros. Ahora `_apply_member_labels_visibility` aplica el mismo gate — `if member_row.visible and
>   cbo_members.selected <= 0: return` (limpia las pilas y no reconstruye). "All members" (índice 1)
>   y un miembro específico (índice 2+) siguen mostrándose; solo el placeholder oculta. Dado que las líneas Type/Name/ID
>   viven en la MISMA pila anclada al cuerpo del miembro, también desaparecen sin miembro seleccionado.

> [!note] "Mesh" y "Skeleton Lines" (de la antigua pantalla developer, 2026-06-23)
> - **Mesh** (`Malha`, **1.º toggle de la lista** desde 2026-06-23, clave `show_malha`, default ON):
>   muestra/oculta la malla del modelo (`MeshInstance3D`) en el preview (salta gizmos con un nombre `_…`). `_apply_malha_visibility`.
> - **Skeleton Lines** (`SkeletonLines`, debajo de Id, clave `show_skeleton_lines`): dibuja
>   las líneas blancas hueso→padre del preview, rehechas cada fotograma desde la pose viva (`_refresh_skeleton_lines`
>   / `_update_skeleton_lines`, gizmo `_SkeletonLines`). Es DIFERENTE de "Skeleton" (que muestra el NOMBRE
>   del hueso). Efecto **solo en esta escena** (el preview). Ambos persisten en la sección de config `models`.

> [!note] Renombrados y nuevos toggles (2.º lote, 2026-06-22)
> - **Colliders** → **Member Colliders** (`Colliders`, `_show_colliders`).
> - **Skeleton** (el resalte naranja, `AuxHighlight`/`_show_aux_highlight`) → **Skeleton Colliders**.
> - **SubMember** (`Osso`/`osso_check`/`_show_osso`, arriba de `LabelLinesRow`) → **Skeleton**; la
>   Label3D ahora muestra **"Skeleton: \<name\>"** (antes solo el nombre del hueso).
> - **NUEVO Sub-member Colliders** (`SubCollider`/`_show_sub_colliders`, clave `show_sub_colliders`;
>   label mostrada **"Sub-member collider"** desde 2026-06-25):
>   muestra/oculta SOLO el gizmo de limbcollider del submiembro seleccionado en el desplegable (rama FOCUS de
>   `_refresh_member_overlays`; un gizmo PART_* sigue ESTE toggle, un gizmo de miembro sigue "Member
>   Colliders"). Los submiembros se quedan OCULTOS en la vista general (`_apply_colliders_visibility` oculta PART_*),
>   **con una excepción (2026-06-25):** con **"All members" + "All Sub-members"** en los desplegables y
>   este toggle ON, `_apply_colliders_visibility` muestra **TODOS** los gizmos de submiembro a la vez,
>   independientemente de "Member Colliders" (helper `_should_show_all_sub_colliders`).
>   El editor de offset/scale también aparece para submiembros bajo este toggle.
> - **NUEVO Sub-members** (`SubMemberLabel`/`_show_sub_member_label`, clave `show_sub_member_label`;
>   label mostrada **"Sub-member"** desde 2026-06-25):
>   Label3D **"Sub-member: \<name\>"** unida al cuerpo del submiembro seleccionado
>   (`_refresh_sub_member_labels`/`_label_sub_member`). Solo en modo específico de miembro. **Color MORADO
>   (2026-06-23):** `_SUB_LBL_COLOR = Color(0.6,0.25,0.9)`; el toggle "Sub-members" tiene **texto morado**
>   (`font_color` vía `_apply_label_line_colors`, fondo normal — sin `modulate`).

Historial (1.º lote, 2026-06-22): "Per-member damage" pasó a ser **Damage**; "Highlight standalone" pasó a ser "Skeleton";
el toggle "Bone" pasó a ser "SubMember" y se movió arriba de `LabelLinesRow` (el toggle "Labels" fue renombrado a
**Member** en 2026-06-21 — `Labels` en el `.tscn`, traducido "Member" en en; el antiguo "Sound" pasó a ser **Audio**; el
toggle **Voices** fue ELIMINADO — Audio ahora cubre todos los emisores, incluidas las voces). Cada
toggle es el **interruptor maestro** de su categoría:

> [!note] Colores de labels 3D (`_LABEL_LINE_COLORS`)
> Member = cian · **Type = ROSA (2026-06-23, antes naranja)** · Name = verde · Id = amarillo ·
> Bone/Skeleton = naranja. El toggle **Type** (`Type`) tiene **texto rosa** vía `font_color`
> (`_apply_label_line_colors`, todos los estados); el `modulate` fue **ELIMINADO (2026-06-25)** para que el
> **fondo del toggle coincida con los demás** (antes el `modulate` teñía todo el control de rosa) —
> mismo patrón que el toggle "Sub-members".
> El `DebugOverlay` de la pantalla developer reutiliza los mismos colores (Type/Name/Id/Member) + Skeleton blanco.

> [!important] Escena Models 100% desacoplada del Debug 3D (2026-06-21)
> El nodo raíz de la escena está en el grupo **`no_debug_overlay`**, así que el `DebugOverlay` global salta la
> escena Models entera (2D **y** 3D) — las definiciones de Debug solo aplican en los **niveles del juego**. Las
> labels de miembro del preview (TYPE/Name/ID/Member) ahora siguen **los toggles dedicados propios de la escena**
> (Member + las checkboxes Type/Name/ID), ya no los sub-toggles globales. Desaparecieron los
> `_debug3d_tooltips_enabled()` y toda lectura de `game/*` en `models.gd`.
>
> **Label del nombre de escena (2026-06-20 → OCULTA 2026-06-21):** el `SceneName` local (nodo en el
> `.tscn`) ahora está **siempre oculto** — el nombre "Models" **no debe aparecer en la ventana de daño**. El
> nodo se preserva solo para no romper `@onready`/referencias; `_ready` hace `visible = false` y nada
> más lo muestra. El nombre de escena ya lo muestra la **marca de agua GLOBAL** de `debug_overlay.gd` en la
> **esquina superior derecha, junto al título** (que tiene un tooltip de Debug 2D). Ver [[🐞 debug-overlay (ES)|debug-overlay]].

> [!important] Los toggles actúan **in-place** (2026-06-17)
> Ningún toggle **reconstruye** el preview: el modelo **no se recarga** y la
> **cámara/rotación quedan intactas**. Cada handler altera el nodo vivo
> (`_preview_instance`) a través de un aplicador dedicado en lugar de llamar a una reconstrucción.

- **Animation** — una animación solo corre cuando se dan **ambas**: el toggle está encendido **Y** un clip
  está elegido en el desplegable "Animation" (2026-06-18). Con el toggle apagado **nada se anima**
  (`_on_animation_selected` retorna temprano); con el toggle encendido pero el combo en "Select..."
  **tampoco corre nada** — **ya no hay auto-play de un clip default/idle**. La reproducción se aplica
  **in-place** por `_apply_animation_state()` (`should_play = _play_animation and chosen != ""`;
  reproduce el clip elegido en quien lo tenga, para todos los demás `_preview_anim_players`).
  **Vuelta a "Select..." (2026-06-23):** cuando nada debe reproducirse, más allá de `stop()` (que solo
  CONGELA la pose actual), el esqueleto se reinicia a la **pose REST = estado inicial del modelo**
  (cada hueso → `get_bone_rest`, vía `set_bone_pose_*`; los modelos no tienen clip "RESET").
  **Loop (2026-06-23):** el clip elegido se queda en **loop** — cuando termina, `_on_preview_anim_finished`
  (señal `animation_finished`) lo re-reproduce. Notablemente, NO toca el `loop_mode` del recurso
  (compartido con el juego). Los clips de muerte/explosión no hacen loop.
- **Audio** — reproduce **todos** los emisores del modelo (walk/run/jump de movimiento,
  motor, disparo, explosión, voces…); apagado, los silencia. Aplicado por `_apply_audio_state()`.
  (Ya no hay un toggle "Voices" separado.)
- **Colliders** — `_apply_colliders_visibility()` añade/quita los gizmos wireframe
  (`_add_collider_gizmos`, idempotente, nodo `_ColliderGizmo`) **sin reconstrucción**; construye los
  colisionadores de miembro bajo demanda una vez (`_ensure_member_colliders`). Para **Characters/
  Weapons** dibuja un gizmo **solo para los colisionadores de MIEMBRO** (`_is_member_collider`, meta
  `member_label`); salta el colisionador de cuerpo genérico del modelo (p. ej.: la cápsula de cuerpo del red_robot)
  y las áreas de detección/muerte, que eran solo ruido rodeando todo (2026-06-18).
  - **Refit en tiempo real durante la animación (2026-06-23):** los colisionadores están unidos a los huesos
    (`BoneAttachment3D`), así que ya siguen **traslación/rotación**. Mientras una animación corre **y** los
    colisionadores están visibles, `_process` llama a `_member_lc.refit(_member_skel)` (`limb_colliders.gd`):
    recalcula el AABB de cada miembro/submiembro en la **pose ACTUAL** de los huesos y reajusta la forma +
    gizmo — para que los colisionadores **sigan la flexión** de los miembros multi-hueso. Solo en el preview (rigs sin
    esqueleto ya siguen el nodo animado).
    - **Rendimiento (2026-06-23):** el refit tardaba ~150 ms/llamada porque `surface_get_arrays`
      reconstruía los arrays de malla cada fotograma. Ahora hay una **caché** (`_build_refit_cache`): por
      vértice almacena grupo + hueso dominante + `bind_pose·vertex`; el refit solo lee las poses ACTUALES de los
      huesos → **~4 ms** (33× más rápido). La caché se construye **al construir los colisionadores**
      (`_add_member_colliders`), sacando el coste único (~150 ms) FUERA de la animación. Además de eso,
      un **throttle adaptativo** en
      `_process` (intervalo = `elapsed·30`, tope 10 Hz / suelo 2 Hz) mantiene el coste en ~3% → **≥ 60 FPS**,
      con modelos más densos reajustándose menos veces. (La 1.ª llamada aún construye la caché ~150 ms una vez.)
  - **Geometría de colisionador + ventana Offset/Scale por miembro/submiembro/hueso-independiente (2026-06-25,
    reemplaza el editor inline):** al elegir un elemento **real** (no "Select..."/"All") en **Member**,
    **Sub-member** o **Skeleton**, aparece un **desplegable de geometría** **a la derecha** de ese desplegable
    (`cboMemberGeo`/`cboSubMemberGeo`/`cboSkeletonGeo`; elementos "Select..." + Sphere/Box/Capsule con
    metadata `""`/`sphere`/`box`/`capsule`) **y** se abre la **ventana flotante REUTILIZABLE**
    ([[📌 ancoragem-ui (ES)|FloatingWindow]] de controls2D) — `_open_or_update_collider_dialog`,
    unida al `UI`, `modal=false` (puedes rotar el modelo), posición recordada en
    `windows/models_collider_dialog` — con **Offset**, **Rotation** (grados) y **Scale** X/Y/Z, **titulada
    con el nombre del elemento**. Cada cambio **persiste al instante** (`LimbConfig.set_collider_offset`/`set_collider_rotation`/
    `set_collider_scale`, **sin botón Save**) y aplica **EN VIVO** (`_apply_collider_xform`: offset →
    `body.position`; rotación → `body.rotation_degrees`; scale → el `scale` de la forma). El **desplegable de geometría** escribe `LimbConfig.set_collider_shape` y
    **reconstruye** los colisionadores (`_rebuild_member_colliders`): en un **MIEMBRO**, "Select..." = `SHAPE_NONE`
    → **elimina el colisionador** (miembro sin hitbox); en un **SUB-MIEMBRO**, "Select..." = `SHAPE_NONE` **SUPRIME el
    colisionador** pero **mantiene el submiembro** en el árbol/desplegable (cuerpo del preview suprimido — ver `include_suppressed`
    abajo) para reconfigurar; la eliminación total es vía el icono de papelera del árbol Damage. Para un **HUESO INDEPENDIENTE** (Skeleton),
    elegir una geometría **NO lo promueve** (2026-06-25): solo persiste la forma del preview (`set_collider_shape`) y el
    resalte **"Skeleton Collider"** empieza a dibujarse en esa geometría (ver abajo) — la promoción (crear realmente el
    colisionador) sigue ocurriendo en la ventana Damage ("Add sub-member"). Los esqueletos **no tienen daño y no entran en los niveles**
    (solo preview). **Preselección de los 3 desplegables (3 estados, 2026-06-25, `_select_geo_for_group`):** forma guardada
    (sphere/box/capsule) → **CARGA** la última elección; `SHAPE_NONE` → **"Select..."** (sin colisionador, explícito);
    **sin elección ("") → AUTO-DETECTA** — la forma EN VIVO del colisionador (`_live_shape_kind`, miembro/sub tienen un cuerpo) o por la
    **forma del hueso** (`_auto_geo_for_box`/`_auto_geo_for_group` vía AABB: alargado→cápsula, redondo→esfera, de lo contrario box).
    **El submiembro suprimido se queda VISIBLE (`include_suppressed`, 2026-06-25):** el preview fija `lc.include_suppressed
    = true`; en `build_for`, un submiembro `SHAPE_NONE` aún se construye (forma automática, meta `suppressed`,
    **sin gizmo** — `_add_collider_gizmos` lo salta) para quedarse en el árbol/desplegable; en el juego (flag false) se SALTA.
    Todo se **relee en el spawn** vía `LimbColliders` (`make_member_shape` honra el override;
    `build_for`/`_add_mesh_member_colliders` saltan los grupos `SHAPE_NONE`). **Visibilidad de geo (2026-06-25):**
    la geo de **Member** desaparece cuando se elige un **submiembro específico** (`PART_*`, ≠ "Select..."/"All Sub-members")
    — entonces aplica la geo del submiembro (misma precedencia que la ventana Offset/Scale). Lógica en
    `_refresh_collider_editors` / `_on_*_geo_selected` / `_sync_collider_dialog` / `_current_edit_target`.
    El antiguo `ColliderEditBox` inline + botón **Save** + `_prompt_save_offset_if_dirty` fueron **ELIMINADOS**.
    Ver [[🩸 dano-localizado (ES)|dano-localizado]].
- **Special effects** — muestra/oculta **todo lo que sobra** unido al modelo que
  ningún otro toggle cubre: partículas, luces, decals/niebla y mallas unidas a huesos (muzzle/
  laser), recolectados por `_collect_effect_nodes` (lista `_EFFECT_CLASSES`). El combo **"Special
  Effects"** aísla **un** efecto (muestra solo ese); **"Select..."** y **"All"** (elemento 1,
  2026-06-18) muestran **todos** (solo con el toggle encendido). La visibilidad la aplica
  `_apply_effects_visibility` (`sel <= 1` = todos; `>1` = aislado) sin reconstruir el preview.
- **Member · Type · Name · ID** (2026-06-21; el toggle **Member** se llamaba "Labels" hasta
  2026-06-21 — solo cambió el TEXTO, el nodo sigue siendo `Labels`/`labels_toggle`) — la pila de tooltips de miembro
  (TYPE/Name/ID/Member) ahora es **enteramente local** a la escena Models, sin nada del Debug 3D global.
  **Member** (CheckButton) enciende
  la línea "Member: …"; **Type/Name/ID** son 3 `CheckButton`s (toggles) **apilados verticalmente** en el
  nodo `LabelLinesRow` (un `VBoxContainer` desde 2026-06-21 — antes eran `CheckBox`es en una fila horizontal
  que **cortaba las labels** en la columna estrecha; la pila vertical asegura que los 3 textos aparezcan
  completos) que encienden las líneas describiendo el `Skeleton3D`. Los tooltips de miembro se dibujan con
  un `render_priority` alto (siempre encima de los gizmos verdes y entre sí).
  `_apply_member_labels_visibility` **recrea la pila in-place**
  (limpia los pivots `_MdlLbl_Pivot` y los re-añade con la visibilidad por línea de
  `_add_member_labels`), sin reconstruir el modelo. `_any_member_label()` (cualquiera de los 4 encendido) decide
  si construir colisionadores/labels. Persistido en `[models]` (`show_member_labels`/`show_type`/`show_name`/
  `show_id`). Diseñado para **inspeccionar qué miembros** reconoce el clasificador (y para solicitar un nuevo miembro).
  - **Color por línea = color del toggle (2026-06-20):** cada línea tiene su **propio color** (Member = cian-azul,
    Type = naranja, Name = verde, ID = amarillo, Bone = naranja — `const _LABEL_LINE_COLORS`) aplicado al
    `modulate` del `Label3D` **y** al texto del `CheckButton` que lo controla (`_apply_label_line_colors`,
    cubriendo los estados normal/hover/pressed/focus), para que el usuario pueda vincular el control con su label 3D de un vistazo.
  - **Toggle "Skeleton" (label de hueso independiente; renombrado de "SubMember"/"Bone" en 2026-06-22):** 1.º `CheckButton` del `LabelLinesRow`
    (`Osso`/`osso_check` — nombre de nodo/var mantenido; **ARRIBA**, justo debajo del toggle "Member" y encima de Type;
    traducido "Skeleton" en en — reutiliza la clave `Esqueleto`). Cuando está encendido **Y** el filtro "Skeleton"
    (en modo "All members") tiene un hueso elegido, dibuja un **`Label3D` naranja**
    (billboard, sin depth-test) con **"Skeleton: \<name\>"** encima de su región, unida vía `BoneAttachment3D`.
    **Independiente** de "Skeleton Colliders" (antes "Highlight standalone"; puedes ver solo el nombre, solo la caja, o ambos) — sigue la MISMA
    selección. `_refresh_aux_labels` (llamado en los handlers de miembro/submiembro, en `_populate_members` y
    `_rebuild_member_colliders`) decide; `_label_aux_bones` dibuja (nodos `_AuxLbl_*`); `_clear_aux_labels`
    elimina. Persistido en `[models]` (`show_osso`). "All Skeletons" los etiqueta todos a la vez.
  - **Anti-colisión entre miembros (2026-06-20):** las 4 líneas de cada miembro se sientan bajo un **pivot**
    (`_MdlLbl_Pivot`, hijo del colisionador) para que se muevan juntas. Cada fotograma `_layout_member_labels`
    proyecta la pila de cada miembro en un rectángulo de pantalla y, procesando de arriba a abajo, **empuja
    hacia abajo** cualquiera que se solape con una pila ya posicionada — para que conjuntos de miembros distintos
    nunca se sobrescriban entre sí (cada conjunto se queda entero, "uno debajo del otro"). El empuje se convierte
    de píxeles a metros (el factor px/m de la cámara a la profundidad del ancla, robusto al
    zoom/escala del fit-to-view) y se aplica moviendo el pivot en espacio de mundo (abajo = `-camera.up`). Indexado en
    `_member_label_pivots`; sin pilas, es un no-op.
- **Damage** — abierto por el **botón `DamageButton`** (a la derecha de "Back", en `UI/Actions`; texto "Dano"/"Damage").
  Antes era el toggle `DamageToggle` de la lista; en 2026-06-23 pasó a ser un **botón de acción dedicado** que invoca la
  pantalla Damage (`_on_damage_button_pressed` → `_show_damage_panel = true` → `_refresh_damage_panel`); el `×` de la ventana la cierra
  (`_on_damage_close`). (La ventana fue renombrada de "Per-member damage" en 2026-06-22; el `Title` muestra "Damage".)
  — **VENTANA FLOTANTE (estado en 2026-06-21):** el `DamagePanel` es una **ventana flotante
  arrastrable**, con un **fondo NEGRO OPACO**, **600×660**, con **todos los controles DENTRO de ella**
  (los campos de valor YA NO flotan sobre el modelo 3D — revertido en 2026-06-21).
  - **Ventana (estilo Windows):** estructura `DamagePanel(PanelContainer, ancla arriba-izquierda) →
    Main(VBox) → TitleBar(PanelContainer) → TitleRow[Title(IGNORE) + CloseButton ×] · Margin →
    Scroll → VBox → Rows`. `_setup_damage_window` (en `_ready`) da al `DamagePanel` un
    `StyleBoxFlat` **negro opaco** (alfa 1) y estiliza la `TitleBar` (gris oscuro opaco), fija `CURSOR_MOVE`
    y conecta `gui_input`→`_on_damage_titlebar_input` (click-drag mueve `damage_panel.position`, encerrado al
    viewport; una red de seguridad en `_process` suelta el drag si el botón se suelta fuera de la barra) y
    el `×`→`_on_damage_close` (cierra la ventana: `_show_damage_panel = false` + `_refresh_damage_panel`). La **última posición se persiste**:
    `_save_damage_panel_pos` escribe `Settings.config_file("models","damage_panel_pos")` (un `Vector2`)
    cuando el drag termina, y `_setup_damage_window` la **restaura** al abrir (encerrada al viewport;
    default = la posición del `.tscn`).
  - **ÁRBOL (Tree) EN la ventana (2026-06-21):** `_refresh_damage_panel` construye un `Tree`
    (`DamageTree`, ensamblado por `_setup_damage_tree` en `_ready`): cada MIEMBRO es una rama; sus
    submiembros (PART_*) son hojas BAJO él, mostrados con el **nombre original del hueso** (p. ej.: "↳ shoulderpad-adjust.L" bajo "ARM L"); los huérfanos van a la
    rama "Other sub-members". **Columnas:** 0 Name · 1 **Def** (`CELL_MODE_CHECK`) · 2 **Bonus %**
    (`CELL_MODE_RANGE` −100..500, paso 5; editable solo con Def encendido) · 3 **Owner** (`CELL_MODE_RANGE`
    con texto separado por comas = desplegable, solo submiembros). Def apagado = **SIN valor propio** (muestra el
    EFECTIVO heredado vía `effective_multiplier`); encendido = explícito (`set_multiplier`). **Ningún valor es
    obligatorio.** `_on_damage_tree_edited` despacha por columna; `_restamp_damage_metas` re-estampa
    las metas y `_refresh_tree_inherited` re-muestra las heredadas (elementos en `_damage_field_anchors` =
    `{item,group,owner}`). Reasociar el **owner** (col 3) requiere **confirmación** (`_on_tree_owner_edited`)
    y reconstruye el árbol. **Footer** abajo: solo la línea "Add sub-member" (hueso independiente + owner
    explícito + Add → `_on_sub_member_added`). **La eliminación es por fila (2026-06-22):** cada hoja de submiembro
    tiene un **botón de PAPELERA a la derecha del nombre** (col 0; icono rojo generado en código
    por `_make_trash_icon` → `ImageTexture`; `TreeItem.add_button` con id `_TRASH_BTN_ID`), y
    `_on_damage_tree_button` (señal `Tree.button_clicked`) **pide confirmación** (`FloatingDialog.confirm`:
    "Do you really want to remove the association of the sub-member: &lt;name&gt; ?") y luego elimina ese submiembro
    (2026-06-22) — reemplazó al antiguo
    gran botón "Remove sub-member" del footer (y los `_on_damage_tree_selected`/`_damage_remove_btn`,
    eliminados). La asociación owner→hijo se guarda en `LimbConfig` y **se recarga en cada add/remove** (vía
    `_rebuild_member_colliders` → `_refresh_damage_panel`). **Espaciado de filas (2026-06-22):**
    `_setup_damage_tree` aplica overrides de tema (`v_separation`/`inner_item_margin_top`/`_bottom`) para que
    el icono de papelera no toque la fila vecina. Ver [[🩸 dano-localizado (ES)|dano-localizado]].
  - **Ventanas abiertas FUERA DE PANTALLA — corrección (2026-06-25):** los botones "no abrían" porque
    `DamagePanel`/`AIPanel` tenían offsets fijos en el `.tscn` (`offset_left` 1300/1220, para pantallas anchas)
    → en resoluciones menores (p. ej.: 1280×720) la ventana abría (`visible=true`) **fuera del viewport, a la
    derecha** (invisible); el clamp de `_setup_*_window` corría solo en `_ready` con `size=0`, fijando la
    posición al borde. **Solución:** `_clamp_window_to_viewport(panel)` llamado **deferred al abrir** (con el
    tamaño real ya) reposiciona la ventana para que quepa completa en pantalla. Paneles **agrandados a 760×620** (nuevos
    offsets) para que el contenido (árbol de 4 columnas / lista de IA) no quede apretado.
  - **Botones sin bloqueo mutuo + ámbito por modelo (2026-06-25):** `_has_active_model_window()` fue
    **eliminado** — ningún botón queda bloqueado por la ventana del otro. Abrir uno **cierra el otro**
    (solo UNA ventana flotante a la vez, un "switch"). **TOGGLE (2026-06-25):** hacer clic en el MISMO botón
    (Damage/AI) de nuevo con la ventana ya abierta la **cierra** (`_on_*_button_pressed` comprueba `panel.visible` y cierra).
    **Hacer scroll sobre la ventana Damage/AI NO hace zoom en el 3D (2026-06-25):** `_unhandled_input` ignora la
    rueda del ratón cuando `_pointer_over_model_window()` (puntero sobre el `damage_panel`/`ai_panel` visible) —
    la rueda solo hace scroll del contenido de la ventana; sobre el 3D, aún hace zoom. **El drag también se congela sobre
    la ventana (2026-06-25):** la rotación de mouse-drag también respeta `_pointer_over_model_window()`
    — la cámara deja de rotar en cuanto el puntero entra en la ventana y se reanuda al salir de ella o
    cerrarla; el helper empezó a incluir `FloatingWindow.pointer_over_any_window()` (cualquier ventana
    flotante, no solo Damage/AI). **Damage aplica a CUALQUIER modelo** en "Whole model"
    (`_supports_damage_editor` reemplazó `_preview_is_whole_character`: ya no requiere la
    categoría "characters" — weapons/rigs usan los colisionadores de miembro). **AI solo para characters** con
    comportamientos definidos (`_supports_ai_editor` = `AIConfigLib.has_behavior_definitions` — hoy
    `red_robot`, `player`, `criatura_alada`; el `ai_button` está `disabled` fuera de esto). El botón tiene
    **texto "Inteligência Artificial"/"Artificial Intelligence"** (PT canónico desde 2026-06-25 — antes
    el `.tscn` llevaba el nombre solo en inglés y `models.pt.json` lo mapeaba a sí mismo, sin traducir).
    **Corrección 2026-06-25:** `_refresh_ai_panel` abortaba en un override de tema inválido
    (`content.theme_override_constants.separation = 6`, un acceso por punto que no existe en GDScript),
    así que la ventana de IA NUNCA abría (un error en tiempo de ejecución antes de `ai_panel.visible = true`); reemplazado por
    `add_theme_constant_override("separation", 6)`. Ver `_on_damage_button_pressed`/`_on_ai_button_pressed`.
  - **El editor de IA pasó a ser un `FloatingWindow` (2026-06-30):** el panel de IA dejó de ser un `PanelContainer`
    del `.tscn` (con barra/×/drag/posición manuales) y pasó a ser un **`FloatingWindow` no-modal en tiempo de
    ejecución**, creado bajo demanda en `_ensure_ai_window` (`remember_position_key = "ai_window"`,
    `min_window_size = (420,480)`). El contenido (ScrollContainer + `ai_list`) lo repuebla
    `_populate_ai_list`; abrir = `_open_ai_window` (`popup_centered`), cerrar = `_close_ai_window`
    (×/ESC disparan `closed` → `_on_ai_window_closed` pone a cero las refs). Así la IA hereda el gap, el anillo de foco/ESC,
    la supresión del Debug 2D de fondo y el click-forward del toggle (ver [[🐞 debug-overlay (ES)|debug-overlay]]).
    Eliminados de `models.gd`: `ai_panel`/`ai_titlebar`/`ai_close_button`, `_setup_ai_window`,
    `_on_ai_titlebar_input`, `_save_ai_panel_pos`, `_on_ai_close` y el drag manual; el subárbol `UI/AIPanel`
    salió del `.tscn`. **Damage** aún usa su propio `PanelContainer` (atado al daño por miembro), con el gap
    aplicado por separado. `_pointer_over_model_window` ahora cubre la IA vía `pointer_over_any_window()`.
  - **Foco/Tab de la ventana Damage + foco inicial de la pantalla (2026-06-30):** `_ready` ahora enfoca el
    control Tab = 1 (`UINav.focus_tab_one` → 1.º por `tab_order` = Categories). La **ventana Damage** ganó
    un anillo de foco LOCAL (`UINav.wire_tab_ring(damage_panel, damage_close_button)` en `_refresh_damage_panel`,
    con el **× siempre último**): `Limbs` 1 → `Bone` 2 → `Owner` 3 → `Add` 4 → **× 5**; enfoca el
    árbol `Limbs` al abrir. `Bone`/`Owner`/`Add` (runtime) reciben `tab_order` vía `set_meta`; `Limbs` y `Close`
    tienen `tab_order` 1 y 5 en el `.tscn`.
  Aparece para **CUALQUIER modelo en "Whole model"**
  (`_supports_damage_editor`); `_refresh_damage_panel` lo repuebla al cambiar de modelo y lo oculta en una malla
  aislada. **No** se persiste (abre cerrado). La clave del modelo = el nombre de la carpeta
  (`_current_model_key`), igual que el `model_key` del gameplay. Los MIEMBROS listados vienen del plan
  corporal del modelo: dado que el preview elimina scripts (y no tiene el `@export body_type`), la pantalla
  espeja el tipo en la const `_MODEL_BODY_TYPE := {"red_robot":"biped","player":"biped"}` y resuelve el
  clasificador por `_body_type_for_current()`/`_current_classifier()` (`BodyPlans.for_type`).
  - **Miembros = TODOS los del plan (2026-06-21):** el panel Damage y el combo "Member" usan
    `_plan_member_entries()` — los CHARACTERS listan **todos** los miembros del plan (`classifier.members()`,
    incluso sin geometría en el preview), en el orden del plan y con sus labels (HEAD/TORSO/ARM L-R/
    LEG L-R); las WEAPONS siguen los colisionadores (WeaponParts).
  - **Submiembros anidados en el panel (2026-06-21):** cada `PART_*` aparece **indentado (↳, margen 24px
    ) bajo su miembro owner**, agrupado por el MISMO `_sub_member_owner_map` que los combos
    (helper `_sub_members_by_owner`) — panel y desplegable concuerdan. Un submiembro sin owner en la lista va
    a la sección **"Other sub-members"**.
  - **El owner EXPLÍCITO tiene precedencia en la agrupación (2026-06-22):** `_sub_member_owner_map` ahora usa
    PRIMERO el owner guardado en `LimbConfig.sub_member_owner` (lo que el usuario eligió al **Añadir** o
    en el desplegable "Owner"), cayendo al `owner_hint`/jerarquía solo cuando no hay uno explícito. Antes, la pantalla
    ignoraba el explícito y reagrupaba por nombre/jerarquía — así un submiembro recién añadido a un
    miembro podía caer en "Other" y **no aparecer bajo el miembro elegido** (ni en el árbol ni en el desplegable
    "Sub-member" al seleccionar el miembro). Ahora aparece y el enlace persiste/recarga correctamente.
  - **Subsección "Sub-members" (2026-06-20):** cada submiembro existente es una fila (label + bonus %
    `SpinBox` + botón **× (remove)**, ahora anidado — ver arriba). La línea de **añadir**
    (`_add_sub_member_add_row`) es un
    `OptionButton` (`_aux_bone_candidates`) con los huesos AUXILIARES del esqueleto del preview
    — aquellos cuyo clasificador `group_of` da "" — + un botón "Add". `_on_sub_member_added`/
    `_on_sub_member_removed` llaman a `LimbConfig.add_sub_member`/`remove_sub_member` y **reconstruyen**
    los colisionadores del preview (`_rebuild_member_colliders` → `_clear_member_colliders` +
    `_ensure_member_colliders`), reemplazando gizmos/labels. Los miembros principales siguen siendo editables
    como antes; solo los `PART_*` reciben esta subsección. Ver [[🩸 dano-localizado (ES)|dano-localizado]]. La const
    `_MODEL_STANDALONE_BONES` fue **eliminada** (los submiembros ahora vienen de `LimbConfig`/plan).
  - **El submiembro PRESERVA el nombre original (2026-06-22):** al **añadirse a un miembro owner**, el
    `PART_*` **mantiene el NOMBRE ORIGINAL del hueso** (el owner solo agrupa el daño; no renombra). `_part_label`
    fue simplificado a `return bone_name` — la antigua label **"PLATE \<MEMBER\>"** (p. ej.: "PLATE ARM L")
    fue descartada por petición. La resolución del owner (`resolve_sub_member_owner`) sigue aplicándose para la
    agrupación/herencia de daño, solo que ya no cambia la label mostrada.
  - **Bajo qué MIEMBRO aparece el submiembro (2026-06-21):** el desplegable "Sub-member" agrupa cada
    `PART_*` por el owner resuelto por **`LimbColliders.resolve_sub_member_owner`**: 1.º el **NOMBRE** de la pieza
    (`owner_hint`), 2.º **sube por la jerarquía** probando
    `owner_hint`/`group_of` en cada ancestro. Desbloqueó: las **hombreras del player**
    (`shoulderpad-adjust`, hijos de `chest`) → ARM por nombre; los **escudos de brazo del red_robot**
    (`L-/R-Shield`, hijos de `L-ARMIK`) → ARM vía el padre `L-ARMIK` en la jerarquía. Ambos **agrupados bajo
    ARM L/R**, pero mostrados con el **nombre original del hueso** (ver el punto de arriba). Los huesos que ya son un MIEMBRO (p. ej.: `L-Shoulder` → ARM) NO entran en la
    lista "Add sub-member". Ver [[🩸 dano-localizado (ES)|dano-localizado]].
  - **Opción "All members" (2026-06-21):** el desplegable "Member" tiene,
    justo después de "Select...", el elemento **"All members"** (`ALL_MEMBERS_LABEL`/`ALL_MEMBERS_VALUE`,
    traducido "All members"; retraducido en un cambio de idioma como "Whole model"/"All"). Él
    **desplaza los miembros a los índices 2+** (`_member_value`/`_member_index_for_value` tratan el índice
    1 = centinela). Cuando se elige, **muestra TODOS los miembros** (sin aislamiento).
  - **Tres desplegables separados — Member · Sub-member · Skeleton (reestructurado en 2026-06-23):** el
    `cboSubMembers` ("Sub-member:", justo debajo de "Member") es ahora SIEMPRE la lista de submiembros —
    nunca más el filtro de hueso independiente. Con un **miembro específico** lista los `PART_*` de ese miembro;
    con **"All members"** ofrece **SOLO "Select..." y "All Sub-members"** (2026-06-25 — los submiembros
    INDIVIDUALES solo aparecen al elegir un miembro específico). **"All Sub-members"**
    (`ALL_SUB_MEMBERS_LABEL`/`ALL_SUB_MEMBERS_VALUE`) no aísla, muestra el modelo entero — **y, con "Sub-member
    Colliders" ON, muestra los gizmos de TODOS los submiembros a la vez** (`_should_show_all_sub_colliders`).
    Los **huesos independientes** quedaron para su PROPIO desplegable **"Skeleton"**
    (`SkeletonRow` → `cboSkeleton`, label estática "Skeleton:" auto-traducida), mostrado **solo en modo "All members"
    ** y **siempre visible en ese modo** — cuando el modelo no tiene huesos independientes candidatos,
    aparece **desactivado** (solo "Select..."). Lista `_aux_bone_candidates`
    (`group_of == ""`, no promovidos), con **"All Skeletons"** (`ALL_AUX_VALUE`) arriba; solo
    inspección/resalte (no aísla). `_populate_sub_members` (submiembros) y `_populate_skeleton` (huesos
    independientes, llamado al inicio de él) pueblan; `_reset_skeleton` limpia. **Posición de "Skeleton":** el
    `SkeletonRow` se sienta justo debajo de "Sub-member" (el antiguo `ColliderEditBox` inline fue ELIMINADO — el
    editor de offset/scale es ahora la ventana flotante reutilizable; ver arriba). A la derecha del
    combo "Skeleton" está el desplegable de geometría `cboSkeletonGeo` cuando se elige un hueso independiente real.
    **Carga del valor PERSISTIDO al mostrar (2026-06-25):** cada `_populate_*` (member/sub/skeleton) CARGA el
    valor persistido (`sel_member`/`sel_submember`/`sel_skeleton`, leído de Settings) siempre que el desplegable se
    (re)muestra; sin valor guardado o uno inválido para el contexto → **"Select..."**. Así **"All members"
    solo "reinicia" Sub-member/Skeleton a "Select..." cuando no encuentra un valor persistido válido** (p. ej.: un `PART_*` de un
    miembro específico no coincide en modo "All members" → "Select..."; pero "All Sub-members" o un
    hueso independiente guardado vuelven). `_restore_selection_chain` **no** restaura member/sub/skeleton
    explícitamente — `_on_mesh_selected(1)` corre `_populate_members`, que hace la carga. (El flag `_restoring`
    y el reset en `_on_member_selected` fueron ELIMINADOS.)
  - **Toggle "Skeleton Colliders" (renombrado de "Highlight standalone"→"Skeleton"→"Skeleton Colliders" en 2026-06-22) + "Whole skeleton" (2026-06-21; el elemento era antes "All standalone bones"):** dado que los characters son UNA
    malla skinned (partes no separables por nodo), el filtro **RESALTA sin ocultar**: el toggle
    `AuxHighlight` (`_show_aux_highlight`, persistido) dibuja una **forma naranja translúcida**
    (sin depth-test, unida vía `BoneAttachment3D`) sobre la región del hueso independiente elegido — el AABB de los
    vértices DOMINANTES del hueso vía `LimbColliders.bone_vertex_box` (estático). El elemento **"All standalone
    bones"** (`ALL_AUX_VALUE`) arriba del filtro los resalta todos a la vez; "Select..." / toggle apagado
    = modelo entero sin resalte. `_refresh_aux_highlight` (llamado en los handlers de miembro/submiembro,
    en `_populate_members` y en `_rebuild_member_colliders`) decide qué; `_highlight_aux_bones`
    dibuja; `_clear_aux_highlights` elimina (nodos con el prefijo `_AuxHL_`).
    **Forma por geometría (2026-06-25):** `_highlight_aux_bones` dibuja en la **geometría** del hueso (guardada en
    `LimbConfig.collider_shape("PART_<bone>")`): `SHAPE_NONE` ("Select...") → **SIN resalte**; **sin elección ("")
    → AUTO-DETECTA** por forma (`_auto_geo_for_box`); forma guardada → esa. Dibuja vía
    `LimbColliders.make_shape` + `_solid_mesh_for_shape`, aplicando también el **offset/scale** guardado del hueso —
    para que el resalte **PREVISUALICE el colisionador** que el hueso tendría si se promoviera, **sin promoverlo**. La
    ventana Offset/Scale llama a `_refresh_aux_highlight` cuando cambia, para que el preview siga en vivo.
  - **Aislamiento EXCLUSIVO (2026-06-21):** `_current_focus_groups` muestra **una pieza a la vez** —
    Miembro elegido **sin** Submiembro → solo el colisionador del MIEMBRO; **con** Submiembro → solo ese
    submiembro. "All members" → el `cboSubMembers` aísla el `PART_*` elegido (o `null` = muestra
    todo, en "Select..."/"All Sub-members"); el desplegable "Skeleton" (`cboSkeleton`) nunca aísla.
  - **Colisionadores encerrados por toggle, POR TIPO (2026-06-21; separados en 2026-06-22):** la rama de foco de
    `_refresh_member_overlays` muestra el gizmo según el **toggle MAESTRO del tipo** del grupo en
    foco: MEMBER → **"Member Colliders"** (`_show_colliders`); SUB-MEMBER (PART_*) → **"Sub-member
    Colliders"** (`_show_sub_colliders`) — `giz_on = in_focus and (_show_sub_colliders if PART_ else
    _show_colliders)`. En la vista GENERAL (sin foco), `_apply_colliders_visibility` muestra los colisionadores de miembro
    **SOLO cuando "Member" está en "All members"** (`cbo_members.selected == 1` + el toggle "Member
    Colliders"; en "Whole model"/"Select..." = **NINGUNO**, 2026-06-25 — antes el toggle solo mostraba
    todos) y **oculta los PART_***; el submiembro solo aparece aislado, vía su toggle — **excepto** en modo "All
    Sub-members" + "Sub-member Colliders" encendido, que muestra TODOS los submiembros a la vez (2026-06-25,
    `_should_show_all_sub_colliders`). El aislamiento de **labels**
    sigue siendo independiente de los toggles de colisionador. Nota: los huesos que ya son un MIEMBRO (p. ej.:
    `shoulder.L/.R` → ARM) **no** entran en la lista "Add sub-member" (que solo ofrece los
    auxiliares, `group_of == ""`); el "shoulder" como submiembro es la placa `shoulderpad-adjust` (mostrada con
    ese nombre original, agrupada bajo ARM), porque el `shoulderpad.L/.R` en bruto tiene 0 vértices.

⚠️ Varios modelos disparan sonido vía **pistas de animación** (`type = "audio"`/`"method"`,
no solo autoplay). Por eso `_apply_audio_state()` **silencia** (volume_db = -80) los emisores
cuando el toggle Audio está apagado y restaura el **volumen de origen** (capturado por
`_capture_av`) cuando se vuelve a encender — para que el audio disparado por la animación misma también respete
el toggle Audio, sin necesitar reconstruir el preview.

🔁 `_capture_av()` también **desactiva todo `AnimationTree`** (`active = false`) al construir el
preview, para que no pose el esqueleto **en paralelo** con el clip reproducido directamente en el
`AnimationPlayer`.

🎭 **red_robot anti-"dos modelos" (2026-06-18):** al encender la animación el red_robot aparecía
**duplicado/desplazado**. Dos causas, ambas en `_capture_av`/`_apply_animation_state`:
- **Root motion:** los clips llevan el root motion en un hueso (`Skeleton3D:MASTER`) que el
  `AnimationTree` extraía y el script aplicaba al cuerpo. Reproduciendo el clip **directamente** en el
  `AnimationPlayer`, ese hueso se APLICABA, trasladando el esqueleto (~1.6 m en Z) → un segundo
  modelo detrás. Solución: `_capture_av` copia `tree.root_motion_track` al player que el tree
  conducía → el clip se reproduce **en su sitio** (root motion extraído y descartado; deriva = 0).
- **Players de efecto/muerte:** el red_robot tiene 4 `AnimationPlayer`s (locomoción + `ShootAnimation` +
  `Explosion`/kaboom + blast). El preview reproducía el 1.º clip de **cada** player → el kaboom
  revelaba los escombros de muerte (copias de partes) sobre el modelo. Solución: sin clip elegido
  en el desplegable **nada se reproduce** (2026-06-18 — antes el player principal reproducía un clip default/idle);
  con un clip explícito del desplegable, `_apply_animation_state` lo reproduce **solo** en quien lo tenga y para
  todos los demás players (p. ej.: elegir "kaboom" muestra la explosión a propósito, sin el blast/shoot
  juntos). El **player principal** (`_main_anim_player` = el que el tree conduce, o el más rico sin tree)
  aún se identifica en `_capture_av` solo para encontrar el `_main_body_root` (el cuerpo vivo a ocultar
  en los clips de muerte).
- **Un clip de muerte/explosión oculta el cuerpo vivo (2026-06-18):** el clip `kaboom` hace el nodo `Death`
  (escombros = copias de partes) **visible** pero NO oculta el cuerpo vivo (eso lo hacía el script,
  eliminado en el preview) → cuerpo + escombros = "dos modelos". `_apply_animation_state` oculta el
  `_main_body_root` (la raíz del cuerpo, p. ej.: `RedRobotModel`) cuando el clip elegido es de muerte
  (`_is_death_clip`: kaboom/explo/death/die/destr), dejando solo la explosión.

(Los emisores van al bus `SFX` — ver [[🔊 audio (ES)|audio]].) Los estados de **rotación,
animación, efectos especiales, audio, colisionadores, labels y Type/Name/ID/Bone** se **persisten** en la
sección `[models]` de `user://settings.ini` vía `Settings.config_file` (`_save_toggle` en cada
handler; `show_member_labels` desde 2026-06-20, `show_type`/`show_name`/`show_id` desde 2026-06-21,
`show_osso` desde 2026-06-22)
y se releen en `_ready` antes de conectar las señales, para que la pantalla reabra como se dejó. El
toggle **Per-member damage** es la excepción — **no** se persiste (siempre abre cerrado).

### 💾 Persistencia de selección + restauración de cadena (2026-06-18)

Más allá de los toggles, **toda elección de desplegable** (Category · Model · Part ·
Animation · Effects) se persiste en la misma sección `[models]` por un **valor estable** — no el
índice — vía `_save_selection(key, value)` en cada `_on_*_selected`: `sel_category` = la clave de la
categoría, `sel_model` = el nombre del modelo, `sel_part` = la label de la malla **o** el centinela `WHOLE_MODEL_VALUE`
(`"__whole_model__"`) para "Whole model", `sel_animation` = el texto del clip, `sel_effect` = el centinela
`ALL_VALUE` (`"__all__"`) para "All"
**o** el texto del elemento (`_effect_value`; el inverso `_effect_index_for_value` lo resuelve a un índice).
Usar el centinela para "All" evita romper la restauración cuando cambia el idioma (la label se
traduce). Así la restauración sobrevive a un re-escaneo de la biblioteca en un orden diferente.

`_restore_selection_chain()` (llamado al final de `_ready` en lugar del antiguo
`select(0)`+`_on_category_selected(0)`) **reproduce la cadena de arriba abajo**: dado que `select()`
**no** emite `item_selected`, cada paso **también** llama al handler explícitamente, poblando el
siguiente combo como un clic real. Los `_find_*_index` resuelven el valor guardado al índice actual de
cada combo. Regla de parada por nivel:

- **valor vacío** (el usuario se detuvo ahí) → deja el combo en el placeholder **activado**, listo para
  continuar. Con todo vacío = un **inicio en blanco** normal (nada previsualizado, ningún elemento
  auto-seleccionado — ver [[🔽 dropdowns (ES)|dropdowns]]).
- **valor inexistente hoy** (la elección guardada desapareció de la biblioteca, "no hay más datos") →
  **desactiva ese combo**; dado que su handler no corre, todos los de abajo se quedan desactivados
  también. Animation y Effects son **hojas paralelas** de "Whole model": cada una se restaura
  independientemente (obsoleta → desactiva solo ella; vacía → se queda en el placeholder).

### 🧍 Miembros y centrado (Characters/Weapons)

Para **Characters** y **Weapons**, `_preview_whole_model` construye los colisionadores de
miembro (vía [[🦿 limb-colliders-gd (ES)|LimbColliders]]) y `_add_member_labels`
flota un `Label3D` con el nombre del miembro (HEAD, TORSO, ARM…) sobre cada colisionador.
La fuente de la label es **36** (¼ menor que el original 48 — 2026-06-17), con outline 9.

**Labels: 100% locales a la escena (2026-06-21):** cada línea de la pila TYPE/Name/ID/Member sigue
**su** propio toggle de escena (Member + las checkboxes Type/Name/ID), con **ninguna** lectura del
Debug 3D global. `_add_member_labels` nombra cada línea con el prefijo `_MdlLbl_` y
`_apply_member_labels_visibility` **recrea la pila in-place** (limpia los `_MdlLbl_*` y re-añade
con la visibilidad por línea). Dado que el nodo raíz de la escena está en el grupo **`no_debug_overlay`**, el
`DebugOverlay` (autoload) ya salta toda la escena — así no hay label doblada ni gizmos globales
en el preview. (La llamada `DebugOverlay.exempt_member_labels(instance)` en `_preview_whole_model`
se mantiene como defensa redundante.) Las labels del navegador usan los overrides de head/torso
como única fuente.

> [!note] red_robot HEAD collider = cara + ojos (2026-06-18)
> El miembro HEAD del red_robot se construye de `mouth_eyes` **+ `L-EYE`/`R-EYE`**
> (override en `_MODEL_HEAD_BONES` y en `red_robot.gd`). Los ojos caen en la exclusión "eye",
> así que sin forzarlos, la cabeza capturaba solo el panel de la cara (~42 vértices) y se volvía una
> esfera diminuta escondida en el box del TORSO. Con los ojos, la esfera pasa a ~`r=0.34` (toda la cara).
> Esto aplica tanto al gizmo del navegador como a la **hitbox de headshot** en el juego (misma
> `LimbColliders`) — el headshot pasó a ser un blanco justo.

> [!note] player HEAD collider = CÁPSULA (2026-06-21)
> La cabeza del **player** usa una **cápsula** (no una esfera): `player.gd` fija `lc.head_shape =
> "capsule"` y la pantalla Models lo espeja vía `_MODEL_HEAD_SHAPE := {"player":"capsule"}`. La cápsula se
> alinea al eje más largo de la cabeza (misma orientación que el hueso) y mantiene el **radio completo**
> (`make_member_shape` → `make_shape("capsule", aabb, cap_radius=false)`), sin el `CROSS_SHRINK`
> de los otros miembros, para **cubrir toda la malla** de la cabeza. Ver [[🩸 dano-localizado (ES)|dano-localizado]].

**Centrado posado (2026-06-17):** el AABB de una malla **skinned** viene de la
pose **bind**, que en el red_robot está ~1.4 m desviada de la pose idle en Z. Usarlo anclaría el pivot
**detrás** del cuerpo, y el modelo "escaparía" al rotarlo. Por eso, cuando hay colisionadores de
miembro, `_posed_member_bounds()` mide el cuerpo **en la pose real** (a partir de los colisionadores) y
`_fit_to_view(model, 2.0, posed)` centra/escala por ese AABB — el modelo rota **en su sitio**.

## 📤 Extracción ("Save as 3D scene")

`_on_save_pressed()` re-instancia el modelo, encuentra el 1.º nodo con la malla seleccionada
(con la colisión hija, si la hay), pone a cero la transformada al origen, redefine owners
y lo empaqueta en un `.tscn` independiente en `library/extracted/<category>/<name>.tscn`.

## 🖼️ Galería "Exported"

`library/extracted/Exported.tscn` (`exported.gd`): escanea `library/extracted/`,
instancia todas las escenas `.tscn`/`.glb` (excepto ella misma), normaliza el tamaño y
las dispone una al lado de la otra. El botón "Exported" navega a ella; "Back"/ESC vuelven a
`models.tscn`. **Nota:** el escaneo es solo de la raíz de `extracted/`; "Save" escribe en
subcarpetas `extracted/<category>/` (las escenas extraídas no aparecen en la galería sin un
escaneo recursivo).

## 🔗 Enlaces / reuso (recuento)

El único enlace que impide la separación es el *skinning* al `Skeleton3D` — solo en los
**characters** (Player, RedRobot): la unidad reutilizable es el personaje entero.
El contenido estático es una pequeña paleta de mallas distintas instanciadas con una
transformada embebida + colisión hija (`StaticBody3D`/`CollisionShape3D`): Core 35,
CoreOutLight 4, Lights 4 (+luminarias), Props 86 (+el `VehicleWheel3D` de los scificars),
Structure 104. El forklift tiene una jerarquía limpia (3 forklifts). Los scificars (en
props.glb) son planos (ruedas + cuerpo como hermanos, sin nodo padre por coche).

## 🎛️ Visor de controles 2D (análogo)

`scenes2D/controls/controls.tscn` (`controls.gd`) es el equivalente 2D de esta pantalla:
un desplegable lista cada control en `controls2D/<name>/<name>.tscn` y el
seleccionado se instancia en un `SubViewport` de preview (aislando controles que cubren
toda la pantalla, como `scanlines`/`pause_menu`, y el `cyberpunk_hud`, que es un
`CanvasLayer`). Alcanzable vía la pantalla `developer` (el botón "2D Controls", junto a
"3D Models"). Soltar una nueva carpeta de control hace que aparezca automáticamente.

`_center_preview` centra el control en el SubViewport **horizontal y verticalmente
siempre que sea posible** (2026-06-16): espera 1 fotograma a que el layout se asiente y solo recentra
el eje en el que el control es **más pequeño** que el viewport — los controles que ya llenan
toda el área (scanlines/hud/pause_menu) se quedan donde están.

## 🔗 Relacionado

- [[🎬 fluxo-de-cenas (ES)|fluxo-de-cenas]]
- [[🧭 main-gd (ES)|main-gd]]
- [[📄 formatacao (ES)|formatacao]]

---
tipo: sistema
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# 🐞 Sistema — Debug Overlay y modo desarrollador

Un overlay de debug global (`autoload/debug_overlay.gd`, autoload **DebugOverlay**), activado por la
pantalla **developer** (`scenes2D/developer/`). Los toggles persisten en `Settings` (sección `game`) y
se aplican al instante (`DebugOverlay.refresh()`).

> [!important] Debug 3D movido a la pantalla Models (2026-06-23)
> La inspección 3D (malla, líneas del esqueleto, etiquetas por miembro / Type / Name / Id) **salió del
> developer y de las pantallas de gameplay** (levels/chooseplayer) y ahora vive en la pantalla **Models**, con sus
> propios toggles sobre la vista previa — ver [[🗿 biblioteca-de-modelos (ES)\|biblioteca-de-modelos]]. El overlay GLOBAL aplica **solo
> Debug 2D** (tooltips de controles), en cualquier pantalla. `_tag` ya no etiqueta
> `Skeleton3D`/`MeshInstance3D`. **Limpieza (2026-06-23):** todo el código 3D/rejilla muerto de
> `debug_overlay.gd` fue **eliminado** (≈200 líneas: `_add_3d_skeleton`, líneas de huesos, caja AABB,
> rejilla, getters `*_3d`/`show_members`/`show_grid`, metas/grupos `no_debug_overlay`/`no_debug_member`,
> `exempt_member_labels`), junto con las claves muertas en `DEFAULTS.game` de la config. La **columna Debug 3D**
> y el **panel de vista previa** del developer fueron **eliminados**.

## Pantalla developer

- **General** (`GridContainer`): **FPS HUD** (`hud_fps`) y **Health Monitor** (`performance_hud`).
- **Debug 2D** (columna única): maestro `debug_2d` + filas `show_type` / `show_name` / `show_id` /
  `show_path` / `show_tab` (**Tab es la última opción**). Dibuja tooltips 2D (borde de color +
  TYPE/Name/ID/PATH/TAB, **una línea por valor, en el MISMO orden que los toggles** de la pantalla developer — el
  orden del `vbox.add_child` en `_add_2d` refleja `_DEBUG2D_SUBROWS`/`developer.tscn`) en cada
  `Control`, con un **color por línea** (Type = rosa, Name = verde, Id = amarillo, **Path = azul claro**,
  **Tab = blanco** — `_LINE_COLORS`). **Debug 2D activado solo no muestra nada**: el borde/tooltips
  solo aparecen con ≥1 línea seleccionada. Las sub-filas **enteras** (la etiqueta `Show*Label`
  **más** los botones) quedan **atenuadas** mientras el maestro (Debug 2D) está apagado
  — `_set_subrows_disabled` oscurece cada `Control` de la fila vía `modulate` y solo deshabilita el
  `BaseButton` (`_DEBUG2D_SUBROWS`; el color base recordado en `_BASE_MODULATE_META`).
  - **Línea Path** (`ShowPathRow` → `show_path`, debajo de `ShowIDRow`; etiqueta "Path"/"Caminho"):
    muestra la **ruta del control en el árbol de la escena activa** (`_scene_path_of` → `root.get_path_to`,
    acortada a los últimos 3 segmentos con `…/` cuando es larga). Sirve para **distinguir controles con
    el mismo Type/Name** en la misma escena. Rellenada cada frame en `_show_overlay_for` (solo para el control
    señalado y su host).
  - **Línea Tab** (`ShowTabRow` → `show_tab`, la **última** sub-fila, debajo de `ShowPathRow`): muestra el
    **índice de Tab/foco** de cada control (`TAB: n`, o `TAB: -` si no es focable). **Valor ESPERADO
    primero (2026-06-30):** si el control declara `metadata/tab_order` (ver
    [[🔁 navegacao-tab (ES)\|navegacao-tab]]), la línea muestra ese número (`UINav.tab_order_of`), para que el orden sea
    predecible e independiente de la cadena en vivo. **Sin** el metadato, recurre al índice CALCULADO: el
    `_compute_tab_indices` empieza al inicio de la cadena (`_tab_chain_start`) y sigue
    `find_next_valid_focus()` numerando 1, 2, 3… **Con una ventana flotante abierta** (fondo suprimido) numera
    la cadena de la VENTANA empezando **después de la ×**, así que la **× obtiene el `TAB: n` MÁS ALTO** (queda la última
    en el anillo — ver [[🎬 fluxo-de-cenas (ES)\|fluxo-de-cenas]]); sin ventana, empieza desde el 1.er focable (`UINav.first_focusable`) de la
    pantalla activa. Recalculado cada frame **solo** mientras la línea Tab es visible (el orden de foco cambia
    a medida que los controles aparecen/desaparecen).
    - **¿Por qué algunos controles muestran `TAB: -`?** Dos razones: (1) **no son focables** — `Label`,
      `ColorRect`, `Panel`, contenedores, el título de la escena, el **idioma activo** (`disabled`): correcto/esperado;
      (2) **son focables, pero la cadena no los alcanza** — en pantallas **sin** `UINav.wire_tab_ring`, el
      `find_next_valid_focus()` sigue los vecinos automáticos de Godot, que pueden no encadenar todos los
      contenedores y cerrar el ciclo antes de tiempo, dejando focables sin número. **Cablear el anillo**
      (`UINav.wire_tab_ring(self)`) hace que todos obtengan `TAB: 1..N`. Detalle en [[🔁 navegacao-tab (ES)\|navegacao-tab]].
- Botones **3D Models** / **2D Controls** (navegación).

## Debug 2D — detalles

- `_tag` aplica el 2D a **TODAS las pantallas, sin excepción** (no comprueba `no_debug_overlay`) — incluidos
  Models y el editor de Daño. Al cambiar de pantalla, `_process` detecta que `_active_screen_root` cambia y
  llama a `refresh()` para reconstruir los tooltips en la nueva escena.
- **Toggle Debug 2D en la barra Actions:** al cambiar de pantalla, `_process` también llama a
  `_ensure_debug2d_toggle(screen)`, que inyecta (de forma idempotente) un `Debug2DToggle`
  (`controls2D/debug2d_toggle.gd`, un `CheckButton`; el **nodo** se llama `Debug2D` — sin el
  sufijo "Toggle", estándar 2026-06-28) en el `HBoxContainer` **Actions** de la pantalla —
  **excepto el developer**, que `_ensure_debug2d_toggle` omite deliberadamente. **El developer también tiene ahora
  el toggle en Actions (2026-06-29):** lo inyecta él mismo (`developer._ensure_actions_debug2d`), en la
  **misma posición por defecto** (último elemento de Actions), y lo mantiene **sincronizado** con su
  par Off/On en la columna Debug 2D — al conmutar uno se refleja en el otro y se reevalúan las sub-filas
  (`_on_actions_debug2d_toggled` ⇄ `_on_toggle("debug_2d")`). Como gestiona el suyo propio, el DebugOverlay lo omite.
  El **menu** también ganó una barra Actions en la posición por defecto (bajo `UI`), para que el toggle le llegue
  cuando es la pantalla activa. **NUNCA en una escena de LEVEL de gameplay (2026-07-02):** aunque los niveles
  (`level_1`/`level_2`) tienen un `Actions` en el `TitleCanvas`, `_ensure_debug2d_toggle` ahora **retorna
  temprano si `screen is Node3D`** (los niveles tienen raíz en un `Node3D`) — el toggle Debug 2D es para PANTALLAS de UI 2D,
  no para el juego en sí. La pantalla **Models** (`scenes3D/models`) tiene raíz en un `Node` plano, así que **no** golpea
  la guarda y sigue recibiendo el toggle. Las pantallas sin ningún Actions se ignoran. El toggle lee/escribe
  `Settings("game","debug_2d")` y llama a `DebugOverlay.refresh()`. Corre incluso con Debug 2D **apagado**
  (la llamada es ANTES del `if _canvas_layer == null: return`), de lo contrario no habría forma de encenderlo.
- **Canvas SIEMPRE encima (2026-06-29):** los dos `CanvasLayer` del overlay subieron a
  `_OVERLAY_LAYER = 129` (tooltips/bordes) y `130` (la marca de agua con el nombre de escena), **por encima de las ventanas
  flotantes** — el `FloatingDialog` construye el diálogo en un `CanvasLayer` en **128** (p. ej. "Quit
  Zimaro ?"), que solía **tapar** el overlay (que estaba en 100/101). Ahora Debug 2D se dibuja sobre el
  diálogo (y, al ser `MOUSE_FILTER_IGNORE`, no roba el clic). No queda debajo de nada — solo el
  overlay de crash del `stability_guard` (128) también está alto, pero el debug, por petición, va delante.
- **Posición del tooltip — la regla de las 4 esquinas (reescrita 2026-06-28):** `_layout_tooltips(hov, host)`
  posiciona **primero** el tooltip del control señalado y **luego** el del **host**, cada uno vía la
  función `_pick_corner`, que prueba 4 esquinas del control **en este orden de prioridad**, eligiendo la
  primera que quepa **entera en pantalla**: (1) a la **derecha de la esquina superior derecha** → (2) a la
  **izquierda de la esquina superior izquierda** → (3) a la **derecha de la esquina inferior derecha** → (4) a la
  **izquierda de la esquina inferior izquierda**. **Si ninguna esquina externa cabe sin colisionar, PROYECTA el
  tooltip DENTRO del área del control (2026-06-29):** `_project_into_rect` busca una de las **4 esquinas internas**
  del rect (superior-izquierda → superior-derecha → inferior-izquierda → inferior-derecha) que quepa en pantalla Y no solape los rects
  ya fijados — como el rect del host suele ser grande (un contenedor), hay espacio interno lejos del tooltip del hijo,
  garantizando la regla de **nunca** solapar padre × hijo. Solo si ni el interior cabe se relaja
  a la primera que al menos quepa; como último recurso, clampa la esquina preferida (1) al viewport (`_clamp_pos`).
  **El tooltip del host, además de caber, evita SOLAPAR el señalado** (que se fijó primero) —
  arreglando el bug de "el overlay del padre está colisionando" al señalar un contenedor (p. ej. el `VBoxContainer` "main"). Reemplazó la antigua
  separación 2D iterativa (`_resolve_tooltip_layout`), ahora innecesaria ya que solo hay 2 tooltips visibles (señalado
  + host) en el inspector de hover. **El título de escena (`Title`) también sigue la regla de las 4 esquinas**
  (2026-06-28) — ya no tiene su propio layout (el antiguo caso especial `is_title`, que lo centraba
  debajo del texto, fue **eliminado**). El color del borde de cada tooltip = el del control, manteniendo la asociación
  visual incluso cuando va a otra esquina.
- **Inspector de hover — overlay solo en el control señalado (2026-06-28):** Debug 2D dejó de
  dibujar borde/tooltip en **todos** los controles a la vez. Ahora `_process` corre en **dos
  pasos**: (1) oculta **todo** el overlay y encuentra el control bajo el cursor — el de **menor área** entre
  los que contienen el ratón (el más específico/interno) y **elegible** (visible en el árbol + ≥1 línea de Debug 2D
  activa + no suprimido por una ventana flotante); (2) vuelve a mostrar **solo** ese control (posiciona
  borde + tooltip y activa las líneas Type/Name/Id/Tab elegidas). Con nada bajo el cursor, **no** aparece
  nada. Como solo queda 1 tooltip visible, `_resolve_tooltip_layout` se convierte en un simple clamp al viewport.
- **Resaltado de iluminación en el control señalado (2026-06-28):** `_apply_border_glow` ilumina el borde del
  control mostrado: un color más claro (`color.lightened(0.5)`), un borde más grueso (`_BORDER_WIDTH + 2`)
  y un **glow** (una sombra de color sin offset) **pulsante** suavemente (`sin(_glow_phase)`,
  amplitud 6→12 px). **Apilamiento (`_Z_*`, 2026-06-29):** los **tooltips** (texto) quedan **SIEMPRE
  encima de los bordes** — incluso el borde grueso/brillante del señalado — para que el texto del padre y del hijo
  quede **legible** incluso cuando el tooltip se proyecta dentro del área del control. Orden:
  borde del host (0) < borde del señalado (1) < tooltip del host (2) < tooltip del señalado (3). Los demás vuelven a la normalidad **una vez**
  (flag `glow_on` en la entrada de `_overlay_map`), así que solo se reescribe 1 `StyleBox` por frame.
  Se aplica en **cada escena 2D** (el mismo barrido global que Debug 2D).
  - **Resaltado débil del host (2026-06-28):** si el control señalado está **dentro de otro**, el
    "host" (el ancestro `Control` rastreado más cercano — `_host_id_of`) también recibe un overlay, con el
    **borde** con el MISMO efecto pero a mucha menor intensidad (`_HOST_GLOW = 0.18`: borde/glow/anchura
    escalados por ese factor en `_set_border_lit(..., intensity)`), solo para situar el control en el
    contenedor. Los **bordes** quedan debajo de los **tooltips** (ver "Apilamiento" arriba): el borde del host (0)
    debajo del señalado (1), y ambos tooltips (host 2, señalado 3) encima de los dos bordes.
  - **El tooltip del host también aparece, sin colisionar con el hijo (2026-06-28):** el overlay del señalado y el
    del host son ensamblados por el mismo helper `_show_overlay_for(inst_id, tab_visible)` (borde + tooltip
    + líneas Type/Name/Id/Tab), así que el **host muestra su tooltip** igual que el hijo. Como hay 2 tooltips
    visibles, `_layout_tooltips` posiciona **el del hijo primero** (señalado) y **el del host después**
    por la regla de las 4 esquinas (`_pick_corner`), con el host **evitando el rect ya fijado del hijo** — no se
    solapan (ver "Posición del tooltip" arriba).
- **Mapeo de coordenadas — controles en un `SubViewport` (2026-06-27):** `_screen_rect_of(ctrl)`
  convierte el `get_global_rect()` (el espacio del viewport del control) a las **coordenadas de pantalla**
  del canvas del overlay. Para controles en el viewport principal es el propio rect; para controles **dentro
  de un `SubViewport`** (p. ej. la vista previa de la **pantalla 2D Controls**, `scenes2D/controls/controls.tscn`, que
  instancia cada widget en un `SubViewport` vía un `SubViewportContainer` con `stretch`), sube por la cadena
  sumando `container.get_global_position()` y la escala `container.size / subviewport.size`. Sin esto, el
  borde/tooltip salía **desplazado** de la posición real del control.
- La **marca de agua con el nombre de escena** (`_scene_name_label`) queda **arriba a la derecha, junto al
  título (`Title`)** (antes era la esquina inferior izquierda), en el canvas persistente. También gana un tooltip
  2D: como `_scan` omite el canvas persistente, `_build_overlays` registra `_scene_name_label`
  explícitamente (`_add_2d`) cuando `debug_2d` está activo.
- **Nodos `Label` sin el sufijo "Label" (2026-06-28):** para limpiar la línea **Name** de los tooltips de Debug
  2D, a los nodos con **`type="Label"`** cuyo nombre terminaba en "Label" se les quitó el sufijo: `TitleLabel →
  Title` (en todas las pantallas + las ventanas de Daño/IA/`FloatingWindow`), `SceneNameLabel → SceneName` (el nodo
  local de Models **y** la marca de agua global creada en `debug_overlay._setup_scene_name_label`) y
  `SubMemberLabel → SubMember` (el **Label** "Sub-member:" de Models). Los accesores `%` en
  `models.gd`/`floating_window.gd` se ajustan en consecuencia; las
  variables GDScript (`_title_label`, `scene_name_label`, `sub_member_label`) **no** cambiaron. **Nota:** el
  **`CheckButton`** `SubMemberLabel` (el toggle de etiquetas de submiembro, renombrado desde `SubMemberLabelToggle`
  en 2026-06-28) **no** es un `Label` y conserva su nombre — los dos `SubMemberLabel` coexistían por error (mismo
  `unique_name`); renombrar el Label a `SubMember` deshizo la colisión.
- **Ventana flotante abierta → el overlay de la UI de fondo desaparece (2026-06-27):** mientras CUALQUIER
  ventana flotante está **visible**, Debug 2D dibuja tooltips/bordes **solo en los controles DENTRO
  de ella** — la UI que la llamó (la pantalla de detrás) queda limpia, para no contaminar con demasiada información. Las
  ventanas se marcan a sí mismas en el grupo `DebugOverlay.FLOATING_WINDOW_GROUP` (`&"debug_floating_window"`); cada
  frame `_process` lista las del grupo que están `is_visible_in_tree()` (`_active_floating_windows`) y
  `_suppressed_by_floating(ctrl, …)` oculta todo lo que no sea descendiente de alguna de ellas. Sin ventana
  abierta nada cambia. **Se aplica en CUALQUIER escena (2026-06-27):** la clase reutilizable `FloatingWindow`
  (`controls2D/floating_window/`) entra en el grupo por sí misma en su `_ready`, así que cada ventana
  basada en ella — incluidos los diálogos de confirmación `FloatingDialog` — ya dispara la supresión en
  cualquier pantalla. En Models, el **editor de IA** pasó a ser un `FloatingWindow` en runtime (2026-06-30, ver
  abajo) y se registra a sí mismo; mientras que el `damage_panel` (Daño) sigue siendo su propio `PanelContainer` (ligado al
  sistema de daño por miembro), así que entra en el grupo **explícitamente** (`add_to_group` en
  `_setup_damage_window`); el `FloatingWindow` de Offset/Scale se registra
  a sí mismo. Abrir/cerrar/conmutar ventanas actualiza la supresión al instante, ya que la decide la
  visibilidad en vivo (ver [[🩸 dano-localizado (ES)\|dano-localizado]], [[🗿 biblioteca-de-modelos (ES)\|biblioteca-de-modelos]]).
- **Gap para identificar la ventana + Debug2D clicable bajo el backdrop (2026-06-30):** una regla del proyecto —
  cada `FloatingWindow` ahora deja un **anillo/margen mínimo** (`_WINDOW_CONTENT_GAP = 4 px`,
  `content_margin` en el stylebox de la `Window`) entre el borde y el contenido/titlebar, para que el ratón pueda pasar
  por ese espacio y Debug 2D **señale la ventana en sí**. Y, incluso con la ventana **modal** (el backdrop
  bloqueando el fondo), un clic sobre ciertos controles de la escena de fondo sigue siendo **accionable**:
  `FloatingWindow._input` (`_clickthrough_button_at`) detecta el clic antes del backdrop y dispara el
  control — el **toggle Debug 2D** (grupo `Debug2DToggle.GROUP` = `&"debug2d_toggle"`, activa/desactiva los
  overlays) **y los botones de la `LangBar`** (idiomas; regla 2026-06-30). `disabled` se ignora (p. ej. el idioma
  activo). Un CheckButton dispara `toggled`; un Button de idioma dispara `pressed`.
  En Models: el **editor de IA** pasó a ser un `FloatingWindow` en runtime **no modal** (`_ensure_ai_window`,
  `remember_position_key = "ai_window"`), así que hereda **todo** — gap, anillo de foco, ESC, supresión y el
  reenvío de clic. **Daño** sigue siendo su propio `PanelContainer` (ligado al daño por miembro): recibió el
  **mismo gap** (`content_margin = 4` en el `win_style` de `_setup_damage_window`); el **reenvío de clic** no
  se le aplica — es **no modal** (sin backdrop), así que el `Debug2DToggle` en la barra Actions de Models ya es
  clicable con ella abierta.

## Inspección 3D → pantalla Models

Malla, líneas del esqueleto, resaltado de huesos, etiquetas de miembro / Type / Name / Id y daño por miembro
son toggles de la **pantalla Models**, aplicados a su vista previa (la escena está en el grupo `no_debug_overlay`,
así que el overlay global no la toca en 3D). Ver [[🗿 biblioteca-de-modelos (ES)\|biblioteca-de-modelos]].

Relacionado: [[🩸 dano-localizado (ES)\|dano-localizado]] (mismo clasificador `BodyParts`),
[[🗣️ localizacao (ES)\|localizacao]], [[📌 ancoragem-ui (ES)\|ancoragem-ui]], [[🗿 biblioteca-de-modelos (ES)\|biblioteca-de-modelos]].

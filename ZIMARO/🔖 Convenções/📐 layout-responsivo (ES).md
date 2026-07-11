---
tipo: convencao
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# 📐 Layout responsivo (containers)

Convención (2026-06-23): las pantallas de UI deben organizar los controles con **Containers** (que
posicionan y dimensionan a sus hijos), **no** con offsets absolutos (`layout_mode = 0`,
`offset_left = 1240`…). Los offsets fijos no se reorganizan cuando cambia la resolución/aspecto y causan
bugs de solapamiento. Complementa [[📌 ancoragem-ui (ES)|Anclaje de UI]] (que gestiona los pocos
elementos pegados a los bordes).

**Stretch del proyecto = `disabled` (2026-06-23):** cambiado de `canvas_items` a **`disabled`**
(`window/stretch/mode`, base 1920×1080). Con `disabled`, los controles tienen un **tamaño fijo en px** (no
escalan con la resolución) y los Containers reorganizan la disposición — mayor resolución = más espacio, no
controles más grandes. Decisión del usuario: controles con un único tamaño independiente de la resolución.

**Contrapartida de `disabled`:** el contenido WIDE diseñado para 1920 **se desbordaría** por debajo de 1920px
(el antiguo `canvas_items` lo encogía para encajarlo). Solución: el contenedor **`HFlowContainer`**
(los hijos pasan a una nueva línea cuando no caben). **Aplicado a `settings` (2026-06-23):** cada fila de opción pasó a ser
un `HFlowContainer` y los botones perdieron `Expand` (ancho = texto, fijo) — a 1366×768 las filas anchas
("Resolution Scale" con 6 botones) se envuelven en 2 líneas sin recorte; a ≥1920 se quedan en una línea. La barra de
pestañas (`TabContainer`) ya hace scroll por sí sola cuando no cabe. `models` es denso por debajo de 1920 pero no tiene
filas anchas — no recibió HFlow (solo sería necesario si las pantallas muy estrechas se vuelven un objetivo).

**Aplicado a `levels` (2026-07-03):** la lista de niveles pasó a ser un **`GridContainer` de 3 columnas**
(`%LevelsGrid`: Level | Template | Scenery), sustituyendo el VBox con HBoxes por fila. Motivo: con
HBoxes independientes cada fila dimensionaba sus botones por el TEXTO (+ el `Expand` del botón de nivel
engordaba la fila más estrecha), desalineando las columnas; el grid iguala cada columna por la celda más ancha
→ **el mismo espaciado y alineación en ambas filas** (h/v_separation 16). Los
botones Template/Scenery se insertan en tiempo de ejecución JUSTO DESPUÉS del botón de su nivel (`move_child`) para que caigan
en la fila correcta; al cargar se oculta **todo el grid** (un hijo oculto en un grid reorganiza el resto).
**Ancho responsivo (2026-07-03):** el grid llena el ancho de la pantalla (sin `size_flags 0`); la
columna Level queda FIJA (min 300, flag FILL) y los botones Template/Scenery reciben
`SIZE_EXPAND_FILL` por código → las dos columnas **se reparten a la mitad el resto del espacio en pantalla**
(~754 px cada una a 1920), a cualquier resolución.
⚠️ **Cache de exportación:** al editar un `.tscn`, la exportación embebía la **escena antigua** de la
cache `.godot/exported/` (no se invalida por mtime) — `build_windows.ps1` ahora **limpia esa cache
automáticamente antes de cada exportación** (ver [[🚀 Build Windows (Prod) (ES)|Build Windows (Prod)]]).

## Esqueleto estándar de las pantallas

```
Control (anchors_preset = 15 → full screen)
└─ MarginContainer (full rect; margins = breathing room at the edges)
   └─ VBoxContainer
      ├─ Title                 (horizontal_alignment = 1)
      ├─ <sections>            (VBox/HBox/Grid)
      └─ Content (HBox)        children with size_flags = Expand → split the width
   (Actions in the footer and LangBar in the corner remain anchored — see ui-anchoring)
```

## Containers disponibles (Godot 4)

| Container | Para qué |
|---|---|
| **VBox/HBoxContainer** | Apila en columna/fila — la base de todo |
| **GridContainer** | Un grid de N columnas (alinea label \| botón \| botón) |
| **FlowContainer** | Como Box pero **envuelve** cuando no cabe |
| **MarginContainer** | Márgenes internos (padding) |
| **CenterContainer** | Centra al hijo sin ninguna cuenta |
| **PanelContainer** | Fondo/borde que se ajusta al contenido |
| **AspectRatioContainer** | Mantiene la relación de aspecto del hijo (p. ej.: viewports 3D) |
| **ScrollContainer** | Scroll cuando se desborda |
| **SplitContainer** | Dos áreas con un divisor |

## Las 3 propiedades de stretch

- **`size_flags_horizontal` / `size_flags_vertical`** → `Fill` (1), **`Expand`** (2, "flex-grow"),
  `Shrink Center` (4) / `Shrink End` (8); `Expand+Fill = 3`, `Shrink Begin = 0`.
- **`custom_minimum_size`** → un suelo antes de estirar.
- **`stretch_ratio`** → la proporción entre los hijos que se expanden.

## Escena piloto: developer (2026-06-23)

`scenes2D/developer/developer.tscn` fue convertida de offsets absolutos a este esqueleto y
sirve de **modelo** para las demás:

- Raíz `UI/Margin` (`MarginContainer`, full rect) → `Main` (`VBoxContainer`).
- `Content` es un `HBoxContainer` con `Col2D`, `Col3D` y `PreviewPanel`, todos `size_flags_horizontal
  = Expand` → se reparten el ancho por igual y se reorganizan a cualquier resolución. El panel 3D obtiene automáticamente la
  **misma altura** que las columnas (sin `offset_top/bottom` fijo). Ver
  [[🐞 debug-overlay (ES)|vista previa del jugador]].
- La sección `General` (3 toggles bajo el título) es un **`GridContainer` de 3 columnas** (label \|
  Off \| On): las celdas de cada columna toman el ancho de la más ancha, de modo que los botones
  **se alinean horizontalmente** por sí solos (sin `custom_minimum_size` mágico en la label). Como el grid no
  tiene un nodo "fila", estos toggles se conectan en el script mediante `_GENERAL_TOGGLES` (un par de botones con nombres
  únicos), y no por el `_row()` usado en las columnas. Usa `size_flags_horizontal = 0` (Shrink Begin) para que
  no se estire por todo el ancho.
- `Actions` (footer) y `LangBar` (esquina) permanecen **anclados** (`BOTTOM_WIDE` / `BOTTOM_RIGHT`) como
  overlays — ese es el caso legítimo para el anclaje, no un contenedor.
- El `ModelHolder` del `SubViewport` usa `unique_name_in_owner` (`%ModelHolder`) para que el script no
  dependa de la ruta en el árbol.

## Despliegue (2026-06-23) — TODAS las pantallas 2D hechas

Aplicado a **todas** las pantallas de UI 2D, usando developer como referencia. Cada pantalla recibió el
esqueleto `Margin → VBox(Main) → content` con `Actions`/`LangBar`/títulos anclados; los nodos accedidos
por script pasaron a `unique_name_in_owner` (`%Name`) cuando fueron reparentados (para no romper
`@onready`/`[connection]`):

- **developer** — Grid en General, columnas HBox Expand (botones de ancho fijo), vista previa en AspectRatio.
- **menu** — menú central en un `CenterContainer` + `PanelContainer`.
- **chooseplayer** — título arriba; flechas ancladas en los lados (V-center); robot 3D intacto.
- **controls** — selector + `SubViewportContainer` Expand.
- **levels** — columna de botones de nivel en `Main`.
- **playonline** — formulario centrado (`CenterContainer` + VBox de 700px).
- **settings** — `TabContainer`; cada pestaña es un `ScrollContainer`; 77 nodos → `%name`.
- **models** — `Selectors`/`Toggles` en `HBox(Body)`; `DamagePanel` MANTENIDO absoluto (arrastrable por
  script); 41 `@onready` → `%name`.

Ver [[ui-responsive-rollout]] (memoria) para el estado y la contrapartida por debajo de 1920.

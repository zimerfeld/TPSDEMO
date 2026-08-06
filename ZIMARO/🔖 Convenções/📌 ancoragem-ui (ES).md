---
tipo: convencao
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# 📌 Anclaje de UI (footer + título)

Convención (2026-06-16): los elementos pegados a los bordes de la pantalla usan anclaje **`*_WIDE`**
(ancho completo) con texto/botones centrados, nunca un ancho centrado fijo.

- **Barra de botones del footer** (`UI/Actions` de menu/settings/models/chooseplayer/
  controls/developer/levels/playonline) → **`BOTTOM_WIDE` (preset 12)**: `anchor_left=0`,
  `anchor_right=1`, `anchor_top=1`, `anchor_bottom=1`, `offset_left/right=0`, con
  `alignment=1` y `grow_horizontal=2`. Ancho completo, pegado al footer, botones centrados.
  - **También en el menú** (bajo `UI`) y en los niveles de gameplay level_1/2/base (bajo el `TitleCanvas`):
    el mismo `Actions` BOTTOM_WIDE, pero con `mouse_filter=2` (ignore, para no bloquear lo que hay detrás)
    — creado para el toggle Debug 2D inyectado por el `DebugOverlay`. Ver [[🐞 debug-overlay (ES)|Debug Overlay]].
  - **LangBar dentro de Actions (2026-06-26; nodos renombrados 2026-06-28):** los botones de idioma
    (`Portuguese`/`English` — antes `PortugueseButton`/`EnglishButton`) YA no están en su propia barra
    anclada a la derecha — la `LangBar` pasó a ser un `HBoxContainer` hijo de `UI/Actions` (un subgrupo
    con `separation=12`), como último elemento del grupo centrado. Esto se aplica a TODAS las pantallas
    (menu/settings/levels/chooseplayer/controls/playonline/developer/models). Rutas:
    `UI/Actions/LangBar/Portuguese` (y las conexiones `pressed`). Las pantallas que referencian por
    `%UniqueName` siguen funcionando; controls/developer/playonline/models usan la ruta
    `$UI/Actions/LangBar/...`. El botón **Back** también pasó de `BackButton` a `Back`.
- **Etiqueta de título** (`Title` — antes `TitleLabel` — de chooseplayer/controls/developer/levels/menu/
  playonline/models; los niveles 3D **ya no tienen** el `TitleCanvas/Title`, eliminado el 2026-08-06
  para no ensuciar la pantalla de juego) → **`TOP_WIDE` (preset 10)**:
  `anchor_left=0`, `anchor_right=1`, `anchor_top/bottom=0`, `offset_left/right=0`, con
  `horizontal_alignment=1`. Ancho completo, pegado arriba, texto centrado. (El título de settings
  está en un `VBox` anclado arriba, así que ya fluye correctamente — no es absoluto.)

**Por qué:** antes usaban un preset central con un **ancho fijo** (footer 660px, título 800px).
En resoluciones estrechas (portrait/móvil) la caja fija reventaba los lados y el
contenido se salía de la pantalla. `*_WIDE` sigue cualquier ancho.

**Complemento (resolución > monitor):** el anclaje por sí solo no lo resuelve cuando la **ventana**
se hace más grande que la pantalla (4K/8K en un monitor 1080p) — entonces toda la ventana (arriba y footer)
queda recortada. Por eso la aplicación de la resolución **limita la ventana al área utilizable de la pantalla**
(`DisplayServer.screen_get_usable_rect`) y la centra — ver `_apply_video_resolution`
(settings.gd) y `Settings.apply_window_resolution` (config.gd). Ver [[🎬 fluxo-de-cenas (ES)|Flujo de escenas]].

**Stretch = `disabled` (2026-06-23):** `window/stretch/mode` pasó de `canvas_items` a `disabled`
— controles con un **tamaño fijo** (no escalan con la resolución); la disposición se reorganiza mediante Containers. Cada
pantalla 2D fue migrada al esqueleto de contenedores; ver [[📐 layout-responsivo (ES)|Layout responsivo]].

Relacionado: [[🔽 dropdowns (ES)|Desplegables]] · [[📐 layout-responsivo (ES)|Layout responsivo]] · la raíz de una escena de UI debe
ser un `Node`/`Control` (un Control hijo de un Node2D acaba con tamaño 0).

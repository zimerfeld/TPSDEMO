---
tipo: convencao
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 📌 UI anchoring (footer + title)

Convention (2026-06-16): elements glued to the screen edges use **`*_WIDE`** anchoring
(full width) with centered text/buttons, never a fixed centered width.

- **Footer button bar** (`UI/Actions` of menu/settings/models/chooseplayer/
  controls/developer/levels/playonline) → **`BOTTOM_WIDE` (preset 12)**: `anchor_left=0`,
  `anchor_right=1`, `anchor_top=1`, `anchor_bottom=1`, `offset_left/right=0`, with
  `alignment=1` and `grow_horizontal=2`. Full width, stuck to the footer, buttons centered.
  - **Also in the menu** (under `UI`) and in the gameplay levels level_1/2/base (under the `TitleCanvas`):
    the same `Actions` BOTTOM_WIDE, but with `mouse_filter=2` (ignore, so as not to block what's behind)
    — created for the Debug 2D toggle injected by the `DebugOverlay`. See [[🐞 debug-overlay (EN)|Debug Overlay]].
  - **LangBar inside Actions (2026-06-26; nodes renamed 2026-06-28):** the language buttons
    (`Portuguese`/`English` — before `PortugueseButton`/`EnglishButton`) NO longer sit in their own bar
    anchored to the right — the `LangBar` became an `HBoxContainer` child of `UI/Actions` (a sub-group
    with `separation=12`), as the last item of the centered group. This applies to ALL screens
    (menu/settings/levels/chooseplayer/controls/playonline/developer/models). Paths:
    `UI/Actions/LangBar/Portuguese` (and the `pressed` connections). The screens that reference by
    `%UniqueName` keep working; controls/developer/playonline/models use the path
    `$UI/Actions/LangBar/...`. The **Back** button also went from `BackButton` to `Back`.
- **Title label** (`Title` — before `TitleLabel` — of chooseplayer/controls/developer/levels/menu/
  playonline/models + the levels' `TitleCanvas/Title`) → **`TOP_WIDE` (preset 10)**:
  `anchor_left=0`, `anchor_right=1`, `anchor_top/bottom=0`, `offset_left/right=0`, with
  `horizontal_alignment=1`. Full width, stuck to the top, text centered. (The settings
  title sits in a `VBox` anchored to the top, so it already flows correctly — it's not absolute.)

**Why:** they used to use a central preset with a **fixed width** (footer 660px, title 800px).
At narrow resolutions (portrait/phone) the fixed box burst the sides and the
content went off-screen. `*_WIDE` follows any width.

**Complement (resolution > monitor):** anchoring alone doesn't solve it when the **window**
gets bigger than the screen (4K/8K on a 1080p monitor) — then the whole window (top and footer)
is clipped. That's why the resolution application **limits the window to the screen's usable area**
(`DisplayServer.screen_get_usable_rect`) and centers it — see `_apply_video_resolution`
(settings.gd) and `Settings.apply_window_resolution` (config.gd). See [[🎬 fluxo-de-cenas (EN)|Scene Flow]].

**Stretch = `disabled` (2026-06-23):** `window/stretch/mode` went from `canvas_items` to `disabled`
— controls with a **fixed size** (they don't scale with the resolution); the layout reflows via Containers. Every
2D screen was migrated to the container skeleton; see [[📐 layout-responsivo (EN)|Responsive Layout]].

Related: [[🔽 dropdowns (EN)|Dropdowns]] · [[📐 layout-responsivo (EN)|Responsive Layout]] · a UI scene's root must
be a `Node`/`Control` (a Control child of a Node2D ends up size 0).

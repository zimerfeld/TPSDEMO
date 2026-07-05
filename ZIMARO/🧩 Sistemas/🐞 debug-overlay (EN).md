---
tipo: sistema
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 🐞 System — Debug Overlay & Developer Mode

A global debug overlay (`autoload/debug_overlay.gd`, autoload **DebugOverlay**), turned on by the
**developer** screen (`scenes2D/developer/`). The toggles persist in `Settings` (section `game`) and
apply instantly (`DebugOverlay.refresh()`).

> [!important] Debug 3D moved to the Models screen (2026-06-23)
> 3D inspection (mesh, skeleton lines, per-member / Type / Name / Id labels) **left the
> developer and the gameplay screens** (levels/chooseplayer) and now lives in the **Models** screen, with its
> own toggles over the preview — see [[🗿 biblioteca-de-modelos (EN)\|biblioteca-de-modelos]]. The GLOBAL overlay applies **only
> Debug 2D** (control tooltips), on any screen. `_tag` no longer labels
> `Skeleton3D`/`MeshInstance3D`. **Cleanup (2026-06-23):** all the dead 3D/grid code of
> `debug_overlay.gd` was **removed** (≈200 lines: `_add_3d_skeleton`, bone lines, AABB box,
> grid, getters `*_3d`/`show_members`/`show_grid`, metas/groups `no_debug_overlay`/`no_debug_member`,
> `exempt_member_labels`), along with the dead keys in `DEFAULTS.game` of the config. The **Debug 3D column**
> and the **preview panel** of the developer were **removed**.

## Developer screen

- **General** (`GridContainer`): **FPS HUD** (`hud_fps`) and **Health Monitor** (`performance_hud`).
- **Debug 2D** (single column): master `debug_2d` + rows `show_type` / `show_name` / `show_id` /
  `show_path` / `show_tab` (**Tab is the last option**). Draws 2D tooltips (colored border +
  TYPE/Name/ID/PATH/TAB, **one line per value, in the SAME order as the toggles** of the developer screen — the
  order of the `vbox.add_child` in `_add_2d` mirrors `_DEBUG2D_SUBROWS`/`developer.tscn`) on each
  `Control`, with a **color per line** (Type = pink, Name = green, Id = yellow, **Path = light blue**,
  **Tab = white** — `_LINE_COLORS`). **Debug 2D turned on alone shows nothing**: the border/tooltips
  only appear with ≥1 line selected. The **entire** sub-rows (the `Show*Label` label
  **plus** the buttons) are **grayed out** while the master (Debug 2D) is off
  — `_set_subrows_disabled` darkens every `Control` of the row via `modulate` and only disables the
  `BaseButton` (`_DEBUG2D_SUBROWS`; the base color remembered in `_BASE_MODULATE_META`).
  - **Path line** (`ShowPathRow` → `show_path`, below `ShowIDRow`; label "Path"/"Caminho"):
    shows the **control's path in the active scene's tree** (`_scene_path_of` → `root.get_path_to`,
    shortened to the last 3 segments with `…/` when long). It serves to **distinguish controls with
    the same Type/Name** in the same scene. Filled every frame in `_show_overlay_for` (only for the control
    pointed at and its host).
  - **Tab line** (`ShowTabRow` → `show_tab`, the **last** sub-row, below `ShowPathRow`): shows the
    **Tab/focus index** of each control (`TAB: n`, or `TAB: -` if not focusable). **EXPECTED value
    first (2026-06-30):** if the control declares `metadata/tab_order` (see
    [[🔁 navegacao-tab (EN)\|navegacao-tab]]), the line shows that number (`UINav.tab_order_of`), so the order is
    predictable and independent of the live chain. **Without** the metadata, it falls back to the CALCULATED index: the
    `_compute_tab_indices` starts at the beginning of the chain (`_tab_chain_start`) and follows
    `find_next_valid_focus()` numbering 1, 2, 3… **With a floating window open** (background suppressed) it numbers
    the WINDOW's chain starting **after the ×**, so the **× gets the HIGHEST `TAB: n`** (it stays last
    in the ring — see [[🎬 fluxo-de-cenas (EN)\|fluxo-de-cenas]]); with no window, it starts from the 1st focusable (`UINav.first_focusable`) of the
    active screen. Recomputed every frame **only** while the Tab line is visible (the focus order changes
    as controls appear/disappear).
    - **Why do some controls show `TAB: -`?** Two reasons: (1) **they are not focusable** — `Label`,
      `ColorRect`, `Panel`, containers, the scene title, the **active language** (`disabled`): correct/expected;
      (2) **they are focusable, but the chain doesn't reach them** — on screens **without** `UINav.wire_tab_ring`, the
      `find_next_valid_focus()` follows Godot's automatic neighbors, which may not chain all the
      containers and close the cycle early, leaving focusables without a number. **Wiring the ring**
      (`UINav.wire_tab_ring(self)`) makes them all get `TAB: 1..N`. Detail in [[🔁 navegacao-tab (EN)\|navegacao-tab]].
- **3D Models** / **2D Controls** buttons (navigation).

## Debug 2D — details

- `_tag` applies the 2D to **ALL screens, with no exception** (it doesn't check `no_debug_overlay`) — including
  Models and the Damage editor. On a screen change, `_process` detects `_active_screen_root` changing and
  calls `refresh()` to rebuild the tooltips on the new scene.
- **Debug 2D toggle in the Actions bar:** on a screen change, `_process` also calls
  `_ensure_debug2d_toggle(screen)`, which injects (idempotently) a `Debug2DToggle`
  (`controls2D/debug2d_toggle.gd`, a `CheckButton`; the **node** is called `Debug2D` — without the
  "Toggle" suffix, standard 2026-06-28) into the screen's **Actions** `HBoxContainer` —
  **except the developer**, which `_ensure_debug2d_toggle` deliberately skips. **The developer also now
  has the toggle in Actions (2026-06-29):** it injects it itself (`developer._ensure_actions_debug2d`), in the
  **same default position** (last item of Actions), and keeps it **in sync** with its Off/On
  pair in the Debug 2D column — toggling one reflects in the other and re-evaluates the sub-rows
  (`_on_actions_debug2d_toggled` ⇄ `_on_toggle("debug_2d")`). Since it manages its own, the DebugOverlay skips it.
  The **menu** also gained an Actions bar in the default position (under `UI`), so the toggle reaches it
  when it is the active screen. **NEVER in a gameplay LEVEL scene (2026-07-02):** even though the levels
  (`level_1`/`level_2`) have an `Actions` in the `TitleCanvas`, `_ensure_debug2d_toggle` now **returns
  early if `screen is Node3D`** (the levels are rooted in a `Node3D`) — the Debug 2D toggle is for 2D UI SCREENS,
  not the game itself. The **Models** screen (`scenes3D/models`) is rooted in a plain `Node`, so it does **not** hit
  the guard and still receives the toggle. Screens with no Actions at all are ignored. The toggle reads/writes
  `Settings("game","debug_2d")` and calls `DebugOverlay.refresh()`. It runs even with Debug 2D **off**
  (the call is BEFORE the `if _canvas_layer == null: return`), otherwise there'd be no way to turn it on.
- **Canvas ALWAYS on top (2026-06-29):** the overlay's two `CanvasLayer`s went up to
  `_OVERLAY_LAYER = 129` (tooltips/borders) and `130` (the scene-name watermark), **above the floating
  windows** — the `FloatingDialog` builds the dialog in a `CanvasLayer` at **128** (e.g. "Quit
  Zimaro ?"), which used to **cover** the overlay (which was at 100/101). Now Debug 2D is drawn over
  the dialog (and, being `MOUSE_FILTER_IGNORE`, it doesn't steal the click). It sits below nothing — only the
  `stability_guard`'s crash overlay (128) is also high, but the debug, by request, comes in front.
- **Tooltip position — the 4-corner rule (rewritten 2026-06-28):** `_layout_tooltips(hov, host)`
  positions **first** the pointed control's tooltip and **then** the **host**'s, each via the
  `_pick_corner` function, which tries 4 corners of the control **in this priority order**, choosing the
  first that fits **entirely on screen**: (1) to the **right of the top-right corner** → (2) to the
  **left of the top-left corner** → (3) to the **right of the bottom-right corner** → (4) to the
  **left of the bottom-left corner**. **If no external corner fits without colliding, it PROJECTS the
  tooltip INSIDE the control's area (2026-06-29):** `_project_into_rect` looks for one of the **4 internal
  corners** of the rect (top-left → top-right → bottom-left → bottom-right) that fits on screen AND doesn't overlap the rects
  already fixed — since the host's rect is usually large (a container), there's internal room far from the child's
  tooltip, guaranteeing the rule of **never** overlapping parent × child. Only if not even the interior fits does it relax
  to the first that at least fits; last resort, it clamps the preferred corner (1) to the viewport (`_clamp_pos`).
  **The host's tooltip, besides fitting, avoids OVERLAPPING the pointed one** (which was fixed first) —
  fixing the "the parent's overlay is colliding" bug when pointing at a container (e.g. the `VBoxContainer` "main"). It replaced the old
  iterative 2D separation (`_resolve_tooltip_layout`), now unnecessary since there are only 2 visible tooltips (pointed
  + host) in the hover inspector. **The scene title (`Title`) also follows the 4-corner rule**
  (2026-06-28) — it no longer has its own layout (the old special case `is_title`, which centered it
  below the text, was **removed**). Each tooltip's border color = that of the control, keeping the visual
  association even when it goes to another corner.
- **Hover inspector — overlay only on the pointed control (2026-06-28):** Debug 2D stopped
  drawing a border/tooltip on **all** controls at once. Now `_process` runs in **two
  steps**: (1) hides **all** the overlay and finds the control under the cursor — the one of **smallest area** among
  those containing the mouse (the most specific/inner) and **eligible** (visible in the tree + ≥1 Debug 2D line
  on + not suppressed by a floating window); (2) re-shows **only** that control (positions
  border + tooltip and turns on the chosen Type/Name/Id/Tab lines). With nothing under the cursor, **nothing**
  appears. Since only 1 tooltip stays visible, `_resolve_tooltip_layout` becomes just a clamp to the viewport.
- **Lighting highlight on the pointed control (2026-06-28):** `_apply_border_glow` lights the border of the
  displayed control: a lighter color (`color.lightened(0.5)`), a thicker border (`_BORDER_WIDTH + 2`)
  and a **glow** (a colored shadow with no offset) **pulsing** gently (`sin(_glow_phase)`,
  amplitude 6→12 px). **Stacking (`_Z_*`, 2026-06-29):** the **tooltips** (text) stay **ALWAYS
  above the borders** — even the pointed one's thick/glowing border — so the parent's and child's text
  stays **legible** even when the tooltip is projected inside the control's area. Order:
  host border (0) < pointed border (1) < host tooltip (2) < pointed tooltip (3). The others go back to normal **once**
  (flag `glow_on` in the `_overlay_map` entry), so only 1 `StyleBox` is rewritten per frame.
  Applies in **every 2D scene** (the same global sweep as Debug 2D).
  - **Weak host highlight (2026-06-28):** if the pointed control is **inside another**, the
    "host" (the closest tracked ancestor `Control` — `_host_id_of`) also receives an overlay, with the
    **border** in the SAME effect but at much lower intensity (`_HOST_GLOW = 0.18`: border/glow/width
    scaled by that factor in `_set_border_lit(..., intensity)`), just to situate the control in the
    container. The **borders** stay below the **tooltips** (see "Stacking" above): the host border (0)
    below the pointed one (1), and both tooltips (host 2, pointed 3) above the two borders.
  - **The host's tooltip also appears, without colliding with the child (2026-06-28):** the pointed one's overlay and
    the host's are assembled by the same helper `_show_overlay_for(inst_id, tab_visible)` (border + tooltip
    + Type/Name/Id/Tab lines), so the **host shows its tooltip** just like the child. Since there are 2 tooltips
    visible, `_layout_tooltips` positions **the child's first** (pointed) and **the host's after**
    by the 4-corner rule (`_pick_corner`), with the host **avoiding the child's already-fixed rect** — they don't
    overlap (see "Tooltip position" above).
- **Coordinate mapping — controls in a `SubViewport` (2026-06-27):** `_screen_rect_of(ctrl)`
  converts the `get_global_rect()` (the control's viewport space) to the overlay canvas's **screen
  coordinates**. For controls in the main viewport it's the rect itself; for controls **inside
  a `SubViewport`** (e.g. the preview of the **2D Controls screen**, `scenes2D/controls/controls.tscn`, which
  instantiates each widget in a `SubViewport` via a `SubViewportContainer` with `stretch`), it walks up the chain
  adding `container.get_global_position()` and the scale `container.size / subviewport.size`. Without this, the
  border/tooltip came out **offset** from the control's real position.
- The **scene-name watermark** (`_scene_name_label`) sits at the **top right, next to the
  title (`Title`)** (it used to be the bottom-left corner), on the persistent canvas. It also gains a 2D
  tooltip: since `_scan` skips the persistent canvas, `_build_overlays` registers `_scene_name_label`
  explicitly (`_add_2d`) when `debug_2d` is on.
- **`Label` nodes without the "Label" suffix (2026-06-28):** to clean the **Name** line of the Debug
  2D tooltips, the nodes with **`type="Label"`** whose name ended in "Label" had the suffix removed: `TitleLabel →
  Title` (on all screens + the Damage/AI/`FloatingWindow` windows), `SceneNameLabel → SceneName` (the local
  node of Models **and** the global watermark created in `debug_overlay._setup_scene_name_label`) and
  `SubMemberLabel → SubMember` (the "Sub-member:" **Label** of Models). The `%` accessors in
  `models.gd`/`floating_window.gd` follow along; the
  GDScript variables (`_title_label`, `scene_name_label`, `sub_member_label`) did **not** change. **Note:** the
  **`CheckButton`** `SubMemberLabel` (the sub-member labels toggle, renamed from `SubMemberLabelToggle`
  in 2026-06-28) is **not** a `Label` and keeps its name — the two `SubMemberLabel`s coexisted by mistake (same
  `unique_name`); renaming the Label to `SubMember` undid the collision.
- **Floating window open → the background UI's overlay disappears (2026-06-27):** while ANY
  floating window is **visible**, Debug 2D draws tooltips/borders **only on the controls INSIDE
  it** — the UI that called it (the screen behind) stays clean, so as not to pollute with too much information. The
  windows mark themselves in the group `DebugOverlay.FLOATING_WINDOW_GROUP` (`&"debug_floating_window"`); each
  frame `_process` lists those in the group that are `is_visible_in_tree()` (`_active_floating_windows`) and
  `_suppressed_by_floating(ctrl, …)` hides whatever is not a descendant of any of them. With no window
  open nothing changes. **Applies in ANY scene (2026-06-27):** the reusable class `FloatingWindow`
  (`controls2D/floating_window/`) enters the group by itself in its `_ready`, so every window
  based on it — including the `FloatingDialog` confirmation dialogs — already triggers the suppression on
  any screen. In Models, the **AI editor** became a runtime `FloatingWindow` (2026-06-30, see
  below) and registers itself; while the `damage_panel` (Damage) is still its own `PanelContainer` (tied to the
  per-member damage system), so it enters the group **explicitly** (`add_to_group` in
  `_setup_damage_window`); the Offset/Scale `FloatingWindow` registers
  itself. Opening/closing/toggling windows updates the suppression instantly, since it's decided by the
  live visibility (see [[🩸 dano-localizado (EN)\|dano-localizado]], [[🗿 biblioteca-de-modelos (EN)\|biblioteca-de-modelos]]).
- **Gap to identify the window + Debug2D clickable under the backdrop (2026-06-30):** a project rule —
  every `FloatingWindow` now leaves a **minimum ring/margin** (`_WINDOW_CONTENT_GAP = 4 px`,
  `content_margin` in the `Window`'s stylebox) between the border and the content/titlebar, so the mouse can pass
  through that space and Debug 2D **point at the window itself**. And, even with the window **modal** (the backdrop
  blocking the background), a click over certain controls of the background scene stays **actionable**:
  `FloatingWindow._input` (`_clickthrough_button_at`) detects the click before the backdrop and triggers the
  control — the **Debug 2D toggle** (group `Debug2DToggle.GROUP` = `&"debug2d_toggle"`, turns the
  overlays on/off) **and the `LangBar` buttons** (languages; rule 2026-06-30). `disabled` is ignored (e.g. the active
  language). A CheckButton fires `toggled`; a language Button fires `pressed`.
  In Models: the **AI editor** became a **non-modal** runtime `FloatingWindow` (`_ensure_ai_window`,
  `remember_position_key = "ai_window"`), so it inherits **everything** — gap, focus ring, ESC, suppression and the
  click-forward. **Damage** is still its own `PanelContainer` (tied to the per-member damage): it got the
  **same gap** (`content_margin = 4` in the `win_style` of `_setup_damage_window`); the **click-forward** does not
  apply to it — it is **non-modal** (no backdrop), so the `Debug2DToggle` in the Models Actions bar is already
  clickable with it open.

## 3D inspection → Models screen

Mesh, skeleton lines, bone highlight, member / Type / Name / Id labels and per-member damage
are toggles of the **Models screen**, applied to its preview (the scene is in the `no_debug_overlay` group,
so the global overlay doesn't touch it in 3D). See [[🗿 biblioteca-de-modelos (EN)\|biblioteca-de-modelos]].

Related: [[🩸 dano-localizado (EN)\|dano-localizado]] (same `BodyParts` classifier),
[[🗣️ localizacao (EN)\|localizacao]], [[📌 ancoragem-ui (EN)\|ancoragem-ui]], [[🗿 biblioteca-de-modelos (EN)\|biblioteca-de-modelos]].

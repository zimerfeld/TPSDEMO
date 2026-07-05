---
tipo: convencao
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 📐 Responsive layout (containers)

Convention (2026-06-23): UI screens must organize the controls with **Containers** (which
position and size their children), **not** with absolute offsets (`layout_mode = 0`,
`offset_left = 1240`…). Fixed offsets don't reflow when the resolution/aspect changes and cause
overlap bugs. Complements [[📌 ancoragem-ui (EN)|UI anchoring]] (which handles the few
elements glued to the edges).

**Project stretch = `disabled` (2026-06-23):** switched from `canvas_items` to **`disabled`**
(`window/stretch/mode`, base 1920×1080). With `disabled`, controls have a **fixed size in px** (they don't
scale with the resolution) and the Containers reorganize the layout — higher resolution = more space, not
bigger controls. User decision: controls with a single size independent of the resolution.

**`disabled` trade-off:** WIDE content designed for 1920 **would overflow** below 1920px
(the old `canvas_items` shrank it to fit). Solution: the **`HFlowContainer`** container
(children wrap to a new line when they don't fit). **Applied to `settings` (2026-06-23):** each option row became
an `HFlowContainer` and the buttons lost `Expand` (width = text, fixed) — at 1366×768 the wide rows
("Resolution Scale" with 6 buttons) wrap into 2 lines without clipping; at ≥1920 they stay on one line. The tab
bar (`TabContainer`) already scrolls on its own when it doesn't fit. `models` is dense sub-1920 but has no
wide rows — it did not get HFlow (it would only be needed if very narrow screens become a target).

**Applied to `levels` (2026-07-03):** the level list became a **3-column `GridContainer`**
(`%LevelsGrid`: Level | Template | Scenery), replacing the VBox with per-row HBoxes. Reason: with
independent HBoxes each row sized its buttons by the TEXT (+ the level button's `Expand`
fattened the narrowest row), misaligning the columns; the grid equalizes each column by the widest
cell → **the same spacing and alignment on both rows** (h/v_separation 16). The
Template/Scenery buttons are inserted at runtime RIGHT AFTER their level's button (`move_child`) so they land
on the correct row; on loading the **whole grid** is hidden (a hidden child in a grid reflows the rest).
**Responsive width (2026-07-03):** the grid fills the screen width (no `size_flags 0`); the
Level column stays FIXED (min 300, FILL flag) and the Template/Scenery buttons get
`SIZE_EXPAND_FILL` by code → the two columns **split the rest of the on-screen space in half**
(~754 px each at 1920), at any resolution.
⚠️ **Export cache:** when editing a `.tscn`, the export embedded the **old scene** from the
`.godot/exported/` cache (it doesn't invalidate by mtime) — `build_windows.ps1` now **cleans that cache
automatically before every export** (see [[🚀 Build Windows (Prod) (EN)|Build Windows (Prod)]]).

## Standard skeleton of the screens

```
Control (anchors_preset = 15 → full screen)
└─ MarginContainer (full rect; margins = breathing room at the edges)
   └─ VBoxContainer
      ├─ Title                 (horizontal_alignment = 1)
      ├─ <sections>            (VBox/HBox/Grid)
      └─ Content (HBox)        children with size_flags = Expand → split the width
   (Actions in the footer and LangBar in the corner remain anchored — see ui-anchoring)
```

## Available containers (Godot 4)

| Container | For what |
|---|---|
| **VBox/HBoxContainer** | Stacks in a column/row — the base of everything |
| **GridContainer** | An N-column grid (align label \| button \| button) |
| **FlowContainer** | Like Box but **wraps** when it doesn't fit |
| **MarginContainer** | Internal margins (padding) |
| **CenterContainer** | Centers the child without any math |
| **PanelContainer** | Background/border that fits the content |
| **AspectRatioContainer** | Keeps the child's aspect ratio (e.g.: 3D viewports) |
| **ScrollContainer** | Scroll when it overflows |
| **SplitContainer** | Two areas with a divider |

## The 3 stretch properties

- **`size_flags_horizontal` / `size_flags_vertical`** → `Fill` (1), **`Expand`** (2, "flex-grow"),
  `Shrink Center` (4) / `Shrink End` (8); `Expand+Fill = 3`, `Shrink Begin = 0`.
- **`custom_minimum_size`** → a floor before stretching.
- **`stretch_ratio`** → the proportion between children that expand.

## Pilot scene: developer (2026-06-23)

`scenes2D/developer/developer.tscn` was converted from absolute offsets to this skeleton and
serves as a **model** for the others:

- Root `UI/Margin` (`MarginContainer`, full rect) → `Main` (`VBoxContainer`).
- `Content` is an `HBoxContainer` with `Col2D`, `Col3D` and `PreviewPanel`, all `size_flags_horizontal
  = Expand` → they split the width equally and reflow at any resolution. The 3D panel automatically gets the
  **same height** as the columns (no fixed `offset_top/bottom`). See
  [[🐞 debug-overlay (EN)|player preview]].
- The `General` section (3 toggles below the title) is a **3-column `GridContainer`** (label \|
  Off \| On): each column's cells take the width of the widest, so the buttons
  **align horizontally** on their own (no magic `custom_minimum_size` on the label). Since the grid doesn't
  have a "row" node, these toggles are wired in the script via `_GENERAL_TOGGLES` (a pair of buttons with unique
  names), and not by the `_row()` used in the columns. It uses `size_flags_horizontal = 0` (Shrink Begin) so it
  doesn't stretch across the whole width.
- `Actions` (footer) and `LangBar` (corner) remain **anchored** (`BOTTOM_WIDE` / `BOTTOM_RIGHT`) as
  overlays — that is the legitimate case for anchoring, not a container.
- The `SubViewport`'s `ModelHolder` uses `unique_name_in_owner` (`%ModelHolder`) so the script doesn't
  depend on the path in the tree.

## Rollout (2026-06-23) — ALL 2D screens done

Applied to **all** 2D UI screens, using developer as the reference. Each screen got the
`Margin → VBox(Main) → content` skeleton with `Actions`/`LangBar`/titles anchored; nodes accessed
by script became `unique_name_in_owner` (`%Name`) when reparented (so as not to break
`@onready`/`[connection]`):

- **developer** — Grid in General, HBox Expand columns (fixed-width buttons), preview in AspectRatio.
- **menu** — central menu in a `CenterContainer` + `PanelContainer`.
- **chooseplayer** — title at the top; arrows anchored on the sides (V-center); 3D robot intact.
- **controls** — selector + `SubViewportContainer` Expand.
- **levels** — column of level buttons in `Main`.
- **playonline** — centered form (`CenterContainer` + 700px VBox).
- **settings** — `TabContainer`; each tab is a `ScrollContainer`; 77 nodes → `%name`.
- **models** — `Selectors`/`Toggles` in `HBox(Body)`; `DamagePanel` KEPT absolute (draggable by
  script); 41 `@onready` → `%name`.

See [[ui-responsive-rollout]] (memory) for the status and the sub-1920 trade-off.

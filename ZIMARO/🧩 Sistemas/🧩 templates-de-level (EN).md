---
tipo: sistema
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 🧩 Level Templates (Template Manager + Scenery Manager)

> Per-level spawn composition: characters (Templates) and scenery objects (Sceneries), with
> faction, count and placement, edited in-game in a floating window and applied when the level
> starts (solo or online room). Related: [[🎬 fluxo-de-cenas (EN)|Scene Flow]] (`levels` screen),
> [[🚪 salas (EN)|Rooms]] (host opens the same window), memory *"rooms are born clean"*.

## Two scenes + two separate managers (2026-07-03, refactor)

Responsibilities **separated** by category (before: a single dialog `LevelTemplateDialog`
parameterized by `configure()` and a single autoload `LevelTemplateManager` — both REMOVED):

- **UI — two `.tscn` scenes** (root `ScrollContainer`, vertical scroll when the fields don't fit):
  - `scenes2D/template_manager/template_manager.tscn` (+ `.gd`) — characters, **with** a Faction row;
  - `scenes2D/scenery_manager/scenery_manager.tscn` (+ `.gd`) — sceneries, **without** Faction.
  - Common logic in the base `scenes2D/managers_common/template_form_base.gd` (`class_name
    TemplateFormBase extends ScrollContainer`); each subclass only defines `_manager()`, the title and
    the default name. The presence/absence of Faction is detected by the `%Factions` node (which only
    exists in the character scene). Each scene has `Resources/<name>.pt.json` + `.en.json` (i18n via Locale).
  - Opened by `open_over(host, level_path)`: they create the `FloatingWindow` (CanvasLayer 128),
    insert their own form into its content and build the footer buttons; on close, the whole
    CanvasLayer is freed (the instance is NOT reused — the caller creates a new one).
  - **Form layout (2026-07-03):** `New` sits to the right of the `Name` field (no longer in the TopRow);
    the `EntryRow` (dropdown `Entries` + `Remove Entry`) comes BEFORE the `EntryNameRow` (field
    `Entry name` + `Add Entry` on the right). The `Entry name` field is **auto-filled**
    with the body of the Entries dropdown label (`_entry_body_text`: custom name or `_entry_auto_label`
    "faction model xN"); `_save_entry_fields` only stores it as a CUSTOM name if the text differs from the
    automatic label (otherwise it keeps `""` = dynamic). Footer: the button was renamed — node `Footer_SalvarAplicar`,
    text **"Save and Apply"** (`add_footer_button` + `save_apply.name = ...`; new i18n key).
- **Data — two autoloads** (`autoload/template_manager_base.gd` = `TemplateManagerBase` with the
  common logic; subclasses `CharacterTemplateManager` and `SceneryTemplateManager`), each in ITS OWN
  file: `user://character_templates.json` and `user://scenery_templates.json`. Uniform API without a
  category: `templates_for_level(level)`, `active(level)`/`active_id(level)`, `set_active`,
  `upsert_template`, `remove_template`, `browse_dir`, `root_dir`, `apply_active(level, spawned)`.
- **One-time migration**: on the 1st load, if the own file doesn't exist, each manager READS the legacy
  `user://level_templates.json` and brings in only its own category (`_matches_legacy`) + the matching
  actives map (`active_by_level` / `active_scenery_by_level`), writing them into its own file.
- **Application**: `level_1`/`level_2` (solo) and `RoomManager` (rooms) call
  `CharacterTemplateManager.apply_active` **and** `SceneryTemplateManager.apply_active`. In `level_2`,
  the default creature only spawns if NEITHER of the two applied anything (preserving the semantics of the old bool).

Each level has TWO buttons on the right in the `levels` screen (Template + Scenery), with independent
actives — a level runs a character template AND a scenery at the same time (solo and rooms).

**Healing obsolete paths (on load):** `_heal_entry_paths` relocates by `model_key`, under the
current root, every entry whose `scene_path` no longer exists (e.g.: saved data pointing to the
extinct `characters/enemies/…`) and rewrites the file. Without this, the dialog cascade opened at
"Select..." instead of re-selecting the saved model. **i18n labels of the level buttons:** the
dynamic texts "Templates/Sceneries: default" and "Template/Scenery: `<name>`" go through `tr_key`
(fixed prefixes translated; the template NAME is data and is not translated), in the `SKIP_GROUP` and
re-translated on `language_changed` — keys in `scenes2D/levels/Resources/levels.{pt,en}.json`.

## Form layout and placement-conditional fields (2026-07-04)

Layout polish of BOTH windows (same `TemplateFormBase`, applied to both `.tscn`):

- **Conditional fields GROUPED.** The fields that only apply to one placement mode moved out of the
  main grid into a `PanelContainer` **`%PlacementGroup`** (title "Placement options", new i18n key in
  both languages), with an inner `MarginContainer` and a 2-column `GridContainer`.
  `_apply_placement_visibility()` shows only the label+field pairs of the current mode (a hidden pair =
  both cells, so the grid stays aligned) and the WHOLE panel hides when there is no entry
  (`_placement_group.visible = has_entry`). Mapping: `coordinates` → Coordinates; `random` → Random
  center + Random size; `formation` → Formation + Origin + Spacing. **Rotation Y** is general (always
  visible, stays in the main grid). Hidden controls drop out of the Tab ring automatically
  (`UINav.collect_focusables` skips invisible ones) — `_win.wire_focus_ring` is re-wired in
  `_on_placement_selected` and on entry change.
- **Compact widths (no oversizing).** Fields no longer stretch with the window
  (`size_flags_horizontal = 0`): dropdowns and vector-text fields **240 px**; integers/numbers
  (`Count`, `Spacing`, `Rotation`) **96 px** (fit the digits without overflow). Grids hug their content
  and left-align, never touching the edges (the `FloatingWindow` already gives a 16 px margin).
- **Model cascade as a column.** `%CascadeRow` became a `VBoxContainer` (was `HFlowContainer`), so each
  `Folders%d` dropdown fills the full width and stacks vertically (VBox stretches on the cross-axis).
- **`ModelValue` removed.** The label that showed "Model: X (x.tscn)" is gone (node + `_model_value_label`
  + `_update_model_label()` + calls) — dead-code cleanup.
- **Smaller window.** `min_window_size` 1040×640 → **700×620**; scenes' `custom_minimum_size`
  1000×560 → **620×540**, cutting idle horizontal space.

> [!warning] `.tscn` does NOT use `#` for comments
> Prose `#` comments INSIDE a `.tscn` corrupt node parenting ("parent path … vanished", children with
> no parent). Godot's resource format uses `;`. Prefer no comment in the `.tscn` (document here) —
> validated by instantiating both scenes headless (every `%UniqueName` resolves, no "vanished").

## CASCADE navigation of the model (2026-07-03)

The old single "Model" dropdown (a flat list polluted with bullet/impact_effect) became a
**cascade of OptionButtons**: one dropdown per folder level starting from the category root —
e.g.: `[enemies] → [red_robot]` — descending only through subfolders that CONTAIN a model at some
depth (`browse_dir`/`_dir_model`/`_dir_has_models` in the manager). On reaching a
model-folder (a scene with the folder's name), the entry's **relevant fields** are mapped
(`model_key` + `scene_path`) and the label below shows "Model: X (x.tscn)". Navigating without
finishing does NOT erase the entry's saved model. The cascade is rebuilt from the `scene_path` when
switching entry/template. The "Type" field (character/structure) was REMOVED (the kind comes from the category);
`model_options`/`_collect_scene_options` became dead code and were deleted.

## Scenery library (`library3D/sceneries/`)

`box/` (2 m magenta cube), `sphere/` (emerald sphere r=1.2) and `pill/` (amber capsule h=3) —
`StaticBody3D` + basic volumetric geometry + EMISSIVE material + its own `OmniLight3D`
(range 6, no shadow — cheap) + `CollisionShape3D` hugging the mesh and `limb_config.json` with the
single **BODY** member (LimbColliders concept — same family as `bomb`), so the Models screen
can configure the collider. They enter the levels' `_spawnable_scenes` (replicable in rooms). The
old `structures/` left the project (user cleanup); the legacy kind
"structure" is migrated to "scenery" on load.

## host_session's ManageTemplates (2026-07-03; ex-ManageTemplatesButton)

The host grid's "Templates" "didn't work" when the level selector was at
"Select..." — SILENT return. Now it shows an alert (`FloatingDialog.alert`: "Select a
level first…"); with a level selected it opens the manager normally (validated live
hosting on 127.0.0.1:4383 — room #1 created, observed, scenery applied).

## Architecture

- **`TemplateManagerBase`** (`autoload/template_manager_base.gd`): common base of the two autoloads.
  API: `upsert_template(t) -> id`, `remove_template(id)`, `set_active(level, id)`,
  `active(level)`/`active_id(level)`, `templates_for_level(level)`, `apply_active(level, spawned)`,
  `browse_dir(dir)`, `root_dir()`. Per-subclass hooks: `_file_path`, `root_dir`, `_entry_kind`,
  `_matches_legacy`, `_install_defaults`.
  - **`CharacterTemplateManager`** → `user://character_templates.json`, root `characters`; with no
    saved template, it installs the example "Level 2 - Aerial hunt".
  - **`SceneryTemplateManager`** → `user://scenery_templates.json`, root `sceneries`; no defaults.
- **`TemplateFormBase`** (`scenes2D/managers_common/template_form_base.gd`): the form controller
  (root `ScrollContainer`) inserted into a `FloatingWindow` (CanvasLayer 128) — 2D theme + Debug 2D
  work. Subclasses: `template_manager.gd` (characters) and `scenery_manager.gd` (sceneries),
  each the root of its `.tscn`. Opened by `open_over(host, level)` from the button of each row of the
  `levels` screen and (only the character one) by `host_session`.
- Template **entry**: `kind` (character/scenery), `model_key`/`scene_path`, `faction`
  (friendly/enemy/neutral — characters only), `count`, `placement` (coordinates/random/formation) +
  fields for each mode, `name` (custom label in the `Entries` dropdown), `rotation_y`, `spacing`.
- **Application**: `level_1.gd`/`level_2.gd` call `apply_active` of BOTH managers in `_ready`
  (offline) and the `RoomManager` on room creation (online). Faction friendly → player `bot_controlled`
  (cover bots); enemy → hostile AI.
- `browse_dir`/`_dir_model` scan the category root recursively; only the scene whose basename
  == folder name enters (the "model" scene; siblings like `bomb.tscn` stay out). It needs the
  `_logical_name` (strip `.remap`/`.import`) to work in the exported `.exe`.

## Bugs fixed on 2026-07-03 (found in playtest on the .exe)

1. **EMPTY Model dropdown on the exported .exe** — `_collect_scene_options` filtered
   `file.ends_with(".tscn")`, but in the export the files appear in `DirAccess` as
   `*.tscn.remap` → no model listed and it was impossible to assemble a valid template in the build.
   **Fix:** helper `_logical_name` (strip `.remap`/`.import`), same pattern as the Models screen
   (`models.gd`). ⚠️ General lesson: **every `DirAccess` scan by extension needs
   `_logical_name`** — the editor does NOT reproduce that state, only the exported build does.
2. **"Save and Use in This Level" didn't activate a NEW template** — `_normalize_template` duplicates
   the dictionary, so the id generated in `upsert_template` stayed only in the copy; the local `_template`
   kept `id=""` → `set_active_template(level, "")` ERASED the active (the row went back to
   "Templates: default") and each Save re-appended (duplicates). **Fix:** `_save_template` now does
   `_template["id"] = LevelTemplateManager.upsert_template(_template)`.
3. **The typed name was lost** — typing the Name and clicking "Add/Remove Entry" made
   `_refresh_template_fields` re-read the old `_template["name"]` (the field was only read on Save).
   **Fix:** `_name_edit.text_changed` writes directly to `_template["name"]` (same as the
   "Entry name" field).

## Observed behaviors (by design)

- `remove_template("")` is a no-op — "Remove" on a template not yet saved does not affect the list.
- Two templates can have the **same name** (the link is by id) — e.g.: two "New template" entries in
  the list are confusing; polish idea: automatic suffix ("New template 2").
- `model_options` lists EVERY scene named like its folder — including `bullet`, `impact_effect`
  (effects/projectiles appear as choosable "models"). Polish idea: filter out support folders
  or mark spawnable categories.

## Field validation (2026-07-03, rebuilt .exe)

Full flow in the build: Levels → Manager → template **"Arena Fable"** (Red Robot × 3,
enemy, random) → "Save and Use in This Level" → the row shows "Template: Arena Fable" → Level 1
solo spawns the 3 red robots, which engage (damage to the player, death and respawn OK) at 59–61 FPS.

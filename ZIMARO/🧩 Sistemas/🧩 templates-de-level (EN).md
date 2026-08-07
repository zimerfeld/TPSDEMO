---
tipo: sistema
projeto: ZIMARO
lang: en-US
atualizado: 2026-08-06
---

# 🧩 Level Templates (Template Manager + Scenery Manager)

> Per-level spawn composition: characters (Templates) and scenery objects (Sceneries), with
> faction, count and placement, edited in-game in a floating window and applied when the level
> starts (solo or online room). Related: [[🎬 fluxo-de-cenas (EN)|Scene Flow]] (`levels` screen),
> [[🚪 salas (EN)|Rooms]] (host opens the same window), memory *"rooms are born clean"*.

---

## 📐 "Scale (%)" field (2026-08-06)

Below **Count**, in **both** managers (Templates and Sceneries), a `SpinBox` sets the model's scale as
a **percentage of its original size**:

| Value | Effect |
|---|---|
| `0` | natural size (default) |
| `+50` | one and a half times |
| `-30` | 30% smaller |

- Accepted range: **-95% to +900%**.
- Persisted on the template entry under the **`scale_percent`** key (JSON in `user://`), so it is
  loaded and can be changed **at runtime**, with no rebuild.
- Applied on every spawn in `TemplateManagerBase._configure_spawned_node`:
  `factor = 1 + scale_percent/100`, with a floor of **0.05** (below that the mesh becomes a dot and the
  colliders degenerate). The factor is also stored in the node's `template_scale_factor` meta.

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

## SCENERY picker in host_session (2026-08-06)

The host grid only had `Levels` + `Templates` (characters) — an online room always spawned with the
level's **default scenery**, while offline mode (the `levels` screen) already picked both. `StartRow`
gained `Sceneries` (OptionButton) + `ManageSceneries` (a "Cenários" button that opens
`scenery_manager` in the same `FloatingWindow`), mirroring the character pair. `_on_start_pressed`
activates BOTH managers **before** `RoomManager.start_room` — the room manager applies both while
building the room (`apply_active_gradual`), so a joining client gets the full level, identical to the
host's. Generic code: `_refresh_picker`/`_apply_picker`/`_open_manager_dialog` take the category's
`TemplateManagerBase` (one path for both). Tab: Levels 1 → Templates 2 → ManageTemplates 3 →
Sceneries 4 → ManageSceneries 5 → Start Room 6 → room rows → Back → Debug 2D.

## Scenery arrived at (0,0,0) on the client — piece spawn properties (2026-08-06)

The host's scenery picker exposed the bug: **on the client all 9 "Palco Neon" pieces spawned at the
origin, stacked**, while on the server they were spread out. Measured with a simultaneous dump from
both sides (host on 44000, client joining through the `zimaro.playit.game` tunnel): `Scenery_box_000`
= `-11.33, 1.00, -3.55` on the server and `0,0,0` on the client — all nine like that.

**Cause.** `MultiplayerSpawner` only transmits WHICH scene to instantiate and the node name; the
`position`/`rotation`/`scale` that `_spawn_job` applies after `instantiate()` never travels in the
packet. **Every model is born at (0,0,0) on the client** — what differs is who FIXES it afterwards:

| scene | synchronizers | result on the client |
| --- | --- | --- |
| `player.tscn` (including the bot ally) | 3, with `net_transform` **and** `spawn_position` (`spawn=true`) | correct on the same frame |
| `red_robot.tscn` / `criatura_alada.tscn` | 4 / 1, with `net_transform` (`spawn=true`) | correct on the same frame |
| `box`/`sphere`/`pill` | **none** | stayed at (0,0,0) forever |

Being static, nothing replicated the pieces' transform after spawn — the error was permanent.

**Fix.** `library3D/sceneries/scenery_piece.gd` (`class_name SceneryPiece`): `spawn_position`,
`spawn_rotation_y` and `spawn_scale` as `@export`s whose setters apply to the node itself, replicated
by a `ServerSynchronizer` with `replication_mode = 0` (**spawn only** — zero traffic afterwards,
which is right for a body that never moves). `_spawn_job` copies the transform into those properties
BEFORE `add_child` (the only way they make it into the creation packet). Same pattern as the player's
`spawn_position`.

**Validated** with the same comparative test: the nine pieces now match decimal for decimal between
server and client (`7.48,1.00,10.37`, `-13.08,1.00,13.89`, …).

### Importer + contract generator (`scripts/scenery_contract.gd`)

A DEVELOPMENT tool (the exported `.exe`'s `res://` is read-only, so scene preparation happens in the
project, never at runtime):

```bash
godot --headless --path . --script scripts/scenery_contract.gd             # validate and report
godot --headless --path . --script scripts/scenery_contract.gd -- --apply  # fix and save
```

- **Validates** each `library3D/sceneries/<name>/<name>.tscn` against the contract and exits with
  code 1 when something is missing (usable as an automated check).
- **Fixes** (`--apply`) by attaching the script + `ServerSynchronizer` to scenes that lack them.
- **Imports** a new model: a folder holding a `.glb`/`.gltf` but no `<name>.tscn` yet gets a
  generated scene — `StaticBody3D` root carrying the contract, the mesh instanced, and a box
  `CollisionShape3D` from the aggregate AABB (an editable starting point; tighten it by hand later).

The contract rule lives in **one place only** — `SceneryPiece.contract_issues()` / `meets_contract()`
/ `make_spawn_config()` — queried by both the tool and the runtime, so the tool can't approve under
one criterion while the game breaks under another. Hence `SceneryPiece` extends `Node3D` rather than
`StaticBody3D`: the contract applies to any 3D root.

**On-screen validation (BOTH managers).** The warning shows the moment a model is PICKED in the
cascade — an amber label under the dropdowns: *"Warning: this model spawns at (0,0,0) for anyone
joining over the network — …"*, listing what's missing. There is also the save-time alert (listing
the template's problematic models) and one `push_warning` per scene in `_spawn_job`, carrying the fix
command.

Each category answers for ITS OWN requirement, via `TemplateManagerBase._node_contract_issues`:

- **sceneries** → the full `SceneryPiece` contract (they are static: if the transform doesn't arrive
  in the spawn packet, nothing fixes it afterwards);
- **characters** → replicating the transform on spawn (`net_transform`/`spawn_position`) is enough,
  since whoever replicates it also keeps correcting it. Checked by `replicates_transform()`.

Results are memoised per `scene_path` (`_contract_cache`) — the cascade re-queries on every click and
the check instantiates the scene.

**`characters/jogador/jogador.tscn` fixed (2026-08-07).** It was a `Node3D` + GLB mesh, no script, no
AI and no synchronizer — a character only by folder, in practice a static piece — so it got the same
contract, applied by the tool itself:

```bash
godot --headless --path . --script scripts/scenery_contract.gd -- --root=res://library3D/characters --only=jogador --apply
```

Hence the two new parameters: **`--root=`** (point at another library) and **`--only=`** (limit to ONE
folder — without it, an `--apply` over `characters` would also GENERATE scenes for `humanoide`,
`monstro` and `mulher`, which only have `.glb` and aren't ready for the manager yet). Two guards
protect scenes that have behaviour: the tool **never overwrites an existing script**, and it reports
`ok (replicates the transform through its own script)` for those already meeting the requirement via
`net_transform` (player, playera, red_robot, criatura_alada). Validated over the network: the three
`Character_jogador_*` match exactly between server and client.

It cannot be fixed at runtime: the spawn properties must exist in the SCENE, which both sides
instantiate — hence the tool does the fixing and the screen only warns.

**The client never builds sceneries** — it never applies a template: the server materialises the room
and the `MultiplayerSpawner` replicates it. "Loading the exact same initial information" is precisely
what the spawn properties guarantee. General rule: **anything dynamic must propagate to every
connected listener** — state that changes at runtime needs continuous replication in the
`replication_config`; creating/removing pieces already travels on its own through the spawner.

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
  `levels` screen and by `host_session` (since 2026-08-06, BOTH — characters and sceneries).
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

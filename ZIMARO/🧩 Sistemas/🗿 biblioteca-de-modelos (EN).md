---
tipo: sistema
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 🗿 Model Library (Models screen)

Screen `scenes3D/models/models.tscn` (`models.gd`): browser + extractor of the
project's 3D models. Reached via **developer → 3D Models**; returns with
"Back" (→ developer) and opens the gallery with "Exported" (→ `Exported.tscn`).

## 🧭 3D axis gizmo (orientation)

Editor-style orientation indicator at the **top right**: three colored axes (X red, Y
green, Z blue) with a ball and letter at the tip, which **rotate together with the model** (`_gizmo_node.rotation =
model_holder.rotation` in `_process`). Built in code (`_setup_axis_gizmo`) in its **own SubViewport**
(`own_world_3d`, `transparent_bg`, MSAA) with an orthographic camera looking down -Z — so it **is never
covered by the model** and is independent of zoom. The overlay is repositioned each frame **to the left of the
column of toggles** (`_position_gizmo_overlay`), so it covers neither the UI nor the model (centered),
at any resolution. **Unshaded** materials (full color, legible without light). Tunables: `_GIZMO_SIZE`,
`_GIZMO_ARM`, `_GIZMO_BALL`.

## 📚 Asset library

Everything under `res://library3D/<type>/<model>/`:

- `characters/` — `player`, `players`, `red_robot`, `criatura_alada`, `demonio_*`,
  `mecha07_infantil`, `enemies/` and the **14 robots** `robot_01..07_*_{infantil,adulto}`
  (imported from `C:\GODOT\MODELOS\robos_3d_godot_infantil_adulto` in 2026-06-16; "robot" prefix)
- `propulsores/` — `forklift` (was `props/` in the old version of the note)
- `structures/` — `core`, `core_out_light`, `door`, `lights`, `props`, `structure`
- `weapons/` — `bomb`, `pistola_infantil`
- support folders (NOT categories): `geometry/` (`.tres` materials), `textures/`, `extracted/` (output)

`_scan_library()` scans only the **4 fixed categories** in `const CATEGORIES`
(characters/propulsores/structures/weapons — support folders like geometry/textures
are ignored on purpose). A new model in `library3D/<type>/<name>/` with a `.glb`
appears on its own — nothing to edit in code.

> [!warning] Compatibility with the EXPORTED BUILD (2026-06-21)
> In the exported `.exe`, the source files do not go raw in the PCK: the `.glb` becomes **`<name>.glb.import`** and the
> `.tscn` becomes **`<name>.tscn.remap`** (both point to the imported resource). That is why the scanner
> normalizes each name with **`_logical_name()`** (strips the `.import`/`.remap` suffix → logical path,
> which `load()` resolves in the editor AND in the export). Without this, `_find_model_file` found nothing and the
> **Category menu was empty in the `.exe`** (it worked in the editor). Validated: editor and export find
> the same 21/1/6/2 models.

### 📄 Importable file types (scanned)

The browser recognizes **only 3 extensions** (case-insensitive), only of files
**directly in the model's folder** (subfolders like `audio/`, `bullet/` are ignored):

| Extension | Role |
|---|---|
| `.glb` / `.gltf` | raw imported mesh (glTF 2.0) — **preferred** |
| `.tscn` | assembled Godot scene — **fallback** |

> [!warning] Formats like `.obj`, `.fbx`, `.dae` **do not appear** in the browser.
> They need to become `.glb`/`.gltf` (or a `.tscn` scene) first. glTF (`.glb`/`.gltf`) is
> the format recommended by Godot for a complete model **with animation** (mesh +
> skeleton + skinning + clips); `.blend`/`.fbx`/`.dae` also animate but depend on
> Blender/FBX2glTF; `.obj` only imports a static mesh.

Each model resolves **two** paths, by two distinct functions:

- **`_find_model_file()`** → `path` (the **mesh**, base of the parts catalog). It prefers,
  in this order: a `.glb`/`.gltf` whose basename **matches the folder** (e.g.: `red_robot.glb`
  in `red_robot/`), then any `.glb`/`.gltf`, then a homonymous `.tscn`, then
  any `.tscn`. The raw mesh wins because it shows the geometry **without running the gameplay
  script**. The "name = folder" criterion prevents a sibling scene (e.g.: `bomb.tscn` in
  `criatura_alada/`, the projectile) from being confused with the model.
- **`_find_display_file()`** → `display_path` (the **"Whole model"** scene). It prefers
  the **`.tscn`** (loads materials, effects, and the intended visible variant that the raw `.glb`
  does not have), falling back to whatever `_find_model_file` resolves (the `.glb`) when there is no scene.

After choosing a model, `_on_model_selected` does `load()` of both paths and
`_build_mesh_catalog` instantiates the scene, scans all the `MeshInstance3D` and **deduplicates
them by the shared `Mesh` resource** (`get_instance_id`) — each distinct mesh lists once,
ordered by number of placements, with a `[skin]` (skinning/animation) or `[+col]` mark.

## 🖥️ Screen flow

**Category → Model → Part**, with **sequential selection** (2026-06-16; the **Prefix**
dropdown was removed in 2026-06-30 — upon choosing the Category, the Model combo already
lists **all** the category's models, with no intermediate filter):
each dropdown below Category stays **disabled** until the one above has a real
choice. Every dropdown starts with the **"Select..."** placeholder (item 0,
default — see [[🔽 dropdowns (EN)|dropdowns]]); selecting it reloads/unlocks the
dependents also at "Select..." and clears the preview. The "Part" dropdown lists
`Select...`, then `Whole model`, then the **distinct** meshes (dedup by
`Mesh` resource via `get_instance_id`), label `Name (×N) [+col]/[skin]` ordered by
use. The preview shows the selected part, centered/scaled (`_fit_to_view`). The
dropdowns are native `OptionButton`s (no lists of buttons).

The **"Animation"** (`AnimationRow`) and **"Special Effects"** (`EffectsRow`, below
Animation) combos only appear when the Part is **"Whole model"**:
`_populate_animations()`/`_populate_effects()` show the rows and
`_reset_animations()`/`_reset_effects()` hide them (placeholder and isolated parts). Both only
apply to the assembled model.

- **Special Effects (2026-06-18):** after "Select...", it lists the **"All"** option (shows
  all effects) and displays **effects of all types** that exist — lights/luminosity
  (and shadows), smoke/particles, decals, fog (`FogVolume`), particle attractors/colliders
  and bone-attached meshes (muzzle/laser). Collected by `_collect_effect_nodes` via the
  `_EFFECT_CLASSES` list (`node.is_class(...)`, catches subclasses). "All" is only included **when there are**
  effects; with no effects, the combo stays at just the placeholder and disabled.

> [!note] StatusLabel removed (2026-06-18)
> The status line (the red label that guided "Select a/an …" above the combos) was
> **removed** from the screen — the `StatusLabel` node left the scene and all the status code
> (`_set_status`/`_apply_status`/`_clear_status`/`_update_whole_model_status`/
> `_refresh_whole_model_status`, `_status_*` vars and orphan onready `selectors_box`/`*_row`) and the
> message keys in the JSONs were deleted. Navigation is guided only by the sequential gating
> of the dropdowns.

**Reset cascade (2026-06-16):** changing any selector resets **all** the ones
below to "Select..." and re-enables only the immediate child. The reset functions
(`_reset_meshes_and_preview`, `_on_model_selected`) now also call
`_reset_animations()`+`_reset_effects()`, so the two combos below join the
cascade (before they got "stuck" visible when switching a selector above).

> [!info] No status line (2026-06-18)
> The screen **no longer has** the `StatusLabel` that showed "Select a/an …" prompts (category/
> prefix/model/part/animation/effect) nor the old part count. The guidance comes only
> from the sequential gating of the dropdowns (each combo disabled until the one above has a real choice).

### 🔄 Preview rotation

Separate `_yaw`/`_pitch` → `model_holder.rotation = Vector3(_pitch, _front_yaw_base + _yaw, 0)`
(roll always 0, only orthogonal axes). `_front_yaw_base` is the model's **BASE frontal orientation**
before the drag (default `DEFAULT_FRONT_YAW = PI`, the 180° flip of the front=-Z convention). **Per
model (2026-06-21):** `_MODEL_FRONT_YAW` overrides this base — `player` and `red_robot` were
exported with the **front facing +Z** (same direction as the camera), so the 180° flip showed them from
**behind**; with `0.0` they **open up facing forward**, without the user needing to rotate. Set in
`_on_model_selected` (and reset in `_reset_meshes_and_preview`). When dragging, **both** axes
go up to **±180°** (2026-06-16): `_yaw` (left/right) rotates the model to its back and
`_pitch` (up/down) tips the model upside down. The model is **leveled** before
the rotation: `_preview_whole_model()` zeroes the built-in rotation of the `.glb` root
(ignoring angular tilts). Dragging with the left button over the 3D area
moves yaw/pitch; the **Rotate** toggle enables/disables the automatic rotation (yaw only, no
lock — spins like a turntable). The root `UI` has `mouse_filter = 2` so the drag reaches
`_unhandled_input`.

**Preview "cruft" cleanup (2026-07-03, `_strip_preview_cruft`):** some gameplay scenes
carry nodes that do not belong in a static preview — `player.tscn`, for example,
embeds a camera rig (`CameraBase/.../Camera3D`) and a game UI (`Crosshair` `TextureRect`
+ a fullscreen-**anchored** fade `ColorRect`). Since the `UI` containers are
`mouse_filter = 2` (ignore), the drag over the 3D area **fell onto that `ColorRect`** (default
`STOP`) instead of reaching `_unhandled_input` — result: **only the player "would not rotate"** (the
other models have no embedded Control). Besides that, the embedded `Camera3D` stole the `current`
and triggered *Physics interpolation* warnings every frame. Fix: right after `_strip_scripts`,
`_preview_whole_model()` calls `_strip_preview_cruft(instance)`, which **frees every `Camera3D`,
`Control` and `CanvasLayer`** in the instantiated subtree **before** it enters the tree. A general fix
(applies to any model that brings these nodes), it keeps the preview 100% static and zeroes the warnings.

### 🎚️ Toggles (preference + persistence)

> [!note] Toggle nodes without the "Toggle" suffix (2026-06-28)
> The toggles' `CheckButton` nodes had the **"Toggle" suffix removed from the name** (a request to clean up the
> 2D Debug tooltips): `Rotate`, `Animation`, `Effects`, `Audio`, `Colliders`, `Labels`, `SubCollider`,
> `SubMemberLabel`, `AuxHighlight` (before `…Toggle`). The `%`-accessors in `models.gd` follow suit; the
> GDScript **variables** (`rotate_toggle`, `colliders_toggle`, …) and the `_show_*` methods did **not** change.
> **"Check" suffix also removed (2026-06-28):** the `CheckButton`s whose name ended in "Check"
> lost the suffix: `Malha`, `Osso`, `SkeletonLines`, `Type`, `Name`, `Id` (before `…Check`). The
> `%`-accessors in `models.gd` follow suit; the variables (`malha_check`, `osso_check`, `type_check`…) and
> the `_show_*` methods did **not** change.

> [!important] Node names → descriptive English (2026-06-29)
> Renaming of the Models screen's **controls** (node names only; **displayed texts and persistence
> unchanged**):
> - **Dropdowns:** `cbo` prefix removed — `cboCategory→Category`, ~~`cboPrefix→Prefix`~~
>   (the **Prefix** dropdown was **removed** in 2026-06-30),
>   `cboModels→Models`, `cboMeshes→Meshes`, `cboAnimations→Animations`,
>   **`cboEffects→EffectsList`** (could not become `Effects`: that is already the effects `CheckButton` node),
>   `cboMembers→Members`, `cboMemberGeo→MemberGeo`, `cboSubMembers→SubMembers`,
>   `cboSubMemberGeo→SubMemberGeo`, `cboSkeleton→Skeleton`, `cboSkeletonGeo→SkeletonGeo`.
> - **Toggles (`CheckButton`):** `Malha→Mesh`, `Colliders→MemberLimbCollider`, `Labels→MemberLabel`,
>   `SubCollider→SubMemberLimbCollider`, `AuxHighlight→SkeletonLimbCollider`, `Osso→SkeletonLabel`.
> - **Axis gizmo:** `AxisGizmoOverlay→AxisGizmo` (the `SubViewportContainer`).
> - **Damage and AI buttons/panels (without the type suffix):** `DamageButton→Damage`, `AIButton→AI`,
>   `DamagePanel→Damage` (window), `CloseButton→Close`, `AICloseButton→AIClose`, `DamageTree→Limbs`.
>   **Name collision:** the button **and** the window become "Damage" (different parents, OK as a node), but the
>   unique `%Damage` goes to the **window**; the **button** is resolved by path (`$UI/Actions/Damage`,
>   without `unique_name`). `AIPanel` was left as is (not requested), so `%AI` (button) does not collide.
> - **Damage panel footer redesigned:** the "Add sub-member" section became a **3-column `GridContainer`**
>   (bone · owner · button) so the headers align at the SAME width as the dropdowns
>   below. The owner dropdown's **tooltip** ("Owner member…") stopped being a tooltip and became a
>   **visible full-width label `OwnerHint`** above the section (a new key in `models.{pt,en}.json`).
>   Controls created in code now have a name (before `@label@…`/`@optionbutton@…`): `Separator`,
>   `OwnerHint`, `AddArea` (grid), `AddTitle`/`OwnerTitle`/`Pad`, `Bone`/`Owner`/`Add`; and the items of the
>   AI list: `<key>`/`Content`/`Enabled`/`Description`.
> - **AIPanel — tooltips removed:** each behavior checkbutton already shows the description as a
>   **label right below** it, so the `tooltip_text` (which duplicated the description) left the toggle **and**
>   the `Description` — the "text only on the label below, no duplicated tooltip" rule.
> - **Mesh dropdown label:** text **"Part:" → "Mesh:"** (`Mesh:` in en; key in
>   `models.{pt,en}.json` migrated from `Parte:` to `Malha:`).
> - **VBox `Selectors`:** lost the `size_flags_horizontal = 3` (no longer stretches the whole row) and
>   gained a **`Spacer`** sibling (expand-fill) before `Toggles`, shrinking the column to ~half and
>   keeping the toggles fixed to the right.
>
> The `%`-accessors in `models.gd` follow suit; the GDScript **variables** (`cbo_*`, `*_check`,
> `*_toggle`) and the `_show_*` methods did **not** change.

Current toggles (order/names in 2026-06-23): **Mesh · Rotate · Animation · Special effects · Audio ·
Member Collider · Member · Sub-member Collider · Sub-members · Skeleton Collider ·
[Skeleton · Skeleton Lines · Type · Name · ID]**. (Renamed from "Colliders
of X" → **"Collider of X"**; `SubCollider`/`SubMemberLabel` moved to the top, right
**below "Member"**; **"Mesh" promoted to 1st in the list** and **"Damage" is no longer a toggle** —
it became the **`DamageButton` button** to the right of "Back", see below.)

> [!note] Type/Name/Id labels on the Skeleton and Sub-member + exclusivity (2026-06-23)
> - **Type/Name/Id** (pink/green/yellow colors from `_LABEL_LINE_COLORS`) now also appear over the
>   **Skeleton** (`_label_aux_bones`) and **Sub-member** (`_label_sub_member`) labels, via
>   `_add_tni_lines` — describing the ELEMENT (node class · bone/sub-member name · node id). The
>   Type/Name/Id handlers refresh member+sub-member (`_refresh_member_overlays`) and skeleton
>   (`_refresh_aux_labels`).
> - **Bug fixed:** the "Member:" stack no longer appears over **sub-members** — `_add_member_labels`
>   skips `PART_*` bodies (an element is a Member OR a Sub-member, never both).
> - **Exclusivity:** `_aux_bone_candidates` already only offers non-member bones (`group_of==""`) to
>   promote; `_on_sub_member_added` still blocks + warns if a Member bone gets there.

> [!note] LOCALIZED 3D label prefixes (2026-06-25)
> The `Label3D` prefixes — **"Member:" / "Sub-member:" / "Skeleton:" / "Type:" / "Name:"** (and "ID:") —
> pass through `Locale.tr_key(...)` at construction (`_add_member_labels`, `_label_aux_bones`,
> `_label_sub_member`, `_add_tni_lines`), so they appear translated in BOTH languages (before "Member/
> Skeleton/Sub-member" stayed in PT in the EN, and "TYPE/Name" in EN in the PT; "Submembro:" became "Sub-membro:").
> Since `Label3D` does NOT go through Locale's auto-translator, `_on_language_changed` now calls
> `_refresh_member_overlays()` + `_refresh_aux_labels()` to rebuild the stacks in the new language.
> New keys in `models.{pt,en}.json`: `Tipo:`/`Nome:` (prefixes) + the `Type`/`Name`/`Skeleton Lines` toggles.

> [!note] Member × sub-member color scheme + sub-member label fix (2026-07-03)
> **Colors** (each toggle's text matches the 3D element it controls — constants at the top of
> `models.gd`):
> - **Member** → colliders **LIGHT BLUE** almost transparent (`_MEMBER_COLLIDER_FILL`, gizmo) and the
>   *Member Collider* toggle text (`_MEMBER_COLLIDER_COLOR`); **DARK BLUE labels** (`_LABEL_LINE_COLORS["Member"]`,
>   also on the *Member* toggle).
> - **Sub-member** → colliders **LIGHT PURPLE** almost transparent (`_SUB_COLLIDER_FILL`) and the toggle text
>   *Sub-member Collider* (`_SUB_COLLIDER_COLOR`); **DARK PURPLE labels** (`_SUB_LBL_COLOR`, also on the *Sub-members* toggle).
> - **Skeleton (standalone bone)** → highlight/box **LIGHT ORANGE** almost transparent (`_AUX_HL_COLOR`) and the text
>   of the *Skeleton Collider* toggle (`_AUX_HL_TEXT_COLOR`); **"Skeleton: …" labels DARK ORANGE**
>   (`_AUX_LBL_COLOR`, also on the *Skeleton* toggle). (2026-07-03)
> - `_add_collider_gizmos` chooses the material by group (`PART_*` → purple; otherwise blue), via the helper
>   `_make_gizmo_material(fill)`. `_apply_label_line_colors` (rewritten in a single dict/loop) paints the 9
>   toggles with color: member/sub/skeleton (dark label × light collider) + Type/Name/ID. The old single green
>   of the colliders (`0.2,1.0,0.4`) and the single orange of the skeleton (`1.0,0.6,0.1`) were replaced;
>   the `"Osso"` key of `_LABEL_LINE_COLORS` left (the toggle now uses `_AUX_LBL_COLOR`).
>
> **Label size:** member and sub-member share `_LBL_FONT_SIZE`/`_LBL_PIXEL_SIZE` (same
> text size — confirmed in the .exe: "Member:" and "Sub-member:" come out identical).
>
> **Bug fixed:** when turning on the **Sub-members** toggle (label) in the **"All members" → "All
> Sub-members"** mode, NO label appeared — `_refresh_sub_member_labels` only handled an individual `PART_`
> (the value `ALL_SUB_MEMBERS_VALUE` does not start with `PART_` → early return). Now, in this mode, it labels
> ALL sub-members (mirroring the collider toggle), ensures the bodies with `_ensure_member_colliders`
> and the clear moved from `_label_sub_member` (called in a loop) to the caller (once only).

> [!note] Labels gated by the dropdown at "Select..." (2026-07-04)
> Each 3D-label family only shows when ITS dropdown has a real choice (≠ "Select..."), uniformly:
> - **Sub-member** (`_refresh_sub_member_labels`) and **Skeleton** (`_refresh_aux_labels`) already did
>   this (early return with `cbo_sub_members.selected <= 0` / `cbo_skeleton.selected <= 0`).
> - **Member** was the exception: with the Member dropdown at "Select..." the "Member:" stack showed on
>   ALL members. Now `_apply_member_labels_visibility` applies the same gate — `if member_row.visible and
>   cbo_members.selected <= 0: return` (clears the stacks and does not rebuild). "All members" (index 1)
>   and a specific member (index 2+) still show; only the placeholder hides. Since the Type/Name/ID lines
>   live in the SAME stack anchored to the member body, they also disappear with no member selected.

> [!note] "Mesh" and "Skeleton Lines" (from the old developer screen, 2026-06-23)
> - **Mesh** (`Malha`, **1st toggle in the list** since 2026-06-23, key `show_malha`, default ON):
>   shows/hides the model's mesh (`MeshInstance3D`) in the preview (skips gizmos with a `_…` name). `_apply_malha_visibility`.
> - **Skeleton Lines** (`SkeletonLines`, below Id, key `show_skeleton_lines`): draws
>   the white bone→parent lines of the preview, redone every frame from the live pose (`_refresh_skeleton_lines`
>   / `_update_skeleton_lines`, gizmo `_SkeletonLines`). It is DIFFERENT from "Skeleton" (which shows the bone
>   NAME). Effect **only in this scene** (the preview). Both persist in the `models` config section.

> [!note] Renames and new toggles (2nd batch, 2026-06-22)
> - **Colliders** → **Member Colliders** (`Colliders`, `_show_colliders`).
> - **Skeleton** (the orange highlight, `AuxHighlight`/`_show_aux_highlight`) → **Skeleton Colliders**.
> - **SubMember** (`Osso`/`osso_check`/`_show_osso`, top of `LabelLinesRow`) → **Skeleton**; the
>   Label3D now displays **"Skeleton: \<name\>"** (before just the bone name).
> - **NEW Sub-member Colliders** (`SubCollider`/`_show_sub_colliders`, key `show_sub_colliders`;
>   displayed label **"Sub-member collider"** since 2026-06-25):
>   shows/hides ONLY the limbcollider gizmo of the sub-member selected in the dropdown (FOCUS branch of
>   `_refresh_member_overlays`; a PART_* gizmo follows THIS toggle, a member gizmo follows "Member
>   Colliders"). Sub-members stay HIDDEN in the general view (`_apply_colliders_visibility` hides PART_*),
>   **with one exception (2026-06-25):** with **"All members" + "All Sub-members"** in the dropdowns and
>   this toggle ON, `_apply_colliders_visibility` shows **ALL** the sub-member gizmos at once,
>   regardless of "Member Colliders" (helper `_should_show_all_sub_colliders`).
>   The offset/scale editor also appears for sub-members under this toggle.
> - **NEW Sub-members** (`SubMemberLabel`/`_show_sub_member_label`, key `show_sub_member_label`;
>   displayed label **"Sub-member"** since 2026-06-25):
>   Label3D **"Sub-member: \<name\>"** attached to the body of the selected sub-member
>   (`_refresh_sub_member_labels`/`_label_sub_member`). Only in member-specific mode. **PURPLE color
>   (2026-06-23):** `_SUB_LBL_COLOR = Color(0.6,0.25,0.9)`; the "Sub-members" toggle has **purple text**
>   (`font_color` via `_apply_label_line_colors`, normal background — no `modulate`).

History (1st batch, 2026-06-22): "Per-member damage" became **Damage**; "Highlight standalone" became "Skeleton";
the "Bone" toggle became "SubMember" and moved to the top of the `LabelLinesRow` (the "Labels" toggle was renamed to
**Member** in 2026-06-21 — `Labels` in the `.tscn`, translated "Member" in en; the old "Sound" became **Audio**; the
**Voices** toggle was REMOVED — Audio now covers all emitters, including voices). Each
toggle is the **master switch** of its category:

> [!note] 3D label colors (`_LABEL_LINE_COLORS`)
> Member = cyan · **Type = PINK (2026-06-23, before orange)** · Name = green · Id = yellow ·
> Bone/Skeleton = orange. The **Type** toggle (`Type`) has **pink text** via `font_color`
> (`_apply_label_line_colors`, all states); the `modulate` was **REMOVED (2026-06-25)** so the
> **toggle's background matches the others** (before the `modulate` tinted the whole control pink) —
> same pattern as the "Sub-members" toggle.
> The developer screen's `DebugOverlay` reuses the same colors (Type/Name/Id/Member) + Skeleton white.

> [!important] Models scene 100% decoupled from 3D Debug (2026-06-21)
> The scene's root node is in the **`no_debug_overlay`** group, so the global `DebugOverlay` skips the
> entire Models scene (2D **and** 3D) — the Debug definitions only apply in the **game levels**. The
> preview's member labels (TYPE/Name/ID/Member) now follow **the scene's own dedicated toggles**
> (Member + the Type/Name/ID checkboxes), no longer the global sub-toggles. Gone are the
> `_debug3d_tooltips_enabled()` and every read of `game/*` in `models.gd`.
>
> **Scene name label (2026-06-20 → HIDDEN 2026-06-21):** the local `SceneName` (node in the
> `.tscn`) is now **always hidden** — the name "Models" **must not appear in the damage window**. The
> node is preserved only to avoid breaking `@onready`/references; `_ready` does `visible = false` and nothing
> else shows it. The scene name is already shown by the **GLOBAL watermark** of `debug_overlay.gd` at the
> **top right, next to the title** (which has a 2D Debug tooltip). See [[🐞 debug-overlay (EN)|debug-overlay]].

> [!important] Toggles act **in-place** (2026-06-17)
> No toggle **rebuilds** the preview: the model **is not reloaded** and the
> **camera/rotation stay intact**. Each handler alters the live node
> (`_preview_instance`) through a dedicated applier instead of calling a rebuild.

- **Animation** — an animation only runs when **both**: the toggle is on **AND** a clip
  is chosen in the "Animation" dropdown (2026-06-18). With the toggle off **nothing animates**
  (`_on_animation_selected` returns early); with the toggle on but the combo at "Select..."
  **nothing runs either** — there is **no more auto-play of a default/idle clip**. Playback is applied
  **in-place** by `_apply_animation_state()` (`should_play = _play_animation and chosen != ""`;
  plays the chosen clip in whoever has it, stops all the other `_preview_anim_players`).
  **Back to "Select..." (2026-06-23):** when nothing should play, beyond `stop()` (which only
  FREEZES the current pose), the skeleton is reset to the **REST pose = model's initial state**
  (each bone → `get_bone_rest`, via `set_bone_pose_*`; the models have no "RESET" clip).
  **Loop (2026-06-23):** the chosen clip stays in **loop** — when it ends, `_on_preview_anim_finished`
  (`animation_finished` signal) replays it. Notably, it does NOT touch the resource's `loop_mode`
  (shared with the game). Death/explosion clips do not loop.
- **Audio** — plays **all** the model's emitters (movement walk/run/jump,
  motor, shot, explosion, voices…); off, it silences them. Applied by `_apply_audio_state()`.
  (There is no longer a separate "Voices" toggle.)
- **Colliders** — `_apply_colliders_visibility()` adds/removes the wireframe gizmos
  (`_add_collider_gizmos`, idempotent, node `_ColliderGizmo`) **without a rebuild**; builds the
  member colliders on demand once (`_ensure_member_colliders`). For **Characters/
  Weapons** it draws a gizmo **only for the MEMBER colliders** (`_is_member_collider`, meta
  `member_label`); it skips the model's generic body collider (e.g.: the red_robot's body capsule)
  and the detection/death areas, which were just noise surrounding everything (2026-06-18).
  - **Real-time refit during animation (2026-06-23):** the colliders are attached to the bones
    (`BoneAttachment3D`), so they already follow **translation/rotation**. While an animation plays **and** the
    colliders are visible, `_process` calls `_member_lc.refit(_member_skel)` (`limb_colliders.gd`):
    it recomputes the AABB of each member/sub-member in the **CURRENT pose** of the bones and re-fits the shape +
    gizmo — so the colliders **follow the bending** of the multi-bone limbs. Only in the preview (rigs without
    a skeleton already follow the animated node).
    - **Performance (2026-06-23):** the refit was ~150 ms/call because `surface_get_arrays`
      rebuilt the mesh arrays every frame. Now there is a **cache** (`_build_refit_cache`): per
      vertex it stores group + dominant bone + `bind_pose·vertex`; the refit only reads the CURRENT poses of the
      bones → **~4 ms** (33× faster). The cache is built **when constructing the colliders**
      (`_add_member_colliders`), moving the one-time cost (~150 ms) OUT of the animation. Besides that,
      an **adaptive throttle** in
      `_process` (interval = `elapsed·30`, cap 10 Hz / floor 2 Hz) keeps the cost at ~3% → **≥ 60 FPS**,
      with denser models re-fitting fewer times. (The 1st call still builds the cache ~150 ms once.)
  - **Collider geometry + per-member/sub-member/standalone-bone Offset/Scale window (2026-06-25,
    replaces the inline editor):** when choosing a **real** item (not "Select..."/"All") in **Member**,
    **Sub-member** or **Skeleton**, a **geometry dropdown** appears **to the right** of that dropdown
    (`cboMemberGeo`/`cboSubMemberGeo`/`cboSkeletonGeo`; items "Select..." + Sphere/Box/Capsule with
    metadata `""`/`sphere`/`box`/`capsule`) **and** the **REUSABLE floating window** opens
    ([[📌 ancoragem-ui (EN)|FloatingWindow]] from controls2D) — `_open_or_update_collider_dialog`,
    attached to the `UI`, `modal=false` (you can rotate the model), position remembered in
    `windows/models_collider_dialog` — with **Offset**, **Rotation** (degrees) and **Scale** X/Y/Z, **titled
    with the item's name**. Each change **persists on the spot** (`LimbConfig.set_collider_offset`/`set_collider_rotation`/
    `set_collider_scale`, **no Save button**) and applies **LIVE** (`_apply_collider_xform`: offset →
    `body.position`; rotation → `body.rotation_degrees`; scale → the shape's `scale`). The **geometry dropdown** writes `LimbConfig.set_collider_shape` and
    **rebuilds** the colliders (`_rebuild_member_colliders`): on a **MEMBER**, "Select..." = `SHAPE_NONE`
    → **removes the collider** (member with no hitbox); on a **SUB-MEMBER**, "Select..." = `SHAPE_NONE` **SUPPRESSES the
    collider** but **keeps the sub-member** in the tree/dropdown (preview body suppressed — see `include_suppressed`
    below) to reconfigure; total removal is via the trash icon of the Damage tree. For a **STANDALONE BONE** (Skeleton),
    choosing a geometry does **NOT promote** it (2026-06-25): it only persists the preview shape (`set_collider_shape`) and the
    **"Skeleton Collider"** highlight starts drawing in that geometry (see below) — the promotion (actually creating the
    collider) still happens in the Damage window ("Add sub-member"). Skeletons **have no damage and do not enter the levels**
    (preview-only). **Pre-selection of the 3 dropdowns (3 states, 2026-06-25, `_select_geo_for_group`):** saved shape
    (sphere/box/capsule) → **LOADS** the last choice; `SHAPE_NONE` → **"Select..."** (no collider, explicit);
    **no choice ("") → AUTO-DETECTS** — the collider's LIVE shape (`_live_shape_kind`, member/sub have a body) or by the
    **bone's shape** (`_auto_geo_for_box`/`_auto_geo_for_group` via AABB: elongated→capsule, round→sphere, otherwise box).
    **Suppressed sub-member stays VISIBLE (`include_suppressed`, 2026-06-25):** the preview sets `lc.include_suppressed
    = true`; in `build_for`, a `SHAPE_NONE` sub-member is still built (automatic shape, meta `suppressed`,
    **no gizmo** — `_add_collider_gizmos` skips it) to stay in the tree/dropdown; in gameplay (flag false) it is SKIPPED.
    Everything is **re-read at spawn** via `LimbColliders` (`make_member_shape` honors the override;
    `build_for`/`_add_mesh_member_colliders` skip `SHAPE_NONE` groups). **Geo visibility (2026-06-25):**
    the **Member** geo disappears when a **specific sub-member** (`PART_*`, ≠ "Select..."/"All Sub-members")
    is chosen — then the sub-member's geo applies (same precedence as the Offset/Scale window). Logic in
    `_refresh_collider_editors` / `_on_*_geo_selected` / `_sync_collider_dialog` / `_current_edit_target`.
    The old inline `ColliderEditBox` + **Save** button + `_prompt_save_offset_if_dirty` were **REMOVED**.
    See [[🩸 dano-localizado (EN)|dano-localizado]].
- **Special effects** — shows/hides **everything left over** attached to the model that
  no other toggle covers: particles, lights, decals/fog and bone-attached meshes (muzzle/
  laser), collected by `_collect_effect_nodes` (`_EFFECT_CLASSES` list). The **"Special
  Effects"** combo isolates **one** effect (shows only it); **"Select..."** and **"All"** (item 1,
  2026-06-18) show **all** (only with the toggle on). Visibility is applied by
  `_apply_effects_visibility` (`sel <= 1` = all; `>1` = isolated) without rebuilding the preview.
- **Member · Type · Name · ID** (2026-06-21; the **Member** toggle was called "Labels" until
  2026-06-21 — only the TEXT changed, the node is still `Labels`/`labels_toggle`) — the member tooltip
  stack (TYPE/Name/ID/Member) is now **entirely local** to the Models scene, with nothing from the global 3D Debug.
  **Member** (CheckButton) turns on
  the "Member: …" line; **Type/Name/ID** are 3 `CheckButton`s (toggles) **stacked vertically** in the
  `LabelLinesRow` node (a `VBoxContainer` since 2026-06-21 — before they were `CheckBox`es in a horizontal row
  that **cut off the labels** in the narrow column; the vertical stack ensures the 3 texts appear in
  full) that turn on the lines describing the `Skeleton3D`. The member tooltips are drawn with
  a high `render_priority` (always on top of the green gizmos and of each other).
  `_apply_member_labels_visibility` **recreates the stack in-place**
  (clears the `_MdlLbl_Pivot` pivots and re-adds them with the per-line visibility from
  `_add_member_labels`), without a model rebuild. `_any_member_label()` (any of the 4 on) decides
  whether to build colliders/labels. Persisted in `[models]` (`show_member_labels`/`show_type`/`show_name`/
  `show_id`). Designed to **inspect which members** the classifier recognizes (and to request a new member).
  - **Color per line = toggle color (2026-06-20):** each line has its **own color** (Member = cyan-blue,
    Type = orange, Name = green, ID = yellow, Bone = orange — `const _LABEL_LINE_COLORS`) applied to the
    `modulate` of the `Label3D` **and** to the text of the `CheckButton` that controls it (`_apply_label_line_colors`,
    covering the normal/hover/pressed/focus states), so the user can link the control to its 3D label at a glance.
  - **"Skeleton" toggle (standalone-bone label; renamed from "SubMember"/"Bone" in 2026-06-22):** 1st `CheckButton` of the `LabelLinesRow`
    (`Osso`/`osso_check` — node/var name kept; **at the TOP**, right below the "Member" toggle and above Type;
    translated "Skeleton" in en — reuses the `Esqueleto` key). When on **AND** the "Skeleton"
    filter (in "All members" mode) has a chosen bone, it draws an **orange `Label3D`**
    (billboard, no depth-test) with **"Skeleton: \<name\>"** above its region, attached via `BoneAttachment3D`.
    **Independent** of "Skeleton Colliders" (formerly "Highlight standalone"; you can see just the name, just the box, or both) — it follows the SAME
    selection. `_refresh_aux_labels` (called in the member/sub-member handlers, in `_populate_members` and
    `_rebuild_member_colliders`) decides; `_label_aux_bones` draws (`_AuxLbl_*` nodes); `_clear_aux_labels`
    removes. Persisted in `[models]` (`show_osso`). "All Skeletons" labels all at once.
  - **Anti-collision between members (2026-06-20):** the 4 lines of each member sit under a **pivot**
    (`_MdlLbl_Pivot`, child of the collider) so they move together. Each frame `_layout_member_labels`
    projects each member's stack onto a screen rectangle and, processing from top to bottom, **pushes
    down** any that overlaps an already-positioned stack — so sets of distinct members
    never overwrite each other (each set stays whole, "one below the other"). The push is converted
    from pixels to meters (the camera's px/m factor at the anchor's depth, robust to the fit-to-view
    zoom/scale) and applied by moving the pivot in world space (down = `-camera.up`). Indexed in
    `_member_label_pivots`; with no stacks, it is a no-op.
- **Damage** — opened by the **`DamageButton` button** (to the right of "Back", in `UI/Actions`; text "Dano"/"Damage").
  Before it was the `DamageToggle` toggle in the list; in 2026-06-23 it became a **dedicated action button** that invokes the
  Damage screen (`_on_damage_button_pressed` → `_show_damage_panel = true` → `_refresh_damage_panel`); the window's `×` closes it
  (`_on_damage_close`). (The window was renamed from "Per-member damage" in 2026-06-22; the `Title` displays "Damage".)
  — **FLOATING WINDOW (state in 2026-06-21):** the `DamagePanel` is a **draggable floating
  window**, with an **OPAQUE BLACK background**, **600×660**, with **all the controls INSIDE it**
  (the value fields NO longer float over the 3D model — reverted in 2026-06-21).
  - **Window (Windows style):** structure `DamagePanel(PanelContainer, top-left anchor) →
    Main(VBox) → TitleBar(PanelContainer) → TitleRow[Title(IGNORE) + CloseButton ×] · Margin →
    Scroll → VBox → Rows`. `_setup_damage_window` (in `_ready`) gives the `DamagePanel` an
    **opaque black** `StyleBoxFlat` (alpha 1) and styles the `TitleBar` (opaque dark gray), sets `CURSOR_MOVE`
    and connects `gui_input`→`_on_damage_titlebar_input` (click-drag moves `damage_panel.position`, clamped to the
    viewport; a safety net in `_process` releases the drag if the button is released outside the bar) and
    the `×`→`_on_damage_close` (closes the window: `_show_damage_panel = false` + `_refresh_damage_panel`). The **last position is persisted**:
    `_save_damage_panel_pos` writes `Settings.config_file("models","damage_panel_pos")` (a `Vector2`)
    when the drag ends, and `_setup_damage_window` **restores** it on opening (clamped to the viewport;
    default = the `.tscn` position).
  - **TREE (Tree) IN the window (2026-06-21):** `_refresh_damage_panel` builds a `Tree`
    (`DamageTree`, assembled by `_setup_damage_tree` in `_ready`): each MEMBER is a branch; its
    sub-members (PART_*) are leaves UNDER it, shown with the **original bone name** (e.g.: "↳ shoulderpad-adjust.L" under "ARM L"); orphans go to the
    "Other sub-members" branch. **Columns:** 0 Name · 1 **Def** (`CELL_MODE_CHECK`) · 2 **Bonus %**
    (`CELL_MODE_RANGE` −100..500, step 5; editable only with Def on) · 3 **Owner** (`CELL_MODE_RANGE`
    with comma-separated text = dropdown, sub-members only). Check off = **NO own value** (shows the
    inherited EFFECTIVE via `effective_multiplier`); on = explicit (`set_multiplier`). **No value is
    mandatory.** `_on_damage_tree_edited` dispatches by column; `_restamp_damage_metas` re-stamps
    the metas and `_refresh_tree_inherited` re-displays the inherited ones (items in `_damage_field_anchors` =
    `{item,group,owner}`). Re-associating the **owner** (col 3) requires **confirmation** (`_on_tree_owner_edited`)
    and rebuilds the tree. **Footer** below: only the "Add sub-member" line (standalone bone + explicit
    owner + Add → `_on_sub_member_added`). **Removal is per-row (2026-06-22):** each sub-member leaf
    has a **TRASH button to the right of the name** (col 0; red icon generated in code
    by `_make_trash_icon` → `ImageTexture`; `TreeItem.add_button` with id `_TRASH_BTN_ID`), and
    `_on_damage_tree_button` (`Tree.button_clicked` signal) **asks for confirmation** (`FloatingDialog.confirm`:
    "Do you really want to remove the association of the sub-member: &lt;name&gt; ?") and then removes that sub-member
    (2026-06-22) — it replaced the old
    big "Remove sub-member" button in the footer (and the `_on_damage_tree_selected`/`_damage_remove_btn`,
    removed). The owner→child association is saved in `LimbConfig` and **reloaded on each add/remove** (via
    `_rebuild_member_colliders` → `_refresh_damage_panel`). **Row spacing (2026-06-22):**
    `_setup_damage_tree` applies theme overrides (`v_separation`/`inner_item_margin_top`/`_bottom`) so
    the trash icon does not touch the neighboring row. See [[🩸 dano-localizado (EN)|dano-localizado]].
  - **Windows opened OFF-SCREEN — fix (2026-06-25):** the buttons "would not open" because
    `DamagePanel`/`AIPanel` had fixed offsets in the `.tscn` (`offset_left` 1300/1220, for wide screens)
    → at smaller resolutions (e.g.: 1280×720) the window opened (`visible=true`) **outside the viewport, to the
    right** (invisible); the `_setup_*_window` clamp ran only in `_ready` with `size=0`, pinning the
    position to the border. **Fix:** `_clamp_window_to_viewport(panel)` called **deferred on open** (with the
    real size already) repositions the window to fit fully on screen. Panels **enlarged to 760×620** (new
    offsets) so the content (4-column tree / AI list) is not cramped.
  - **Buttons without mutual blocking + per-model scope (2026-06-25):** `_has_active_model_window()` was
    **removed** — neither button is blocked by the other's window. Opening one **closes the other**
    (only ONE floating window at a time, a "switch"). **TOGGLE (2026-06-25):** clicking the SAME button
    (Damage/AI) again with the window already open **closes** it (`_on_*_button_pressed` checks `panel.visible` and closes).
    **Scrolling over the Damage/AI window does NOT zoom the 3D (2026-06-25):** `_unhandled_input` ignores the
    mouse wheel when `_pointer_over_model_window()` (pointer over the visible `damage_panel`/`ai_panel`) —
    the wheel only scrolls the window content; over the 3D, it still zooms. **Dragging also freezes over
    the window (2026-06-25):** the mouse-drag rotation also respects `_pointer_over_model_window()`
    — the camera stops rotating as soon as the pointer enters the window and resumes when leaving it or
    closing it; the helper started including `FloatingWindow.pointer_over_any_window()` (any floating
    window, not just Damage/AI). **Damage applies to ANY model** in "Whole model"
    (`_supports_damage_editor` replaced `_preview_is_whole_character`: it no longer requires the
    "characters" category — weapons/rigs use the member colliders). **AI only for characters** with
    defined behaviors (`_supports_ai_editor` = `AIConfigLib.has_behavior_definitions` — today
    `red_robot`, `player`, `criatura_alada`; the `ai_button` is `disabled` outside this). The button has
    **text "Inteligência Artificial"/"Artificial Intelligence"** (canonical PT since 2026-06-25 — before
    the `.tscn` carried the name in English only and `models.pt.json` mapped it to itself, without translating).
    **Fix 2026-06-25:** `_refresh_ai_panel` aborted on an invalid theme override
    (`content.theme_override_constants.separation = 6`, a dot access that does not exist in GDScript),
    so the AI window NEVER opened (a runtime error before `ai_panel.visible = true`); replaced by
    `add_theme_constant_override("separation", 6)`. See `_on_damage_button_pressed`/`_on_ai_button_pressed`.
  - **AI editor became a `FloatingWindow` (2026-06-30):** the AI panel stopped being a `PanelContainer`
    from the `.tscn` (with manual bar/×/drag/position) and became a **non-modal runtime
    `FloatingWindow`**, created on demand in `_ensure_ai_window` (`remember_position_key = "ai_window"`,
    `min_window_size = (420,480)`). The content (ScrollContainer + `ai_list`) is repopulated by
    `_populate_ai_list`; opening = `_open_ai_window` (`popup_centered`), closing = `_close_ai_window`
    (×/ESC fire `closed` → `_on_ai_window_closed` zeroes the refs). This way the AI inherits the gap, the focus
    ring/ESC, the suppression of the background 2D Debug and the toggle's click-forward (see [[🐞 debug-overlay (EN)|debug-overlay]]).
    Removed from `models.gd`: `ai_panel`/`ai_titlebar`/`ai_close_button`, `_setup_ai_window`,
    `_on_ai_titlebar_input`, `_save_ai_panel_pos`, `_on_ai_close` and the manual drag; the `UI/AIPanel` subtree
    left the `.tscn`. **Damage** still uses its own `PanelContainer` (tied to the per-member damage), with the gap
    applied separately. `_pointer_over_model_window` now covers the AI via `pointer_over_any_window()`.
  - **Damage window focus/Tab + screen's initial focus (2026-06-30):** `_ready` now focuses the
    Tab = 1 control (`UINav.focus_tab_one` → 1st by `tab_order` = Categories). The **Damage window** gained
    a LOCAL focus ring (`UINav.wire_tab_ring(damage_panel, damage_close_button)` in `_refresh_damage_panel`,
    with the **× always last**): `Limbs` 1 → `Bone` 2 → `Owner` 3 → `Add` 4 → **× 5**; it focuses the
    `Limbs` tree on opening. `Bone`/`Owner`/`Add` (runtime) receive `tab_order` via `set_meta`; `Limbs` and `Close`
    have `tab_order` 1 and 5 in the `.tscn`.
  Appears for **ANY model in "Whole model"**
  (`_supports_damage_editor`); `_refresh_damage_panel` repopulates it when switching models and hides on an isolated
  mesh. It is **not** persisted (opens closed). The model key = the folder name
  (`_current_model_key`), same as the gameplay `model_key`. The MEMBERS listed come from the model's
  body plan: since the preview removes scripts (and does not have the `@export body_type`), the screen
  mirrors the type in the const `_MODEL_BODY_TYPE := {"red_robot":"biped","player":"biped"}` and resolves the
  classifier by `_body_type_for_current()`/`_current_classifier()` (`BodyPlans.for_type`).
  - **Members = ALL of the plan (2026-06-21):** the Damage panel and the "Member" combo use
    `_plan_member_entries()` — CHARACTERS list **all** the plan's members (`classifier.members()`,
    even with no geometry in the preview), in the plan's order and with its labels (HEAD/TORSO/ARM L-R/
    LEG L-R); WEAPONS follow the colliders (WeaponParts).
  - **Sub-members nested in the panel (2026-06-21):** each `PART_*` appears **indented (↳, 24px
    margin) under its owner member**, grouped by the SAME `_sub_member_owner_map` as the combos
    (helper `_sub_members_by_owner`) — panel and dropdown agree. A sub-member with no owner in the list goes
    to the **"Other sub-members"** section.
  - **EXPLICIT owner takes precedence in the grouping (2026-06-22):** `_sub_member_owner_map` now uses
    FIRST the owner saved in `LimbConfig.sub_member_owner` (what the user chose when **Adding** or
    in the "Owner" dropdown), only falling back to the `owner_hint`/hierarchy when there is no explicit one. Before, the screen
    ignored the explicit one and regrouped by name/hierarchy — so a newly-added sub-member of a
    member could fall into "Other" and **not appear under the chosen member** (in the tree nor in the "Sub-member"
    dropdown when selecting the member). Now it appears and the link persists/reloads correctly.
  - **"Sub-members" subsection (2026-06-20):** each existing sub-member is a row (label + bonus %
    `SpinBox` + **× (remove)** button, now nested — see above). The **add** line
    (`_add_sub_member_add_row`) is an
    `OptionButton` (`_aux_bone_candidates`) with the AUXILIARY bones of the preview's skeleton
    — those whose classifier `group_of` gives "" — + an "Add" button. `_on_sub_member_added`/
    `_on_sub_member_removed` call `LimbConfig.add_sub_member`/`remove_sub_member` and **rebuild**
    the preview's colliders (`_rebuild_member_colliders` → `_clear_member_colliders` +
    `_ensure_member_colliders`), replacing gizmos/labels. The main members remain editable
    as before; only the `PART_*` get this subsection. See [[🩸 dano-localizado (EN)|dano-localizado]]. The const
    `_MODEL_STANDALONE_BONES` was **removed** (sub-members now come from `LimbConfig`/plan).
  - **Sub-member PRESERVES the original name (2026-06-22):** when **added to an owner member**, the
    `PART_*` **keeps the bone's ORIGINAL NAME** (the owner only groups the damage; it does not rename). `_part_label`
    was simplified to `return bone_name` — the old label **"PLATE \<MEMBER\>"** (e.g.: "PLATE ARM L")
    was discarded on request. The owner resolution (`resolve_sub_member_owner`) still applies for the
    damage grouping/inheritance, it just no longer changes the displayed label.
  - **Under which MEMBER the sub-member appears (2026-06-21):** the "Sub-member" dropdown groups each
    `PART_*` by the owner resolved by **`LimbColliders.resolve_sub_member_owner`**: 1st the piece's **NAME**
    (`owner_hint`), 2nd **climbs the hierarchy** trying
    `owner_hint`/`group_of` on each ancestor. It unlocked: the **player's shoulder pads**
    (`shoulderpad-adjust`, children of `chest`) → ARM by name; the **red_robot's arm shields**
    (`L-/R-Shield`, children of `L-ARMIK`) → ARM via the parent `L-ARMIK` in the hierarchy. Both **grouped under
    ARM L/R**, but shown with the **original bone name** (see the item above). Bones that are already a MEMBER (e.g.: `L-Shoulder` → ARM) do NOT enter the
    "Add sub-member" list. See [[🩸 dano-localizado (EN)|dano-localizado]].
  - **"All members" option (2026-06-21):** the "Member" dropdown has,
    right after "Select...", the **"All members"** item (`ALL_MEMBERS_LABEL`/`ALL_MEMBERS_VALUE`,
    translated "All members"; re-translated on a language switch as "Whole model"/"All"). It
    **shifts the members to indices 2+** (`_member_value`/`_member_index_for_value` treat index
    1 = sentinel). When chosen, it **shows ALL the members** (no isolation).
  - **Three separate dropdowns — Member · Sub-member · Skeleton (restructured in 2026-06-23):** the
    `cboSubMembers` ("Sub-member:", right below "Member") is now ALWAYS the list of sub-members —
    never again the standalone-bone filter. With a **specific member** it lists that member's `PART_*`;
    with **"All members"** it offers **ONLY "Select..." and "All Sub-members"** (2026-06-25 — INDIVIDUAL
    sub-members only appear when choosing a specific member). **"All Sub-members"**
    (`ALL_SUB_MEMBERS_LABEL`/`ALL_SUB_MEMBERS_VALUE`) does not isolate, shows the whole model — **and, with "Sub-member
    Colliders" ON, it displays the gizmos of ALL the sub-members at once** (`_should_show_all_sub_colliders`).
    The **standalone bones** left for their OWN dropdown **"Skeleton"**
    (`SkeletonRow` → `cboSkeleton`, static "Skeleton:" label auto-translated), shown **only in "All members"
    mode** and **always visible in that mode** — when the model has no candidate standalone bones,
    it appears **disabled** (only "Select..."). It lists `_aux_bone_candidates`
    (`group_of == ""`, not promoted), with **"All Skeletons"** (`ALL_AUX_VALUE`) at the top; only
    inspection/highlight (does not isolate). `_populate_sub_members` (sub-members) and `_populate_skeleton` (standalone
    bones, called at the top of it) populate; `_reset_skeleton` clears. **Position of "Skeleton":** the
    `SkeletonRow` sits right below "Sub-member" (the old inline `ColliderEditBox` was REMOVED — the
    offset/scale editor is now the reusable floating window; see above). To the right of the
    "Skeleton" combo there is the geometry dropdown `cboSkeletonGeo` when a real standalone bone is chosen.
    **Load of the PERSISTED value on display (2026-06-25):** each `_populate_*` (member/sub/skeleton) LOADS the
    persisted value (`sel_member`/`sel_submember`/`sel_skeleton`, read from Settings) whenever the dropdown is
    (re)shown; with no saved value or one invalid for the context → **"Select..."**. So **"All members"
    only "resets" Sub-member/Skeleton to "Select..." when it finds no valid persisted value** (e.g.: a `PART_*` of a
    specific member does not match in "All members" mode → "Select..."; but "All Sub-members" or a
    saved standalone bone come back). `_restore_selection_chain` does **not** restore member/sub/skeleton
    explicitly — `_on_mesh_selected(1)` runs `_populate_members`, which does the load. (The `_restoring` flag
    and the reset in `_on_member_selected` were REMOVED.)
  - **"Skeleton Colliders" toggle (renamed from "Highlight standalone"→"Skeleton"→"Skeleton Colliders" in 2026-06-22) + "Whole skeleton" (2026-06-21; the item was previously "All standalone bones"):** since the characters are ONE
    skinned mesh (parts not separable by node), the filter **HIGHLIGHTS without hiding**: the toggle
    `AuxHighlight` (`_show_aux_highlight`, persisted) draws a **translucent orange shape**
    (no depth-test, attached via `BoneAttachment3D`) over the region of the chosen standalone bone — the AABB of the
    bone's DOMINANT vertices via `LimbColliders.bone_vertex_box` (static). The **"All standalone
    bones"** item (`ALL_AUX_VALUE`) at the top of the filter highlights all at once; "Select..." / toggle off
    = whole model with no highlight. `_refresh_aux_highlight` (called in the member/sub-member handlers,
    in `_populate_members` and in `_rebuild_member_colliders`) decides what; `_highlight_aux_bones`
    draws; `_clear_aux_highlights` removes (nodes with the `_AuxHL_` prefix).
    **Shape by geometry (2026-06-25):** `_highlight_aux_bones` draws in the bone's **geometry** (saved in
    `LimbConfig.collider_shape("PART_<bone>")`): `SHAPE_NONE` ("Select...") → **NO highlight**; **no choice ("")
    → AUTO-DETECTS** by shape (`_auto_geo_for_box`); saved shape → that one. It draws via
    `LimbColliders.make_shape` + `_solid_mesh_for_shape`, also applying the bone's saved **offset/scale** —
    so the highlight **PREVIEWS the collider** the bone would have if promoted, **without promoting it**. The
    Offset/Scale window calls `_refresh_aux_highlight` when it changes, so the preview follows live.
  - **EXCLUSIVE isolation (2026-06-21):** `_current_focus_groups` shows **one piece at a time** —
    Member chosen **without** Sub-member → only the MEMBER collider; **with** Sub-member → only that
    sub-member. "All members" → the `cboSubMembers` isolates the chosen `PART_*` (or `null` = shows
    everything, at "Select..."/"All Sub-members"); the "Skeleton" dropdown (`cboSkeleton`) never isolates.
  - **Colliders gated by toggle, BY TYPE (2026-06-21; separated in 2026-06-22):** the focus branch of
    `_refresh_member_overlays` shows the gizmo according to the **MASTER toggle of the type** of the group in
    focus: MEMBER → **"Member Colliders"** (`_show_colliders`); SUB-MEMBER (PART_*) → **"Sub-member
    Colliders"** (`_show_sub_colliders`) — `giz_on = in_focus and (_show_sub_colliders if PART_ else
    _show_colliders)`. In the GENERAL view (no focus), `_apply_colliders_visibility` shows the member colliders
    **ONLY when "Member" is in "All members"** (`cbo_members.selected == 1` + the "Member
    Colliders" toggle; in "Whole model"/"Select..." = **NONE**, 2026-06-25 — before the toggle alone showed
    all) and **hides the PART_***; the sub-member only appears isolated, via its toggle — **except** in "All
    Sub-members" mode + "Sub-member Colliders" on, which shows ALL the sub-members at once (2026-06-25,
    `_should_show_all_sub_colliders`). The **label** isolation
    remains independent of the collider toggles. Note: bones that are already a MEMBER (e.g.:
    `shoulder.L/.R` → ARM) do **not** enter the "Add sub-member" list (which only offers the
    auxiliary ones, `group_of == ""`); the "shoulder" as a sub-member is the `shoulderpad-adjust` plate (shown with
    that original name, grouped under ARM), because raw `shoulderpad.L/.R` has 0 vertices.

⚠️ Several models fire sound via **animation tracks** (`type = "audio"`/`"method"`,
not just autoplay). That is why `_apply_audio_state()` **mutes** (volume_db = -80) the emitters
when the Audio toggle is off and restores the **authored volume** (captured by
`_capture_av`) when it is turned back on — so the audio fired by the animation itself also respects
the Audio toggle, without needing to rebuild the preview.

🔁 `_capture_av()` also **deactivates every `AnimationTree`** (`active = false`) when building the
preview, so it does not pose the skeleton **in parallel** with the clip played directly on the
`AnimationPlayer`.

🎭 **red_robot anti-"two models" (2026-06-18):** when turning on the animation the red_robot appeared
**duplicated/offset**. Two causes, both in `_capture_av`/`_apply_animation_state`:
- **Root motion:** the clips carry the root motion in a bone (`Skeleton3D:MASTER`) that the
  `AnimationTree` extracted and the script applied to the body. Playing the clip **directly** on the
  `AnimationPlayer`, that bone was APPLIED, translating the skeleton (~1.6 m in Z) → a second
  model behind. Fix: `_capture_av` copies `tree.root_motion_track` to the player the tree
  drove → the clip plays **in place** (root motion extracted and discarded; drift = 0).
- **Effect/death players:** the red_robot has 4 `AnimationPlayer`s (locomotion + `ShootAnimation` +
  `Explosion`/kaboom + blast). The preview played the 1st clip of **each** player → the kaboom
  revealed the death debris (copies of parts) over the model. Fix: with no clip chosen
  in the dropdown **nothing plays** (2026-06-18 — before the main player played a default/idle clip);
  with an explicit clip from the dropdown, `_apply_animation_state` plays it **only** in whoever has it and stops
  all the other players (e.g.: choosing "kaboom" shows the explosion on purpose, without the blast/shoot
  together). The **main player** (`_main_anim_player` = the one the tree drives, or the richest without a tree)
  is still identified in `_capture_av` only to find the `_main_body_root` (the live body to hide
  in the death clips).
- **A death/explosion clip hides the live body (2026-06-18):** the `kaboom` clip makes the `Death` node
  (debris = copies of parts) **visible** but does NOT hide the live body (that was done by the script,
  removed in the preview) → body + debris = "two models". `_apply_animation_state` hides the
  `_main_body_root` (the body's root, e.g.: `RedRobotModel`) when the chosen clip is a death one
  (`_is_death_clip`: kaboom/explo/death/die/destr), leaving only the explosion.

(The emitters go to the `SFX` bus — see [[🔊 audio (EN)|audio]].) The states of **rotation,
animation, special effects, audio, colliders, labels and Type/Name/ID/Bone** are **persisted** in the
`[models]` section of `user://settings.ini` via `Settings.config_file` (`_save_toggle` in each
handler; `show_member_labels` since 2026-06-20, `show_type`/`show_name`/`show_id` since 2026-06-21,
`show_osso` since 2026-06-22)
and re-read in `_ready` before connecting the signals, so the screen reopens as it was left. The
**Per-member damage** toggle is the exception — it is **not** persisted (always opens closed).

### 💾 Selection persistence + chain restoration (2026-06-18)

Beyond the toggles, **every dropdown choice** (Category · Model · Part ·
Animation · Effects) is persisted in the same `[models]` section by a **stable value** — not the
index — via `_save_selection(key, value)` in each `_on_*_selected`: `sel_category` = the category
key, `sel_model` = the model name, `sel_part` = the mesh label **or** the sentinel `WHOLE_MODEL_VALUE`
(`"__whole_model__"`) for "Whole model", `sel_animation` = the clip text, `sel_effect` = the sentinel
`ALL_VALUE` (`"__all__"`) for "All"
**or** the item text (`_effect_value`; the inverse `_effect_index_for_value` resolves it to an index).
Using the sentinel for "All" avoids breaking the restoration when the language changes (the label is
translated). This way the restoration survives a re-scan of the library in a different order.

`_restore_selection_chain()` (called at the end of `_ready` in place of the old
`select(0)`+`_on_category_selected(0)`) **replays the chain top to bottom**: since `select()`
does **not** emit `item_selected`, each step **also** calls the handler explicitly, populating the
next combo like a real click. The `_find_*_index` resolve the saved value to the current index of
each combo. Stopping rule per level:

- **empty value** (the user stopped there) → leaves the combo at the placeholder **enabled**, ready to
  continue. With everything empty = a normal **blank start** (nothing previewed, no item
  auto-selected — see [[🔽 dropdowns (EN)|dropdowns]]).
- **value non-existent today** (the saved choice vanished from the library, "no more data") →
  **disables that combo**; since its handler does not run, all the ones below stay disabled
  too. Animation and Effects are **parallel leaves** of "Whole model": each is restored
  independently (stale → disables only it; empty → stays at the placeholder).

### 🧍 Members and centering (Characters/Weapons)

For **Characters** and **Weapons**, `_preview_whole_model` builds the member
colliders (via [[🦿 limb-colliders-gd (EN)|LimbColliders]]) and `_add_member_labels`
floats a `Label3D` with the member name (HEAD, TORSO, ARM…) over each collider.
The label font is **36** (¼ smaller than the original 48 — 2026-06-17), with outline 9.

**Labels: 100% local to the scene (2026-06-21):** each line of the TYPE/Name/ID/Member stack follows
**its** own scene toggle (Member + the Type/Name/ID checkboxes), with **no** read of the
global 3D Debug. `_add_member_labels` names each line with the `_MdlLbl_` prefix and
`_apply_member_labels_visibility` **recreates the stack in-place** (clears the `_MdlLbl_*` and re-adds
with the per-line visibility). Since the scene's root node is in the **`no_debug_overlay`** group, the
`DebugOverlay` (autoload) already skips the whole scene — so there is no doubled label nor global gizmos
in the preview. (The `DebugOverlay.exempt_member_labels(instance)` call in `_preview_whole_model`
remains as a redundant defense.) The browser's labels use the head/torso overrides
as the only source.

> [!note] red_robot HEAD collider = face + eyes (2026-06-18)
> The red_robot's HEAD member is built from `mouth_eyes` **+ `L-EYE`/`R-EYE`**
> (override in `_MODEL_HEAD_BONES` and in `red_robot.gd`). The eyes fall into the "eye" exclusion,
> so without forcing them, the head caught only the face panel (~42 vertices) and became a
> tiny sphere hidden in the TORSO box. With the eyes, the sphere becomes ~`r=0.34` (the whole face).
> This applies both to the browser gizmo and to the **headshot hitbox** in game (same
> `LimbColliders`) — the headshot became a fair target.

> [!note] player HEAD collider = CAPSULE (2026-06-21)
> The **player's** head uses a **capsule** (not a sphere): `player.gd` sets `lc.head_shape =
> "capsule"` and the Models screen mirrors it via `_MODEL_HEAD_SHAPE := {"player":"capsule"}`. The capsule is
> aligned to the head's longest axis (same orientation as the bone) and keeps the **full radius**
> (`make_member_shape` → `make_shape("capsule", aabb, cap_radius=false)`), without the `CROSS_SHRINK`
> of the other members, to **cover the entire mesh** of the head. See [[🩸 dano-localizado (EN)|dano-localizado]].

**Posed centering (2026-06-17):** the AABB of a **skinned** mesh comes from the
**bind** pose, which in the red_robot is ~1.4 m off the idle pose in Z. Using it would anchor the pivot
**behind** the body, and the model would "escape" when rotated. That is why, when there are member
colliders, `_posed_member_bounds()` measures the body **in the real pose** (from the colliders) and
`_fit_to_view(model, 2.0, posed)` centers/scales by that AABB — the model rotates **in place**.

## 📤 Extraction ("Save as 3D scene")

`_on_save_pressed()` re-instantiates the model, finds the 1st node with the selected mesh
(with the child collision, if any), zeroes the transform to the origin, re-defines owners
and packs it into a standalone `.tscn` in `library/extracted/<category>/<name>.tscn`.

## 🖼️ "Exported" gallery

`library/extracted/Exported.tscn` (`exported.gd`): scans `library/extracted/`,
instantiates all the `.tscn`/`.glb` scenes (except itself), normalizes the size and
lays them out side by side. The "Exported" button navigates to it; "Back"/ESC return to
`models.tscn`. **Note:** the scan is only of the root of `extracted/`; "Save" writes to
`extracted/<category>/` subfolders (extracted scenes do not appear in the gallery without a
recursive scan).

## 🔗 Bindings / reuse (survey)

The only binding that prevents separation is the *skinning* to `Skeleton3D` — only in the
**characters** (Player, RedRobot): the reusable unit is the whole character.
The static content is a small palette of distinct meshes instantiated with an
embedded transform + child collision (`StaticBody3D`/`CollisionShape3D`): Core 35,
CoreOutLight 4, Lights 4 (+luminaires), Props 86 (+the scificars' `VehicleWheel3D`),
Structure 104. The forklift has a clean hierarchy (3 forklifts). The scificars (in
props.glb) are flat (wheels + body as siblings, with no parent node per car).

## 🎛️ 2D controls viewer (analogous)

`scenes2D/controls/controls.tscn` (`controls.gd`) is the 2D equivalent of this screen:
a dropdown lists each control in `controls2D/<name>/<name>.tscn` and the
selected one is instantiated in a preview `SubViewport` (isolating controls that cover
the whole screen, like `scanlines`/`pause_menu`, and the `cyberpunk_hud`, which is a
`CanvasLayer`). Reachable via the `developer` screen (the "2D Controls" button, next to
"3D Models"). Dropping a new control folder makes it appear automatically.

`_center_preview` centers the control in the SubViewport **horizontally and vertically
whenever possible** (2026-06-16): it waits 1 frame for the layout to settle and only recenters
the axis in which the control is **smaller** than the viewport — controls that already fill the
whole area (scanlines/hud/pause_menu) stay where they are.

## 🔗 Related

- [[🎬 fluxo-de-cenas (EN)|fluxo-de-cenas]]
- [[🧭 main-gd (EN)|main-gd]]
- [[📄 formatacao (EN)|formatacao]]

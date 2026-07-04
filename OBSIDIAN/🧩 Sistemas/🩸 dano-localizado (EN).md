---
tipo: sistema
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 🩸 Weapon Damage System + Localized Hitboxes

> Implemented on 2026-06-06; migrated to **native 3D colliders** on 2026-06-14.
> Damage from the attacker's **weapon**, with **one `StaticBody3D` per limb group** and
> **localized damage** (physical collision, no longer a "glass" Area3D).

---

## Damage attributed to the weapon

| Character | `weapon_damage` (export) | Note |
|---|---|---|
| Player | `50` | Assigned to each bullet fired (`bullet.weapon_damage = weapon_damage`) |
| Enemy (Red Robot) | `25` | Applied to the player by the laser |

`hit(amount: int)` now receives the damage value (it used to be fixed).

---

## Hitbox groups (limbs)

`effects_shared/limb_colliders.gd` classifies bones into groups and creates **one `StaticBody3D` per limb** (fitted to the skinned vertices, AABB in the root-bone space), with `group` + `damage_multiplier` metas. The shape is chosen by `make_member_shape()`:

The table below is the **biped** plan (the default — see **Body-plan hierarchy**
below); the multipliers are the **PLAN defaults** (`BodyParts.default_multiplier`).

| Group | Shape | Multiplier (plan default) |
|---|---|---|
| **HEAD** (head/neck) | `SphereShape3D` (optional capsule — see below) | `1.5` (+50%) |
| **TORSO** (hips/spine/chest/body) | `BoxShape3D` | `1.0` |
| **ARM R/L** (shoulder/arm/forearm/hand/**wing** + side) | `CapsuleShape3D` (long axis) | `1.0` |
| **LEG R/L** (thigh/shin/knee/foot/leg + side) | `CapsuleShape3D` (long axis) | `1.0` |

> The multipliers above are **body-plan defaults** (head +50%, everything else 1.0). Since
> 2026-06-20 each model can have its OWN per-limb multiplier, editable in the Models screen and
> persisted in the model's folder (`res://library3D/<cat>/<model_key>/limb_config.json`; runtime
> override in `user://` — see **Per-model editable multipliers** below).
> The LIMBS themselves depend on the model's `body_type` (biped/quadruped/crawler).

Side detected by `.L/.R` suffix (player) or `L-/R-` prefix (enemy). `wing` counts
as ARM (winged creatures: criatura_alada, robot_*_alado).

**Per-model overrides** (`group_of(..., head_bones, torso_bones, leg_bones)` + exports
`head_bone_names`/`torso_bone_names`/`leg_bone_names` of `LimbColliders`): force bones the
classifier would otherwise discard. red_robot uses: HEAD=`mouth_eyes`+`L-EYE`/`R-EYE` (the eyes go
into the HEAD so the headshot doesn't become a tiny sphere covering just the face panel — 2026-06-18),
TORSO=`Bone.001`, and **LEG=
`L-RearLegGuard`/`R-RearLegGuard`** (2026-06-18) — the **leg plates**, previously excluded by the
word "guard", go into the leg collider (side by the L-/R- prefix). The same overrides are
applied in the Models screen preview (`models.gd` `_MODEL_LEG_BONES`). Control bones like
`L-LEGORIENT`/`L-LEGIK` remain excluded (they are not in the list).

**Per-model HEAD shape** (2026-06-21) — `LimbColliders` has an export
`head_shape` (`"sphere"` default or `"capsule"`). The **player** uses `"capsule"`
(`player.gd` sets `lc.head_shape = "capsule"`): the head becomes a **capsule aligned to
the head's longest axis** (same orientation as the bone), keeping the **full radius**
(`make_member_shape` calls `make_shape("capsule", aabb, cap_radius=false)`: with
`cap_radius=false` the head skips BOTH the `CROSS_SHRINK` AND the `LIMB_RADIUS_RATIO` cap
— it keeps the full radius to **cover the whole mesh**, instead of slimming down). Other
models keep the sphere. The Models screen preview mirrors this via the const
`_MODEL_HEAD_SHAPE := {"player":"capsule"}` (`models.gd`), same as gameplay.

**Size fine-tuning** (2026-06-16, width reduced on 2026-06-20) — so the
colliders hug the body more tightly: `CROSS_SHRINK = 0.72`
(radius/width/depth, **limbs only** — the head with `cap_radius=false` does NOT
apply this shrink), `LENGTH_SHRINK = 0.95` (long axis) and
`LIMB_RADIUS_RATIO = 0.32` (cap on the capsule radius as a fraction of the length,
ensuring a limb with a near-cubic AABB — e.g. the player's right arm, which
holds the weapon — still reads as a **capsule** and not as a ball).

---

## Body-plan hierarchy (2026-06-20)

Each model's LIMBS come from its **BODY PLAN**. `effects_shared/body_parts.gd`
(`class_name BodyParts`) is no longer a static-only class and became an **instantiable BASE
with VIRTUAL methods** — because static `BodyParts.group_of(...)` is **NOT polymorphic** in
GDScript. **Always use an INSTANCE** (via `BodyPlans.for_type`/`.default`). See
[[🦴 body-parts-gd (EN)\|body-parts-gd]] for the dedicated note.

- **`BodyParts` (base)** — universal constants `HEAD`/`TORSO` + `BASE_LABELS` (HEAD/TORSO) +
  `EXCLUDE_KEYWORDS`. **Universal statics** (plan-independent): `side_of(name)` (L/R; detects
  `L-/R-`, `.l/_l`, `…L/…R` prefixes/suffixes and the words `left`/`right`/`esquerd`/`direit`) and
  `front_rear_of(name)` (F/R: front/fore/dianteira vs rear/hind/back/traseira). **Instance
  virtuals**: `members()`, `group_of(bone, head_bones, torso_bones, leg_bones)`, `label_of(group)`,
  `default_multiplier(group)` (head 1.5, everything else 1.0) and `default_sub_members()`.
- **`BodyPartsBiped`** (`extends BodyParts`) — adds `ARM_L/ARM_R/LEG_L/LEG_R` (ARM L/R,
  LEG L/R). It is the **DEFAULT**. `wing` counts as ARM (winged creatures).
- **`BodyPartsQuadruped`** — adds `LEG_FL/LEG_FR/LEG_RL/LEG_RR` (FRONT LEG L/R, REAR LEG
  L/R), **without arms**; uses `front_rear_of` + `side_of` to separate the 4 legs.
- **`BodyPartsCrawler`** (snake/slug/worm) — **inherits only**: just HEAD/TORSO (elongated body =
  TORSO). Future extension point.
- **`BodyPlans` (factory)** — `effects_shared/body_plans.gd`. `BodyPlans.for_type(body_type) ->
  BodyParts` (match: `quadruped`/`crawler`/`_ => biped`) and `BodyPlans.default()` (biped). `const
  TYPES = ["biped","quadruped","crawler"]`. **Isolated** from the classes to avoid a
  base↔subclass cycle (the base does not reference the subclasses).

**`body_type`** — `LimbColliders` gained `@export_enum("biped","quadruped","crawler") var
body_type`, which picks the classifier via `BodyPlans.for_type` in `build_for`. `player.gd` and
`red_robot.gd` set `lc.body_type = "biped"`. The Models screen mirrors this in the const
`_MODEL_BODY_TYPE := {"red_robot":"biped","player":"biped"}` (the preview strips scripts, so the
@export isn't available) + helpers `_body_type_for_current()`/`_current_classifier()`.

The **3D Debug overlay** (`debug_overlay.gd._add_3d_skeleton`) now uses `var classifier :=
BodyPlans.default()` (biped instance) instead of the old statics, since it runs over arbitrary
level skeletons.

> [!note] Fallback "BODY" member (2026-07-01)
> **Every model has at least ONE editable member.** In the Models screen, when a model has **no**
> classified member, `_add_mesh_member_colliders` (models.gd) synthesizes a single
> **`CORPO`** (BODY) member enclosing **all visible meshes** (AABB), with a **box** shape by default —
> so there is always a target for defining a collider/damage. Two situations:
> - **Structures/Propulsors** (categories **without** a body plan): the classifier does **not** run
>   (avoids matching names like `horse_head` to HEAD by substring) → falls straight to `CORPO`.
> - **Characters/Weapons** whose rig without a `Skeleton3D` matched no mesh → they also get `CORPO`.
>
> `CORPO` is a regular member (meta `group="CORPO"`), so it inherits offset/scale/rotation/shape and the
> damage multiplier via `LimbConfig` (key `CORPO` in the model's `limb_config.json`), and the
> **Member** dropdown now appears for **any category** in "Full model" (not only Characters/Weapons).
> Const `FALLBACK_MEMBER_GROUP`/`FALLBACK_MEMBER_LABEL` in `models.gd`.

---

## Per-model editable multipliers (2026-06-20)

`effects_shared/limb_config.gd` (`class_name LimbConfig`, `RefCounted` with a static API) — the former
`LimbDamage` (renamed/replaced; `limb_damage.gd` + `data/limb_damage.json` were **removed**)
— stores each member/sub-member's multiplier, the list of sub-members **and** the owner relationship
of each one. **ONE FILE PER MODEL IN THE MODEL'S FOLDER (2026-06-22):**
`res://library3D/<category>/<model_key>/limb_config.json` — alongside the mesh/scene, versionable and
editable in Godot (`_model_dir` resolves the folder by scanning `library3D`, with a cache). **Writable
runtime override:** since `res://` is **read-only in the exported .exe** (embedded PCK), edits made
WHILE RUNNING the game (Models screen in the .exe) go to `user://limb_config/<model_key>.json`, which has
**read precedence** — so what you edit on screen is re-read and shows up. In the editor the save goes
straight to the model's folder (canonical source) and **deletes** the obsolete `user://` override of that model.
> ⚠️ **Bug fixed (2026-06-22):** the config used to be written to `res://data/limb_config/<key>.json`;
> in the **.exe** `res://` is read-only, so Add sub-member (e.g. "mouth"→HEAD) **failed to
> write** and the rebuild re-read the disk without it → it didn't appear in the tree or the dropdown. With the
> `user://` override the edit persists and reflects on screen even in the .exe.

**Transparent migration (read, in order):** `user://` (override) → model folder → old
`res://data/limb_config/<key>.json` → legacy combined `res://data/limb_config.json`; the first SAVE
writes to the new location without losing data. Schema of each file:

```json
{
  "damage": { "HEAD": 2.0, "PART_L-RearLegGuard": 1.0 },
  "sub_members": ["L-RearLegGuard", "R-RearLegGuard"],
  "sub_member_owners": { "L-RearLegGuard": "LEG_L", "R-RearLegGuard": "LEG_R" },
  "collider_offsets": { "HEAD": [0.0, 0.1, 0.0] },
  "collider_scales": { "HEAD": [1.2, 1.2, 1.2] },
  "collider_shapes": { "HEAD": "capsule", "TORSO": "none" }
}
```

- **`model_key`** = name of the model's folder (`"red_robot"`, `"player"`), the SAME value that
  `player.gd`/`red_robot.gd` pass in `LimbColliders.model_key`; it is now the **file name**.
  `GROUP` = plan key (`HEAD`/`TORSO`/`ARM_L`/…/`LEG_FL`/…) or `PART_<bone>` for a sub-member.
  Value = **multiplier** (`1.0` = normal, `1.5` = +50%). `sub_member_owners` = EXPLICIT owner
  member of each sub-member (a purely logical grouping for inheritance; empty = automatic resolution).
  `collider_offsets` (2026-06-22) = **offset** `[x,y,z]` (meters, collider local space)
  applied to the `StaticBody3D`'s `position`; `collider_rotations` (2026-06-25) = **rotation** `[x,y,z]`
  (DEGREES) applied to the `StaticBody3D`'s `rotation_degrees`; `collider_scales` (2026-06-22) = **scale**
  `[x,y,z]` applied to the collider shape (around the center). `collider_shapes` (2026-06-25) = **shape**
  chosen in the Models screen: `"sphere"`/`"box"`/`"capsule"` overrides the automatic shape, `"none"`
  (`SHAPE_NONE`) **suppresses the collider** of the member/sub-member (no hitbox; the Models screen preview still
  shows the suppressed sub-member in the tree via `include_suppressed`), absent = automatic plan shape.
  All per member/sub-member, editable in the Models screen (see [[🗿 biblioteca-de-modelos (EN)\|biblioteca-de-modelos]]);
  absent/zero(offset)/[1,1,1](scale) = neutral.
- Static API (2026-06-21): `effective_multiplier(model_key, group, classifier, owner_group="")`
  (WITH inheritance), `get_multiplier(...)` (wrapper without owner), `has_multiplier`/`clear_multiplier`
  (state of the "Define" checkbox), `set_multiplier`, `sub_members`, `sub_member_owner(s)`,
  `set_sub_member_owner`, `add_sub_member(model_key, bone, owner="")`, `remove_sub_member` (also deletes
  the `PART_<bone>` from `damage`, the owner, the `collider_offsets`, the `collider_scales`, the
  `collider_rotations` and the `collider_shapes`), `collider_offset`/`set_collider_offset`,
  `collider_scale`/`set_collider_scale` (2026-06-22), `collider_rotation`/`set_collider_rotation`,
  `collider_shape`/`set_collider_shape` + const `SHAPE_NONE` (2026-06-25) and `load_table`.
- **Inheritance / "no value is mandatory" (2026-06-21):** `effective_multiplier` — an EXPLICIT value
  on the group itself takes precedence; a `PART_*` WITHOUT its own value **inherits the OWNER member's**
  (owner's explicit, otherwise the owner's plan default); with nothing, it falls back to the
  `default_multiplier` of its own group. `LimbColliders` stamps the already-RESOLVED `damage_multiplier`
  meta (owner = explicit from `LimbConfig`, otherwise `resolve_sub_member_owner`). The file only stores user
  adjustments (no JSON = plan default, zero regression).
- **Editor:** the Models screen has the **"Damage"** toggle (renamed from "Damage per member" in 2026-06-22) that opens a floating panel
  (`DamagePanel`, centered, **720 px tall** — increased from 500 in 2026-06-20 to fit
  more members/sub-members without scrolling) with a `SpinBox` in **bonus %** per member (head `+50%` ⇒
  multiplier `1.5`); changing it saves via `LimbConfig.set_multiplier`. It only appears for a **character
  in "Full model"**. See [[🗿 biblioteca-de-modelos (EN)\|biblioteca-de-modelos]]. `res://` is writable only when running
  from the editor; the game only reads.

---

## Configurable sub-members (2026-06-20)

**Sub-members** = protruding auxiliary bones PROMOTED to their OWN box collider (unique group
`PART_<bone>`, for parts the member's capsule wouldn't cover — e.g. the red_robot's **leg plates**).
In `LimbColliders.build_for`, the effective sub-members come from the UNION of **THREE sources**:

1. the node's `@export standalone_part_bones`,
2. `LimbConfig.sub_members(model_key)` (the ones edited on screen),
3. `classifier.default_sub_members()` (the ones from the body plan).

`red_robot.gd` **no longer hardcodes** `standalone_part_bones`: the plates (`L-RearLegGuard`/
`R-RearLegGuard`) were **migrated to `data/limb_config.json`** (seed) and are editable on screen. The
Models screen removed the const `_MODEL_STANDALONE_BONES`.

**Which MEMBER a sub-member belongs to (2026-06-21):** resolved by
**`LimbColliders.resolve_sub_member_owner(skel, bone, classifier, head, torso, leg)`** (static,
used by the Models screen's `_sub_member_owner_map`/damage-inheritance grouping). It no longer renames
the label: since 2026-06-22 `_part_label` returns the **bone's ORIGINAL name** (see below). Layers: (1) **the part's OWN NAME** via `owner_hint` (member
words + side, ignoring exclusions); (2) **walks up the HIERARCHY** and, on each ancestor, tries
`owner_hint` and then `group_of` (with head/torso/leg overrides). Step (2) with `owner_hint` is what
catches plates hanging off an AUX/IK bone whose NAME says the member:
- **player** — `shoulderpad-adjust.L/.R` (children of `chest`): resolve by (1), name "shoulder" → **ARM L/R**.
- **red_robot** — `L-Shield/R-Shield` (arm shields, children of `L-ARMIK`/`R-ARMIK`): (1) fails
  ("shield" is not a member word), but the walk-up finds the parent **`L-ARMIK`** whose `owner_hint` gives
  **ARM** → **ARM L/R** (only to GROUP/inherit damage; the label stays the bone name).
- **red_robot** — `L-/R-RearLegGuard`: name has "leg" → **LEG L/R** by (1).

The **label KEEPS the bone's ORIGINAL name (2026-06-22):** `_part_label` was simplified to
`return bone_name`. The old owner-derived label **"PLATE \<MEMBER\>"** (e.g. "PLATE ARM L",
"PLATE LEG R") was **dropped by request** — adding a sub-member to a member only groups the damage,
it never renames the part. Seeds in `data/limb_config.json`: player = `shoulderpad-adjust.L/.R`; red_robot =
`L-/R-RearLegGuard` + `L-/R-Shield`. ⚠️ The bone ideally has its **own skinned vertices** —
`shoulderpad.L/.R` (without `-adjust`) have 0 vertices and the region is deformed by `shoulderpad-adjust.L/.R`.
**Fallback for bones without vertices (2026-06-22):** a promoted sub-member whose bone has NO dominant
vertices (e.g. `Mouth`, structural/empty bones) **no longer added a collider** and disappeared from the
Models screen's tree/dropdown; now `_collect_member_boxes` (step 4, helper `_fallback_part_size`)
generates a **small box centered on the bone's origin (rest)** (~20% of the largest measured member, scale-aware),
so the sub-member **appears and can take damage**. (The orange "Skeleton Colliders" highlight and the "Skeleton" toggle label (ex-"SubMember"/"Bone"), which use
`bone_vertex_box`, still require vertices.) Bones that are already a MEMBER (`L-Shoulder`/`R-Shoulder` →
ARM) don't enter the "Add sub-member" list (which only offers auxiliaries, `group_of == ""`).

**Editor ("Damage" panel):** lists **all the plan's members** (`_plan_member_entries`,
same source as the "Member" combo since 2026-06-21) and, **nested (↳, 24px margin) under each member**,
its sub-members (`PART_*`) — grouped by the SAME `_sub_member_owner_map`/`owner_hint` as the combos
(helper `_sub_members_by_owner`), so panel and dropdown agree; a sub-member without an owner in the list
goes to the **"Other sub-members"** section. The panel is a **Tree**; each sub-member leaf
has a **trash button to the right of the name** to remove it right there — with a **confirmation dialog**
("Do you really want to remove the association of sub-member: <name> ?") (2026-06-22; replaced the old big
"Remove sub-member" button in the footer — see [[🗿 biblioteca-de-modelos (EN)\|biblioteca-de-modelos]]). At the bottom, the
**add** row (`_build_damage_footer`): an `OptionButton` with the AUXILIARY bones of the preview skeleton
(those whose `group_of` gives "") + the **owner-member** dropdown + an "Add" button.
**Merged header (2026-06-27):** the labels "Add sub-member" and "To Owner Member" are
now in a **single `HBoxContainer`** above the row (before: a loose title + a label inside a
`VBoxContainer` over the dropdown). "Add sub-member" uses `SIZE_EXPAND_FILL` (left, over the
bone selector) and "To Owner Member" sits on the right.
**Column titles re-translated (2026-06-27):** the tree headers (Member/Def/Bonus %/Owner)
are **not** `Label`/`Button`, so the `Locale` auto-localizer couldn't reach them and they got stuck
in the language of the last build. Now `_apply_damage_tree_titles()` re-applies them via `tr_key` both in
`_refresh_damage_panel` and in `_on_language_changed` (see [[🗣️ localizacao (EN)\|localizacao]]).
Add/remove calls `LimbConfig.add_sub_member`/`remove_sub_member` and **rebuilds** the preview's
colliders (`_rebuild_member_colliders`), restoring gizmos/labels. In-game reading (`bullet.gd`/
`laser_shooter.gd` reading the `damage_multiplier` meta) is **unchanged**.

---

## Collision layers

| Bit | Value | Use |
|---|---|---|
| bit4 | `8` | Projectile (bullet) — the bullet's `collision_layer` |
| bit5 | `16` | **Player** member colliders |
| bit6 | `32` | **Enemy** member colliders |

- Bullet: `layer = 8`, `mask = 51` (`3` world/bodies + `16` + `32`) to collide physically with the members.
- Member colliders: `StaticBody3D` on layer 16/32, `mask = 0` (passive — they are hit, they don't detect).

---

## Damage flow (player → enemy)

```
bullet (server) collides physically (move_and_collide) with an enemy member collider
  → bullet._apply_hit(collider)
      → reads damage_multiplier + character metas; ignores if character == shooter
      → enemy.hit.rpc(round(weapon_damage * multiplier))   [server]
      → bullet explodes
Fallback: if the bullet hits a body with hit() and no member metas → TORSO damage (1x)
          in the same _apply_hit (idempotent via _registered)
```

**Character body pass-through (2026-06-18):** the character's generic body (the `CharacterBody3D`'s
capsule/sphere) wraps the whole figure, so it would be hit BEFORE the member colliders
(which hug the mesh) — always 1× damage, no headshot. In `bullet._physics_process`, if the
`move_and_collide` hits a `CharacterBody3D` that has the `LimbColliders` node, the bullet does
`add_collision_exception_with(body)` and **keeps flying**, passing through the body until it hits the
MEMBER collider behind it. This fixed the red_robot, whose body was a `SphereShape3D` of radius
~1.12 m that wrapped everything and intercepted every shot. The body still exists so the enemy can walk on
the ground and be aimed at/detected (the player's aim rays use `mask 0b11`); it only steps out of the SHOT's way.

**Body collider = capsule like the player (2026-06-18):** the red_robot's giant body sphere was
swapped for a **`CapsuleShape3D` (radius 0.5 / height 2.0, at y=1)** — the SAME logic as the player's
`CollisionShape3D` — so there's no more huge sphere. The node stays `CollisionShape3D` (dependency of
`red_robot.gd`).

**Per-model locomotion-capsule auto-fit (2026-07-03):** instead of the default capsule (0.5×2.0)
SAME for every model, the physical block is now **proportional to the model**, derived from the SAME member
boxes that `LimbColliders` already measures — keeping **1 shape per character** (cheap, stable and
deterministic, so server and client-prediction agree; independent of the animated pose). Method
`LimbColliders.fit_locomotion_capsule(shape_node, character)`, called right after `build_for` in
`player.gd` and `red_robot.gd`:
- **RADIUS = standing footprint** (`_is_footprint_group`: **TORSO + LEGS** — `LEG_*` of any plan).
  Arms (a T-pose's wingspan), head (top) and `PART_*` pieces are left **out** so they don't fatten
  the radius. `radius = 0.5 · max(footprint.x, footprint.z)`, with floor `MIN_BODY_CAPSULE_RADIUS = 0.12`.
- **HEIGHT = total vertical extent** (top of head → feet), with the **BASE anchored to the character's
  floor** (`bottom = min(aabb.min.y, 0)`) so the capsule never **floats** (keeps `is_on_floor`).
- **Center** on the model's axis (footprint x/z) and vertically at the middle. **Duplicates** the shape so
  it doesn't mutate a shared sub-resource. **No-op** (returns `{}`) if nothing was built (e.g. criatura_alada,
  which doesn't build `LimbColliders` in gameplay; a model with no classified members) → **preserves the
  authored capsule** as a safe fallback.
- Internal helpers: `member_boxes_in(space)` (per-group AABBs in the character's space, reading the
  REAL shape geometry — post-shrink), `_shape_local_aabb` (sphere/box/capsule) and
  `_transform_aabb` (envelope of the 8 corners, correct for rotated member capsules).
- **Validated** by a deterministic headless probe (synthetic biped ~1.8 m): radius **0.250** (footprint,
  NOT the arms at 0.575), height **1.800**, base **0.000** — all 3 criteria OK.

The shooter excludes its own member colliders from the projectile (`player._exclude_own_limbs`)
so the shot isn't born hitting its own arm/weapon.

## Damage flow (enemy → player)

`red_robot.shoot()` (server) **fires a cannon ball** (no longer a hitscan laser), via the
`CannonShooter` component, in the direction of the player (with dispersion if `aim_accuracy < 1`). The ball flies and,
when it hits a player MEMBER collider (bit5), applies `player.hit.rpc(weapon_damage * mult)` —
the same localized path as the player's shot (`bullet._apply_hit`).

## Reusable shooting components (2026-06-18)

To reuse shooting across models, the logic was isolated in `effects_shared/`:

- **`CannonShooter`** (`cannon_shooter.gd`, `class_name`): `static fire(parent, origin, dir, damage,
  shooter, tint, ball_color, ball_scale)` → instantiates `bullet.tscn`, positions/orients it, excludes the
  shooter's body + member colliders and launches it. Optional colors (alpha 0 = the player's default blue
  visual). Used by the **player** (blue, default) and by the **red_robot** (BLACK ball + RED effect,
  `ball_scale 2.5`).
- **`LaserShooter`** (`laser_shooter.gd`, `class_name`): `static fire(muzzle, beam_mesh, blast_scene,
  damage, hitbox_layer, exclude)` → hitscan laser (raycast + localized damage + beam clip + blast).
  Extracted from the red_robot's old laser; **available for reuse** (red_robot now uses the cannon; no
  model uses the laser for now).
- `bullet.gd` gained `tint`/`ball_color`/`ball_scale` (alpha 0 sentinel = don't touch → player untouched),
  applied in `_apply_visuals` (light + trail CPUParticles + ball material).

---

## BulletCache (trap resolved)

`player.tscn` has a `BulletCache` node (pre-instantiated bullet, warm-up). With no shooter,
it caused 50 damage at the start. Fix: **a bullet with no `shooter` stays inert**
(`_ready`: `if shooter == null or not is_server: disable`). Also covers clients
(where `shooter` isn't replicated).

**Networking (2026-06-26):** the `BulletCache` carried the `bullet.tscn`'s `MultiplayerSynchronizer` into
the player's replicated scene. When spawning/despawning the player over the network, this sync generated
`Node not found .../BulletCache/MultiplayerSynchronizer`, `Failed to get cached node from peer` and
`on_despawn_receive ERR_UNAUTHORIZED`. Fix: in `player.tscn`, override the cache's sync with
**`public_visibility = false`** (doesn't replicate) — affects only the cache; real bullets (instances of
`bullet.tscn`) keep replicating normally.

---

## Enemy accuracy and range

| Export | Default | Function |
|---|---|---|
| `aim_accuracy` | `1.0` | Chance to hit when firing (100% = always) |
| `effective_range` | `30.0` m | Only fires when the player is within this range |

The enemy waits to close in (`shoot_countdown = 0`) while the player is out of range.

> **Detection radius = range:** the `PlayerDetectionArea` (`SphereShape3D`) has a **30 m radius**,
> equal to `effective_range`, so the robot **detects and starts firing at 30 m** (it used to be 20 m,
> which prevented opening fire at the weapon's full range).

---

## Inspector tuning (character node)

In `limb_colliders.gd` (node `LimbColliders`): `enabled`, `padding`, **`body_type`**
(`@export_enum("biped","quadruped","crawler")`, default `biped` — picks the body plan via
`BodyPlans.for_type`; 2026-06-20), `head_bone_names` (`["mouth_eyes", "L-EYE", "R-EYE"]` on the enemy),
`torso_bone_names` (forces a generically-named bone to TORSO — `["Bone.001"]` on the red_robot, whose
body wasn't recognized and had **no torso collider**), `standalone_part_bones` (fixed sub-members
on the node — UNIONED with `LimbConfig`'s and the plan's; the red_robot **no longer uses** this export, the
leg plates migrated to `limb_config.json`), `hitbox_layer` (16 player / 32 enemy) and
**`model_key`** (`"player"`/`"red_robot"` — key of the multipliers/sub-members in `LimbConfig`;
2026-06-20). The color/radius exports from the old glass system were removed.

> Verified via the Godot MCP ([[godot-mcp]]): the enemy laser applies 25 (weapon),
> hitbox lookup working, the cache no longer causes damage at the start, no errors.

---

## Related

- [[🔫 combate-tiro (EN)\|combate-tiro]]
- [[❤️ sistema-de-vida (EN)\|sistema-de-vida]]
- [[🦿 limb-colliders-gd (EN)\|limb-colliders-gd]]
- [[🦴 body-parts-gd (EN)\|body-parts-gd]]
- [[💥 bullet-gd (EN)\|bullet-gd]]
- [[🤖 red-robot-gd (EN)\|red-robot-gd]]
- [[🩹 enemy-health-bar-gd (EN)\|enemy-health-bar-gd]]

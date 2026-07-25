---
tipo: arquivo-chave
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-23
---

# 🦿 effects_shared/limb_colliders.gd

**Renamed from `glass_hitboxes.gd` on:** 2026-06-14 · **Extends:** `Node3D`

---

## Responsibilities

- Generate **native 3D colliders** (`StaticBody3D` + `CollisionShape3D`) per **limb group** of a `Skeleton3D`
- Each limb → `BoneAttachment3D → StaticBody3D (BoxShape3D)`, attached to the **root bone** (follows pose/animation)
- Projectiles collide **physically** with these bodies and the enemy's laser hits them by **raycast against bodies** → **localized damage** to the owning character
- The **LIMBS** come from the model's **body plan**, chosen by the `@export body_type` via the factory **`BodyPlans.for_type`** (an instance of [[🦴 body-parts-gd (EN)|BodyParts]] — `_classifier`, resolved in `build_for`). Biped (default), quadruped or crawler.
- The per-limb damage multiplier comes from **`LimbConfig`** (read by `model_key`), with a fallback to the **plan's** default (`_classifier.default_multiplier`): head = +50% (`1.5`), the rest = `1.0` (2026-06-20). Editable on the Models screen (see [[🩸 dano-localizado (EN)|Localized Damage]])
- **Sub-members** (protruding bones with their OWN collider `PART_<bone>`) = the UNION of 3 sources in `_resolve_sub_members`: the `@export standalone_part_bones` + `LimbConfig.sub_members(model_key)` + `_classifier.default_sub_members()`
- **Automatic DISTAL sub-members (2026-07-23):** with the `@export auto_distal_sub_members` (new, `true` by default), **forearm/hand** and **shin/foot** become sub-members of their own (`PART_<bone>`, with localized collider and damage) instead of being absorbed into the ARM/LEG. `player.gd` and `red_robot.gd` **opt out**. Measured: humanoide/monstro = **6 limbs + 8 sub-members**; player = **6 limbs and 0 sub-members**
- **No Area3D, no glass visual, no labels** (it replaced the old "glass hitbox" system)
- See [[🩸 dano-localizado (EN)|Localized Damage]]

---

## How it works (positioning by skinned vertices)

1. Classifies the bones into groups via `_classifier.group_of` — an **INSTANCE** of the body plan (`BodyPlans.for_type(body_type)`), since the static `BodyParts.group_of` is NOT polymorphic. Biped gives HEAD/TORSO/ARM L-R/LEG L-R; quadruped gives 4 legs; crawler gives only HEAD/TORSO (see [[🦴 body-parts-gd (EN)|body_parts.gd]])
2. Chooses the **root bone** of each group (the shallowest in the hierarchy)
3. For each **skinned vertex** of the mesh, takes the highest-weight bone and converts it to the root bone's local space using the skin's **bind pose** (`get_bind_pose`) → accumulates an **AABB per limb** (+ a `padding` margin)
4. Creates `BoneAttachment3D` (on the root bone) → `StaticBody3D` + `CollisionShape3D (BoxShape3D)` the size of the AABB
5. Metas on the `StaticBody3D`: `group`, `damage_multiplier` (from `LimbConfig.effective_multiplier(model_key, group, _classifier, owner_group)` — `owner_group` only kicks in for sub-members, for the damage inheritance), `member_label` (label) and `character` (owner)
6. **Offset + Scale (2026-06-22):** `body.position = LimbConfig.collider_offset(model_key, group)` displaces the whole body (shape/gizmo/label follow); `shape_node.scale = LimbConfig.collider_scale(model_key, group)` scales the shape around the center. Both in the bone's local space, editable live on the Models screen (X/Y/Z rows for Offset and Scale + a Save button, with the Colliders toggle on); see [[🗿 biblioteca-de-modelos (EN)|Model Library]]. Empty = zero offset / scale [1,1,1].

- **Fallback for a sub-member with no vertices (2026-06-22):** step 3 only generates an AABB for groups with **dominant vertices**. A promoted sub-member (`PART_*`) whose bone has no vertices of its own (e.g.: `Mouth`, structural bones) ended up **without a collider** and vanished from the Models screen. Now step 4 of `_collect_member_boxes` (helper `_fallback_part_size`) creates a **small box centered on the bone's origin (rest)** (~20% of the largest measured limb) so it **shows up and can take damage**. It applies only to `PART_*` (limbs without vertices still get no collider).

- **Headless robot:** the RedRobot rig has no standard head bone; it uses `head_bone_names = ["mouth_eyes", "L-EYE", "R-EYE"]` to force the HEAD (face + eyes — the eyes, excluded by "eye", are added so the sphere isn't tiny; 2026-06-18). The player has the 6 groups; the enemy also resolves 6 (with the forced one).

- **Sub-members (protruding pieces):** bones that get their OWN collider (a box) fitted only to their vertices, instead of being absorbed by a limb. For PROTRUDING pieces the limb's capsule wouldn't cover — e.g.: the red_robot's **rear leg plates** (`L-/R-RearLegGuard`). Internally they become a single group `PART_<bone>` (reusing the whole pipeline), with a **box** shape. The effective set (`_sub_member_set`) is the UNION of 3 sources (`_resolve_sub_members`): `standalone_part_bones` (export) + `LimbConfig.sub_members(model_key)` + `_classifier.default_sub_members()`. `_classify()` intercepts these bones BEFORE the normal classifier, so they don't pollute the neighboring limb. The red_robot **no longer uses** the export — the plates migrated to `limb_config.json` and are editable on the screen (see [[🩸 dano-localizado (EN)|Localized Damage]]).

- **AUTOMATIC subdivision of the extremities (2026-07-23):** `_classify()` now intercepts in **TWO** cases, always BEFORE the limb classifier — (a) an **EXPLICIT** sub-member (`_sub_member_set`, the 3 sources above) and (b) an **automatic DISTAL** one, via `_classifier.is_distal_sub_member(bone)` when `auto_distal_sub_members` is on (forearm/hand/shin/foot; see [[🦴 body-parts-gd (EN)|body_parts.gd]]). The **OWNER** limb (only for damage INHERITANCE) is resolved afterwards, in `_build_member_shape`: first the saved EXPLICIT choice (`LimbConfig.sub_member_owner`) and, failing that, `resolve_sub_member_owner` (`owner_hint` from its own name → walks up the bone hierarchy). So the hand inherits the ARM's damage and the foot the LEG's, but each extremity has its **own hitbox and multiplier**. **OPT-OUT:** `player.gd` and `red_robot.gd` set `auto_distal_sub_members = false` to keep the already-tuned **WHOLE** ARM/LEG hitbox; `models.gd` mirrors the opt-out in the preview (`_MODEL_NO_AUTO_DISTAL`), so the Models screen shows exactly the same limbs as the game.

---

## Real-time refit (Models screen preview)

`refit(skel, max_groups = 0)` re-fits the limb/sub-member colliders to the **CURRENT ANIMATED pose** (the `BoneAttachment3D` already provides translation/rotation; the refit re-adjusts the box's **VOLUME** to the bend). The 1st call builds the **skinning cache** (`_build_refit_cache`, a one-off cost — that's where the expensive `surface_get_arrays` runs); after that only the bones' CURRENT poses are read.

**2026-07-23 optimizations** (the refit was what dragged the FPS down on the Models screen):

- **INVARIANT groups skipped (`_rc_dyn`).** A group's AABB is computed in its **root bone's LOCAL space**: `p = inv(gpose[root]) * gpose[bone] * bv`. In a group with a **SINGLE bone**, root == bone, the terms cancel out and `p = bv` is left — the AABB is **CONSTANT**, regardless of the pose (the collider already follows the bone via `BoneAttachment3D`). With the subdivision, **13 out of 14 groups** became single-bone ones (only the **TORSO** = hip + chest is dynamic), so refitting them all was recomputing the same value. Now `_rc_dyn` lists only the groups with **2+ bones** and the refit walks just those.
- **ROUND-ROBIN (`max_groups`).** With `max_groups > 0`, each call processes only that many groups, advancing `_refit_cursor` until it wraps around. `models.gd` calls it **every frame** with `REFIT_GROUPS_PER_FRAME = 3` — it replaces the old **adaptive throttle**, which redid everything at once every ~190 ms and caused a stutter. `0` (default) = all at once, as before.
- **Cache SORTED by group (counting sort).** `_build_refit_cache` now sorts the vertices by group via **counting sort**, storing each one's contiguous range in `_rc_gstart`/`_rc_gcount` — that's what makes it possible to refit a **SUBSET** of groups without scanning the whole cache. (The old `_rc_group`, one group index per vertex, is gone.)
	- ⚠️ **GDScript pitfall** that motivated the counting sort: a `Packed*Array` stored **INSIDE** an `Array` comes back **COPIED** when read — accumulating into per-group "buckets" does not work, the `append`s are lost **silently**.
- **Gizmo on demand.** `shape.get_debug_mesh()` **GENERATES** geometry on every call; in the refit it is only called when the gizmo `is_visible_in_tree()`. A hidden gizmo is updated on the first refit after it reappears (maximum lag = one refit interval).

**Measured gain (humanoide):** 6.45 ms → 1.89 ms (after the `LimbConfig` cache) → **0.318 ms per frame** (~1.9% of a 60 FPS frame). The player, opted out of the subdivision, sits at **0.612 ms** with 6 dynamic groups.

---

## Detection (physical, native)

- **Bullet → limb:** `bullet.gd` uses `move_and_collide`; when hitting a limb collider, `_apply_hit` reads `damage_multiplier`/`character` and applies `character.hit.rpc(round(weapon_damage * mult))`. Body fallback (capsule) = `1×`. The shooter excludes its own colliders (`player._exclude_own_limbs`).
- **Enemy laser → player limb:** `red_robot._damage_player` raycasts with `collide_with_bodies = true` on layer 16.
- `bullet.tscn collision_mask = 51` (world/bodies `3` + limbs `16` + `32`).

---

## Exports

| Export | Player / Enemy | Description |
|---|---|---|
| `enabled` | `true` | Enables/disables the generation |
| `body_type` | `"biped"` | Body plan (`@export_enum` biped/quadruped/crawler) → classifier via `BodyPlans.for_type` (see [[🦴 body-parts-gd (EN)|body_parts.gd]]) |
| `padding` | `0.03` | Margin (m) added to each side of the box |
| `head_bone_names` | `[] / ["mouth_eyes", "L-EYE", "R-EYE"]` | Bones forced into the HEAD |
| `head_shape` | `"capsule" (player) / "sphere"` | Shape of the HEAD collider (`@export_enum` sphere/capsule) |
| `head_scale` | `1.0 / 1.3` | Scale factor for the head VOLUME (red_robot = 1.3, larger headshot) — scales the AABB around the center (2026-06-21) |
| `torso_shape` | `"box" / "sphere"` | Shape of the TORSO collider (`@export_enum` box/sphere; red_robot = sphere) (2026-06-21) |
| `torso_bone_names` | `[] / ["Bone.001"]` | Bones forced into the TORSO (the enemy's generic bone) |
| `leg_bone_names` | `[]` | Bones forced into the L/R LEG |
| `standalone_part_bones` | `[] / []` | FIXED sub-members on the node (their OWN collider) — UNITED with those from `LimbConfig` + the plan. The red_robot **no longer uses it** (the plates migrated to `limb_config.json`) |
| `hitbox_layer` | `16 / 32` | Layer of the colliders (player bit5, enemy bit6) |
| `model_key` | `"player" / "red_robot"` | Key (folder name) to look up multipliers + sub-members in [[🩸 dano-localizado (EN)\|LimbConfig]]; empty = plan defaults |
| `include_suppressed` | `false` (`true` only in the Models screen preview) | True: `SHAPE_NONE` ("Select...") SUB-MEMBERS are still built (auto shape, `suppressed` meta, no gizmo) so they stay in the tree/dropdown and can be reconfigured. False (gameplay): skipped, no hitbox (2026-06-25) |
| `auto_distal_sub_members` | `false / false` (opt-out; **default `true`**) | AUTOMATIC subdivision of the extremities: forearm/hand and shin/foot become sub-members of their own (`PART_<bone>`, localized collider + damage, inheriting the ARM/LEG when they have no value of their own) instead of being absorbed into the big limb. On by default (new models); player/red_robot opt out to keep the already-tuned WHOLE hitbox (2026-07-23) |

---

## Instantiation (by code)

`player.gd._setup_limb_colliders()` and `red_robot.gd._setup_limb_colliders()`:
```gdscript
var skel = <model>.get_node_or_null(^".../Skeleton3D") as Skeleton3D
var lc = preload("res://effects_shared/limb_colliders.gd").new()
lc.name = "LimbColliders"
lc.body_type = "biped"   # body plan → classifier (BodyPlans.for_type)
lc.model_key = "player"   # "red_robot" on the enemy — key of the multipliers/sub-members in LimbConfig
lc.hitbox_layer = 16   # 32 on the enemy
lc.auto_distal_sub_members = false   # opt-out: WHOLE ARM/LEG (hitbox already tuned)
add_child(lc)
lc.build_for(skel)   # resolves _classifier (body_type) + _sub_member_set (3 sources)
```
Built on all peers (only the server simulates the shots). `get_limb_bodies()` lists the created `StaticBody3D` (used to exclude the shooter's own from the fired projectile's collision).

> [!note] SHAPE override + per-group suppression (2026-06-25)
> `make_member_shape(group, aabb, head_kind, torso_kind, head_scale, shape_override="")` gained the
> **`shape_override`** param: `"sphere"/"box"/"capsule"` FORCES that group's shape over the automatic one
> (a capsule HEAD keeps the full radius). `build_for`/`_build_member_shape`/`refit` read
> `LimbConfig.collider_shape(model_key, group)` and pass the override; and `build_for` **skips** the groups
> whose `collider_shape == LimbConfig.SHAPE_NONE` (`"none"`) → the limb/sub-member ends up **without a collider**
> (except SUB-MEMBERS in the Models screen preview, via `include_suppressed` — see the table). Everything is
> chosen on the Models screen (the geometry dropdown to the right of Member/Sub-member/Skeleton) and re-read
> here on spawn. The skeleton-less path (`models.gd._add_mesh_member_colliders`) honors the same
> two. See [[🗿 biblioteca-de-modelos (EN)|Model Library]] and [[🩸 dano-localizado (EN)|Localized Damage]].

- Player skeleton: `PlayerModel/Robot_Skeleton/Skeleton3D` (the player inherits from Player)
- Enemy skeleton: `RedRobotModel/Armature/Skeleton3D`

---

## Path: `effects_shared/limb_colliders.gd`

---

## Related

- [[🩸 dano-localizado (EN)|Localized Damage]]
- [[🦴 body-parts-gd (EN)|body_parts.gd]]
- [[🗿 biblioteca-de-modelos (EN)|Model Library]]
- [[🎮 player (EN)|Player]]
- [[🤖 inimigos (EN)|Enemies]]
- [[🎮 player-gd (EN)|player.gd]]
- [[🤖 red-robot-gd (EN)|red_robot.gd]]
- [[💥 bullet-gd (EN)|bullet.gd]]

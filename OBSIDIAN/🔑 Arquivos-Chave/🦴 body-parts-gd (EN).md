---
tipo: arquivo-chave
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 🦴 effects_shared/body_parts.gd (+ body plans)

**Created/refactored on:** 2026-06-20 · **Extends:** `RefCounted` (no node)

---

## What it is

The **BODY PLAN hierarchy**: it classifies the bones of a `Skeleton3D` into
**LIMBS** (HEAD, TORSO, ARM, LEG…) and provides each limb's default labels and damage
multipliers. Used by the localized-damage colliders
([[🦿 limb-colliders-gd (EN)|LimbColliders]]) and by the Debug 3D overlay
(`debug_overlay.gd`).

`BodyParts` stopped being a static-only class and became an **instantiable BASE with
VIRTUAL methods** — because static `BodyParts.group_of(...)` is **NOT polymorphic** in
GDScript: a static call would always resolve to the base, ignoring the subclass. **Always use
an INSTANCE** (via [[#BodyPlans (factory)|BodyPlans]]).

---

## Files

| File | `class_name` | Role |
|---|---|---|
| `body_parts.gd` | `BodyParts` | **BASE**: HEAD/TORSO + common pipeline + universal statics |
| `body_parts_biped.gd` | `BodyPartsBiped extends BodyParts` | + L/R ARM, L/R LEG — **DEFAULT** |
| `body_parts_quadruped.gd` | `BodyPartsQuadruped extends BodyParts` | + 4 legs (front/rear × L/R), no arms |
| `body_parts_crawler.gd` | `BodyPartsCrawler extends BodyParts` | just inherits — HEAD/TORSO only |
| `body_plans.gd` | `BodyPlans` | **factory** that delivers the right instance per `body_type` |

---

## Base `BodyParts`

- **Universal constants:** `HEAD`/`TORSO` + `BASE_LABELS` (HEAD/TORSO) + `EXCLUDE_KEYWORDS`
  (auxiliary/mechanical bones — ik, guard, piston, plate, eye… — that do NOT become a main limb;
  they can be promoted to a sub-member per model).
- **Universal statics** (independent of the plan, valid for all subclasses):
  - `side_of(name) -> "L"/"R"/""` — detects the side by name: prefix/suffix `L-/R-`, `.l/_l`,
    `…L/…R` in UPPERCASE, **and** the words `left`/`right`/`esquerd`/`direit` (fallback).
  - `front_rear_of(name) -> "F"/"R"/""` — front (front/fore/dianteira/frente) vs rear
    (rear/hind/back/traseira); used by the quadruped to separate the 4 legs.
- **Instance virtuals** (the base handles only HEAD/TORSO; subclasses extend and fall back to the base via
  `super`):
  - `members() -> Array[String]` — the groups the plan defines (for the screen to list/label).
  - `group_of(bone, head_bones, torso_bones, leg_bones) -> String` — the bone's group or "".
    `head_bones`/`torso_bones` force generically-named bones (ignoring exclusions).
  - `label_of(group) -> String` — a readable label (HEAD, L ARM…).
  - `default_multiplier(group) -> float` — the limb's **damage default**: head 1.5, the rest 1.0.
  - `default_sub_members() -> Array[String]` — the plan's default sub-members (base: none).

## Subclasses

- **`BodyPartsBiped`** — `ARM_L/ARM_R/LEG_L/LEG_R` (L/R ARM, L/R LEG). Side via `side_of`.
  `wing` counts as an ARM (winged creatures). It is the **DEFAULT** (player, red_robot).
- **`BodyPartsQuadruped`** — `LEG_FL/LEG_FR/LEG_RL/LEG_RR` (FRONT L/R LEG, REAR L/R LEG), no
  arms. `_leg_group` combines `front_rear_of` + `side_of`.
- **`BodyPartsCrawler`** — snake/slug/worm: **just inherits** (elongated body = TORSO). A thin subclass,
  a future extension point (e.g.: tail segments as sub-members).

## `BodyPlans` (factory)

`effects_shared/body_plans.gd` — **isolated** from the classes to avoid base↔subclass coupling
(the base doesn't reference the subclasses → no `extends` cycle).

- `BodyPlans.for_type(body_type) -> BodyParts` — match: `quadruped`/`crawler`/`_ => biped`.
- `BodyPlans.default() -> BodyParts` — biped (for whoever doesn't know the type, e.g.: the debug overlay
  over arbitrary level skeletons).
- `const TYPES = ["biped","quadruped","crawler"]` — valid values for the `@export body_type`.

---

## Who uses it

- **`LimbColliders`** (`build_for`) resolves `_classifier = BodyPlans.for_type(body_type)` and
  classifies each bone by `_classifier.group_of(...)`. The default multiplier of each limb comes
  from `_classifier.default_multiplier(group)` (the per-model saved one comes from `LimbConfig`).
- **`debug_overlay.gd`** (`_add_3d_skeleton`) uses `BodyPlans.default()` to label level skeletons.
- **`models.gd`** resolves the classifier via `_current_classifier()` (from `_MODEL_BODY_TYPE`) to
  list members and discover the AUXILIARY bones (whose `group_of` gives "") as sub-member candidates.

---

## Path: `effects_shared/body_parts.gd` (+ `body_parts_biped/quadruped/crawler.gd`, `body_plans.gd`)

---

## Related

- [[🩸 dano-localizado (EN)|Localized Damage]]
- [[🦿 limb-colliders-gd (EN)|limb_colliders.gd]]
- [[🗿 biblioteca-de-modelos (EN)|Model Library]]
- [[🧱 recursos-nativos-godot (EN)|Native Godot Resources]]

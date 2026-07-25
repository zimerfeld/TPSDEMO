---
tipo: arquivo-chave
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-23
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
  - `words_of(name) -> PackedStringArray` *(2026-07-23)* — splits the name into WORDS, separating
    camelCase and `_ . -` (`"peDireito"` → `["pe","direito"]`). It exists to match **ambiguous terms by
    EXACT token** instead of `contains`: the PT "pe" (foot), as a substring, would show up inside
    `peito`/`perna`/`pescoco`.
- **Instance virtuals** (the base handles only HEAD/TORSO; subclasses extend and fall back to the base via
  `super`):
  - `members() -> Array[String]` — the groups the plan defines (for the screen to list/label).
  - `group_of(bone, head_bones, torso_bones, leg_bones) -> String` — the bone's group or "".
    `head_bones`/`torso_bones` force generically-named bones (ignoring exclusions).
  - `label_of(group) -> String` — a readable label (HEAD, L ARM…).
  - `default_multiplier(group) -> float` — the limb's **damage default**: head 1.5, the rest 1.0.
  - `default_sub_members() -> Array[String]` — the plan's default sub-members (base: none).
  - `is_distal_sub_member(bone) -> bool` *(2026-07-23)* — is the bone an **extremity** that should become
    an automatic SUB-MEMBER (forearm/hand, shin/foot)? Base: `false` (head/torso only). See
    [[🩸 dano-localizado (EN)|Localized Damage]].

### 🌍 Bilingual PT + EN *(2026-07-23)*

The keywords now cover **English and Portuguese**, because the models arrive in both languages
(`humanoide` came with `head/chest/upper_arm.R`; `monstro` with `cabeca/peito/bracoDireito`). Before that,
a PT rig classified **0 out of 16 bones**.

| Limb | EN | PT |
|---|---|---|
| HEAD | `head`, `neck` | `cabeca`, `pescoco` |
| TORSO | `hips`, `pelvis`, `spine`, `chest`, `torso`, `body` | `tronco`, `peito`, `quadril`, `bacia`, `coluna`, `torax` |

## Subclasses

- **`BodyPartsBiped`** — `ARM_L/ARM_R/LEG_L/LEG_R` (L/R ARM, L/R LEG). Side via `side_of`.
  `wing`/`asa` counts as an ARM (winged creatures). It is the **DEFAULT** (player, red_robot).
  - Per-segment words (EN+PT), in constants: `_ARM_ROOT_KW` (`shoulder/arm` · `ombro/braco`),
    `_ARM_DISTAL_KW` (`forearm/hand` · `antebraco/mao`), `_LEG_ROOT_KW` (`thigh/knee/leg` ·
    `coxa/joelho/perna`), `_LEG_DISTAL_KW` (`shin/calf/lowerleg` · `canela/panturrilha`). The **foot** has
    its own handling (`_is_foot_word`): `foot`/`feet` by substring and the PT `pe` by **exact token**.
  - `is_distal_sub_member` returns `true` for the DISTAL words (+ foot) **with a defined side** and outside
    the exclusions. The distal ones also carry over into `group_of`/`owner_hint`: when the model **opts out**
    of the subdivision, the extremity goes back to being absorbed into the ARM/LEG (player/red_robot behavior).
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

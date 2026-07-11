---
tipo: arquivo-chave
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# 🦴 effects_shared/body_parts.gd (+ body plans)

**Created/refactored on:** 2026-06-20 · **Extends:** `RefCounted` (sin nodo)

---

## Qué es

La **jerarquía de BODY PLAN**: clasifica los huesos de un `Skeleton3D` en
**MIEMBROS** (HEAD, TORSO, ARM, LEG…) y proporciona las etiquetas por defecto y los multiplicadores
de daño de cada miembro. Usada por los colisionadores de daño localizado
([[🦿 limb-colliders-gd (ES)|LimbColliders]]) y por el overlay Debug 3D
(`debug_overlay.gd`).

`BodyParts` dejó de ser una clase solo-estática y pasó a ser una **BASE instanciable con
métodos VIRTUALES** — porque el estático `BodyParts.group_of(...)` **NO es polimórfico** en
GDScript: una llamada estática siempre resolvería a la base, ignorando la subclase. **Usa siempre
una INSTANCIA** (vía [[#BodyPlans (factory)|BodyPlans]]).

---

## Archivos

| File | `class_name` | Rol |
|---|---|---|
| `body_parts.gd` | `BodyParts` | **BASE**: HEAD/TORSO + pipeline común + estáticos universales |
| `body_parts_biped.gd` | `BodyPartsBiped extends BodyParts` | + L/R ARM, L/R LEG — **POR DEFECTO** |
| `body_parts_quadruped.gd` | `BodyPartsQuadruped extends BodyParts` | + 4 piernas (front/rear × L/R), sin brazos |
| `body_parts_crawler.gd` | `BodyPartsCrawler extends BodyParts` | solo hereda — solo HEAD/TORSO |
| `body_plans.gd` | `BodyPlans` | **factory** que entrega la instancia correcta por `body_type` |

---

## Base `BodyParts`

- **Constantes universales:** `HEAD`/`TORSO` + `BASE_LABELS` (HEAD/TORSO) + `EXCLUDE_KEYWORDS`
  (huesos auxiliares/mecánicos — ik, guard, piston, plate, eye… — que NO se convierten en un miembro principal;
  pueden ascenderse a un submiembro por modelo).
- **Estáticos universales** (independientes del plan, válidos para todas las subclases):
  - `side_of(name) -> "L"/"R"/""` — detecta el lado por el nombre: prefijo/sufijo `L-/R-`, `.l/_l`,
    `…L/…R` en MAYÚSCULAS, **y** las palabras `left`/`right`/`esquerd`/`direit` (fallback).
  - `front_rear_of(name) -> "F"/"R"/""` — delantero (front/fore/dianteira/frente) vs trasero
    (rear/hind/back/traseira); usado por el cuadrúpedo para separar las 4 piernas.
- **Virtuales de instancia** (la base maneja solo HEAD/TORSO; las subclases extienden y recurren a la base vía
  `super`):
  - `members() -> Array[String]` — los grupos que el plan define (para que la pantalla los liste/etiquete).
  - `group_of(bone, head_bones, torso_bones, leg_bones) -> String` — el grupo del hueso o "".
    `head_bones`/`torso_bones` fuerzan huesos con nombres genéricos (ignorando exclusiones).
  - `label_of(group) -> String` — una etiqueta legible (HEAD, L ARM…).
  - `default_multiplier(group) -> float` — el **daño por defecto** del miembro: cabeza 1.5, el resto 1.0.
  - `default_sub_members() -> Array[String]` — los submiembros por defecto del plan (base: ninguno).

## Subclases

- **`BodyPartsBiped`** — `ARM_L/ARM_R/LEG_L/LEG_R` (L/R ARM, L/R LEG). Lado vía `side_of`.
  `wing` cuenta como un ARM (criaturas aladas). Es el **POR DEFECTO** (jugador, red_robot).
- **`BodyPartsQuadruped`** — `LEG_FL/LEG_FR/LEG_RL/LEG_RR` (FRONT L/R LEG, REAR L/R LEG), sin
  brazos. `_leg_group` combina `front_rear_of` + `side_of`.
- **`BodyPartsCrawler`** — serpiente/babosa/gusano: **solo hereda** (cuerpo alargado = TORSO). Una subclase fina,
  un punto de extensión futuro (p. ej.: segmentos de cola como submiembros).

## `BodyPlans` (factory)

`effects_shared/body_plans.gd` — **aislado** de las clases para evitar el acoplamiento base↔subclase
(la base no referencia a las subclases → sin ciclo de `extends`).

- `BodyPlans.for_type(body_type) -> BodyParts` — match: `quadruped`/`crawler`/`_ => biped`.
- `BodyPlans.default() -> BodyParts` — biped (para quien no conoce el tipo, p. ej.: el debug overlay
  sobre esqueletos arbitrarios de nivel).
- `const TYPES = ["biped","quadruped","crawler"]` — valores válidos para el `@export body_type`.

---

## Quién lo usa

- **`LimbColliders`** (`build_for`) resuelve `_classifier = BodyPlans.for_type(body_type)` y
  clasifica cada hueso por `_classifier.group_of(...)`. El multiplicador por defecto de cada miembro viene
  de `_classifier.default_multiplier(group)` (el guardado por modelo viene de `LimbConfig`).
- **`debug_overlay.gd`** (`_add_3d_skeleton`) usa `BodyPlans.default()` para etiquetar esqueletos de nivel.
- **`models.gd`** resuelve el clasificador vía `_current_classifier()` (a partir de `_MODEL_BODY_TYPE`) para
  listar miembros y descubrir los huesos AUXILIARES (cuyo `group_of` da "") como candidatos a submiembro.

---

## Path: `effects_shared/body_parts.gd` (+ `body_parts_biped/quadruped/crawler.gd`, `body_plans.gd`)

---

## Relacionado

- [[🩸 dano-localizado (ES)|Daño Localizado]]
- [[🦿 limb-colliders-gd (ES)|limb_colliders.gd]]
- [[🗿 biblioteca-de-modelos (ES)|Biblioteca de Modelos]]
- [[🧱 recursos-nativos-godot (ES)|Recursos Nativos de Godot]]

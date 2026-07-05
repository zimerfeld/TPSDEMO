---
tipo: arquivo-chave
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 🧠 library3D/characters/red_robot/IA/red_robot_ai.gd

**Created on:** 2026-06-18
**Extends:** `Node` · **`class_name RedRobotAI`**

---

## Responsibilities

Centralizes the Red Robot's combat **behaviors and decisions** at runtime. The body
(`red_robot.gd`) instantiates this AI as a child in `_ready()` (name `IA`) and queries it every frame.
It keeps the physics, animation and firing in the body; only the **decision rules** and the
tunables live here, easy to adjust without touching the state machine.

---

## Tunables (`@export`)

| Var | Value | Effect |
|---|---|---|
| `fire_rate_multiplier` | `1.5` | Reload **1.5× faster** (1st and next shots) |
| `flee_distance` | `10.0 m` | Player at this distance or less → the robot backs away shooting |
| `flee_speed` | `6.0 m/s` | Speed when running away from the player |
| `formation_cohesion` | `0.55` | Strength of the return to the assigned formation slot |
| `formation_band` | `5.0 m` | Tolerance before the robot is pulled back to the slot |
| `speed_variation` | `±0.18` | Per-individual speed variation (breaks the lockstep) |

---

## API

```gdscript
enum Action { APPROACH, ENGAGE, FLEE }

func reload_time(base_wait: float) -> float        # base_wait / fire_rate_multiplier
func decide(distance, effective_range) -> Action   # FLEE / ENGAGE / APPROACH
func should_shoot(distance, effective_range) -> bool  # distance <= effective_range
```

- `decide()`: `dist ≤ flee_distance` → **FLEE**; `dist ≤ range` → **ENGAGE**; otherwise **APPROACH**.
- `reload_time()`: used by the body for `shoot_reload = ai.reload_time(SHOOT_WAIT)`.

---

## How the body uses it (`red_robot.gd`)

- **Accelerated reload:** `shoot_reload` replaces `SHOOT_WAIT` in all resets of
  `shoot_countdown` (1st shot included).
- **Backing away (FLEE):** when `decide(...) == FLEE`, `_flee_movement()` faces the player (front +Z) and
  sets the velocity in the opposite direction (`-fwd * flee_speed`), overriding the root motion; the legs
  play `walk` and firing continues (the player is within range).
- **Firing:** the aiming logic already only fires within `effective_range`, covering ENGAGE and FLEE.

---

## Path: `library3D/characters/red_robot/IA/red_robot_ai.gd`

---

## Individualization + formation (2026-06-25)

- **No lockstep:** `_ready` seeds per instance `_strafe_sign` (random ±1), `_phase` and
  `_speed_mult` (`1 ± speed_variation`); the resets of `_strafe_cooldown` in `_choose_strafe_sign`
  use `randf_range` (≈0.45–1.6 s) instead of fixed periods (~1 s). This way the squad **does not walk
  identically every second**. Server RNG (movement is server-authoritative; clients interpolate).
- **Assigned formation:** on the 1st call of `movement_plan`, it captures `_slot_bearing` from
  `origin - target_position` (the spawn direction seen from the player). During strafe/engage, it adds a
  **return bias** to the point `player + slot_dir * preferred` when the slack exceeds `formation_band`,
  weighted by `formation_cohesion`. The robot **circles freely** but tends to **return to its place**.
- **Speed:** `flee/strafe/pressure speed` come out multiplied by `_speed_mult`.

---

## Related

- [[🤖 red-robot-gd (EN)|red_robot.gd]]
- [[🤖 inimigos (EN)|Enemies]]
- [[🩸 dano-localizado (EN)|Localized Damage]]

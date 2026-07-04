---
tipo: arquivo-chave
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 🤖 library3D/characters/red_robot/red_robot.gd

**Extends:** `CharacterBody3D`

---

## Responsibilities

- AI with 3 states: APPROACH / AIM / SHOOTING
- Laser raycast that detects the player and applies a hit
- HP system (`health: int = 5`)
- Death with ragdoll physics (parts explode as RigidBody3D)
- Respawn managed by the level (signal `exploded`)

---

## Exported / Synchronized Variables

```gdscript
const HIT_DAMAGE: int = 50          # damage per shot taken
@export var enemy_name: String = "Red Robot"
@export var max_health: int = 200
@export var health: int = 200
@export var state: State = State.APPROACH
@export var dead: bool = false
@export var target_position: Vector3
@export var aim_preparing: float
```

---

## `hit()` Method (RPC call_local)

```gdscript
health = maxi(health - HIT_DAMAGE, 0)   # -50 per shot → dies in 4 shots
# animates a random hit (hit1/hit2/hit3)
if health <= 0:
    dead = true
    # hides model, disables collision
    # parts explode (shield1/shield2/head)
    # emits the exploded signal
    # server: queue_free() after 10s
```

---

## Laser

- `RayCast3D` fired from the position of the `RayFrom` bone
- A shader clips the ray mesh by the collision length
- `LaserEmber` particles positioned in the middle of the ray
- On hitting the player: `player.add_camera_shake_trauma(13.0)` after a 0.1s delay

---

## Death (Parts)

| Node | Type |
|---|---|
| `PartShield1` / `PartShield2` | `RigidBody3D` |
| `PartHead` | `RigidBody3D` |
| `DetachSpark1/2` | `CPUParticles3D` |

---

## Path: `library3D/characters/red_robot/red_robot.gd`

---

## Weapon, accuracy and damage (updated)

- `weapon_damage`, `aim_accuracy = 1.0` (100%), `effective_range = 30 m`
- Only fires when the player is within range (precise aim)
- `hit(amount)` takes damage from the attacker's weapon; the projectile (CannonShooter) applies
  localized damage to the player's limb colliders
- `show_health_hud(distance)` displays the distance **and the weapon range** (`effective_range`) on the HUD
- See [[🩸 dano-localizado (EN)|Localized Damage]]

---

## AI (`IA/red_robot_ai.gd`)

The runtime behaviors/decisions live in a dedicated AI script
([[🧠 red-robot-ai-gd (EN)|red_robot_ai.gd]], `class_name RedRobotAI`), instantiated as a child in `_ready()`
and queried every frame by the body (`red_robot.gd`):

- **Reload 1.5× faster** — `shoot_reload = ai.reload_time(SHOOT_WAIT)` = `SHOOT_WAIT / 1.5`;
  used on the 1st shot and in all resets of `shoot_countdown` (applies to the 1st and the next).
- **Engage** — fires whenever the player is within `effective_range` (the shooting aim already
  does that test); in practice, it opens fire in the range `10 m < dist ≤ range`.
- **Back away (FLEE)** — when `dist ≤ flee_distance` (10 m), `_flee_movement()` orients the body
  to **face the player** (front +Z) and sets the velocity in the **opposite direction**
  (`-fwd * flee_speed`), overriding the root motion; the legs play `walk` and firing continues.
- Tunables in the AI: `fire_rate_multiplier = 1.5`, `flee_distance = 10.0`, `flee_speed = 6.0`.

---

## Related

- [[🤖 inimigos (EN)|Enemies]]
- [[🧠 red-robot-ai-gd (EN)|red_robot_ai.gd]]
- [[🩸 dano-localizado (EN)|Localized Damage]]
- [[🎯 fluxo-de-tiro (EN)|Shooting Flow]]

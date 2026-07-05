---
tipo: arquivo-chave
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 🎮 library3D/characters/players/player/player.gd

**Class:** `Player extends CharacterBody3D`

---

## Responsibilities

- Physics and movement (root motion, server)
- Animation management (enum `Animations`)
- Bullet instantiation and firing
- **HP and respawn system**
- **Player name** — `NameLabel` (Label3D, billboard) above the head appears only for the
  **other** connected players; on the local player itself the name goes to the HUD (health_bar) and the
  Label3D is hidden. Decided by `_is_owned_locally()` (the InputSynchronizer's authority ==
  this peer and not a bot; covers host id 1 and clients), re-evaluated when `player_id`/`bot_controlled`/
  `player_name` change. See [[💚 health-bar-gd (EN)|health_bar.gd]]
- Sounds: jump, land, shoot
- Camera shake via trauma

---

## Structure

```
_ready()
  ├─ initializes orientation
  ├─ disables process on clients (the server does physics)
  └─ _setup_health_bar.call_deferred()  (also fired by the player_id setter)

player_id (setter)
  ├─ set_multiplayer_authority(InputSynchronizer)
  └─ _setup_health_bar.call_deferred()  (guarantees the HUD on a multiplayer client)

_physics_process(delta)
  ├─ server → apply_input(delta)
  └─ client  → animate(current_animation, delta)

apply_input(delta)
  ├─ interpolates motion
  ├─ jump / airborne logic
  ├─ aiming → STRAFE → instantiates a bullet
  ├─ walk → orients by movement
  ├─ root motion → move_and_slide()
  └─ respawn if y < -40

animate(anim, delta)
  └─ controls the AnimationTree parameters
```

---

## Important Constants and Variables

```gdscript
const MOTION_INTERPOLATE_SPEED: float = 10.0
const ROTATION_INTERPOLATE_SPEED: float = 10.0
const MIN_AIRBORNE_TIME: float = 0.1
const JUMP_SPEED: float = 5.0
const MAX_HP: int = 100

var hp: int = MAX_HP
var airborne_time: float = 100.0
var orientation := Transform3D()
var root_motion := Transform3D()
var motion := Vector2()
```

---

## Dependencies (`@onready`)

```
$InputSynchronizer      → PlayerInputSynchronizer
$AnimationTree          → AnimationTree
$PlayerModel            → Node3D (3D model)
$FireCooldown           → Timer (0.4s)
$SoundEffects/Jump      → AudioStreamPlayer
$SoundEffects/Land      → AudioStreamPlayer
$SoundEffects/Shoot     → AudioStreamPlayer
PlayerModel/.../GunBone/ShootFrom → Marker3D
```

---

## Path: `library3D/characters/players/player/player.gd`

---

## Related

- [[🎮 player (EN)|Player]]
- [[❤️ sistema-de-vida (EN)|Health System]]
- [[🕹️ player-input-gd (EN)|player_input.gd]]
- [[💚 health-bar-gd (EN)|health_bar.gd]]

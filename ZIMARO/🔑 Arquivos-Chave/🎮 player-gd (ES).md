---
tipo: arquivo-chave
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# 🎮 library3D/characters/players/player/player.gd

**Class:** `Player extends CharacterBody3D`

---

## Responsabilidades

- Física y movimiento (root motion, servidor)
- Gestión de animaciones (enum `Animations`)
- Instanciación y disparo de balas
- **Sistema de HP y reaparición**
- **Nombre del jugador** — `NameLabel` (Label3D, billboard) sobre la cabeza aparece solo para los
  **otros** jugadores conectados; en el propio jugador local el nombre va al HUD (health_bar) y el
  Label3D se oculta. Decidido por `_is_owned_locally()` (la autoridad del InputSynchronizer ==
  este peer y no es un bot; cubre el host id 1 y los clientes), reevaluado cuando `player_id`/`bot_controlled`/
  `player_name` cambian. Ver [[💚 health-bar-gd (ES)|health_bar.gd]]
- Sonidos: salto, aterrizaje, disparo
- Sacudida de cámara mediante trauma

---

## Estructura

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

## Constantes y variables importantes

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

## Dependencias (`@onready`)

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

## Relacionado

- [[🎮 player (ES)|Jugador]]
- [[❤️ sistema-de-vida (ES)|Sistema de Vida]]
- [[🕹️ player-input-gd (ES)|player_input.gd]]
- [[💚 health-bar-gd (ES)|health_bar.gd]]

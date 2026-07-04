---
tipo: arquivo-chave
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 🕹️ library3D/characters/players/player/player_input.gd

**Class:** `PlayerInputSynchronizer extends MultiplayerSynchronizer`

---

## Responsibilities

- Captures input from keyboard, mouse and gamepad
- Rotates the camera
- Synchronizes `motion`, `aiming`, `shooting`, `shoot_target` to the server
- Manages the aim toggle/hold logic
- Does a fade-to-black when falling off the map
- Shows/hides the HUD for non-local peers
- **Detects an enemy under the crosshair** (`_update_enemy_focus()`) and shows the enemy HUD

---

## `_update_enemy_focus()`

Runs every frame in `_process` (only on the local player). Casts a ray from the crosshair and
**tracks** the focused enemy (`var _focused_enemy: Node`):

```gdscript
# Mask 0b100011 = body (bits 1-2) + the enemy's limb colliders (bit6=32).
var col = ...intersect_ray(ray_from, ray_from + ray_dir*1000, 0b100011, [self])
var enemy = _resolve_focus_enemy(col.collider)
if enemy:
    enemy.show_health_hud()       # shows/updates the boss bar
    _focused_enemy = enemy
elif _focused_enemy != null:
    if is_instance_valid(_focused_enemy):
        _focused_enemy.hide_health_hud()   # aim left → hide immediately
    _focused_enemy = null
```

`_resolve_focus_enemy(collider)` accepts **two** kinds of hit:
1. **The enemy body** (`CharacterBody3D`) — already has `show_health_hud`.
2. **A LIMB / SUB-MEMBER collider** (a passive `StaticBody3D` of the `LimbColliders`,
   layer 32) — it stores the owner in `meta("character")`; the HUD is resolved from it.

> The mask includes **layer 32** (the enemy's limb hitbox) besides the body, so that aiming
> at a **protruding sub-member** (e.g.: the red_robot's leg plates, which escape the body's
> silhouette and used to register nothing) also shows the enemy's health. The player is unaffected
> (its limbs sit on layer 16, outside the mask). The HUD disappears the instant the crosshair leaves
> the enemy. See [[🩹 enemy-health-bar-gd (EN)|enemy_health_bar.gd]] and [[🦿 limb-colliders-gd (EN)|limb_colliders.gd]]

---

## Synchronized Variables (`@export`)

```gdscript
@export var aiming: bool = false
@export var shoot_target := Vector3()
@export var motion := Vector2()
@export var shooting: bool = false
@export var jumping: bool = false   # via RPC
```

---

## Scene References (`@export` — inspector)

```
camera_animation : AnimationPlayer
crosshair        : TextureRect
camera_base      : Node3D
camera_rot       : Node3D
camera_camera    : Camera3D
color_rect       : ColorRect
```

---

## Camera Constants

```gdscript
CAMERA_CONTROLLER_ROTATION_SPEED = 3.0
CAMERA_MOUSE_ROTATION_SPEED      = 0.001
CAMERA_X_ROT_MIN = -89.9°
CAMERA_X_ROT_MAX =  70.0°
AIM_HOLD_THRESHOLD = 0.4 s
```

---

## Vertical aim — PROCEDURAL (`get_aim_pitch()` + `procedural_aim.gd`)

The player's vertical aim **no longer** uses the additive `AIM-Up`/`AIM-Down` blend of the
`AnimationNodeAdd3`. Diagnosis (headless, driving the real player and reading the weapon
direction `hand.R+X`): that blend **cannot lower the arm** — both looking up and
down gave a slight **V** shape (minimum at the center, rising to both sides), so the
lower half appeared **inverted** (weapon up when aiming down). No value of
`add_amount` points the weapon down — it's a limitation of the rig's own animations.

> [!info] Procedural solution (2026-06-18)
> `player_input.get_aim_pitch()` returns the camera's pitch (rad). In `player.gd` (STRAFE
> state) the vertical additive is **turned off** (`parameters/aim/add_amount = 0`) and that pitch
> feeds `_aim_modifier.aim_pitch`. The `SkeletonModifier3D` [[procedural-aim-gd|procedural_aim.gd]]
> (a child of the `Skeleton3D`, created in `_setup_aim_modifier`) runs, **after** the AnimationTree,
> the **`chest`** bone around the skeleton's right axis by `aim_pitch * strength`. Since
> shoulders/arms/weapon/neck are children of `chest`, the whole torso follows the aim
> **up AND down**.
>
> Tunables on the modifier (exports): `strength` (fraction of the pitch, default 0.7), `pitch_axis`
> (flip the sign if the aim comes out reversed), `aim_bone` (default `chest`). Fine-tuning is
> **visual** (check in-game) — the global pose cache in headless doesn't reflect the
> post-modifier result, so direction/magnitude are confirmed by running the game.

---

## Behavior in `_ready()`

```gdscript
if authority == local_id:
    camera.make_current()
    Input.set_mouse_mode(CAPTURED)
else:
    set_process(false)       # doesn't process input
    set_process_input(false)
    color_rect.hide()        # hides other players' HUD
```

---

## Path: `library3D/characters/players/player/player_input.gd`

---

## Related

- [[🎮 player (EN)|Player]]
- [[⌨️ fluxo-de-input (EN)|Input Flow]]
- [[🎮 player-gd (EN)|player.gd]]

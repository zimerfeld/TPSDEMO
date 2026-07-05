---
tipo: fluxo
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# ⌨️ Input Flow

---

## Full Pipeline

```
Keyboard/Mouse/Gamepad
        │
        ▼
PlayerInputSynchronizer._process()  [runs only on the owner peer]
        │  captures: motion, aiming, shooting
        │  camera: rotate_camera()
        │
        ▼  [synchronized → server via MultiplayerSynchronizer]
Player.apply_input()  [runs only on the server]
        │  reads: player_input.motion, player_input.aiming, etc.
        │
        ▼
  move_and_slide()  [physics on the server]
        │
        ▼  [ServerSynchronizer replicates the transform → clients]
Player.animate()  [runs only on the clients]
```

---

## Mapped Actions

| Action | Function |
|---|---|
| `move_right` / `move_left` | X axis of `motion` |
| `move_back` / `move_forward` | Y axis of `motion` |
| `view_right/left/up/down` | Camera rotation (gamepad) |
| `aim` | Toggle/hold to aim |
| `shoot` | Shoot (hold) |
| `jump` | Jump (immediate RPC) |
| `quit` | Exit to the menu |

---

## Camera

- `camera_base` rotates on the Y axis (horizontal)
- `camera_rot` rotates on the X axis (vertical) with clamp
- Mouse: `InputEventMouseMotion` → `rotate_camera(screen_relative * speed)`
- Gamepad: `camera_move * delta * CAMERA_CONTROLLER_ROTATION_SPEED`

### Reduced speed while aiming
| Mode | Factor |
|---|---|
| Gamepad aiming | `0.5x` |
| Mouse aiming | `0.75x` |

---

## Aim System (Toggle vs Hold)

```
Press aim:
  - toggled_aim = false

Release aim in < 0.4s:
  - current_aim = true (toggle on)
  - toggled_aim = true

Release aim in > 0.4s:
  - hold mode: aim active only while the button is pressed

Press aim again with the toggle active:
  - deactivates aim (toggled_aim = false)
```

---

## Crosshair Raycasting

```gdscript
var ch_pos = crosshair.position + crosshair.size * 0.5
var ray_from = camera.project_ray_origin(ch_pos)
var ray_dir  = camera.project_ray_normal(ch_pos)
# PhysicsRayQuery of 1000 units
# → shoot_target (synchronized with the server)
```

---

## Related

- [[🎮 player (EN)|Player]]
- [[🌐 multiplayer (EN)|Multiplayer]]
- [[🕹️ player-input-gd (EN)|player_input.gd]]

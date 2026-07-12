---
tipo: fluxo
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# ⌨️ Flujo de input

---

## Pipeline completa

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

## Acciones mapeadas

| Acción | Función |
|---|---|
| `move_right` / `move_left` | Eje X de `motion` |
| `move_back` / `move_forward` | Eje Y de `motion` |
| `view_right/left/up/down` | Rotación de la cámara (mando) |
| `aim` | Alternar/mantener para apuntar |
| `shoot` | Disparar (mantener) |
| `jump` | Saltar (RPC inmediato) |
| `quit` | Salir al menú |

---

## Cámara

- `camera_base` rota en el eje Y (horizontal)
- `camera_rot` rota en el eje X (vertical) con clamp
- Ratón: `InputEventMouseMotion` → `rotate_camera(screen_relative * speed)`
- Mando: `camera_move * delta * CAMERA_CONTROLLER_ROTATION_SPEED`

### Velocidad reducida al apuntar
| Modo | Factor |
|---|---|
| Apuntar con mando | `0.5x` |
| Apuntar con ratón | `0.75x` |

---

## Sistema de puntería (alternar vs mantener)

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

## Raycasting de la mira

```gdscript
var ch_pos = crosshair.position + crosshair.size * 0.5
var ray_from = camera.project_ray_origin(ch_pos)
var ray_dir  = camera.project_ray_normal(ch_pos)
# PhysicsRayQuery of 1000 units
# → shoot_target (synchronized with the server)
```

---

## Relacionado

- [[🎮 player (ES)|Jugador]]
- [[🌐 multiplayer (ES)|Multiplayer]]
- [[🕹️ player-input-gd (ES)|player_input.gd]]

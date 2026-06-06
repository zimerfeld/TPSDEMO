# Fluxo de Input

---

## Pipeline Completo

```
Teclado/Mouse/Gamepad
        │
        ▼
PlayerInputSynchronizer._process()  [roda apenas no peer dono]
        │  captura: motion, aiming, shooting
        │  câmera: rotate_camera()
        │
        ▼  [sincronizado → servidor via MultiplayerSynchronizer]
Player.apply_input()  [roda apenas no servidor]
        │  lê: player_input.motion, player_input.aiming, etc.
        │
        ▼
  move_and_slide()  [física no servidor]
        │
        ▼  [ServerSynchronizer replica transform → clientes]
Player.animate()  [roda apenas nos clientes]
```

---

## Actions Mapeadas

| Action | Função |
|---|---|
| `move_right` / `move_left` | Eixo X do `motion` |
| `move_back` / `move_forward` | Eixo Y do `motion` |
| `view_right/left/up/down` | Rotação de câmera (gamepad) |
| `aim` | Toggle/hold para mirar |
| `shoot` | Atirar (hold) |
| `jump` | Pular (RPC imediato) |
| `quit` | Sair para o menu |

---

## Câmera

- `camera_base` rotaciona no eixo Y (horizontal)
- `camera_rot` rotaciona no eixo X (vertical) com clamp
- Mouse: `InputEventMouseMotion` → `rotate_camera(screen_relative * speed)`
- Gamepad: `camera_move * delta * CAMERA_CONTROLLER_ROTATION_SPEED`

### Velocidade reduzida ao mirar
| Modo | Fator |
|---|---|
| Gamepad aiming | `0.5x` |
| Mouse aiming | `0.75x` |

---

## Sistema de Aim (Toggle vs Hold)

```
Pressionar aim:
  - toggled_aim = false
  
Soltar aim em < 0.4s:
  - current_aim = true (toggle ligado)
  - toggled_aim = true

Soltar aim em > 0.4s:
  - hold mode: aim ativo apenas enquanto botão pressionado

Pressionar aim novamente com toggle ativo:
  - desativa aim (toggled_aim = false)
```

---

## Crosshair Raycasting

```gdscript
var ch_pos = crosshair.position + crosshair.size * 0.5
var ray_from = camera.project_ray_origin(ch_pos)
var ray_dir  = camera.project_ray_normal(ch_pos)
# PhysicsRayQuery de 1000 unidades
# → shoot_target (sincronizado com servidor)
```

---

## Relacionado

- [[sistemas/player]]
- [[sistemas/multiplayer]]
- [[arquivos-chave/player-input-gd]]

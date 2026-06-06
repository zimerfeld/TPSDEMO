# player/player_input.gd

**Classe:** `PlayerInputSynchronizer extends MultiplayerSynchronizer`

---

## Responsabilidades

- Captura input do teclado, mouse e gamepad
- Rotaciona a câmera
- Sincroniza `motion`, `aiming`, `shooting`, `shoot_target` para o servidor
- Gerencia lógica de aim toggle/hold
- Faz fade-to-black ao cair do mapa
- Exibe/oculta HUD para peers não-locais
- **Detecta inimigo sob a mira** (`_update_enemy_focus()`) e exibe o HUD do inimigo

---

## `_update_enemy_focus()`

Roda a cada frame no `_process` (apenas no player local). Lança um raio da mira e
**rastreia** o inimigo focado (`var _focused_enemy: Node`):

```gdscript
var col = ...intersect_ray(ray_from, ray_from + ray_dir*1000, 0b11, [self])
var enemy = (collider tem show_health_hud) ? collider : null
if enemy:
    enemy.show_health_hud()       # mostra/atualiza a boss bar
    _focused_enemy = enemy
elif _focused_enemy != null:
    if is_instance_valid(_focused_enemy):
        _focused_enemy.hide_health_hud()   # mira saiu → esconde imediatamente
    _focused_enemy = null
```

> Usa `has_method("show_health_hud")` para reagir só a inimigos (o player não tem esse método).
> O HUD some no instante em que a mira deixa o inimigo. Ver [[arquivos-chave/enemy-health-bar-gd]]

---

## Variáveis Sincronizadas (`@export`)

```gdscript
@export var aiming: bool = false
@export var shoot_target := Vector3()
@export var motion := Vector2()
@export var shooting: bool = false
@export var jumping: bool = false   # via RPC
```

---

## Referências de Cena (`@export` — inspector)

```
camera_animation : AnimationPlayer
crosshair        : TextureRect
camera_base      : Node3D
camera_rot       : Node3D
camera_camera    : Camera3D
color_rect       : ColorRect
```

---

## Constantes de Câmera

```gdscript
CAMERA_CONTROLLER_ROTATION_SPEED = 3.0
CAMERA_MOUSE_ROTATION_SPEED      = 0.001
CAMERA_X_ROT_MIN = -89.9°
CAMERA_X_ROT_MAX =  70.0°
AIM_HOLD_THRESHOLD = 0.4 s
```

---

## Comportamento em `_ready()`

```gdscript
if authority == local_id:
    camera.make_current()
    Input.set_mouse_mode(CAPTURED)
else:
    set_process(false)       # não processa input
    set_process_input(false)
    color_rect.hide()        # oculta HUD de outros players
```

---

## Caminho: `player/player_input.gd`

---

## Relacionado

- [[sistemas/player]]
- [[fluxos/fluxo-de-input]]
- [[arquivos-chave/player-gd]]

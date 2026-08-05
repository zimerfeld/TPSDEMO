---
tipo: arquivo-chave
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-07-04
---

# 🕹️ library3D/characters/players/player/player_input.gd

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
# Máscara 0b100011 = corpo (bits 1-2) + colliders de membro do inimigo (bit6=32).
var col = ...intersect_ray(ray_from, ray_from + ray_dir*1000, 0b100011, [self])
var enemy = _resolve_focus_enemy(col.collider)
if enemy:
    enemy.show_health_hud()       # mostra/atualiza a boss bar
    _focused_enemy = enemy
elif _focused_enemy != null:
    if is_instance_valid(_focused_enemy):
        _focused_enemy.hide_health_hud()   # mira saiu → esconde imediatamente
    _focused_enemy = null
```

`_resolve_focus_enemy(collider)` aceita **dois** tipos de acerto:
1. **Corpo do inimigo** (`CharacterBody3D`) — já tem `show_health_hud`.
2. **Collider de MEMBRO / SUB-MEMBRO** (`StaticBody3D` passivo dos `LimbColliders`,
   layer 32) — guarda o dono em `meta("character")`; o HUD é resolvido por ela.

> A máscara inclui a **layer 32** (hitbox de membro do inimigo) além do corpo, para que mirar
> num **sub-membro saliente** (ex.: as placas das pernas do red_robot, que escapam da silhueta
> do corpo e antes não acusavam nada) também exiba a vida do inimigo. O player não é afetado
> (seus membros ficam na layer 16, fora da máscara). O HUD some no instante em que a mira deixa
> o inimigo. Ver [[🩹 enemy-health-bar-gd (PT)|🩹 enemy-health-bar-gd]] e [[🦿 limb-colliders-gd (PT)|🦿 limb-colliders-gd]]

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

## Mira vertical — PROCEDURAL (`get_aim_pitch()` + `procedural_aim.gd`)

A mira vertical do player **não** usa mais o blend additive `AIM-Up`/`AIM-Down` do
`AnimationNodeAdd3`. Diagnóstico (headless, dirigindo o player real e lendo a direção da
arma `hand.R+X`): aquele blend **não consegue abaixar o braço** — tanto olhar p/ cima quanto
p/ baixo davam um leve formato de **V** (mínimo no centro, subindo p/ os dois lados), então a
metade de baixo aparecia **invertida** (arma para cima ao mirar para baixo). Nenhum valor de
`add_amount` aponta a arma para baixo — é limitação das próprias animações do rig.

> [!info] Solução procedural (2026-06-18)
> `player_input.get_aim_pitch()` devolve o pitch da câmera (rad). Em `player.gd` (estado
> STRAFE) o additive vertical é **desligado** (`parameters/aim/add_amount = 0`) e esse pitch
> alimenta `_aim_modifier.aim_pitch`. O `SkeletonModifier3D` [[procedural-aim-gd|procedural_aim.gd]]
> (filho do `Skeleton3D`, criado em `_setup_aim_modifier`) roda, **depois** do AnimationTree,
> o osso **`chest`** em torno do eixo direito do esqueleto por `aim_pitch * strength`. Como
> ombros/braços/arma/pescoço são filhos do `chest`, o torso inteiro acompanha a mira para
> **cima E para baixo**.
>
> Tunáveis no modifier (exports): `strength` (fração do pitch, default 0.7), `pitch_axis`
> (inverter o sinal se a mira ficar trocada), `aim_bone` (default `chest`). Ajuste fino é
> **visual** (verificar no jogo) — o cache de pose global no headless não reflete o resultado
> pós-modifier, então direção/magnitude se confirmam rodando o jogo.

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

## Caminho: `library3D/characters/players/player/player_input.gd`

---

## Relacionado

- [[🎮 player (PT)|🎮 player]]
- [[⌨️ fluxo-de-input (PT)|⌨️ fluxo-de-input]]
- [[🎮 player-gd (PT)|🎮 player-gd]]

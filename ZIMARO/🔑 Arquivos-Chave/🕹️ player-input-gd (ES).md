---
tipo: arquivo-chave
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# 🕹️ library3D/characters/players/player/player_input.gd

**Class:** `PlayerInputSynchronizer extends MultiplayerSynchronizer`

---

## Responsabilidades

- Captura la entrada del teclado, el ratón y el mando
- Rota la cámara
- Sincroniza `motion`, `aiming`, `shooting`, `shoot_target` con el servidor
- Gestiona la lógica de toggle/mantener de la puntería
- Hace un fundido a negro al caer del mapa
- Muestra/oculta el HUD para los peers no locales
- **Detecta un enemigo bajo la mira** (`_update_enemy_focus()`) y muestra el HUD del enemigo

---

## `_update_enemy_focus()`

Se ejecuta cada frame en `_process` (solo en el jugador local). Lanza un rayo desde la mira y
**rastrea** el enemigo enfocado (`var _focused_enemy: Node`):

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

`_resolve_focus_enemy(collider)` acepta **dos** tipos de impacto:
1. **El cuerpo del enemigo** (`CharacterBody3D`) — ya tiene `show_health_hud`.
2. **Un colisionador de MIEMBRO / SUBMIEMBRO** (un `StaticBody3D` pasivo de los `LimbColliders`,
   layer 32) — guarda al propietario en `meta("character")`; el HUD se resuelve a partir de él.

> La máscara incluye la **layer 32** (la hitbox de miembro del enemigo) además del cuerpo, de modo que apuntar
> a un **submiembro sobresaliente** (p. ej.: las placas de las piernas del red_robot, que escapan de la
> silueta del cuerpo y antes no registraban nada) también muestre la salud del enemigo. El jugador no se ve afectado
> (sus miembros están en la layer 16, fuera de la máscara). El HUD desaparece en el instante en que la mira abandona
> al enemigo. Ver [[🩹 enemy-health-bar-gd (ES)|enemy_health_bar.gd]] y [[🦿 limb-colliders-gd (ES)|limb_colliders.gd]]

---

## Variables sincronizadas (`@export`)

```gdscript
@export var aiming: bool = false
@export var shoot_target := Vector3()
@export var motion := Vector2()
@export var shooting: bool = false
@export var jumping: bool = false   # via RPC
```

---

## Referencias de escena (`@export` — inspector)

```
camera_animation : AnimationPlayer
crosshair        : TextureRect
camera_base      : Node3D
camera_rot       : Node3D
camera_camera    : Camera3D
color_rect       : ColorRect
```

---

## Constantes de cámara

```gdscript
CAMERA_CONTROLLER_ROTATION_SPEED = 3.0
CAMERA_MOUSE_ROTATION_SPEED      = 0.001
CAMERA_X_ROT_MIN = -89.9°
CAMERA_X_ROT_MAX =  70.0°
AIM_HOLD_THRESHOLD = 0.4 s
```

---

## Puntería vertical — PROCEDURAL (`get_aim_pitch()` + `procedural_aim.gd`)

La puntería vertical del jugador **ya no** usa la mezcla aditiva `AIM-Up`/`AIM-Down` del
`AnimationNodeAdd3`. Diagnóstico (headless, conduciendo al jugador real y leyendo la dirección
del arma `hand.R+X`): esa mezcla **no puede bajar el brazo** — tanto mirar arriba como
abajo daban una ligera forma de **V** (mínimo en el centro, subiendo hacia ambos lados), por lo que la
mitad inferior aparecía **invertida** (arma arriba al apuntar hacia abajo). Ningún valor de
`add_amount` apunta el arma hacia abajo — es una limitación de las propias animaciones del rig.

> [!info] Solución procedural (2026-06-18)
> `player_input.get_aim_pitch()` devuelve el pitch de la cámara (rad). En `player.gd` (estado STRAFE)
> el aditivo vertical se **desactiva** (`parameters/aim/add_amount = 0`) y ese pitch
> alimenta `_aim_modifier.aim_pitch`. El `SkeletonModifier3D` [[procedural-aim-gd|procedural_aim.gd]]
> (un hijo del `Skeleton3D`, creado en `_setup_aim_modifier`) ejecuta, **después** del AnimationTree,
> el hueso **`chest`** alrededor del eje derecho del esqueleto por `aim_pitch * strength`. Como
> hombros/brazos/arma/cuello son hijos de `chest`, todo el torso sigue la puntería
> **hacia ARRIBA Y hacia ABAJO**.
>
> Ajustables en el modificador (exports): `strength` (fracción del pitch, por defecto 0.7), `pitch_axis`
> (invierte el signo si la puntería sale al revés), `aim_bone` (por defecto `chest`). El ajuste fino es
> **visual** (comprobar en el juego) — la caché de pose global en headless no refleja el
> resultado post-modificador, por lo que la dirección/magnitud se confirman ejecutando el juego.

---

## Comportamiento en `_ready()`

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

## Relacionado

- [[🎮 player (ES)|Jugador]]
- [[⌨️ fluxo-de-input (ES)|Flujo de Entrada]]
- [[🎮 player-gd (ES)|player.gd]]

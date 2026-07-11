---
tipo: arquivo-chave
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# 💥 library3D/characters/player/bullet/bullet.gd

**Extends:** `CharacterBody3D`

---

## Responsabilidades

- Mover la bala en línea recta (`-transform.basis.z`)
- Detectar una colisión y llamar a `hit.rpc()` en el objetivo
- Autodestruirse tras `5.0 s` o al colisionar
- Reproducir la animación de explosión

---

## Constantes

```gdscript
const BULLET_VELOCITY: float = 20.0
var time_alive: float = 5.0
```

---

## Procesamiento

- La física se ejecuta **solo en el servidor** (`set_physics_process(false)` en los clientes)
- Colisión **desactivada en los clientes** (`collision_shape.disabled = true`)

```gdscript
func _physics_process(delta):
    var col = move_and_collide(-delta * BULLET_VELOCITY * transform.basis.z)
    if col:
        if collider.has_method("hit"):
            collider.hit.rpc()
        explode.rpc()
```

---

## RPCs

| RPC | Mode | Qué hace |
|---|---|---|
| `explode()` | `call_local` | Reproduce la animación "explode", activa la sombra en el OmniLight |

---

## Arma + daño localizado (actualizado)

- `weapon_damage` (asignado por quien dispara), `shooter` (evita el autodaño), `_registered` (idempotente)
- `_apply_hit(collider)` — en `move_and_collide`: lee los metas `damage_multiplier`/`character` del colisionador del miembro → `character.hit.rpc(round(weapon_damage*mult))`
- Fallback de TORSO (1x) en el mismo `_apply_hit` si golpeó un cuerpo con `hit()` y sin metas de miembro
- **Traspaso del cuerpo del personaje (2026-06-18):** si `move_and_collide` golpea un
  `CharacterBody3D` que tiene el nodo `LimbColliders` (jugador/enemigo), la bala añade un
  `add_collision_exception_with(body)` y **sigue volando** — de modo que el disparo atraviesa la
  cápsula/esfera genérica del cuerpo y golpea el colisionador del MIEMBRO que hay detrás (daño localizado real, con headshots).
  Sin esto, la esfera del cuerpo del red_robot (radio ~1.12 m) interceptaba cada disparo → siempre 1×.
- `collision_layer = 8` (bit4); `mask = 51` (mundo/cuerpos `3` + miembros `16` + `32`) para colisionar con los miembros
- **Apariencia configurable (2026-06-18):** `tint` (color del efecto: luz + estela), `ball_color` (color de la bola), `ball_scale` (tamaño) — alpha 0 centinela = «no tocar» (mantiene el disparo azul del jugador). Aplicado en `_apply_visuals()` en `_ready`. El **`CannonShooter`** (`effects_shared/cannon_shooter.gd`) instancia y configura la bala; usado por el jugador (azul) y el red_robot (bola negra + efecto rojo). Ver [[🩸 dano-localizado (ES)|Daño Localizado]].
- **Inerte si `shooter == null`** (cubre el `BulletCache` de la escena y las balas en los clientes)
- Ver [[🩸 dano-localizado (ES)|Daño Localizado]]

---

## Relacionado

- [[🔫 combate-tiro (ES)|Combate/Disparo]]
- [[🩸 dano-localizado (ES)|Daño Localizado]]
- [[🎯 fluxo-de-tiro (ES)|Flujo de Disparo]]

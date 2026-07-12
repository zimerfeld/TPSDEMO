---
tipo: fluxo
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# 🎯 Flujo de disparo

---

## Diagrama completo

```
[Owner Client]
  Input.is_action_pressed("shoot") → shooting = true
  Camera raycast (excludes the shooter's own body/limbs + ignores a point-blank hit < 3 m) → shoot_target
        │
        │ [MultiplayerSynchronizer]
        ▼
[Server — apply_input()]
  shooting && fire_cooldown.time_left == 0
        │
        ▼
  degenerate shoot_dir (target < 0.5 m)? → uses -player_model.basis.z (network; aim already corrected on the client)
  bullet = bullet.tscn.instantiate()
  bullet.transform = parent_inv * Transform3D(origin).looking_at(origin+dir)  # BEFORE the add_child:
  get_parent().add_child(bullet, true)                                        # replicated spawn is born at the barrel
  shoot.rpc()  ──────────────────────────────► [All peers]
        │                                         particles + flash + sound
        │
        ▼ [bullet._physics_process — server only]
  move_and_collide(displacement)
        │
   collides? ──► collider.has_method("hit") ──► collider.hit.rpc()
        │                                          │
        │                                   [All peers]
        │                                    hit() runs:
        │                                    - hp -= 25
        │                                    - HUD updates
        │                                    - camera shake 0.75
        │                                    - if hp==0 → respawn.rpc()
        ▼
  explode.rpc() ──► explosion animation
  bullet.destroy() after the animation [server only]
```

---

## Condiciones de disparo (servidor)

```gdscript
if player_input.shooting and fire_cooldown.time_left == 0:
    # instantiates bullet
```

- `fire_cooldown` es un `Timer` de **0.4 s** en el jugador
- La bala tiene una excepción de colisión con su propio jugador (`add_collision_exception_with(self)`)

---

## Qué puede recibir un impacto

Cualquier nodo con un método `hit()`:
- **Jugador** — decrementa el HP, camera shake, respawn si es necesario
- **Robot rojo** — decrementa `health`, anima el impacto, muere si `health == 0`

---

## Correcciones del disparo online (2026-06-24)

- **La bala nacía FUERA del arma en el cliente:** el `global_transform` de la bala es una *spawn property*
  (`bullet.tscn`) y el `MultiplayerSpawner` toma la instantánea **en `add_child`**. El `cannon_shooter` fijaba
  la posición **después** de `add_child` → el paquete de spawn llevaba el origen POR DEFECTO y la bala aparecía
  desplazada en el cliente hasta la 1ª sincronización. **Corrección:** construir el transform del cañón (`Transform3D(origin).looking_at(
  origin+dir)`, convertido al espacio del `parent`) **ANTES** de `add_child`. Un `up` no paralelo a la dirección
  cubre los disparos verticales.
- **Disparar "al cielo" al apuntar-y-disparar rápido:** el raycast de puntería (`player_input`) excluía solo `[self]`
  (el synchronizer, que ni siquiera es un cuerpo físico) → el rayo, que parte desde detrás del hombro, golpeaba el
  **cuerpo/cabeza del propio tirador** durante la transición de puntería y colocaba el objetivo justo encima del cañón = un disparo casi
  vertical. **Corrección:** `_aim_ray_exclude()` excluye el **cuerpo + los colisionadores de miembros** del tirador y descarta
  los impactos a quemarropa (`< MIN_AIM_DISTANCE` 3 m, usando el punto lejano a lo largo de la dirección de la cámara). En el servidor, una guarda extra:
  un objetivo degenerado (`< 0.5 m`) recurre a `-player_model.basis.z`.

## Relacionado

- [[🔫 combate-tiro (ES)|Combate/Disparo]]
- [[❤️ sistema-de-vida (ES)|Sistema de salud]]
- [[💥 bullet-gd (ES)|bullet.gd]]
- [[🎮 player-gd (ES)|player.gd]]

---
tipo: arquivo-chave
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 💥 library3D/characters/player/bullet/bullet.gd

**Extends:** `CharacterBody3D`

---

## Responsibilities

- Move the bullet in a straight line (`-transform.basis.z`)
- Detect a collision and call `hit.rpc()` on the target
- Auto-destroy after `5.0 s` or on collision
- Play the explosion animation

---

## Constants

```gdscript
const BULLET_VELOCITY: float = 20.0
var time_alive: float = 5.0
```

---

## Processing

- Physics runs **only on the server** (`set_physics_process(false)` on clients)
- Collision **disabled on clients** (`collision_shape.disabled = true`)

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

| RPC | Mode | What it does |
|---|---|---|
| `explode()` | `call_local` | Plays the "explode" animation, enables the shadow on the OmniLight |

---

## Weapon + localized damage (updated)

- `weapon_damage` (assigned by the shooter), `shooter` (avoids self-damage), `_registered` (idempotent)
- `_apply_hit(collider)` — on `move_and_collide`: reads the `damage_multiplier`/`character` metas of the limb collider → `character.hit.rpc(round(weapon_damage*mult))`
- TORSO fallback (1x) in the same `_apply_hit` if it hit a body with `hit()` and no limb metas
- **Character body pass-through (2026-06-18):** if `move_and_collide` hits a
  `CharacterBody3D` that has the `LimbColliders` node (player/enemy), the bullet adds an
  `add_collision_exception_with(body)` and **keeps flying** — so the shot passes through the body's
  generic capsule/sphere and hits the LIMB collider behind it (true localized damage, with headshots).
  Without this, the red_robot's body sphere (radius ~1.12 m) intercepted every shot → always 1×.
- `collision_layer = 8` (bit4); `mask = 51` (world/bodies `3` + limbs `16` + `32`) to collide with the limbs
- **Configurable appearance (2026-06-18):** `tint` (effect color: light + trail), `ball_color` (ball color), `ball_scale` (size) — alpha 0 sentinel = "don't touch" (keeps the player's blue shot). Applied in `_apply_visuals()` in `_ready`. The **`CannonShooter`** (`effects_shared/cannon_shooter.gd`) instantiates and configures the bullet; used by the player (blue) and the red_robot (black ball + red effect). See [[🩸 dano-localizado (EN)|Localized Damage]].
- **Inert if `shooter == null`** (covers the scene's `BulletCache` and bullets on clients)
- See [[🩸 dano-localizado (EN)|Localized Damage]]

---

## Related

- [[🔫 combate-tiro (EN)|Combat/Shooting]]
- [[🩸 dano-localizado (EN)|Localized Damage]]
- [[🎯 fluxo-de-tiro (EN)|Shooting Flow]]

---
tipo: fluxo
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 🎯 Shooting Flow

---

## Full Diagram

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

## Shooting Conditions (Server)

```gdscript
if player_input.shooting and fire_cooldown.time_left == 0:
    # instantiates bullet
```

- `fire_cooldown` is a **0.4 s** `Timer` on the player
- The bullet has a collision exception with its own player (`add_collision_exception_with(self)`)

---

## What Can Take a Hit

Any node with a `hit()` method:
- **Player** — decrements HP, camera shake, respawn if needed
- **Red Robot** — decrements `health`, animates the hit, dies if `health == 0`

---

## Online shooting fixes (2026-06-24)

- **The bullet was born OUTSIDE the gun on the client:** the bullet's `global_transform` is a *spawn property*
  (`bullet.tscn`) and the `MultiplayerSpawner` takes the snapshot **on `add_child`**. The `cannon_shooter` set
  the position **after** `add_child` → the spawn packet carried the DEFAULT origin and the bullet appeared
  offset on the client until the 1st sync. **Fix:** build the barrel transform (`Transform3D(origin).looking_at(
  origin+dir)`, converted to the `parent` space) **BEFORE** `add_child`. A non-parallel `up` to the direction
  covers vertical shots.
- **Shooting "at the sky" when aiming-and-shooting fast:** the aim raycast (`player_input`) excluded only `[self]`
  (the synchronizer, which isn't even a physics body) → the ray, which starts from behind the shoulder, hit the
  **shooter's own body/head** during the aim transition and placed the target just above the barrel = an almost
  vertical shot. **Fix:** `_aim_ray_exclude()` excludes the shooter's **body + limb colliders** and discards
  point-blank hits (`< MIN_AIM_DISTANCE` 3 m, using the far point along the camera direction). On the server, an extra guard:
  a degenerate target (`< 0.5 m`) falls back to `-player_model.basis.z`.

## Related

- [[🔫 combate-tiro (EN)|Combat/Shooting]]
- [[❤️ sistema-de-vida (EN)|Health System]]
- [[💥 bullet-gd (EN)|bullet.gd]]
- [[🎮 player-gd (EN)|player.gd]]

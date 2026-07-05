---
tipo: sistema
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 🔫 Combat and Shooting System

---

## 🧩 Components

| File | Role |
|---|---|
| `library3D/characters/players/player/player.gd` | Instantiates the bullet, fires the `shoot()` RPC |
| `library3D/characters/player/bullet/bullet.gd` | Bullet physics, collision detection, calls `hit.rpc()` |
| `library3D/characters/player/bullet/bullet.tscn` | Bullet scene: CharacterBody3D + AnimationPlayer + OmniLight |

---

## 🔄 Shooting Cycle

1. `player_input.shooting` (Input captured on the local client, replicated to the server)
2. The server checks `fire_cooldown.time_left == 0` **and** `_aim_held_time ≥ AIM_WARMUP_TIME` (aim settled)
3. The server instantiates `bullet.tscn`, positions it at `ShootFrom`, applies the direction
4. `shoot.rpc()` → `call_local` → particles + flash + sound + camera shake (trauma 0.35)

> 🐞 **"Ghost bullet stuck in the barrel" bug on the client (fixed 2026-06-24):** `apply_input()` runs
> on the server **and** in the local client's prediction. The shooting block (and the `jump`/`land`/`shoot` RPCs)
> ran on both → the client instantiated a LOCAL `bullet.tscn` which, not being the server, had
> `_physics_process` disabled and **was neither replicated nor destroyed** → it stayed stuck in the barrel
> "forever" (an effect that "does not disappear"). **Fix** (`player.gd`): computes `authoritative = is_server()` at the
> top of `apply_input` and gates the authoritative effects (bullet spawn + `shoot/jump/land.rpc()`)
> behind it. The **movement** prediction (velocity, `move_and_slide`, jump) remains local/responsive;
> only what is authoritative became server-exclusive. Offline (`OfflineMultiplayerPeer` =
> server) shoots normally.

### 🎯 Shooting Direction
```gdscript
var ray_from = camera.project_ray_origin(crosshair_center)
var ray_dir  = camera.project_ray_normal(crosshair_center)
# 1000-unit ray; collision → shoot_target = col.position
# No collision → shoot_target = ray_from + ray_dir * 1000
```

> 🐞 **"Crooked bullet" bug on very fast aim→shot (fixed):** the bullet leaves from `shoot_from` (barrel,
> attached to the `player_model`). When aiming, the body rotated toward the camera via **slow slerp**
> (`ROTATION_INTERPOLATE_SPEED`); on an aim→shot in 1-2 frames the barrel still pointed in the OLD
> direction while the `shoot_target` was already the camera's → wrong direction. **Fix** (`player.gd`,
> aim branch): on **aim-enter** (`_was_aiming` false → true) the body is **aligned to the camera on
> the spot** (`orientation.basis = Basis(q_to)` + immediately updates the `player_model`), without slerp, before the
> firing test. The following frames continue with normal slerp.

> 🎯 **Aim warmup (`AIM_WARMUP_TIME = 0.45 s`, 2026-06-25):** the shot now only happens
> after the player has been aiming for ≥ `AIM_WARMUP_TIME` (`_aim_held_time` accumulates in the aim branch
> of `apply_input`, resets when leaving the aim / in the air). This way **the bullet leaves only after the aim
> animation settles and the barrel is aligned** — fixes the glitch on the **client** player, whose body is
> rendered ~100 ms in the past and made the bullet seem to leave before the aim / outside the barrel. Applies to
> host, client, and bots; does not affect sustained shots (gated by the `FireCooldown`), only the 1st after aiming.

---

## 💥 Bullet (`bullet.gd`)

| Property | Value |
|---|---|
| Speed | `20.0` u/s |
| Lifetime | `5.0` s |
| Physics processing | **Server** only |
| Client collision | Disabled (`disabled = true`) |

### On collision
```gdscript
if collider.has_method("hit"):
    collider.hit.rpc()   # hits any node with a hit() method
collision_shape.disabled = true
explode.rpc()
```

---

## ⏱️ Shooting Cooldown

- `FireCooldown` Timer: **0.7 s**, auto-start (was 0.4 — more spaced-out cadence)
- Checked in `apply_input()`: `fire_cooldown.time_left == 0`

---

## 🔵 Bullet appearance (little ball)

- The **visible little ball** = `MeshInstance3D` (SphereMesh, scale **0.13**) with material `StandardMaterial3D_ffosa`:
  **unshaded + HDR blue** `Color(0.14902, 0.74902, 1.50196)` (blue channel > 1 → "blooms" in the glow). Before it was white with no color and depended 100% on the scene glow; now it is vividly blue even **without** bloom.
- The extra color comes from the blue `OmniLight3D` + particle trail (`BulletBody/MainBody`, `Trail`).
- `CannonShooter.fire(...)` accepts `tint`/`ball_color`/`ball_scale` (alpha 0 = keeps the authored look, the player's blue shot); `bullet.gd._apply_visuals()` applies it on all peers.
- ⚠️ The "glowing orb" effect depends on the `Environment` **glow/bloom**. `level_1`/`level_2` have `glow_enabled` + `glow_hdr_threshold=0.9` + inline `glow_intensity` so the bullet blooms. The "bloom" setting (`config.gd`) enables/disables `glow_enabled` at runtime.

---

## 📍 Bullet Spawn Point

- `ShootFrom`: `Marker3D` at `Robot_Skeleton/Skeleton3D/GunBone/ShootFrom`
- Offset: `(0, 0.4, 0)` relative to the barrel bone

---

## ✴️ Mutual projectile × projectile annihilation (2026-06-24)

When two projectiles collide — a player bullet, a red_robot cannon bullet (both `bullet.tscn`)
or the creature's bomb (`bomb.tscn`) — **both are destroyed** with an explosion (you can "shoot down" the enemy's
cannon bullet/bomb in mid-air).

- **Collision:** all projectiles are on **layer 4** (value 8) and nothing else uses this layer. The
  **masks** gained bit 4 (bullet `51→59`, bomb `3→11`) → they now collide **only with each other**,
  without touching collision with the world/characters.
- **Detection:** both join the `&"projectiles"` group in `_ready`. In `move_and_collide` (server),
  if the `collider` is in this group → it calls `annihilate()` on itself and on the other and returns (before the
  damage/phase logic). It is **idempotent** (`hit`/`_done` guards), so it does not matter which detects
  first nor whether both detect in the same frame.
- **`annihilate()`:** on the bullet = explode + disable collision (same outcome as a hit); on the bomb =
  `_explode(null)` (detonates without damage to the player). The explosions/removals replicate via the existing
  `call_local` RPCs + `MultiplayerSpawner` despawn → **no extra network traffic**.
- ⚠️ Best-effort: very fast and small projectiles can "tunnel" in one frame; the cannon bullet
  (larger, `ball_scale 2.5`) and the bomb are easy targets.

---

## 📷 Camera Shake

| Event | Trauma |
|---|---|
| Shooting | `0.35` |
| Being hit | `0.75` |

---

## 🔗 Related

- [[🎮 player (EN)|player]]
- [[❤️ sistema-de-vida (EN)|sistema-de-vida]]
- [[💥 bullet-gd (EN)|bullet-gd]]

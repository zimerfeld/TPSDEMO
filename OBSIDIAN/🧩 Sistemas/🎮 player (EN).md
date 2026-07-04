---
tipo: sistema
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 🎮 Player System

**Class:** `Player` extends `CharacterBody3D`
**Script:** `library3D/characters/players/player/player.gd`
**Scene:** `library3D/characters/players/player/player.tscn`

---

## 🔢 Constants

| Constant | Value | Description |
|---|---|---|
| `MOTION_INTERPOLATE_SPEED` | `10.0` | Smoothing of the movement vector |
| `ROTATION_INTERPOLATE_SPEED` | `10.0` | Smoothing of the rotation |
| `MIN_AIRBORNE_TIME` | `0.1` s | Minimum airborne time before enabling a jump |
| `JUMP_SPEED` | `6.5` | Vertical jump speed (was 5.0 — higher jump) |
| `JUMP_CUT_DAMPING` | `14.0` /s | Variable jump: damping of the ascent when the space bar is RELEASED mid-jump (soft cut); holding to the end = full arc |
| `AIM_WARMUP_TIME` | `0.45` s | Time spent aiming before the **1st shot** (waits for the aim to settle) |
| `MAX_HP` | `100` | Maximum health |

---

## 🧮 State Variables

| Variable | Type | Description |
|---|---|---|
| `hp` | `int` | Current health (decreases with `hit()`) |
| `airborne_time` | `float` | Accumulated airborne time |
| `orientation` | `Transform3D` | Player rotation/orientation |
| `root_motion` | `Transform3D` | Root motion accumulator |
| `motion` | `Vector2` | Movement vector from input |

---

## 📤 Exports (Synchronized via ServerSynchronizer)

| Export | Type | Description |
|---|---|---|
| `player_id` | `int` | Owning peer's ID; the setter assigns authority on the InputSynchronizer |
| `current_animation` | `Animations` | Current animation state |

---

## ⚙️ Main Logic

### `_physics_process(delta)`
- **Server:** calls `apply_input()` — all physics runs on the server
- **Client:** calls only `animate()` for visual feedback

### `apply_input(delta)`
1. Interpolates `motion` with `player_input.motion`
2. Manages the jump and airborne time — **variable jump (2026-07-03):** with the space bar HELD, the ascent
   follows the full ballistic arc (maximum animation and distance); with the space bar RELEASED during the
   ascent of a real jump (`_jump_active`), the vertical velocity is damped by `exp(-JUMP_CUT_DAMPING·delta)`
   until gravity takes over (the animation switches to `jump_down` at the early apex). The button state arrives
   through the new `player_input.jump_held` (synchronized; seeded `true` in the `jump()` RPC)
3. If aiming: orients by the camera quaternion → STRAFE state → fires a bullet **only after
   `_aim_held_time ≥ AIM_WARMUP_TIME`** (the shot waits for the aim to settle; fixes the client glitch)
4. If walking: orients by the movement direction → WALK state
5. Applies root motion → `move_and_slide()`
6. Respawns if `y < -40`

---

## 📡 RPCs

| RPC | Mode | What it does |
|---|---|---|
| `jump()` | `call_local` | Animates jump + sound |
| `land()` | `call_local` | Animates landing + sound |
| `shoot()` | `call_local` | Particles + flash + cooldown + camera shake |
| `hit()` | `call_local` | `-25 HP`, updates HUD; if `hp==0` calls `respawn.rpc()` |
| `respawn()` | `call_local` | Resets HP, teleports to `initial_position` |
| `add_camera_shake_trauma(amount)` | `call_local` | Camera trauma |

---

## 🧷 Relevant Child Nodes

| Node | Type | Use |
|---|---|---|
| `InputSynchronizer` | `PlayerInputSynchronizer` | Input + camera + HUD |
| `AnimationTree` | `AnimationTree` | Animation blend tree |
| `PlayerModel` | `Node3D` | Robot 3D model |
| `FireCooldown` | `Timer` | **0.7 s** between shots (was 0.4 — more spaced-out cadence) |
| `SoundEffects/*` | `AudioStreamPlayer` | Jump, Land, Shoot |

---

## 🦿 Limb colliders (localized damage)

- `_setup_limb_colliders()` in `_ready` creates native 3D colliders (`StaticBody3D` + `BoxShape3D`) per limb
- Uses `effects_shared/limb_colliders.gd` over `PlayerModel/Robot_Skeleton/Skeleton3D` (playera inherits from Player)
- Layer 16 (bit5); the bullet collides physically. When shooting, the player excludes its own colliders (`_exclude_own_limbs`)
- See [[🦿 limb-colliders-gd (EN)|limb-colliders-gd]]

### Auto-fitted locomotion capsule (2026-07-03)
Right after `build_for`, `_setup_limb_colliders` calls
`lc.fit_locomotion_capsule($CapsuleShape3D, self)`: the **physical-blocking** capsule stops being the
default (0.5×2.0) and becomes **proportional to the model** — radius from the footprint (torso+legs),
height from the vertical extent, base anchored to the ground. It remains **1 shape per character** (cheap,
stable, netcode-friendly). Details and validation in [[🩸 dano-localizado (EN)|dano-localizado]] ("Per-model
auto-fit of the locomotion capsule"). The red_robot does the same ([[🤖 inimigos (EN)|inimigos]]).

---

## 🤝 Allied bots (`bot_controlled`)

- With `bot_controlled = true` (friendly faction in the templates), the same `player.gd` is driven by a
  dedicated AI `library3D/characters/players/player/IA/player_bot_ai.gd` (instantiated in
  `_apply_bot_controlled`), which **covers the player**: it engages threats near the bot or near the
  player, but **follows the player** and respects a **leash** (`max_leash`/`soft_leash`) — outside it,
  regrouping takes priority, so the ally **does not run off the map**. The bot also goes through the
  `AIM_WARMUP_TIME` (aims before shooting).

---

## 🔗 Related

- [[❤️ sistema-de-vida (EN)|sistema-de-vida]]
- [[🔫 combate-tiro (EN)|combate-tiro]]
- [[🌐 multiplayer (EN)|multiplayer]]
- [[🤖 inimigos (EN)|inimigos]]
- [[🎮 player-gd (EN)|player-gd]]
- [[🕹️ player-input-gd (EN)|player-input-gd]]
- [[🦿 limb-colliders-gd (EN)|limb-colliders-gd]]

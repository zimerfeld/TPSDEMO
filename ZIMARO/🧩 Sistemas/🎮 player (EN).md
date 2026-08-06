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

### Orbit + faction (2026-07-08)

- **Runtime faction:** the player (human and bot) is seeded as **`ally`** in `_ready`
  (`Factions.seed_node`). The bot picks enemies via `Factions.are_enemies` and allies via `same_side`
  (no longer by "has a `hit` method"). See [[⚔️ facções (EN)|facções]].
- **Orbits the nearest player:** the anchor is now the **NEAREST human** (`_find_nearest_human_ally`,
  was the first one). With no threat, `_follow_move` **circles** the anchor at `follow_distance`
  (radial radius spring + tangential `orbit_strength`, individual direction) instead of just closing in
  and stopping.
- **No collision:** `_sync_anchor_collision` keeps a **collision exception** between the bot and its
  anchor (re-applied when the nearest player changes) → the ally stays around **without shoving** the player.
- **Ally separation:** `_separation` (boids-style steering) pushes each ally away from the OTHER allies
  within `separation_radius` (weight `separation_strength`) → multiple bots **spread out on the orbit
  without stacking**, instead of converging on the same point. The anchor is excluded (already handled
  by the orbit + collision exception).
- **No friendly fire:** the ally's bullets phase through the player (see [[🔫 combate-tiro (EN)|combate-tiro]]).

### ⚠️ INVERTED movement convention (2026-08-06)

The bot's `input.motion` is a vector in **camera** space, exactly like what the keyboard produces.
But `apply_input` uses `target = camera_x*motion.x + camera_z*motion.y` **only to ORIENT** the body
(`Basis.looking_at`) — the displacement comes from the animation's **root motion**, which runs along
local `+Z` ("The animation's forward/backward axis is reversed", `player.gd`). Net effect: the body
**travels opposite to `target`**, and the GLB mesh (which faces `+Z`) makes that look right on screen.
For a human it all lines up because the W key already sends `motion.y = -1`.

**Measured in the harness:** a player *without AI* fed `motion=(0,-1)` moves toward `-camFwd`
(alignment **-1.00**). The AI was projecting with the wrong sign — which is why the ally **ran in a
straight line until it died**, ignoring post and target, and **shot in one direction while the
projectile went another**.

Three fixes in `player_bot_ai.gd`:

1. **`_world_dir_to_motion` projects `-dir`** (not `dir`).
2. **`_face_point` points `camera_base`'s `-Z` AWAY from the target** — the body's effective front is
   that basis's `+Z` — with the pitch mirrored to match.
3. **Turn BEFORE projecting:** the outbound and inbound conversions now use the same basis within the
   same frame. Before, a one-frame mismatch **fed the error back** every tick.

After: escort converges to **2.53 m** (`follow_distance` 2.5) and stops; aim and projectile both hit
alignment **1.00** with the enemy.

### Guard stance — `guard_stance` (2026-08-06)

The ally's **default** behavior (toggleable in the **Models → AI** screen). It stops being a hunter
and acts like a **bodyguard**: escorts at a safe distance, without colliding and without running
around aimlessly.

| Rule | How |
| --- | --- |
| **Post** instead of an orbit | `_guard_station` computes a point always at `follow_distance` from the protected player. **At peace:** the **rear** diagonal (`guard_back_ratio` 0.8 behind + `guard_side_ratio` 0.6 to the side), out of their line of fire and following them as they turn. The side comes from the randomized `_orbit_sign`, so two allies cover opposite sides. |
| **Interposes** (2026-08-06) | With an enemy within `player_threat_radius` of the protected player, the post moves **forward**, toward the threat (`guard_screen_ratio` 0.8) — the ally stands **between the two**, keeping the lateral offset so it doesn't block their shot. This is where the "reactivity" comes from: it repositions whenever the threat switches sides, while never leaving `follow_distance`. |
| **Stops on arrival, with hysteresis** | Reaches the post at `station_tolerance` (0.6 m) and only starts moving again once it drifts `× settle_release` (2.2 → ≈1.3 m). The small dead zone gives reactivity; the hysteresis prevents per-frame jitter. `scan_interval` 0.35 → **0.2 s** to notice the threat switching sides sooner. |
| **Never touches** | Below `min_standoff` (1.8 m) the only possible movement is to **back away** — even with the physics collision exception active. |
| **Doesn't push onto the enemy** | In combat, `_combat_move` returns the same post-keeping movement; it only backs off if the enemy gets closer than `preferred_combat_distance - combat_band`. No charge and **no flanking** (`pressure_flank` is suppressed in this stance). |
| **With nobody to escort, it guards its home post** (2026-08-06) | `_hold_move` keeps the spot where the bot spawned (`_home`, captured on the 1st `update_input`): it walks back if it drifted, stops on arrival, same hysteresis. **Bug fixed:** the whole stance hinged on `has_anchor`, and the anchor requires a **human** (`_find_nearest_human_ally` skips bots) — so with the host spectating, in a room before the player joins, or after they leave, the code fell through to the old branch (advance + flank) and the ally **charged the enemy until it died**. Now, with nobody to escort, it holds the post and shoots from there. |

**Numbers recalibrated alongside** (`@export` defaults): `follow_distance` 5.5 → **2.5** m ·
`orbit_strength` 0.7 → **0.15** · `preferred_combat_distance` 18 → **12** m · `engage_range` 32 →
**16** m · `player_threat_radius` 24 → **18** m · `soft_leash` 14 → **6** m · `max_leash` 20 → **9** m.

> **Where to tune the "reactivity"** without turning it back into a hunter: `station_tolerance`
> (lower = corrects sooner), `settle_release` (lower = leaves the post more easily), `scan_interval`
> (lower = notices sooner) and `guard_screen_ratio` (higher = steps further toward the threat).

> Turning `guard_stance` off in the Models screen brings back the classic **orbit** described above
> (with the new numbers, so tighter than before).

---

## 🔗 Related

- [[❤️ sistema-de-vida (EN)|sistema-de-vida]]
- [[🔫 combate-tiro (EN)|combate-tiro]]
- [[🌐 multiplayer (EN)|multiplayer]]
- [[🤖 inimigos (EN)|inimigos]]
- [[🎮 player-gd (EN)|player-gd]]
- [[🕹️ player-input-gd (EN)|player-input-gd]]
- [[⚔️ facções (EN)|facções]]
- [[🦿 limb-colliders-gd (EN)|limb-colliders-gd]]

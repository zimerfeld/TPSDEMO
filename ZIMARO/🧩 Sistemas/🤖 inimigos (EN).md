---
tipo: sistema
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-08
---

# 🤖 Enemy System — Red Robot

**Script:** `library3D/characters/red_robot/red_robot.gd`
**Scene:** `library3D/characters/red_robot/red_robot.tscn`

---

## 🔁 State Machine

```
APPROACH ──► AIM ──► SHOOTING
    ▲          │
    └──────────┘ (missed / left sight)
```

| State | Behavior |
|---|---|
| `APPROACH (0)` | Walks toward the player, turns to face it |
| `AIM (1)` | Stops, prepares the shot, counts `AIM_TIME = 1.0 s` |
| `SHOOTING (2)` | Fires a cannon bullet; waits for the reload before the next one |

> **Retreat (FLEE):** beyond the 3 states, a decision from the [[🧠 red-robot-ai-gd (EN)|AI]] overrides
> the movement when the player gets to **≤ 10 m**: the robot opens up space in the opposite direction (it is
> not a machine `State`, it is a per-frame movement override). Since 2026-07-08 the **legs turn toward the
> direction of travel** (anti-slide mechanic — see below), so it **turns and runs** instead of back-pedalling;
> the **turret/cannon keeps aiming at the player** independently.

---

## 🎛️ Parameters

| Constant | Value |
|---|---|
| `PLAYER_AIM_TOLERANCE_DEGREES` | `15°` |
| `SHOOT_WAIT` | `6.0 s` (base reload) |
| `shoot_reload` | `SHOOT_WAIT / 1.5 ≈ 4.0 s` (effective reload via AI — 1.5× faster) |
| `AIM_TIME` | `1.0 s` |
| `AIM_PREPARE_TIME` | `0.5 s` |
| `BLEND_AIM_SPEED` | `0.05` |
| `effective_range` | `30 m` (weapon range; shown in the HUD) |
| `PlayerDetectionArea` | `SphereShape3D` radius `30 m` (= `effective_range`) |

> The effective reload (1st and subsequent shots) comes from the [[🧠 red-robot-ai-gd (EN)|AI]]
> (`fire_rate_multiplier = 1.5`), not directly from `SHOOT_WAIT`.
>
> The **detection radius (30 m)** was matched to the `effective_range` so the robot **detects and opens
> fire at 30 m** (previously 20 m prevented shooting at full range).

---

## 🧮 State Variables (Exported / Synchronized)

| Var | Type | Description |
|---|---|---|
| `health` | `int` | Robot's health (default: `200`) |
| `max_health` | `int` | Maximum health for the HUD (default: `200`) |
| `HIT_DAMAGE` | `const int` | Damage per shot = `50` (dies in 4 shots) |
| `enemy_name` | `String` | Name shown in the HUD (default: `"Red Robot"`) |
| `state` | `State` | Current AI state |
| `dead` | `bool` | Whether it was destroyed |
| `target_position` | `Vector3` | Position of the target player |

---

## ❤️ Health HUD (Boss Bar)

- `controls2D/enemy_health_bar.gd` — shared `CanvasLayer` at the **top-center**
- Triggered by:
  - `hit()` → `show_health_hud()` (when hit)
  - **player's aim enters** → `player_input._update_enemy_focus()` calls `show_health_hud()`
  - **player's aim leaves** → calls `hide_health_hud()` (disappears immediately)
- `show_health_hud()` and `hide_health_hud()` are **public**; show is guarded by `if dead: return`
- Disappears: immediately when the aim leaves or on death; 6 s fallback if hit without aim
- Shows `enemy_name` + `remaining / total` bar + **distance (m)** + **weapon range (m)**
  (`show_health_hud(distance)` passes along `effective_range`; the HUD only shows the range when informed)
- See [[🩹 enemy-health-bar-gd (EN)|enemy-health-bar-gd]]

---

## 📡 RPC `hit()`

```gdscript
@rpc("call_local")
func hit() -> void:
    health = maxi(health - HIT_DAMAGE, 0)   # -50 per shot
    _show_health_hud()                 # updates boss bar
    # plays a random hit animation (hit1/hit2/hit3)
    if health <= 0:
        # destroys: parts explode, emits exploded signal
        _hide_health_hud()             # hides boss bar
        # the server does queue_free() after 10s
```

> **Balancing:** `200 HP ÷ 50 damage = 4 shots to die`.

---

## 🔦 Laser

- `RayCast3D` on `RayFrom` (BoneAttachment on the skeleton)
- Checks the line of sight before `AIM → SHOOTING`
- If it hits the player: calls `player.add_camera_shake_trauma(13.0)` after 0.1 s
- Clips the laser shader by the ray's length

---

## 🌱 Spawn

- **level_1:** spawns at each `RobotSpawnpoints/*`; automatic respawn after 15 s

---

## 📶 Signal

- `exploded` — emitted on death; the level connects it for respawn

---

## 🦿 Limb colliders (localized damage)

- `_setup_limb_colliders()` in `_ready` (if `not dead`) creates native 3D colliders (`StaticBody3D` + `BoxShape3D`) per limb
- Uses `effects_shared/limb_colliders.gd` over `RedRobotModel/Armature/Skeleton3D` (`head_bone_names = ["mouth_eyes", "L-EYE", "R-EYE"]` — the eyes go into the HEAD so the headshot is not tiny; 2026-06-18)
- Layer 32 (bit6); the player's bullet collides physically and applies localized damage
- **Auto-fitted locomotion capsule (2026-07-03):** after `build_for`, `red_robot.gd` calls
  `lc.fit_locomotion_capsule(collision_shape, self)` — the physical blocking becomes proportional to the model
  (radius from the torso+legs footprint, height from the vertical extent), instead of the default capsule. See
  [[🩸 dano-localizado (EN)|dano-localizado]] ("Per-model auto-fit of the locomotion capsule").
- See [[🦿 limb-colliders-gd (EN)|limb-colliders-gd]]

---

## 🧠 AI refinement — slide, target, flight, faction (2026-07-02)

User feedback validated in Test A. Four behavior fronts + faction marking
(parameters/limits will come in a dedicated screen — see [[📌 Backlog (EN)|Backlog]] P1.5):

- **End of the "sliding" (ground units):** the MANUAL movement (strafe/retreat/formation, `_apply_direct_movement`)
  used `velocity = dir × speed` FIXED while playing `walk` at its natural cadence → the feet skated. Now
  `_match_locomotion_cadence(speed)` scales the `speed_scale` of the locomotion AnimationPlayer (resolved from
  `animation_tree.anim_player`) so the **legs' cadence matches the real speed** → no skating
  (and faster flee = legs cycle faster). Outside manual mode, `_reset_locomotion_cadence()` returns to
  1.0 (APPROACH already uses root motion, feet locked). Tunables: `walk_natural_speed` (2.2), `gait_speed_scale`.
  **Code only** — the AnimationTree `.tscn` was NOT touched (there is no TimeScale node; scaling the AnimationPlayer
  solves it without editing the 10k-line blend tree).
- **Less rigid formation:** `formation_cohesion` 0.55→**0.32**, `formation_band` 5→**7 m**, and the slot's bearing
  now **oscillates softly** (`formation_wander` 0.5 rad, individual phase) → the point "breathes" instead of
  converging to fixed coordinates. Less pragmatic, more organic.
- **Target = nearest player (multiplayer):** before, the target was the **1st player** that entered the radius
  (`_on_area_body_entered` set `player = body`, single-target). Now `_players_in_range` keeps ALL the
  players in the alert radius and `_pick_target()` chooses the **nearest** each frame, with **hysteresis**
  (`TARGET_SWITCH_MARGIN` 2.5 m) so it does not oscillate. **Any enemy shoots at any player** in the radius. It also applies
  to the Winged Creature (`_find_nearest_player`/`_collect_players` — before `_find_player` picked the 1st).
- **Aerial flight with smooth, contextual altitude (Winged Creature):** the fixed sinusoidal bob became an interpolated
  **layer switch** (`_alt_bias`, framerate-independent exponential ease): **THREATENED** (took a shot, `_recent_hit_t`
  3 s window) → **climbs** up to `escape_altitude_above_target` (24 m) to escape; **about to bomb**
  (`_bomb_cd ≤ 1.2 s` in PATROL) → **descends** to `dive_altitude_above_target` (7.5 m) for precision; otherwise
  cruise (`preferred_altitude_above_target` 14 m). The body's vertical rate is limited (`climb_speed × 1.6`)
  → the climb/descent is always smooth. Escape has priority over bombing.
- **Faction marking (structural):** `AIConfig.faction(model_key)` / `set_faction` (per-model JSON, key
  `"faction"`, user:// precedence like the behaviors). Values `hostile`/`neutral`/`ally`; defaults: red_robot
  and criatura_alada = **hostile**, player = **ally**. There is still **no neutral character** — the field exists and is
  read (`is_hostile`/`is_neutral`), ready for the "neutral only reacts if threatened (shot/randomness)" logic.

---

## 🚶 Realistic locomotion — matched stride + legs facing travel (2026-07-08)

Fix for the ground enemies' "sliding". Replaces the earlier attempt (2026-07-02 section), which **did
not work**: scaling `AnimationPlayer.speed_scale` is **ignored** when an `AnimationTree` drives the
animation — the cadence never actually sped up.

**Diagnosis (measured):** the `Walk` animation has a natural stride of **~0.8 m/s** (its root-motion
bone `MASTER` travels 2 m over 2.5 s), but the code assumed `walk_natural_speed = 2.2` and the AI drove
the body at 2.4–3.8 m/s in manual mode → the body moved 3–4.75× faster than the feet. On top of that
`Walk` is **forward-only**: moving sideways/backward with it always slides.

**Solution (3 fronts):**

1. **Cadence via the tree (for real):** a new `AnimationNodeTimeScale` node **`locomotion_scale`** inserted
   into the blend tree between `state` and `aiming` (edits the `.tscn`). `_match_locomotion_cadence(speed)`
   now writes `parameters/locomotion_scale/scale` (the mechanism the `AnimationTree` honors), no longer the
   player's `speed_scale`. Range `[0.6, 2.6]`.
2. **Stride calibrated at runtime:** `_calibrate_walk_natural_speed()` in `_ready` measures the real stride
   of `Walk` (horizontal MASTER displacement ÷ length) → `walk_natural_speed ≈ 0.8`. Stays correct even if
   the artist re-exports the animation. The `@export` (0.8) is just a fallback.
3. **Legs face travel + displacement from root motion:** in manual mode `_face_move_direction` smoothly
   turns the **body** (`body_turn_rate` 7 rad/s) to face where it walks, and the velocity comes from the
   **animation's own `get_root_motion_position()`** projected along that facing. Because the body faces its
   movement, the footstep lands exactly on the ground covered → **no sliding in any direction**. The
   **turret/cannon aims at the player separately** (the `aim` blendspace), so it walks one way and shoots
   the player.

**Network note:** the scale is not replicated; on the client `_match_remote_cadence` estimates speed from
the **interpolated** position and matches the local cadence (the body already arrives facing the right way,
computed on the server) → feet locked on the client too.

**AI speeds lowered** to the band the stride sustains (cadence ~1.75–2.5×): `strafe_speed` 2.4→**1.4**,
`pressure_speed` 3.2→**1.8**, `flee_speed` 3.8→**2.0**. APPROACH stays on natural root motion (~0.8 m/s),
feet already locked. Above 2.6× stride, speed is **capped** (never slides; just limited). Tunables (headed
for the AI parametrization screen): `walk_natural_speed`, `body_turn_rate`, `gait_speed_scale`, and the AI
speeds.

---

### Direction smoothing (anti-jitter, 2026-07-08)

Because the body now **faces the direction of travel**, the AI's raw heading (strafe flips, target
re-search, geometry probes) made the robot **shake**. Fixes: `move_dir_response` (4.0) **filters the
heading** before turning the body; `body_turn_rate` 7→**5** rad/s (heavier turn); and the AI now
**commits to each strafe direction for 1.6–3 s** (was ~0.5 s), including geometry and reposition
flips. Direction changes now come in gradually.

### Targeting by faction (2026-07-08)

`_pick_target` filters by `Factions.are_enemies(self, target)` → the robot targets **only the
OPPOSITE faction** (you + allied bots), never another hostile nor a neutral. The filter is at target
**selection** (not at Area entry) → it reacts to provoked neutrals that turn ally. See [[⚔️ facções (EN)|facções]].

---

## 🚶 Individualized movement + formation (2026-06-25)

So the enemies **do not all walk identically every second**, the AI (`red_robot_ai.gd`) seeds in each robot's
`_ready` its own **strafe signal**, a **phase**, and a **speed multiplier**
(server RNG — movement is server-authoritative, clients only interpolate), and the **strafe flips**
now use random periods (`randf_range`) instead of exactly ~1 s, breaking the lockstep.

Each robot also keeps a **designated formation slot**: the 1st time, it captures the direction from the
player (derived from the spawn point) as `_slot_bearing` and, during combat, gains a **soft return bias**
toward the point `player + slot_dir * preferred` (`formation_cohesion`/`formation_band`).
Result: the platoon **circles/strafes freely**, but tends to **return to formation** instead of bunching up.
Tunables: `formation_cohesion` (0.55), `formation_band` (5 m), `speed_variation` (±0.18).

The **Winged Creature** had its flight oscillation (`_t`/bob) **desynchronized** across instances via a
random `_bob_phase` seeded in `_ready` (and reused when re-entering PATROL), so several creatures
do not rise/fall in sync. See [[🧠 red-robot-ai-gd (EN)|red-robot-ai-gd]].

---

## 🔗 Related

- [[🔫 combate-tiro (EN)|combate-tiro]]
- [[🤖 red-robot-gd (EN)|red-robot-gd]]
- [[🧠 red-robot-ai-gd (EN)|red-robot-ai-gd]]
- [[🦿 limb-colliders-gd (EN)|limb-colliders-gd]]

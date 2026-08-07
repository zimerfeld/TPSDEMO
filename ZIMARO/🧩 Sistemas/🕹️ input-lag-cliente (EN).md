---
lang: en-US
---

# 🕹️ Client input lag

Investigation and fix of the response latency felt by whoever plays as the **client** (2026-08-07).
Sibling notes: [[🕹️ input-lag-cliente (PT)|PT]] · [[🕹️ input-lag-cliente (ES)|ES]]. See also
[[🚪 salas (EN)]] and [[🧩 templates-de-level (EN)]].

## The framing that changed the diagnosis

We raised 58 latency hypotheses and checked each against the code; 29 held up. The finding that
organises everything: **almost every big number is symmetric** — host and client pay it equally (aim
warmup, vsync, physics interpolation, body slerp, GPU cost). What **only the client** pays:

| Asymmetric term | Cost | Where |
| --- | --- | --- |
| Shot feedback only returns via `shoot.rpc()` | RTT + ~35 ms | `player.gd` |
| Input upload quantisation | 0–33 ms (avg 16.7) | `player_input.gd` |
| `render_delay_ms` on remote target age | 60 ms (was **100**) | `net_config.gd` |
| playit tunnel RTT | not measured | transport |

In short: complaining about "input lag" and then tuning GPU/vsync would fix nothing — the host pays
those too, and the host isn't complaining.

## What was fixed

- **Predicted shot feedback on the client** (`player.gd`). The sensory part (particle, muzzle flash,
  sound, camera shake) moved out of `shoot()` into `_play_shot_fx()`; the owning client plays it the
  instant of the click, and the server's `shoot()` arriving later recognises it and doesn't repeat
  (`SHOT_FX_DEDUPE_MS`). **Bullet and damage remain 100% server-side** — only what the player sees
  and hears was brought forward. Two traps avoided: the local gate uses its own clock (`_local_fx_at`
  + the cooldown's `wait_time`), **not** `FireCooldown` (which only the server starts); and the
  **first** shot of each aim session is not predicted — the local warmup clock leads the server's, so
  predicting the first one would fire the effect before authorisation, systematically.
- **Input upload decoupled from `sync_hz`** (`player_input.gd` + `NetConfig.input_interval()`).
  "Sync rate" sizes the **state broadcast** (many entities × many peers); tying a ~40 B packet of one
  player's keys to it put up to 33 ms in front of every action to save ~2 KB/s. The client now sends
  at frame pace. **Mandatory guard** `if not multiplayer.is_server()`: on the host that same
  synchronizer is authoritative, and `apply_authority` is deferred — without the guard it would
  overwrite the interval RoomManager applied to the room.
- **`AIM_WARMUP_TIME` 0.45 → 0.25 s**, plus decay instead of zeroing while airborne. The technical
  floor is 0.20 s (the `AnimationNodeTransition` `xfade_time` that settles the GunBone pose); below
  it the "bullet outside the barrel" glitch returns. And a single jump used to wipe the whole warmup
  of someone who had been aiming for a while.
- **`reset_physics_interpolation()` after the `_reconcile` snap**. With physics interpolation on, the
  position correction was drawn tearing from the old position to the new one.
- **SSAO bug** (`config.gd`): the second test was `if` instead of `elif`, so "Off" fell into the
  `else` and **re-enabled** the effect — and the mapping was swapped (Medium requested HIGH at full
  resolution, the most expensive of the three). Fixed, and off by default.
- **Bullet advances smoothly on the client** (`bullet.gd`): it only received the transform at 30 Hz
  and jumped 0.67 m per sample. It now integrates position per frame — visual only, no collision, no
  damage, no RPC. Deliberately not `NetInterp`: interpolation renders in the past and would leave the
  bullet behind the barrel.
- **Interpolation preference** moved back from "Smooth" (100 ms) to "Balanced" (60 ms) — 40 ms of
  target age, without a line of code.

## What was left out, and why

- **Stop replicating `.:motion` to the owner** (the server overwrites the prediction ~30×/s) and
  **smooth reconciliation with an RTT-scaled threshold**: both touch the same spot and have a hard
  dependency — reconciliation comes first, otherwise "mushy movement" becomes "teleport every 2 m".
  And there is **no measured evidence** the snap fires today: instrument a snap counter first.
- **Input buffer with replay/rollback**: unfeasible in this architecture, not a matter of risk.
  Movement is 100% `AnimationTree` root motion, and the engine offers no snapshot/restore of
  blend/xfade state nor physics-world rewind.
- **Camera rig outside physics interpolation**: 8–11 ms measured in a headless harness, but it is
  **symmetric** and needs `top_level` + `get_global_transform_interpolated()` — without those the
  camera steps at 60 Hz while the model stays interpolated.
- **`frame_queue_size=1`**: invalid value (engine minimum is 2).
- **RANGE_CODER compression**: microsecond cost; changing it on one side only breaks the connection
  before the version handshake — a silent failure.

## Bug filed separately

**`hp` is in no `SceneReplicationConfig`.** A lost `hit()`/`respawn()` causes **permanent**
health/limb desync in the client's HUD. Not latency: state that never self-heals. Deserves its own
fix.

## How to measure it properly

None of the above was timed inside the game — the numbers come from the code (16.7/33.3 ms grids,
RTT). The honest path: turn on the Performance HUD and record `NET` (`PEER_ROUND_TRIP_TIME`), FPS and
frame time across the four combinations (host × client, loopback × tunnel), before and after. For the
shot, instrument `Time.get_ticks_usec()` between `is_action_just_pressed("shoot")` and entry into
`_play_shot_fx()`: the goal is the client's delta dropping to the same order as the host's.

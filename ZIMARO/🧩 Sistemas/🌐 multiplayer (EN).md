---
tipo: sistema
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 🌐 Multiplayer Architecture

---

## Model: Server-Authoritative

```
                ┌─────────────────────┐
                │       SERVER        │
                │  - player physics   │
                │  - bullet physics   │
                │  - enemy AI         │
                └────────┬────────────┘
                         │ RPC / MultiplayerSynchronizer
              ┌──────────┼──────────┐
         ┌────▼───┐  ┌───▼────┐ ┌──▼─────┐
         │Client 1│  │Client 2│ │Client N│
         │ animate│  │ animate│ │ animate│
         └────────┘  └────────┘ └────────┘
```

---

## Synchronization Nodes

### `ServerSynchronizer` (in `player.tscn`)
Replicates server → clients:
- `net_transform` (proxy of `transform` for interpolation — see the anti-flicker section)
- `net_model_transform` (proxy of `PlayerModel:transform`)
- `player_id`
- `motion`
- `current_animation`
- `spawn_position`

### `InputSynchronizer` (PlayerInputSynchronizer)
Replicates owning-client → server:
- `aiming`
- `shoot_target`
- `motion`
- `shooting`
- `jumping` (via RPC)

---

## Processing Pattern

| Code | Runs on |
|---|---|
| `player.apply_input()` | Server only |
| `player.animate()` | Clients only |
| `bullet._physics_process()` | Server only |
| `red_robot._physics_process()` | Server only |
| `criatura_alada._physics_process()` | Server only (the client just interpolates — see anti-flicker) |
| `bomb._physics_process()` | Server only (the client receives the replicated `global_transform`) |
| `player_input._process()` | Only the owning peer (`authority`) |

---

## Main RPCs

| RPC | Declaration | Typical direction |
|---|---|---|
| `player.hit()` | `call_local` | Server → all |
| `player.respawn()` | `call_local` | Server → all |
| `player.shoot()` | `call_local` | Server → all |
| `player.jump()` / `land()` | `call_local` | Server → all |
| `player_input.jump()` | `call_local` | Client → server |
| `red_robot.hit()` | `call_local` | Server → all |
| `red_robot.play_shoot()` | `call_local` | Server → all |
| `bullet.explode()` | `call_local` | Server → all |

---

## Player Lifecycle

### All levels use the same pattern (server-authoritative)
`level_1` and `level_2` have a `MultiplayerSpawner` (spawn_path → `SpawnedNodes`)
+ `PlayerSpawnpoints` (Marker3D) and, in `_ready`, **only the server** spawns enemy(ies) and
players:
```gdscript
if multiplayer.is_server():
    # enemy(ies) → spawned_nodes.add_child(...)   (replicated by the spawner)
    add_player(1, spawn_point)                    # host/offline = peer 1
    for id in multiplayer.get_peers(): add_player(id, ...)
    multiplayer.peer_connected.connect(add_player)
    multiplayer.peer_disconnected.connect(del_player)
# add_player: player.name = str(id); player.player_id = id (→ authority of the InputSynchronizer)
```
- **Offline** (OfflineMultiplayerPeer): `is_server()` = true, `get_peers()` = empty →
  spawns only player 1. The **same script** serves offline and online.
- **"Host Only" mode** (`PlayerSelection.spectator_host`): with `spawn_host=false`, the **`NetSpawn`**
  adds a **non-replicated free camera** instead of the host's player.
  Centralized in `NetSpawn._add_spectator_camera` **(2026-06-24)** → works across the levels (before
  this was handled by a single level; the others ignored it and created a player even in "Host Only").
  See [[🛰️ hospedagem-online (EN)\|hospedagem-online]].
- Each spawner's `_spawnable_scenes` lists the **players** (`player` + `playera`), the
  **level's enemy** (`red_robot` in level_1/base, `criatura_alada` in level_2), the
  **bullet** and, in level_2, the creature's **bomb** (both fired under `SpawnedNodes`, they need to replicate).
- The levels are chosen in the **Play Online** flow (chooseplayer → levels → playonline);
  see [[🎬 fluxo-de-cenas (EN)\|fluxo-de-cenas]].

---

## Client spawn position (`spawn_position`)

The replicated transform **doesn't arrive in time** on the entering client: the player was born at **(0,0,0)** and
**fell off the map** (the host was fine). Deterministic solution (the same reliable mechanism as
`player_id`):

- `player.gd` has **`@export var spawn_position: Vector3`** with a setter that calls
  `_apply_spawn_position()` (sets `global_position`, `initial_position`, zeroes `velocity` and
  `_has_prediction`, and `reset_physics_interpolation()`). Registered in `ServerSynchronizer` as a
  **spawn property** (`spawn=true`, `replication_mode=0` = only in the spawn packet).
- **`NetSpawn._spawn`** (see the section above) sets `player.spawn_position = spawn_point.transform.origin`
  before `add_child`. On the client the setter fires when the property arrives → repositions.
- `playera` inherits everything (instantiates `player.tscn` + `extends Player`).
- ⚠️ Sentinel: `spawn_position == Vector3.ZERO` is ignored — **no spawnpoint may sit
  exactly at (0,0,0)** (the markers use y ≥ 1). It also fixes the respawn (uses `initial_position`).

---

## Input authority on the client (Spawner timing)

The `MultiplayerSpawner` creates the player on the client and **only afterward** applies the
replicated `player_id` property — which defines the `InputSynchronizer`'s authority. Since
`InputSynchronizer._ready()` already ran before that, it can't decide "am I the owner?"
only in `_ready`.

- `player_input.gd` → method **`apply_authority()`** (reentrant): activates the local camera
  (`make_current`) + input reading when it's the owner; turns off `_process`/input
  otherwise. Called in `_ready` **and** again by the `player_id` setter.
- `player.gd` → the `player_id` setter calls `$InputSynchronizer.apply_authority.call_deferred()`
  when it's already in the tree (an entering client).

> 🐞 **Symptom if this breaks:** the remote client "is born at the center of the map" (actually it's
> the camera stuck at the origin, because `make_current` wasn't called) and **doesn't move** (input
> off, `motion` stays zero and nothing reaches the server). On the host it doesn't appear because there
> `player_id` is set **before** the `add_child`.

---

## Remote-movement smoothing (anti-flicker) — interpolation buffer

On the **client**, remote players/robots have no prediction (`apply_input` runs only on the server): the pose
comes through the `MultiplayerSynchronizer` ~30x/s. Applying that raw transform generates **stutter/flicker**. The
"proper" solution for netcode over UDP is an **interpolation buffer with timestamped snapshots**.

- **`effects_shared/net_interp.gd`** (`class_name NetInterp`, RefCounted): stores the received
  `Transform3D` samples with their arrival time (`Time.get_ticks_msec()`) and returns the transform
  interpolated at the instant **(now − 100 ms)** (`RENDER_DELAY_MS`), via `Transform3D.interpolate_with`
  (lerp of the origin + slerp of the basis). Rendering "in the past" always guarantees 2 samples around it → no
  extrapolation. Cheap (a short linear search + 1 interpolate per frame) → **it doesn't weigh on the FPS**.
- **Replicated proxies** in place of the raw transform: the player's `ServerSynchronizer` now
  replicates **`.:net_transform`** and **`.:net_model_transform`** (instead of `.:transform` and
  `PlayerModel:transform`); the `red_robot` and the **`criatura_alada` (2026-06-24)** replicate
  **`.:net_transform`** (instead of `.:global_transform`). Without this the creature **had
  no `MultiplayerSynchronizer` at all** and stayed **frozen on the clients** (it only simulated on the host).
  - **Server**: mirrors the real state into the proxies every frame (`net_transform = transform`).
  - **Remote client** (`_interpolate_remote`): buffers the proxies and applies the interpolated transform.
  - **OWNING client**: uses `net_transform` as the **server's truth** in `_reconcile` (the real transform is
    NO longer overwritten by the sync → more stable local prediction, no snap fights).
- **Replication rate** ~30 Hz (`replication_interval` 0.033) + **`reset_physics_interpolation()`**
  on every jump (spawn/teleport) and on the 1st interpolated sample (avoids the "tear" from the origin).
- `net_transform` is a **spawn property** seeded **only on the server** in `_ready` (on the client the value
  arrives via spawn replication; seeding on the client would interpolate from (0,0,0)).
- The **host doesn't notice** anything: it is the server, everything runs in local physics at 60 Hz, with no sync.
- **Tuning**: `NetInterp.RENDER_DELAY_MS` (100 ms). Higher = smoother but more "behind";
  lower = more responsive but sensitive to UDP jitter.

---

## Per-peer variant/color (loadout) — `NetSpawn`

Before, the server spawned **all** players from ITS own `PlayerSelection.scene_path`
→ the variant/color the **client** chose (e.g. `playera`) didn't appear. Centralized in the autoload
**`NetSpawn`** (`autoload/net_spawn.gd`, path `/root/NetSpawn` same on all peers → reliable
RPC):

- `chooseplayer` stores **`PlayerSelection.variant_id`** (an index into `PlayerSelection.VARIANTS`, same
  order as the selector). It travels as an **int** (not an arbitrary path) in the RPC.
- Each level calls **`NetSpawn.setup(spawned_nodes, player_spawn_points, not PlayerSelection.spectator_host)`**
  in `_ready` (replaces the `add_player`/`del_player` duplicated in the levels). The levels pass
  the same argument → uniform "Host Only" behavior **(2026-06-24)**.
  - **Host**: spawns itself (peer 1) with its own variant. `spawn_host=false` in "Host Only"
    → `NetSpawn` adds the free camera instead of the player.
  - **Running scenario**: `NetSpawn` stores the level scene's path (`_server_scenario`) and
    answers it to the client via the RPCs **`request_scenario`/`answer_scenario`** — used by `playonline`
    to only confirm reconnection when the client enters the **same scenario**. See [[🛰️ hospedagem-online (EN)\|hospedagem-online]].
  - **Entering client**: the server **reserves the spawn and WAITS** for the client to inform the variant via
    `register_loadout.rpc_id(1, variant_id)` (sent on `connected_to_server`); only then does it spawn the
    right model. The `MultiplayerSpawner` replicates the instantiated scene → the color/variant appears on ALL
    peers (`playera.gd` applies the tint in each instance's `_ready`). 5 s fallback → default variant.

---

## Offline Mode

- `main.gd` uses `OfflineMultiplayerPeer`
- `multiplayer.get_unique_id()` returns `1`
- `multiplayer.is_server()` returns `true`
- All the code works normally

---

## Related

- [[🎮 player (EN)\|player]]
- [[⌨️ fluxo-de-input (EN)\|fluxo-de-input]]
- [[🛰️ hospedagem-online (EN)\|hospedagem-online]] — play with friends over the internet (playit.gg / Tailscale / port forwarding)

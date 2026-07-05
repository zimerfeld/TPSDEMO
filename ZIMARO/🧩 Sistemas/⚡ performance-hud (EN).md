---
tipo: sistema
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# ⚡ System — Performance Indicators (PerformanceHUD + StabilityGuard)

> Replaced the old **SystemHealth** on 2026-06-20. They are TWO complementary autoloads:
> **StabilityGuard** (always-on protection) and **PerformanceHUD** (readout bar, optional).
> Both read only from the `Performance` singleton (internal engine metrics, reliable and
> cross-platform). See [[🧱 recursos-nativos-godot (EN)|Native Godot Resources]].
>
> **Label on the developer screen (2026-06-23):** the row that toggles the bar (key `performance_hud`) is
> labeled **"Health Monitor"** / PT "Monitor de Saúde" (it was "Performance HUD"). The config key
> and the autoloads did NOT change.

## StabilityGuard (`autoload/stability_guard.gd`)

Safety net against crash/freeze, **always on** (no toggle). Samples every
`check_interval` (0.5 s) and classifies into 3 states, applying the action on the **transition**:

| State | Action |
|---|---|
| `NORMAL` | physics at `physics_normal_tps` (60), tree unpaused, overlay hidden |
| `THROTTLE` | physics drops to `physics_throttle_tps` (30) + signal `throttle_activated` |
| `EMERGENCY` | `get_tree().paused = true` + emergency overlay (fullscreen, ESC dismisses) |

**5 indicators** (`@export` thresholds, in `warn`/`crit`):

| Indicator | Monitor | Real risk |
|---|---|---|
| System free RAM | `OS.get_memory_info()` "free" | little free physical RAM → swap/OOM/freeze |
| VRAM | `RENDER_VIDEO_MEM_USED` | exhaustion → GPU driver crash |
| Collision Pairs | `PHYSICS_3D_COLLISION_PAIRS` | explosion → physics thread freeze |
| Node Count | `OBJECT_NODE_COUNT` | leak → RAM grows nonstop |
| FPS | `TIME_FPS` | `≤ fps_crit` for `fps_crit_frames` → main loop stuck |

- **RAM moved to the system (2026-06-21):** the RAM check uses `OS.get_memory_info()` "free"
  and acts when the free physical RAM falls **BELOW** the thresholds (`ram_free_warn_mb` 1024 / `ram_free_crit_mb`
  512) — inverted vs. the other indicators (which act ABOVE the threshold). `MEMORY_STATIC` (the game's RAM)
  was 0 in the release `.exe`, so RAM protection never fired in the executable. With no platform data
  (`free < 0`) the RAM check is skipped (never fires for lack of data).
- Signals: `state_changed(new_state, reason)`, `throttle_activated`, `emergency_activated`,
  `recovered` — the PerformanceHUD listens to them for the badge.
- `state_name()`/`state_color()`/`last_reason`/`dismiss_emergency()`/`force_check()` are the read/control
  API. The overlay runs in `PROCESS_MODE_ALWAYS` (it lives during the pause).
- The overlay texts and the `reason` are localized via `Locale.tr_key` (templates with `%`
  preserved, formatted afterward) — dictionary in `res://scenes2D/overlays/Resources`.

## PerformanceHUD (`autoload/performance_hud.gd` + `scenes2D/overlays/performance_bar.gd`)

GLOBAL overlay: the autoload (Node `PerformanceHUD`) creates a `CanvasLayer` (layer 99) with the
`performance_bar.gd` bar, shown/hidden by the config `game/performance_hud` (toggle **Performance
HUD** on the `developer` screen). It is **click-through** (mouse only on the toggle bar) and
`_process` is skipped when hidden (`is_visible_in_tree`).

- **Basic** (32 px): `FPS | NET | RAM | CPU% | GPU% | ● StabilityGuard badge`.
  - `CPU%` **(2026-06-23)** = `(TIME_PROCESS + TIME_PHYSICS_PROCESS) / real_frame_time ÷ cores`
    (`OS.get_processor_count`) → the PROCESS's % relative to the **system total** (~ Task
    Manager), in place of the old fixed `TIME_PROCESS / 16.67` which **saturated at 100%** per core.
    It's still a proxy (only main-thread process+physics; it doesn't count the render thread) — it undercounts vs the real
    process CPU, but no longer saturates. `GPU%` = proxy via `RENDER_TOTAL_DRAW_CALLS_IN_FRAME`.
  - **NET (2026-06-24)** measures the **ENet RTT/ping** (`_refresh_net`): on the **client**, the ping to the
    server (`enet.get_peer(1).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)`); on the **host**, the
    **average** of the clients' pings + the count (`NET: 42 ms (2)`); with no client it shows `NET: host (0)`.
    Colored by threshold (<80 ms green / <160 yellow / else red). Offline or with no ENet peer →
    **"N/A"**. It works through UDP tunnels (e.g.: **playit.gg**): ENet measures the real packet RTT,
    including the relay. (Before it relied on a non-existent `NetworkManager.get_total_bps()` → stuck at "N/A".)
  - **RAM** (2026-06-21) = **SYSTEM** memory via `OS.get_memory_info()`, format **"used/total GB"**
    (used = `physical - free`, like Task Manager's "In use"; colored by usage %).
    **Why:** `Performance.MEMORY_STATIC` is only tracked in **debug** and is **0 in the release-exported .exe**.
    `OS.get_memory_info()` works in release; it uses `free` (not `available`, which on Windows
    is virtual/commit memory and would give `physical - available < 0` → 0).
- **Advanced** (toggle ▼/▲, 130 px): columns **CPU** (Process/Physics/Load/Nodes/Objects/3D Bodies/
  Col. Pairs), **GPU** (Draw Calls/Triangles/VRAM/Tex. Mem.) and **Memory** (**System RAM** — the
  same used/total GB as the basic — / Resources), each value colored by threshold (green/yellow/
  red), plus the Guard row.

## Integration

- `project.godot` `[autoload]` (after `DebugOverlay`): `StabilityGuard` and `PerformanceHUD`.
- `developer.gd`: `_TOGGLES["PerformanceHUDRow"] = "performance_hud"`; `_on_toggle` calls
  `PerformanceHUD.refresh()`. Row `PerformanceHUDRow` in `developer.tscn`.
- `config.gd`: default `game/performance_hud = false`. The protection (StabilityGuard) has **no**
  config — it is always on.
- Localization: HUD/Guard keys in `scenes2D/overlays/Resources/overlays.{pt,en}.json`
  (scanned by `Locale`), with all nodes in `Locale.SKIP_GROUP` (the script owns the texts).

## Why it replaced SystemHealth

SystemHealth also paused the tree; keeping both would create a fight over `get_tree().paused`.
Decision (2026-06-20): StabilityGuard becomes the ONLY protection and PerformanceHUD the readout. **Accepted
losses**: the REAL per-process CPU (PowerShell `Get-Process` thread) and the critical-peak **beep** of
SystemHealth were not ported — the HUD's CPU% is a frame-time proxy.

Related: [[🧱 recursos-nativos-godot (EN)|Native Godot Resources]], [[🗣️ localizacao (EN)|Localization]], [[🐞 debug-overlay (EN)|Debug Overlay]].

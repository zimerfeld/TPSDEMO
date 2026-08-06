---
tipo: sistema
projeto: ZIMARO
lang: en-US
atualizado: 2026-08-05
---

# 🚪 Simultaneous rooms (multi-level server)

> Lets the host run **several levels at the same time** and manage them (start/stop/restart,
> **spectate** and **play** in each) without leaving one of them tearing down the server. The role (Host/Client) is
> chosen in `playonline` (two buttons) and the **room is chosen BEFORE** `chooseplayer` — only then does the
> player spawn in it. Related: [[🌐 multiplayer (EN)\|multiplayer]], [[🛰️ hospedagem-online (EN)\|hospedagem-online]],
> [[🎬 fluxo-de-cenas (EN)\|fluxo-de-cenas]].
>
> 🧪 **To validate in the field:** see [[🧪 teste-salas-multiplayer (EN)\|teste-salas-multiplayer]] (loopback → LAN → internet script).
> ✅ **VALIDATED on 2 real PCs (2026-08-05)** via **playit.gg** (UDP tunnel `zimaro.playit.game:44000` → host `192.168.0.211:44000`), after fixing the **enemy freeze on the client** — see the *Enemy freeze on the client* section below (release `202608051826`).

---

## Architecture

- **`RoomManager`** (`autoload/room_manager.gd`, persistent autoload): each "room" is a level
  running inside a **`SubViewport` with its own `World3D`** (`own_world_3d = true`). This isolates
  **physics, navigation and `WorldEnvironment`** — without a separate World3D, two levels would occupy the same
  space and the environments would clash (only 1 `WorldEnvironment` per World3D is valid).
- Since it lives in the autoload, the rooms **survive the scene change** (including going to `chooseplayer` and
  back) → the ENet peer is **not** closed when navigating; only on **"Back"** from the sessions, which calls
  `RoomManager.stop_all()` + closes the peer and returns to `playonline` (there is no more `_exit_tree → stop_all`).
- **On-demand rendering (optimization):** the SubViewports stay in `UPDATE_DISABLED`; only the
  **spectated/played** room becomes `UPDATE_ALWAYS`. The **enemy simulation runs in ALL** rooms,
  regardless of rendering → you don't pay GPU for rooms nobody is watching.
- API: `start_room(level_path) -> id`, `stop_room(id)`, `restart_room(id) -> new_id`, `get_rooms()`,
  `stop_all()`. **`stop_room` and `restart_room` call the same `_close_room(id, reason)`** (enum
  `CloseReason.{STOPPED, RESTARTED, SILENT}`), which notifies the room's clients BEFORE freeing it with
  the RPC appropriate to the reason: **STOPPED → `notify_room_closed`** ("The level was stopped by the host"),
  **RESTARTED → `notify_room_restarted`** ("The level was restarted by the host"). **host plays:**
  `host_spawn_in_room(id, variant_id)` / `host_leave_room()`; **client leaves:** `client_leave_room(id)`
  (+ RPC `leave_room`); signals `rooms_changed`, `room_closed(id)` and **`room_restarted(id)`**. Markers
  of the "Play" flow (inverted): `pending_play_room` / `pending_play_level` / `pending_play_return`.

## Flow and screens — role chosen in `playonline`

In `playonline`, below Port/Address, there are two buttons: **"Manage Rooms"** (Host → opens
`host_session`) and **"Join Rooms"** (Client → opens `client_session`). **"Play"** (host or client) always goes through `chooseplayer`
BEFORE spawning: it sets `pending_play_room`/`return`, goes to the character selector and, on return, the
session's `_ready` consumes the marker and enters play mode (spawns + hides the panel + captures the
mouse). During play the **session stays the root scene** (it only hides the panel).

- **SERVER (`scenes2D/host_session/`, server-only)** — `_on_manage_rooms_pressed` creates the ENet
  server and switches to `host_session.tscn` (peer kept, **no room on load**). UI: level dropdown
  (**1st item "Select…"**) + **Start Room**; per room **Play / Spectate / Restart /
  Stop**; **Back** (tears down the server and returns to `playonline`).
  - **Spectate:** the SubViewport texture full-screen, mouse **CAPTURED**, mouse pushed to the room
    (`viewport.push_input`) → the free camera (`register_room_level`) looks around; **ESC** exits
    spectating.
  - **Play:** `chooseplayer` → `host_spawn_in_room` spawns a **host (peer 1)** player in the room and
    **turns off its free camera** (otherwise both would read the global `Input`); the player's camera becomes
    `current` in the SubViewport (rendered full-screen, only the mouse is pushed). **ESC** opens a
    `FloatingDialog.confirm` window ("Disconnect and go back to management ?") → `host_leave_room` and returns to the grid.
  - **Stop:** ends **only that room**; the clients that were playing in it receive `notify_room_closed`,
    see **"The level was stopped by the host"** and return to the `client_session` browser. Other rooms continue.
  - **Restart:** recreates the level from scratch (`restart_room` = `_close_room(RESTARTED)` + `start_room`); the
    room's clients receive `notify_room_restarted`, see **"The level was restarted by the host"** and return
    to the browser (the recreated room reappears in the list for re-entry). The **host returns to the grid with the mouse
    VISIBLE** (identical state to "Start Room") — `_on_restart_room` re-enters the recreated room only if
    it was spectating/playing THIS room. Before, the restart could leave the screen in a state without mouse/respawn.
- **CLIENT (`scenes2D/client_session/`, client-only — NEW)** — `_on_join_rooms_pressed` connects and,
  on `connected_to_server`, opens `client_session.tscn`. It requests `request_room_list` and lists
  **#id — level (N players) + Play** (the button **only appears if there is a room**). **Play:**
  `chooseplayer` → `client_join_room` mirrors the room as a **plain Node** (renders in the **main
  window**, no SubViewport) and sends `join_room`; the server spawns the player. **ESC** → confirm →
  `client_leave_room` (despawns on the server + removes the mirror, **without closing the peer**) and returns to the
  browser. **Back** closes the peer and returns to `playonline`.

## Deterministic path (replication)

Server and client put the room at `/root/RoomManager/Room<id>/Level/...` (the level node renamed to
`"Level"`) → the level's `MultiplayerSpawner` replicates the same way. **Intentional asymmetry:** on the server
`Room<id>` is a `SubViewport` (its own World3D, several isolated rooms + spectating); on the client it is a plain
`Node` (a single room, renders in the main window). The string path is the same → the replication matches.

## Per-room isolation (interest management)

`RoomManager._apply_room_visibility` adds **only a *visibility filter*** (vetoes anyone not in the
room) on every `MultiplayerSynchronizer` of everything that enters the room's `SpawnedNodes` (enemies, bullets,
players): it only replicates to peers whose `_peer_room[peer] == room_id`. When a peer enters,
`_refresh_room_visibility` calls `update_visibility()` → the already-existing spawns (enemies) are
(re)sent to it.

> ⚠️ **Do NOT set `public_visibility = false`.** In the engine,
> `MultiplayerSynchronizer.is_visible_to(peer)` is: `do all filters pass?` **AND**
> `peer_visibility.has(0) or peer_visibility.has(peer)` — where `has(0)` is `public_visibility`.
> Filters **only VETO** (returning `true` doesn't grant visibility on its own). With
> `public_visibility = false` the synchronizer becomes **invisible to EVERYONE** → **nothing replicates to the
> client** (its player without camera/level, other players and the enemy don't appear). Keeping the default
> (`true`) makes the filter work: in the room = visible, out = vetoed. **Bug fixed on 2026-06-24**
> (`feature/spawnplayer2`): it was the cause of "the level doesn't show in `client_session`" and of players/
> enemy not syncing. The `red_robot`'s death *parts* are born `public_visibility=false` on
> purpose (they only sync when exploding, via `part.gd`) — preserved: they get only the filter.

## Enemy freeze on the client = render stall (fixed, VALIDATED 2 PCs 2026-08-05)

Symptom: the client enters the host's room and the enemies appear **frozen**; the shot hits but **does not
detect collision**. Reproduced in a **headless 2-process harness** with the REAL `RoomManager`: the
**core of the room netcode is correct** — replication, visibility filter, interpolation
(`net_transform`) and even the **server-side collision inside the SubViewport** work (the bullet killed the
enemies in the test). The failure only appears with the **client RENDERING**: when materializing the ~16
template entities **all at once**, the main loop **stalls several seconds** (shader/pipeline compilation on the
GPU + building the `red_robot`s' `LimbColliders` on the CPU, in the same frame). On **weak graphics
hardware** this stall (a) makes the enemy "freeze" on screen and (b) **blows the DEFAULT ENet timeout
(min 5 s) → the connection DROPS**; and since **no handler was treating `server_disconnected`** (only
`connection_failed` existed on the initial connection), the client got **stuck in the frozen room** and,
disconnected, the shot never reached the server → "doesn't detect collision". The `StabilityGuard` **doesn't
catch** this: it runs in `_process` (not even called during the stalled frame) and the FPS trigger requires
10 samples in a row, not 1 giant spike.

**Fixes (release `202608051826`, validated on 2 PCs via playit.gg on 2026-08-05):**
- **GRADUAL spawn** of the template entities (1/physics frame) instead of all at once —
  `TemplateManagerBase.apply_active_gradual()` (refactored `_apply_template` into `_plan_template`
  [skips the dead path via `ResourceLoader.exists`] + `_spawn_job`), used by
  `RoomManager._ensure_template_spawned`.
- **TOLERANT ENet timeout** (limit 32, min 20 s, max 40 s) applied to each peer that connects —
  `RoomManager._apply_peer_timeout` in `_on_peer_connected` — a render stall no longer drops the
  connection. *(Validated in the harness: a 3.7 s stall did NOT drop and the sync recovered.)*
- **`client_session` handles `server_disconnected`** (`_on_server_lost`): it warns "The connection to the
  host was lost" and returns to `playonline`, instead of a frozen room.
- **DYNAMIC `MultiplayerSpawner` whitelist** — new `SpawnableLibrary.configure(spawner)`
  (`effects_shared/spawnable_library.gd`), called in the `_ready` of `level_1`/`level_2`: it scans `library3D`
  in **deterministic lexicographic order** (indices match across peers) → any template model,
  **including the new ones** (`humanoide/jogador/monstro/mulher`), replicates to the client. Before, the
  whitelist was fixed in the `.tscn` and only had the old models.
- **`StabilityGuard` loosened** (2026-08-05): `col_pairs` **16000/40000**, `node` **20000/45000**,
  `vram_warn` **3072** (crit 5120), `fps_crit_frames` **20** (10 s), `physics_throttle_tps` **45** —
  headroom for the multi-room host and tolerates the loading hitch without throttling the physics. See the
  section below.

⏳ **Remaining** is a *loading hitch on the 1st room entry* (~1.6–2.6 s), **non-fatal**: the tolerant
ENet timeout survives it and the `server_disconnected` handler recovers cleanly.

> ⚠️ **PRE-WARMING DOES NOT FIX IT — measured on 2026-08-05, do NOT re-explore.** Five approaches were
> tested with cold-cache measurements: entity warm in a SubViewport (~25%, noise); entity warm on the
> ROOT viewport (no gain); **LEVEL** warm in a SubViewport (**0%**); **LEVEL** warm on the root viewport
> (**0%**); and a queue spreading the `LimbColliders` builds (~40 ms, negligible). **All reverted,
> nothing shipped.** Cost breakdown (level_1, cold cache): initial render of the **level's
> environment/floor ≈ 2336 ms (86%)**, entities ≈ 400 ms, colliders ≈ 40 ms. **Why it fails:** the cost
> is tied to the level becoming the **ACTIVE scene with full setup** (`apply_graphics_settings` + shadow
> atlas + render buffers + occlusion **on the real window**) — every offscreen pre-render produced
> **0 ms of stall**, i.e. it doesn't reproduce the cost, so it can't front-load it. **It is not
> one-time:** with a warm on-disk shader cache it drops from ~2.6 s to ~1.6 s, but **never to zero**
> (first-3D-render window setup, per launch).
> ✅ **SOLVED with the "LOADING" SCREEN** (autoload `LoadingScreen`, 2026-08-05) — see the
> *Loading screen* section below. In short: the startup loads a **REAL** level (full activation)
> and discards it, front-loading the **global** renderer setup (**2473 ms → 602 ms on the next entry,
> −76%**); and every entry into a level/room is now **covered** by the screen. **The key:** the warm failed
> because the `_ready` with the `warmup` meta returned BEFORE `Settings.apply_graphics_settings(...)` — only
> COMPLETE activation reproduces (and therefore front-loads) the cost. The `feature/salas-prewarm-shaders`
> branch is now moot.

See [[salas-freeze-render-stall]] in memory.

## "Loading" screen (`LoadingScreen`) — 2026-08-05

Autoload **`LoadingScreen`** (`autoload/loading_screen.gd`), a `CanvasLayer` (layer 200,
`PROCESS_MODE_ALWAYS`) with an opaque background + "Loading..." — canonical texts in pt, translated by
[[locale]] via `scenes2D/loading/Resources/loading.{pt,en,es}.json`. **Two roles:**

1. **`run_startup_preload()`** — called in `main.gd._ready` before the menu. It instantiates a **REAL**
   level (`level_1`), keeps it alive for ~6 frames and discards it. It is the **complete activation** that
   front-loads the **global** renderer setup. Measured (cold cache): **2473 ms here → the next entry
   into a room drops to 602 ms (−76%)**. `spectator_host = true` (no controlled player → no mouse
   capture) and `set_process_input(false)` on the level (ESC doesn't trigger the `LevelExit`). **Headless**
   (dedicated server, no GPU) and `-- nopreload` skip it.
2. **`cover(action)`** — covers the screen BEFORE **every** entry and reveals only with the frame ready:
   it shows the screen, lets **2 frames PAINT** (otherwise the stall would eat the frame of the screen
   itself and the player would see a frozen window), runs the `action` (the heavy activation) and waits
   `SETTLE_FRAMES`. Wired in: **`levels.gd`** (offline level entry), **`client_session`** (entering the room) and
   **`host_session._set_observing` / `_set_playing`** (spectating/playing a room). Measured: a covered
   entry = **896 ms masked** (validated with a screenshot during the cover).

> ⚠️ Only **complete activation** pays the cost — `cover`/preload must NOT become an offscreen "warm"
> (SubViewport or root viewport give **0 ms of stall**: they don't reproduce the cost, so they front-load nothing).
> See the measurement in the *Enemy freeze on the client* section.

## Black screen on the client (level_base/level_2) — StabilityGuard (2026-06-24, `feature/spawnplayer2`)

> ⤴ **Values updated on 2026-08-05** (see the *Enemy freeze on the client* section): `col_pairs`
> 16000/40000, `node` 20000/45000, `vram_warn` 3072, `fps_crit_frames` 20, `physics_throttle_tps` 45.
> The limits below (8000/25000 etc.) are the **history** of the original 2026-06-24 calibration.

> 🗑️ **Historical note (2026-07-01):** the `level_base` level was **REMOVED** from the project in the
> `feature/restrutu` restructure (scene, `.ogg` and all references in `levels`/`host_session`/`playonline`/
> `music_manager`). The record below is kept as **context** for the `StabilityGuard` calibration: the
> ~3066 collision pairs / ~1.2 GB of VRAM that motivated the current limits apply to **any real 3D level**
> (today `level_1`/`level_2`) — the lesson hasn't changed, only the example. The headless server's default
> room became `level_1` (`DEFAULT_ROOM_LEVEL`).

Symptom: when entering as a CLIENT into a **Level Base** room (and, with one such room running on the server,
also **Level 2**), the screen went **black** — not even the scenery appeared. **Cause:** the `StabilityGuard`
(always-on autoload) went into **EMERGENCY** because level_base has **~3066 collision pairs** of
static geometry and the critical limit was **600**; `_apply_emergency` did `get_tree().paused = true`,
which on a server/client **freezes the MultiplayerSpawner/Synchronizer and the RPCs** → the client's player
doesn't spawn (no camera = black screen) and nothing syncs. On the SERVER, pausing freezes ALL rooms → that's
why Level 2 (simple) also broke when there was a Level Base running alongside. Level 1 (flat floor,
few pairs) never triggered → only it worked.

**Fixes:**
- `stability_guard.gd`: limits recalibrated to real 3D-game values (level_base uses ~3066
  collision pairs AND ~1198 MB of VRAM — both NORMAL and which triggered the guard): `col_pairs` 8000/25000,
  `node` 12000/30000, **`vram` 2560/5120 MB**. And `_apply_emergency` **never pauses in an ONLINE session**
  (it only throttles physics + logs) — pausing breaks the netcode of all peers. The pause + overlay still
  apply in solo/offline (where there's no network to break). ⚠️ Even WITHOUT pausing, the EMERGENCY/THROTTLE lowers
  physics to 30 tps on the server (slow game for everyone), so the limits MUST not trigger in normal
  gameplay — hence the recalibration. Validated: host starting/spectating a level_base room stays **NORMAL**.
- `level_base.tscn`: `_spawnable_scenes` converted from UIDs → **explicit paths** (like level_1),
  eliminating the risk of a UID not resolving in the MultiplayerSpawner (which would silence the spawn).

**UI polish (2026-06-24):** `host_session`/`client_session` now apply the **project theme**
(`res://themes/ui_theme.tres`, same as playonline/menu) to the root → buttons/labels/dropdowns with the
cyberpunk look. ⚠️ `ui_theme.tres` only styles **Button/Label** (it gives no background), so `_make_panel` was
rewritten (`_panel` became a `Control`, no longer a `PanelContainer`): **background with the menu's cyberpunk texture**
(`menu_surreal_training_bg.png`) + dark veil, but with its own IDENTITY per scene (host × client deciding
factor): **HOST = WARM gradient (amber)** + "radar" rings EXPANDING outward (the server broadcasts /
is the source); **CLIENT = COOL gradient (cyan)** + rings CONTRACTING inward (connects to the server). The
rings come from the shader `res://themes/session_signal_bg.gdshader` (uniforms `ring_color` + `dir` ±1 + `aspect`),
assembled by the helper `_make_signal_layer(color, dir)`. A flat navy looked "colorless" — hence the rich texture. Also: **full screen** (margins + centered title);
**content/lists in a centered VBox of max width 900** (HBox `ALIGNMENT_CENTER`); **Back button
200×50 centered at the bottom** (no longer full-width). Everything inside `_panel`, hidden while spectating/
playing (then the SubViewport/level fills the screen). `_make_back_button` removed (the Back button is assembled in `_make_panel`).

**playonline persistence:** ALL options persist and reload — Port and IP/Domain
(`_prefill_last_used`: reads `online/last_port|last_address`, written on ANY change via
`_on_port_changed`/`_on_address_changed`, without polluting the history; fallback to the top of the history,
then the default); host interpolation/rate/render (`NetConfig`, section `netopt`); language (`Locale`,
`game/language`).

**History dropdowns (Port/IP) — fix 2026-06-25:** the `OptionButton`s `PortHistory`/
`AddressHistory` **reflect the field's current value** and **keep the selection** — before, `_fill_history`
forced `selected = 0` ("Select...") and the selection handlers also reset to 0, so the
dropdown never showed nor kept the stored value. Now: `_ready` calls `_prefill_last_used()`
**before** `_refresh_history()`; `_fill_history(option, key, current)` calls `_select_in_history` to
leave selected the item equal to the current value (or "Select..." if it's not in the history); the
`_on_*_history_item_selected` **no longer reset** to 0; and `_on_port_changed`/`_on_address_changed`
re-sync the dropdown while typing. (Setting `.selected` by code doesn't fire `item_selected` → no
recursion.) The value itself already persisted in `online/last_port|last_address` — what was missing was the dropdown
**mirroring** that value.

**level_base debug HUD (REMOVED):** the "Debug" `Label` (script `debug.gd`, showed FPS/VSync/
Memory/Online/Multiplayer ID) was legacy from `level_base.tscn` (didn't exist in level_1/2), appeared by
default and was redundant with the **Performance HUD**. It was **deleted** from `level_base.tscn` (node +
ext_resource) and the files `debug.gd`/`debug.gd.uid` erased. It wasn't generated by me — it was abandoned code.

## Standardized confirmation windows + animated screen backgrounds (2026-06-24)

**Dialogs (rewritten 2026-06-25):** ALL confirmation/notice windows (Quit, Resolution, Restore,
Disconnect host/client, session notices, save/reassociate/remove in the Models screen and `CrashHandler`
errors) are built on top of the **reusable 2D control `FloatingWindow`**
(`controls2D/floating_window/`, `class_name FloatingWindow`) by the helper **`FloatingDialog`**
(`themes/floating_dialog.gd`, `confirm()/alert()`). It's a `Control` (not the native `Window`/`ConfirmationDialog`):
**centered title** (the left spacer mirrors the ×), **uniform-width buttons**, **standard close ×**
(same opaque black look as the Damage/AI panels), **modal background** that darkens and blocks the
rest of the UI, **ESC = cancel**, **Enter = confirm** (the OK button focused), **focus returned** to the
previous control on close and **drag by the title bar**. It goes in a `CanvasLayer` (layer 128) on top — covers
2D and 3D — and self-frees on close. Texts passed RAW (canonical keys): the window translates via Locale
(SKIP_GROUP + meta `loc_key`) and **updates on language change**. ESC is consumed by the window (the descendant
added last) before the screen's `_input`, so the background doesn't navigate along. The old `UIDialogs`
(`themes/ui_dialogs.gd`, which only styled the native dialogs) was **REMOVED**. The same base serves
any future floating window (export `remember_position_key` saves/restores the position in Settings).

**NON-DESTRUCTIVE error window (`CrashHandler`, 2026-07-02):** the global error window is no longer
fatal. × / ESC / the **"Back"** button only CLOSE and return the focus to the calling scene (the `FloatingWindow`
already restores `_prev_focus` in `close()`); with `retry_callback` there is also **"Try Again"** (re-runs).
Before, the button was "Close Game" and `CrashHandler` wired `canceled/confirmed → get_tree().quit()` — a
port/connection error from `playonline` (or even a **Models screen validation**) would shut down the whole game.
Reason: a port/connection/validation error is recoverable — the player adjusts and tries again, without losing the session.

**Button colors (theme default, 2026-06-25):** the shared styleboxes (`scenes2D/menu/button_*.tres`,
used via `ui_theme.tres` on all screens) were standardized — a button **without focus = GRAY background**
(`button_normal`), **with focus = BLACK background** (`button_focus`, opaque overlay), text **opaque white** in all
states (hover = light gray, pressed = near black). **Hover and focus** bring back the **neon** effect:
**white border** + **smoky white shadow** (`shadow_size`), giving the glow of neon light around the
control. The **window close × buttons** follow their own rule, `FloatingWindow.style_close_button(btn)`
(applied to the FloatingWindow's × AND to the Damage/AI panels): **without focus = GRAY, with focus/hover = DARKISH
RED**, white text.

**Animated backgrounds:** each 2D screen gained its own `canvas_item` shader (in `themes/backgrounds/`,
applied as a `ShaderMaterial` on the scene's `Background/Bg` node, over the navy base) that **evokes the screen's
function** — `levels_bg` (a perspective level grid), `playonline_bg` (a SUBTLE node network, only at the edges — the
center stays calm/navy so the form's texts are LEGIBLE; rewritten 2026-06-25 because the 1st
version lit up the center and made it hard to read), `settings_bg` (equalizer + sliders),
`developer_bg` (blueprint + horizontal sweep). Cheap (math
per pixel, no textures) → no relevant cost on a menu screen. The host/client sessions still use the
`session_signal_bg` (radar rings) — see *UI polish*.

## Optimization selectable before the room — `NetConfig` (2026-06-24)

Autoload **`NetConfig`** (`autoload/net_config.gd`, persists in `Settings`/section `netopt`) + a selector on the
**playonline** screen (3 STATIC dropdowns in the `.tscn` — columns `HostColumn`/`BothColumn`/`ClientColumn`
with `HostRenderModes`/`SyncRates`/`Interpolations` (renamed from the old `*Picker` in the 2026-07-03 name
sweep — OptionButton in the plural, no abbreviation), `tab_order` 6/7/8 before the Host/Client buttons;
the code only populates items/selection and connects — `_build_optimization_options`/`_setup_opt_picker`, 2026-06-30,
before they were assembled at runtime). They are LOCAL prefs (not replicated) — each side adjusts what it controls:
- **Smoothing ↔ Response** — interpolation delay of remote models: Smooth 100 ms / **Balanced
  60 ms (default)** / Responsive 35 ms. Applied in `NetInterp.render_delay_ms` (now a `static var`).
- **Sync rate** — 30 / 60 Hz. Valid on BOTH sides, each in the direction it sends: the
  SERVER sets `replication_interval = 1/Hz` on the entities' synchronizers (`_apply_room_visibility`,
  server→clients broadcast); the owning CLIENT sets it on its own `InputSynchronizer` (`apply_authority`,
  upload of its input). They don't need to match — they control different flows.
- **Host render** — Windowed (spectates rooms) / **Pure server** (no room renders → frees GPU;
  Spectate/Play on the host are disabled). Read by `host_session._render_only`.
Project rule ([[optimize-when-adding-scene-elements]]): explicit trade-offs (response × smoothness/
bandwidth/FPS) without compromising the experience; the Balanced default is already faster than the old fixed 100 ms.

**Explicit scope on screen (2026-06-24):** the selector is assembled in **3 columns** aligned with the buttons
below, with a colored scope badge: **HOST ONLY** (Host render, left/orange, over "Manage
Rooms"), **HOST + CLIENT** (Sync rate, middle/green) and **CLIENT ONLY** (Smoothing↔Response,
right/cyan, over "Join Rooms") + a hint of the interpolation×Hz trade-off. Localized PT/EN: the
**Labels** use canonical (pt) text and the [[locale]] auto-localizer translates/re-translates; the **OptionButton
items** (which Locale skips) are re-translated by `_relocalize_options` on `language_changed`.
⚠️ Do not pass `tr_key()` when setting the text of a Label the auto-localizer covers — it would store the wrong
canonical if the scene is born in EN (the language is persisted) and the label wouldn't revert to pt.

## Host render modes (user's question)

- **Headless** (`--headless`): idle GPU — ideal for many rooms; only CPU/RAM. (The 8GB AMD
  card doesn't weigh in here; what matters is single-thread CPU + RAM + network.)
- **Windowed**: renders only the spectated room (the others just simulate) → the GPU cost doesn't multiply.

## State / pending items

- ✅ **Phase 1 (validated in a single instance):** persistent server, isolated rooms simulating in
  parallel, management grid, per-room spectating.
- ✅ **Phase 2 (server side validated in a single instance; REAL network pending 2 PCs):** **per-room**
  player spawn (`RoomManager`, isolated from the single-level `NetSpawn`), **client join** to a room
  (`request_room_list`/`join_room`), room mirror on the client, **per-peer visibility**. Fixed
  `criatura_alada._find_player` (searches in its own `SpawnedNodes`, not `current_scene`).
- ✅ **Phase 3 — flow reorganization (parse/load validated; interactive play pending):** Host/Client
  role via two buttons in `playonline`; `host_session` became **server-only** and the
  `client_session` was born (client-only); **room chosen before `chooseplayer`** (markers
  `pending_play_*`); **host plays inside the room** (`host_spawn_in_room`, free camera off);
  **ESC** with confirmation to disconnect; **Stop** notifies the room's clients (`notify_room_closed`)
  and sends them to `client_session`; **Back** from the sessions tears down the peer and returns to `playonline`.
- ✅ **Interest management fixed (2026-06-24, `feature/spawnplayer2`):** `_apply_room_visibility`
  was setting `public_visibility = false`, which made EVERYTHING invisible to all peers (filters only veto) —
  that's why `client_session` didn't see the level/camera and players/enemy didn't sync. Now it only
  adds the filter (keeps `public_visibility` at the default `true`). See the *Per-room isolation* section.
- ✅ **Test A (loopback `127.0.0.1`, 2 instances) VALIDATED in the field (2026-07-02):** local `playonline`
  OK; client enters and spawns in the room (scenery, not gray), host shows "(1 connection)", client↔host
  replication. **The netcode is proven** — only the real network transport is missing (Test B/C). See
  [[🧪 teste-salas-multiplayer (EN)\|teste-salas-multiplayer]].
- ✅ **"Play" race guard on the client (2026-07-02):** when returning from `chooseplayer`, the
  `client_session` re-validates via `server_room_list()` that the room still exists (the `RoomManager` autoload
  keeps receiving `receive_room_list` during character selection). If the host STOPPED/restarted the room
  in the meantime, it does NOT spawn into a dead room: it returns to the browser with the notice "The room is no longer
  available" (helper `_server_has_room`). Avoids the empty scene of entering a room that no longer runs.
- ✅ **REAL network between 2 PCs VALIDATED (2026-08-05):** tested via **playit.gg** (UDP tunnel), after
  fixing the **enemy freeze on the client** (render stall + ENet timeout + missing
  `server_disconnected` handler) — see the *Enemy freeze on the client* section (release
  `202608051826`).
- ✅ **1st-entry hitch: SOLVED** (2026-08-05) by the **"Loading" screen** (`LoadingScreen`):
  the startup front-loads the global renderer setup (−76% on the next entry) and every entry into a
  level/room is covered by the screen. **Offscreen pre-warming was measured and ruled out** (5 approaches,
  all 0–25%); **do not re-explore** without reading that measurement.
- ⏳ **Pending items:**
  `enemy_health_bar.get_shared(get_tree().current_scene)` (enemy HUD) is still global —
  on the client with 1 fullscreen room it works; on the host spectating/playing it may appear in the wrong place.
  See [[🌐 multiplayer (EN)\|multiplayer]].

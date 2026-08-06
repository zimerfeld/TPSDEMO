---
tipo: sistema
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 🔊 Audio (buses + settings)

Project audio system: bus layout in `default_bus_layout.tres`
(`uid://vtdn63d3ksc2`, referenced by `project.godot` under `[audio]
buses/default_bus_layout`) and the controls in the **Audio** tab of the settings.

## 🎚️ Bus layout

| # | Bus | Send | Use |
|---|---|---|---|
| 0 | `Master` | — | final mix |
| 1 | `Outside` | `SFX` | reverb zone (Area3D `SoundOutside`) |
| 2 | `Reactor` | `SFX` | reverb zone (Area3D `SoundReactorRoom`) |
| 3 | `Music` | `Master` | background music |
| 4 | `SFX` | `Master` | every sound that is **not** music |

`Music` carries only the background music, now centralized in the **MusicManager** autoload (see
the section below) in a single player with `bus = &"Music"` — the old `Music` nodes embedded in
`menu`/`chooseplayer` were removed. `SFX` (created in 2026-06-16) carries
**everything else**: each gameplay `AudioStreamPlayer/3D` (footsteps/shot/explosion of the
player, `Shot` of the pistol, `Boom` of the bomb, `sound` of the door, `Sound`/`Motor` of the
characters, `Cannon`/`Explosion`/`Hit`/`Walk` of the red_robot, etc.) received
`bus = &"SFX"`, and the reverb buses `Outside`/`Reactor` were rewired to send
to `SFX` instead of `Master`. This way muting `SFX` silences every effect without touching the music.

## 🎵 Per-scene/level music — `MusicManager` (2026-06-25)

Background track per **scene name**, in **infinite loop**. The `MusicManager` autoload
(`res://autoload/music_manager.gd`) keeps a single `AudioStreamPlayer` on the `Music` bus; on each
screen change the `main.gd` router calls `MusicManager.play_for_scene(node)`:

- **Default = SILENCE (2026-06-25):** a scene WITHOUT a saved assignment stays at **"Select..." = no
  music** (does not play). Before, the default automatically resolved by `audios/<scene-name>.<ext>` — that
  is now the **"Default" option** (`BYNAME` override), chosen per scene in the Manager.
- **Resolution by name ("Default" option):** `res://audios/<scene-name>.<ext>` (1st of `.ogg`/`.mp3`/`.wav`
  that exists), in `_resolve_by_name`. E.g.: `menu` → `audios/menu.ogg`. `ALIASES` makes `chooseplayer`
  inherit the `menu` track. Same track as the previous scene → continues without restarting (smooth transition).
- **Loop forced at runtime** (`_ensure_loop`): applies to any loose file in `audios/`,
  even if the import comes with `loop=false`.
- **Online:** in the rooms the root scene is `host_session`/`client_session`, so their music comes from
  `audios/host_session.ogg`/`client_session.ogg`. Switching the track by the level observed inside a
  room (its own SubViewport) is outside the scope of this autoload.

To set the music of a scene/level, just place the file in `res://audios/` with the scene name.
Included tracks: `audios/menu.ogg` + the 41-track NCS (Copyright Free Music) library — removed by
mistake in the "limpeza" commit (2026-07-03) and restored on 2026-08-06. See `audios/README.md` and
[[🎬 fluxo-de-cenas (EN)|fluxo-de-cenas]].

### 🎛️ Music Manager (Settings → Music → Enabled)

Clicking **Music: Enabled** in the Audio tab opens the **Music Manager**
(`scenes2D/music_manager/music_manager_window.gd`). Since 2026-06-29 it is a **controller** that builds the
form INSIDE the reusable **floating window** (`FloatingWindow`), in a `CanvasLayer` at the top —
same pattern as the **Template Manager** window (level templates). This way it inherits the project's 2D theme
and the **2D Debug works over it** (the `FloatingWindow` joins the `DebugOverlay` group),
just like the other floating windows. It allows:

- **Listening to** any track in `audios/` (separate pre-listen player; pauses the background while playing).
  Each **▶ Play** button has a **⏸ Pause** and a **⏹ Stop** next to it (2026-06-25) — both on the
  "Listen to track" row and in the per-scene list. ▶ resumes a pause of the SAME track (`preview_or_resume`).
- **Assigning** the track of each scene/level. **Every dropdown has "Select..." as the 1st option = no
  music (silence), the DEFAULT** of an unconfigured scene. Other options: **"Default"** (resolves by
  name, `BYNAME` override) or a specific **file**.

The assignments become **overrides** persisted in `Settings` (section `[music]`: `scene_key = file`,
`BYNAME` = by name, `""` = explicit silence; **NO key = "Select..." = silence**, the default).
`_resolve()` reads this. Changing the
assignment reapplies **on the spot** if it is the currently playing scene. `MusicManager` exposes `list_tracks()`,
`scene_list()`, `assignment_of()`, `set_assignment()`, `effective_track()`, `preview()`,
`preview_or_resume()`/`pause_preview()`/`resume_preview()` (2026-06-25), `stop_preview()`. It opens via
the Enabled button's `button_down` (opens even with the music already on). The action buttons are in the
**footer** of the `FloatingWindow` (**🎲 Randomize tracks** and **Close**); closing (× / ESC / Close) stops
the pre-listen. The controller persists in the Settings screen between openings; the window itself
auto-frees on close.

**Randomize + state persistence (2026-06-25):** the footer has a **"🎲 Randomize tracks"** button
(in place of the 2nd "Stop" — there is already one in "Listen to track") that assigns a **random** track from
`audios/` to EACH scene/level (`set_assignment`, which persists) and updates the screen → the choices
reload on the next opening. Every window control **persists on change**: the per-scene assignments
already save via `set_assignment`; the track chosen in "Listen to track" now saves in
`[music_ui] listen` and is restored in `_refresh` (`_restore_listen_choice`).

## 🎧 Positional (3D) player sounds — 2026-06-24

The player's effects (`SoundEffects/Step`, `Jump`, `Land`, `Shoot`) were
`AudioStreamPlayer` (non-positional) → in multiplayer you heard another player's shot
without knowing where it came from. Now they are **`AudioStreamPlayer3D`** and the parent node
`SoundEffects` became a **`Node3D`** (otherwise the 3D children would play at the world origin, not
at the player's position). Since these sounds already fire via the RPC **`@rpc("call_local")`**
(`jump`/`land`/`shoot`), they play on all peers from the player's **replicated position** →
correct spatialization, **with no extra network traffic or latency**. For the **local**
player (camera = listener, very close) the sound is crisp and consistent.

- **Range/attenuation** (calibrated to avoid wasting audio voices on distant players):
  `Step` `unit_size 8`/`max_distance 30`;
  `Jump`/`Land` `8`/`35`; `Shoot` `12`/`60` (the shot carries farther; ranges mirror
  the creature's `Motor` ~35 and the red_robot's `Explosion` ~60). Above `max_distance`,
  Godot discards the voice → CPU cost only for audible sounds.
- The `playera` inherits everything (instantiates `player.tscn`), so the same applies to the variant.

## ⚙️ Settings controls

The **Audio** tab of `scenes2D/settings/settings.tscn` has two independent rows,
each a pair of `Disabled`/`Enabled` buttons in a `ButtonGroup` (see `_make_button_group`):

- **Music** (`MusicRow`) → key `[audio] music`
- **Sound Effects** (`SFXRow`) → key `[audio] sfx`

`settings.gd` reads/writes both in `_load_current_settings` / `_on_apply_pressed`.
`Settings` (autoload `scenes2D/settings/config.gd`) applies them in
`apply_audio_settings()`: mutes/unmutes the `Music` and `SFX` buses via
`AudioServer.set_bus_mute(get_bus_index(...), not value)`. Defaults in `DEFAULTS.audio`
(`music = true`, `sfx = true`); `apply_audio_settings()` runs in the autoload's `_ready`
and on every option change.

### 🎚️ Per-bus volume — VolumeBar (2026-06-25)

To the right of each row (Music/SFX) there is a **`VolumeBar`** (`controls2D/volume_bar/`,
`class_name VolumeBar`), a **reusable** volume control drawn as an **equalizer** (10
segments, green→yellow→red gradient) that the user **clicks/drags** to adjust from
**1 to 100** (emits `value_changed`). `settings.gd` creates the two in code (`_add_volume_bar`),
enables/disables them according to the toggle (`enabled`, volume only adjustable with audio on) and saves in
`[audio] music_volume` / `sfx_volume`. `apply_audio_settings()` converts the % to dB
(`_volume_to_db` → `linear_to_db`; 100% = 0 dB) and applies it via `AudioServer.set_bus_volume_db`.
Defaults `music_volume = 100` / `sfx_volume = 100`. The control also appears on its own in the
**Controls** screen (the `controls2D/` scanner finds `volume_bar/volume_bar.tscn`).

> **Active buttons "lit up" (2026-06-25):** `scenes2D/menu/button_pressed.tres` (the theme's pressed/active
> state, used by the settings radios) went from a dark (recessed) background to a **light background +
> white border + glow** → the selected button stands out as "lit".

## 🔍 Model preview

Since the characters' emitters moved to the `SFX` bus, the preview audio in the
[[🗿 biblioteca-de-modelos (EN)|biblioteca-de-modelos]] also respects the global mute of `SFX` — the local
toggles **Audio** (every sound that is not speech) and **Voices** (only voice/shouts,
classified by name via `_is_speech_audio`) enable/disable the playback, and the global
bus can silence it on top.

## 🔗 Related

- [[🗿 biblioteca-de-modelos (EN)|biblioteca-de-modelos]]
- [[🎬 fluxo-de-cenas (EN)|fluxo-de-cenas]]
- [[📄 formatacao (EN)|formatacao]]

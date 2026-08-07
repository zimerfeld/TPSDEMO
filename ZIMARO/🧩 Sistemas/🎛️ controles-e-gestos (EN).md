---
tipo: sistema
projeto: ZIMARO
lang: en-US
atualizado: 2026-08-07
---

# 🎛️ Controls, remapping and gestures

> The **Controls** tab in settings: every player function and every model animation mappable to a key
> or mouse button — plus the path that makes the animation actually play in a match.
> Siblings: [[🎛️ controles-e-gestos (PT)|PT]] · [[🎛️ controles-e-gestos (ES)|ES]].
> See also [[🧍 humanoide-jogavel (EN)]] and [[🎮 player (EN)]].

## ESC in a match opens settings

ESC used to open the "Leave the match?" confirmation directly. Now it opens the **settings screen over
the game**, which is **paused** — that's what leaves the character idle, unresponsive to input and no
longer taking damage while the player adjusts options. The screen runs in `PROCESS_MODE_ALWAYS` so it
keeps working with the tree stopped (the same pattern the confirmation already used).

- **Back** resumes the game exactly where it stopped (unpauses, recaptures the mouse).
- **Leave Match** — a button that only exists in this mode, built in code — raises the **same**
  confirmation as always. "Yes" returns to level selection; "No" returns the player to settings, with
  the game still paused.

**Online stayed as it was** (ESC returns to the menu): in a room the tree can't be paused — it would
freeze replication — and room ESC is already handled by `host_session`/`client_session`, which don't
even forward the key to the level inside the SubViewport.

## Action remapping

`scenes2D/settings/input_bindings.gd`. Actions and their **default** events live in `project.godot`;
only what the player CHANGED goes to `Settings.config_file`, section `bindings` — anyone who never
remapped keeps a clean file.

- 14 actions in four groups: **Movement**, **Combat**, **Camera**, **System**.
- Clicking the shortcut enters capture ("Press a key…"); ESC cancels. Accepts **key or mouse button**.
- Keys stored by **physical position** (`physical_keycode`), like the rest of the project: AZERTY and
  ABNT2 keep the same spot on the keyboard.
- **Factory** events are kept in memory at boot, before any override — that's what the **Default**
  button restores, with no restart.
- A clash with another action is **accepted with a warning**: people who remap usually swap two
  actions, and blocking would force clearing one first.
- `Settings.load_settings()` applies overrides at boot; without it they'd only last the session.

> **Gotcha:** `ConfigFile.get_value(section, key, null)` counts as "no default given" and floods the
> console with errors. The "not saved" sentinel is an **empty dictionary**.

## Animation shortcuts

`scenes2D/settings/animation_bindings.gd`. The list is **not hand-written**: it comes from the
humanoid model's own animations, read from the `.glb` — adding a clip in Blender makes it show up on
screen. They're the 36 from the 16-bone rig, named in Portuguese (`ocioso`, `andar`, `rolar_frente`,
`defender_esq`…), the same bank FIGArtStudio uses.

- Persisted under `anim_bindings`, only what the player changed.
- **Default inheritance:** `andar`/`correr` inherit the `move_forward` key, `saltar` the `jump` one,
  `atirar_*` the `shoot` one. Remapping the action carries the animation along — inheritance, not a
  copy.
- `defender_*` was deliberately left **out** of the defaults: the right button is **aim**
  (toggle), not defence; inheriting from it would make one button mean two things.

## Gestures: how the animation plays in a match

Three decisions, each avoiding one way of getting it wrong:

1. **A gesture is a LAYER, not a state.** It goes into an `AnimationNodeOneShot` on top of locomotion.
   As a state, `animate()` — which runs every physics frame — would rewrite it the next frame and the
   gesture simply wouldn't show. Measured: the character covers 2.34 m **while** the gesture plays.
2. **The event is NOT consumed, and locomotion never becomes a gesture.**
   `ocioso`/`andar`/`correr`/`saltar` belong to the state machine (`AnimationBindings.is_locomotion`);
   firing them on top would fight the walking itself. Together with not consuming the event, that's
   what keeps **WASD intact** even when a locomotion animation inherits its key. Only the **rising
   edge** counts — holding doesn't re-fire.
3. **The server mediates.** The owner plays immediately (responsiveness) and asks for confirmation;
   the server **validates that the requester owns that body** — otherwise any peer could animate
   someone else's character — and rebroadcasts. The echo returning to the owner is ignored within a
   window, so it doesn't play twice.

A character without the layer (the robot, today) is a **silent no-op**: `supports_gestures()` returns
`false`.

## Where this lives

| file | role |
| --- | --- |
| `scenes2D/settings/input_bindings.gd` | actions: capture, persistence, `InputMap` application, defaults |
| `scenes2D/settings/animation_bindings.gd` | animations: list read from the `.glb`, default inheritance, lookup by event |
| `scenes2D/settings/settings.gd` | the tab (rows built in code), shared capture, pause mode |
| `library3D/characters/player/player.gd` | `request_gesture` / `play_gesture` (server-mediated RPC) |
| `library3D/characters/player/player_input.gd` | key interception on the local owner |
| `scenes3D/level_exit.gd` | ESC → settings; leave-match confirmation |

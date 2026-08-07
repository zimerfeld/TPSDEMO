# ZIMARO — Full documentation (English)

> Detailed, extensive English documentation. For the high-level bilingual summary see
> [README.md](README.md); the Portuguese version is [README.pt-BR.md](README.pt-BR.md) and the
> Spanish version is [README.es-ES.md](README.es-ES.md).
> The [`ZIMARO/`](ZIMARO) vault mirrors this content with per-system notes.

ZIMARO is a third-person shooter sandbox made using [Godot Engine](https://godotengine.org).

[![GitHub stars](https://img.shields.io/github/stars/zimerfeld/ZIMARO?style=for-the-badge&logo=github)](https://github.com/zimerfeld/ZIMARO/stargazers) &nbsp; [![GitHub downloads](https://img.shields.io/github/downloads/zimerfeld/ZIMARO/total?style=for-the-badge&logo=github&label=Downloads)](https://github.com/zimerfeld/ZIMARO/releases)

This game is built and maintained in my free time. If you enjoy ZIMARO, a sponsorship helps keep new features and fixes coming. 💜

[![GitHub Sponsor](https://img.shields.io/badge/Sponsor-zimerfeld-EA4AAA?style=for-the-badge&logo=githubsponsors&logoColor=white)](https://github.com/sponsors/zimerfeld) &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; [![Ko-fi](https://img.shields.io/badge/Ko--fi-Buy%20me%20a%20coffee-FF5E2B?style=for-the-badge&logo=ko-fi&logoColor=white)](https://ko-fi.com/C0D621FCGD)

## Overview

Built on the [Godot Engine](https://godotengine.org), ZIMARO is a small
third-person shooter sandbox. At a high level it offers:

- **Menu-driven flow** — a main menu leads to character selection, a level picker, a
  settings screen, a developer screen, and online play.
- **Screen visuals & dialogs** — each 2D screen carries its own lightweight **animated shader
  background** evoking its purpose: a receding **stage grid** (Levels), a **connecting-nodes
  network** (Play Online), an **equalizer** (Settings) and a **dev blueprint** with a scan sweep
  (Developer). The **Play Online** screen also frames its border (inset margin) with a **thick
  braided-metal wire** that **two pulses of intense electric energy** (white-hot core, pulsing bloom
  and branching sparks) slowly run, **mirrored across the
  vertical axis** (they split at the top and meet again at the bottom), with **lightning/thunder
  sparks** crackling along it. All
  **confirmation/alert windows are built on one reusable floating-window control**
  (`FloatingWindow`, a `controls2D` scene) — centered text, equal-width buttons, a standard × close and a
  modal backdrop — created by the `FloatingDialog` helper; the same base other floating windows can reuse.
  The **global error window is recoverable**: closing it (× / ESC / **Back**) just returns focus to the
  calling scene — a port/connection or validation error **never quits the game** (with a **Try Again**
  option when it makes sense).
- **Playable characters** — selectable player variants that move, aim, jump and shoot,
  with first-person camera control and a local health HUD. The **jump is higher** and the **fire
  rate more spaced out**; the **shot now leaves only after the aim settles** (once the aim animation
  finishes), from the barrel tip — fixing the glitch where, on the **client** player, the bullet
  seemed to leave before the aim / outside the barrel.
- **Allied bots (covering fire)** — players of the **friendly faction** (spawned `bot_controlled` by
  the level templates) give **cover and assistance** to the human player: they engage threats near
  the bot or the player, but **orbit the nearest player** at a set distance (circling around them
  **without ever colliding**, and **spreading out among themselves** instead of stacking) and stay
  within a **leash** — when they stray too far, regrouping takes
  priority over chasing, so they **no longer run off until falling off the map**. Their behaviors
  (follow squad, prioritize enemies, combat spacing, pressure flank…) live in a dedicated AI script
  (`library3D/characters/players/player/IA/player_bot_ai.gd`).
- **Level templates (Template Manager)** — each level row on the Levels screen has a **template
  button** that opens the **Template Manager** (a **scrollable** floating window, also reachable from
  the host's room manager): named spawn templates per level, each with entries defining
  **model**, **faction** (friendly/enemy/neutral), **count**, **scale** and **placement**
  (explicit coordinates, random area or combat formation). The **Scale (%)** field — right below
  Count, in both managers — grows or shrinks the model as a percentage of its original size (`0` =
  natural, `+50` = one and a half times, `-30` = 30% smaller; range -95% to +900%). The value is
  **saved in the template**, so it is loaded and can be changed **at runtime**, with no rebuild. **"Save and Apply"** activates
  the template, applied when the level starts (solo or as an online room). Works the same in the
  editor and in the **exported .exe**: the model scanner resolves the `.remap` names the export
  produces (same pattern as the Models screen), saving a **new** template stores the generated id (so
  activating right after saving works and re-saving never duplicates it), and the template **name
  survives** entry add/remove refreshes. Each entry's model is picked through **cascading folder
  navigation**: one dropdown per library folder level (`characters/` → `enemies/` → `red_robot`,
  for example), descending only through folders that contain models — reaching a model folder
  fills the entry's model/scene fields. The form is **tidied for readability**: the
  placement-specific fields are gathered into a titled **"Placement options"** panel that shows only
  the fields for the chosen mode (coordinates / random center + size / formation + origin + spacing),
  numeric fields (count, spacing, rotation) are compact, and the window is sized to its content so
  controls no longer stretch edge-to-edge.
- **Scenery Manager** — sibling of the Template Manager with its own button beside each level:
  same window and fields (minus Faction), browsing the **`library3D/sceneries`** library (stage
  props: **magenta box, emerald sphere and amber pill** — basic volumetric geometries with
  emissive materials, their own light and colliders following the LimbColliders/BODY-member
  concept, configurable in the Models screen). A level can have a character template **and** a
  scenery active at the same time, applied in solo play and in online rooms. Since version
  **202608071124**, the **host's room management also picks the scenery** (previously only the
  character template): the online room is born with the complete level, and the pieces reach whoever
  joins **at the server's exact coordinates** — before, they all spawned stacked at the origin for
  clients, because the transform never travelled in the creation packet. A command-line tool
  (`scripts/scenery_contract.gd`) validates, fixes and imports models against that contract, and the
  managers warn on screen when the chosen model doesn't meet it.
- **Arena environments (striking, cheap by design)** — each level ships its own cyberpunk
  atmosphere: a **procedural gradient sky**, exponential **distance fog** and an emissive **neon
  grid floor** (one shared shader, `themes/level_grid_floor.gdshader` — pure per-pixel math, no
  textures, with a distance fade that kills horizon moiré), each with a per-level color identity
  (**Level 1 = cyan**, **Level 2 = amber sunset**, the same color language as the Host/Client
  session screens). Built to the project's performance goal — **60+ FPS on minimal graphics
  hardware** — so it looks striking at near-zero GPU cost; the grid glow is pure emission, so it
  works with Bloom off and gains a free neon halo when Bloom is enabled in Settings.
- **Enemies** — a ground enemy (Red Robot) that approaches, aims and fires a black **cannon
  ball** (a recolored, red-glowing version of the player's shot), and a flying bomber
  (Criatura Alada) that orbits the player and drops bombs.
- **Red Robot AI** — its runtime behaviors and decisions live in a dedicated AI script
  (`library3D/characters/red_robot/IA/red_robot_ai.gd`): **1.5× faster reload** (first and
  subsequent shots); it **opens fire** as soon as the player enters weapon range and is more than
  10 m away; and if the player gets to **10 m or closer**, the robot **opens up space** — since it
  now **turns its legs toward where it moves** (see below), it **turns and runs** while the
  **turret keeps aiming and shooting** at the player independently. Each robot moves
  **individually** (its own strafe sign, phase and speed, seeded at spawn) so the squad **doesn't
  march in lockstep every second**, and keeps a **loose formation** (now even **less rigid** — the
  formation point "breathes" in a slow drift instead of converging on fixed coordinates).
  **Realistic ground locomotion (no more foot-sliding):** the walk animation's real stride is
  **measured at runtime** and the enemy's **legs face the direction it walks** while the step itself
  is **driven by the animation's own root motion** — so the foot always lands exactly on the ground it
  covers, in any direction, with the **cadence matched to speed** (feet no longer skate). Their
  **movement speeds are tuned to the stride the walk sustains** (strafe ~1.4 m/s, pressure
  repositioning ~1.8 m/s, retreat ~2.0 m/s) with a **smooth body turn** toward the travel direction,
  for weighty, believable motion. Each enemy targets the **closest
  player** within its alert radius — **any enemy can shoot any player** that enters the radius
  (multiplayer). The **Criatura Alada** varies its **flight height smoothly**: it **descends** to a
  limit to bomb more precisely and **climbs** to a limit to **escape** when it takes fire.
- **Factions (runtime sides)** — a per-character, runtime **faction** (**hostile / ally / neutral**)
  drives combat: **no friendly fire** (a shot never hurts the same side — the bullet even **phases
  through** an ally so it doesn't block your line of fire), **targeting by side** (enemies chase only
  the **opposite faction**, never each other), and **dynamic neutrals** — a neutral hit by an **ally
  turns hostile**, hit by an **enemy turns ally**, reverting after a few seconds. Movement was also
  **smoothed** so enemies **change direction gracefully** instead of jittering while they reposition.
- **Enemy HUD** — the shared top-screen *boss bar* shows the enemy's name, health and distance and,
  when the enemy has an attack/shooting mechanism, also its **weapon range in meters**.
  It only appears with **aiming active** and with the crosshair on one of the enemy's **limbs or
  sub-members**, and hides the moment your aim leaves it or you stop aiming — so simply walking
  past an enemy no longer pops the overlay. Any **protruding sub-member** (e.g. the leg guards)
  counts as a valid target and reveals the enemy's health. With the crosshair on a limb, the overlay
  shows **that limb's name and HP** (e.g. `Red Robot — CABEÇA`) rather than the body's health — the
  limb is what has to fall.
- **Per-limb HP (defeat condition)** — every limb and sub-limb has **its own HP**, and an enemy is
  only defeated once **all of them** are destroyed. The character's total health is split among them
  (the **head is worth double** an ordinary limb) and the percentages from the Models screen remain a
  **damage multiplier**. Destroying a limb **takes its sub-limbs down with it**; hitting the **face**
  (eyes/mouth) **takes the whole head down** — the reward for precise aim. It applies to enemies,
  friendlies and neutrals alike.
- **Per-model physical body** — the locomotion capsule (physical blocking between characters) is
  **auto-fitted to each model** from its limb colliders (radius from the standing footprint, height
  from the full extent), instead of one hand-authored default for everyone. It stays a single cheap,
  animation-independent shape per character — stable physics and deterministic networking.
- **Localized damage** — per-limb native 3D colliders sized to each character's mesh, so hits to
  different body parts deal different damage (headshots deal extra). The members come from the
  model's **body plan**, chosen by a `body_type` (**biped** = head/torso/2 arms/2 legs — the
  default; **quadruped** = head/torso/4 legs; **crawler** = head/torso only), classified by the
  `BodyParts` hierarchy via the `BodyPlans` factory — which recognises bone names in **English or
  Portuguese** (`head`/`cabeca`, `chest`/`peito`, `upper_arm.R`/`bracoDireito`…), so a new model gets
  classified without renaming its skeleton. Shots pass through the generic body collider
  to land on the limb colliders. **Extremities with their own damage** — forearm, hand, shin and foot
  become **automatic sub-members** (the big limb narrows down to the upper arm / thigh), each with its
  own collider and damage bonus; with no value set they **inherit the ARM/LEG** they belong to — you can
  hit "the hand", not just "the arm". Already-balanced characters (**Player** and **Red Robot**) opt out
  of the split and keep the whole-limb hitbox. **Sub-members** — protruding parts that get their OWN box collider
  (e.g. the Red Robot's **rear leg guard plates** and the Player's **shoulder plates**, which the
  limb capsule wouldn't wrap) — are now **editable in the Models screen** (add/remove + a bonus-%
  each), not hardcoded; each part is grouped and labeled under the limb it belongs to by name
  (e.g. "PLACA BRAÇO E", "PLACA PERNA D"), even when it's attached to another bone in the skeleton.
  The per-limb multiplier is **per-model and editable in the Models screen**: each member/sub-member
  is edited in a **draggable floating window** (title bar + **×**, Windows-style) holding a **TREE**:
  each member is a branch, its sub-members are leaves under it (e.g. "↳ PLACA BRAÇO E" under
  "BRAÇO E"). Columns: Name | Set (check) | Bonus % | Owner; each sub-member leaf carries a **trash
  button to the right of its name** to remove it in place (with a confirmation dialog; replacing the
  old footer "Remove sub-member" button). **No value is required** — without its
  own value a sub-member **inherits the owner member's**, then the plan default. The **owner** is
  chosen **explicitly** (logical grouping only — it never changes the mesh; reassigning asks for
  confirmation). Everything is saved to **one file per model, in the model's own folder**
  (`library3D/<cat>/<model>/limb_config.json` — damage values, offsets/scales + each sub-member's
  owner/inheritance relation; since `res://` is read-only in the exported `.exe`, in-game edits go to a
  writable `user://limb_config/<model>.json` override that takes read precedence; migrates from the old
  `data/limb_config/<key>.json` / combined `data/limb_config.json`) and read at runtime via `LimbConfig`; the default
  multiplier comes from the body plan (head +50%, rest ×1). Collider shapes are per-model — e.g. the
  **red_robot** uses a **spherical torso** and a **larger head** (`torso_shape`/`head_scale` on
  `LimbColliders`). **Fallback `CORPO` member** — every model with no classified member (e.g.
  **Structures** like the bronze statues, or a rig whose meshes don't match the plan) gets a single
  **CORPO** member on the Models screen that wraps the whole model (box by default), so a
  collider/damage can **always** be defined; the **Member** dropdown now shows for **any category** in
  "Whole model".
- **Reusable shooting** — the cannon-bullet and hitscan-laser firing are isolated into
  reusable components (`CannonShooter` / `LaserShooter` in `effects_shared/`) that any model
  can use; the player and Red Robot both fire via `CannonShooter`. The bullet's muzzle transform is
  baked **before** it enters the tree, so its networked spawn lands exactly at the gun on remote
  clients (no off-the-barrel offset); and the aim ray now **excludes the shooter's own body/limbs**
  and ignores point-blank hits, so rapid aim-and-fire no longer sends a shot to the sky.
- **Multiple levels** — a simple arena (Level 1) and a bomber encounter (Level 2), plus
  **rooms-based online play**: the **Play Online** screen has two
  buttons that choose the role. **Manage Rooms** opens the room manager (`host_session`), where
  you start one or more levels as isolated rooms and, per room, **Play** (after the character picker,
  spawn into it as a player), **Observe** (free-fly no-collision camera), **Restart** or **Stop**.
  Both send a **distinct notice to the room's clients**: **Stop** ends the room and sends them back to
  the browser with "The level was stopped by the host"; **Restart** reloads the level fresh and sends
  "The level was restarted by the host" (the rebuilt room reappears in the list to re-join). After a
  restart the host stays on the management grid with the mouse free (just like starting a level).
  **Join Rooms** opens the room browser (`client_session`), which lists the running rooms with a **Play**
  button (shown only while a room exists) that drops you into the chosen room after the character
  picker. Each player's chosen variant/colour shows for everyone online (per-peer loadout), and each
  player's **name** floats as a 3D label above the **other** players' heads — never above your own,
  whose name sits at the top of your local HP HUD instead. Other players/enemies are smoothed with a
  **timestamped interpolation buffer** for a flicker-free, high-FPS client view. The Play Online screen also has an **Optimization** selector applied before you host/join:
  interpolation **Smooth / Balanced / Responsive** (render delay 100 / 60 / 35 ms — smoothness vs.
  responsiveness), **sync rate 30 / 60 Hz** (server→client updates per second), and **host render
  Window / Pure-server** (skip room rendering to free the GPU). All dynamic models (players, enemies,
  bullets, bombs) replicate from the host server. On connect, host and client exchange a **build ID** —
  mismatched builds are refused with a clear **"Incompatible versions — Host / You"** notice (PT/EN/ES)
  instead of failing silently, so both players know to run the **same `.exe`** (build stamped at export).
  The Play Online screen persists every option (last
  Port/IP, interpolation, sync rate, host render) and restores them next time; the **IP/Domain**
  dropdown lists recent addresses **and saved full domains** (FQDNs kept apart, not rolled out by
  recent IPs) to reselect later; the Host/Client screens
  are full-screen, matching the rest of the UI. The room-based online play is **validated across 2 PCs**
  (including through a public tunnel like **playit.gg**): room entities spawn **gradually** so modest
  machines don't stall, the connection **tolerates loading spikes** (a shader hitch no longer drops the
  match) and, if the connection does drop, the client **returns to the room browser with a notice**
  instead of being stuck; any library model — including ones added later — replicates automatically.
  A **"Loading" screen** covers every entry into a level (offline) or room (online) and, at startup,
  prepares the graphics ahead of time — so the first match starts smooth instead of freezing for a few
  seconds waiting on shaders mid-action.
- **A third playable character: the HUMANOID** — besides the robot and the pink variant, you can now
  pick a humanoid with its **own rig and animations** (36 clips). It walks, runs and jumps; the
  remaining animations are available as **gestures** (see Controls below). The game's movement engine
  took speed from the animation itself — and the humanoid's don't displace the body, so it got
  computed locomotion with the **stride cadence scaled** so the feet don't slide. The selection screen
  now shows **each character's** model and resting pose, instead of the robot for everyone.
- **Run, crouch and switch the aim shoulder** — holding **SHIFT** makes the character run (with the
  running animation, not a sped-up walk); releasing goes back to walking. **CTRL** crouches, and the
  kneeling leg follows the aim side. **C** flips the aim to the other shoulder and remembers it. All
  three keys are remappable, and the stride cadence follows the real speed — the animation never turns
  into fast-forward. Each movement now behaves the way the body expects: hold a direction and the
  character **keeps walking** (or running) instead of taking one step and stopping; crouch and he
  **stays down** instead of kneeling over and over, then **stands back up** when you release CTRL.
  The jump knows where it came from too — one animation for jumping in place, another walking,
  another running.
- **Settings during a match (ESC)** — ESC in game now opens **settings over the paused match**: the
  character goes idle, unresponsive to input and taking no damage while you adjust options. **Back**
  resumes exactly where you stopped; **Leave Match** raises the usual confirmation.
- **Controls tab: remap everything** — every player function (move, jump, aim, shoot, look, quit,
  fullscreen, debug) can be mapped to a **key or mouse button**, with a per-row reset to default. Keys
  are stored by **physical position**, so AZERTY and ABNT2 keyboards keep the same spot. And there's
  an **Animations** section: the humanoid's 36, read from the model itself, mappable to keys —
  pressing the key plays the animation **on top of movement**, without disturbing WASD, and the other
  players see the gesture.
- **The template's weapon now counts** — the character manager's "Weapon" field was saved but ignored;
  it now sets the **damage** of whoever carries it. Each weapon has its own configurable damage in the
  Models screen (default: 1 health per hit), and a **character with no weapon doesn't shoot**.
- **Health and response over the network (version 202608071124)** — health stopped propagating only
  through events and became **replicated state**, including the **per-limb** map: whoever joins a room
  already in combat sees the enemy with the server's exact health and limbs, instead of full bars that
  never corrected themselves — and a downed enemy no longer keeps walking around until it vanishes
  without exploding. On the control side, the **muzzle flash, the sound and the camera shake fire at
  the instant of the click** (bullet and damage are still decided by the server), your command no
  longer waits for the sync grid before going out, and **movement stopped stuttering**: the server no
  longer echoes back to the owner the movement vector they just produced. Stopping is crisp now,
  without sliding or jumping forward.
- **Much cheaper room spawn (version 202608071124)** — building a character's per-limb hitboxes cost
  **282 ms**; a room with 16 enemies burned about 4 seconds of CPU on that alone. With bone
  classification done once (instead of once per vertex) and reused across entities of the same model,
  it dropped to **0.25 ms** from the second character on — with the hitboxes verified identical, not a
  millimetre of collision changed.
- **3D model library + viewer** — reusable 3D assets organized by type under `library3D/`,
  browsable in-game through the Models screen (category → model → part) with toggles, in
  order, for rotation, **Animação**, **Efeitos especiais** (everything linked to the model
  that no other toggle covers — particles, lights, bone-mounted laser/muzzle meshes),
  **Audio** (every sound the model emits — movement, motor, shots, explosions, voices),
  **Colisores de Membro** / member colliders (with the toggle on and one member/sub-member isolated, shows that collider's
  translucent gizmo — **members in light blue, sub-members in light purple**), **member labels** (a browser-owned toggle for the "Membro: …" tags over each
  collider — in **dark blue** — independent of the Debug 3D screen — with, right below the **Membro** toggle, an **Esqueleto** toggle
  that floats the **dark-orange** "Esqueleto: \<name\>" label of the chosen loose bone over it, plus extra Type/Name/ID lines), **Colisores de Esqueleto** (in "All members" mode → "Skeleton" filter, highlights the
  chosen loose bone's region — or all of them — with a **light-orange** translucent box), **Submembros** (floating
  **dark-purple** "Submembro: \<name\>" labels — over the sub-member chosen in the dropdown, or over **every**
  sub-member at once in "Todos os Sub-membros" mode) and **Colisores de Submembros**
  (shows the selected sub-member's limbcollider — or all of them in "Todos os Sub-membros"). The selectors are **three
  dropdowns** — **Membro** (member), **Sub-membro** right below it (with a **"Todos os Sub-membros"** option to show
  them all at once) and, only in **"Todos os membros"** mode, **Esqueleto** (loose bones), which sits below Sub-membro.
  Picking a **real** item (not "Selecione…"/"Todos") in any of the three reveals, **to its right**, a
  **collider-geometry dropdown** (sphere/box/capsule) and opens a **reusable floating window** (the controls2D
  `FloatingWindow`) with X/Y/Z **Offset, Rotation (degrees) and Scale**, titled with the item's name: each change **persists instantly**,
  shows on the model and is **read back when a character spawns**. Every geometry dropdown follows the same rule:
  it **loads the last saved choice**; with **no saved choice it auto-detects** the shape from the part's form
  (elongated → capsule, round → sphere, else box); and **"Selecione…" means no limbcollider**. "Selecione…" on a
  **member** removes its collider; on a **sub-member** it **suppresses** the collider yet **keeps the sub-member**
  in the Damage tree/dropdown so you can reconfigure it (full removal stays on the trash icon). For a **loose bone**
  (Esqueleto), a chosen shape only **previews** the collider via the **"Colisor de Esqueleto"** toggle and
  "Selecione…" hides it; the bone is **not** promoted to a sub-member (promotion stays in the Damage window's "Add
  sub-member"), and skeletons carry no damage, so they are **ignored in level scenes**. When a specific
  **sub-member** is selected, the **member** geometry dropdown is hidden (the sub-member's takes over). Members'
  colliders are shown **only** with **Membro = "Todos os membros"** (at "Modelo completo"/"Selecione…" none are
  shown). The **Dano (Damage)
  screen** is not in the toggle list: it opens from the **"Dano" button** (right of the "Voltar"/Back button) — a
  **draggable floating window** with an opaque black background ("Dano" title bar + × close) holding a **tree** of
  each member/sub-member's bonus %, where you also add/remove protruding `PART_*` colliders (which **keep the
  bone's original name** when added to an owner member) and set each one's **owner member**. Each toggle is the master switch for its category (no
  sound/animation plays while its toggle is off — including sound driven by animation tracks) and
  the toggle states are persisted between visits (the damage panel aside — it opens closed, but the
  damage window's **last position** is remembered and restored on reopen). An
  animation plays only when **the toggle is on AND a clip is
  picked** in the "Animação" dropdown (there is no default-clip auto-play anymore). The
  "Animação" and "Efeitos Especiais" dropdowns appear only for the assembled "Modelo completo"
  view. "Efeitos Especiais" lists, right after "Selecione…", a **"Todos"** option and shows every
  kind of effect the model has (lights/luminosity, smoke, particles, decals, fog…); picking one
  isolates a single effect. Picking a
  value in any selector (Categoria → Modelo → Malha) resets every dropdown below it to
  "Selecione…". **Every
  selector choice is persisted** (alongside the toggles), and reopening the screen restores the
  chain exactly as it was left — without auto-selecting any item: the first selector with no saved
  choice sits on "Selecione…" ready to continue, and if a saved choice no longer exists in the
  library that selector (and the ones below it) are disabled. Navigation is guided purely by the
  sequential dropdown gating (no status line). Drag with the **left button** to hand-rotate the
  model up to 180° on both axes, and with the **right button** to **move the camera** (pan) — bringing
  an off-frame part (a hand, a foot) to the centre without having to spin and zoom out. The pan works
  "grab the scene" style (the point under the cursor follows the drag, feeling the same at any zoom),
  is clamped so the model never leaves the view, and re-centres when you switch models; the mouse
  wheel still zooms. Rotating and panning **freeze** while the pointer is over a floating window —
  Damage/AI or any other — and resume when it leaves or the window closes. A **3D axis gizmo**
  (editor-style: red X, green Y, blue Z, with a ball and letter at each tip) sits at the **top
  right** — in its own overlaid SubViewport, left of the toggles, without covering the model — and
  **rotates together with the model**, showing its orientation. Toggling any option acts on the live preview in place — it
  never reloads the model nor changes the camera/rotation. For Personagens and Armas, a
  **member tooltip stack** floats over each member's collider: each line has its **own color**
  (Membro = cyan-blue, Tipo = orange, Nome = green, ID = yellow), **the same color applied to the
  toggle** that turns it on, and stacks from different members **never overlap** — when they would
  collide on screen one is pushed to another position (each set stays whole, "one below the other").
  Driven by the Models screen's **own** dedicated toggles (Membro + Tipo/Nome/ID toggles) —
  the Models scene is fully decoupled from the global **Debug 3D** overlay (its root is in the
  `no_debug_overlay` group), so Debug 2D/3D only affect actual game levels. Being exempt from the
  global overlay, so only Debug 3D is limited to game levels (Debug 2D now applies everywhere). The
  scene name shows via the **global watermark** at the **top-right, beside the scene title** (from
  `debug_overlay.gd`); the old LOCAL label stays hidden (not shown in the damage window). Skinned characters
  are framed/centered from their posed colliders so they spin in place instead of drifting, and
  models open **facing the camera** (player and red_robot, exported with their front on +Z, start
  showing their face with no need to rotate).
- **Cyberpunk HUD & 2D widgets** — a set of reusable UI controls (HUD, minimap, vitals,
  crosshair, pause menu, scanlines, and more).
- **Debug tooling** — see [Developer screen & debug overlay](#developer-screen--debug-overlay).
- **Localization (EN/PT)** — see [Localization](#localization-enpt).
- **Settings** — see [Settings](#settings).

## Developer screen & debug overlay

A global debug overlay (`autoload/debug_overlay.gd`, autoload **DebugOverlay**) is toggled
from the **developer** screen and the settings "Debug" tab. All toggles persist in the
saved settings (`game` section) and apply immediately (`DebugOverlay.refresh()`). Each
Disabled/Enabled toggle pair uses the **same coloured-button style as the Settings screen**: the
**selected** option shows its full authored colour (green/yellow) while the **unselected** one is
**darkened** (a disabled sub-toggle — its Debug 2D master off — greys out instead).

The developer screen lays the toggles out in **two columns**, whose tooltips use distinct
light colors so you can tell them apart:

- **Debug 2D** (light-yellow labels/tooltips) — master `debug_2d` plus the dependent line
  switches `Type` / `Name` / `Id` / `Path` / `Tab`. Controls the 2D overlay (a colored border + a
  TYPE/Name/ID/PATH/TAB tooltip, one line per value, in the same order as the toggles) over the `Control`s. It works as a **hover inspector**: the border and
  tooltip show **only for the control under the cursor** — the **most specific** (innermost) one the
  mouse covers — and **every other control stays hidden**; with nothing under the cursor, nothing
  shows. The pointed control's border **lights up** with a glow highlight (lighter, thicker, pulsing);
  if it sits **inside another control**, that **host** (container) also shows its overlay — a border
  with a **much fainter glow** plus its own tooltip — and the two tooltips (host and child) are **nudged
  apart so they don't overlap**. It works in **every scene with no exception** — including Models and the Damage editor (which opt out
  of the **3D** overlay via `no_debug_overlay`) — and also over the **scene-name label** (top-right,
  beside the title). Each tooltip picks one of the control's **four corners**, trying them in order and taking the
  first that fits **fully on-screen**: (1) right of the **top-right** corner → (2) left of the
  **top-left** → (3) right of the **bottom-right** → (4) left of the **bottom-left**. The pointed
  control's tooltip is placed **first**; the **host**'s tooltip is placed **after** and additionally
  **avoids overlapping** the child's (fixing the "parent overlay collides" case when you hover a
  container). When **none of the four outer corners** fits without colliding, the tooltip is **projected
  inside the control's own area** (one of its four free inner corners) — guaranteeing parent and child
  **never** overlap. This applies to **every** control, including the scene **title** (the `Title` label). Controls hosted inside a
  **`SubViewport`** (e.g. the Controls 2D preview) are mapped to their real on-screen position so the
  border/tooltip no longer drifts. In **any scene**, with a
  **floating window open** (e.g. Models' **Damage**/**AI**/offset-scale windows, or any `FloatingWindow`/
  confirmation dialog), Debug 2D **hides the tooltips of the calling UI behind it** — only controls
  **inside** the floating window keep their overlay, to avoid cluttering the screen; opening, closing or
  switching windows updates this live. The **Tab** line (white, `show_tab`) reports each control's
  keyboard **tab/focus index** in the active 2D scene (`-` for non-focusable controls). The **Path**
  line (light blue, `show_path`) shows the control's **path in the scene tree** (e.g. `UI/Margin/Main`),
  to **tell apart controls that share the same Type/Name**. Besides the
  developer screen, every 2D screen with a footer **Actions** bar carries a **Debug 2D** toggle
  (`CheckButton`, injected by `DebugOverlay`) so you can flip the master on/off without leaving the scene
  (the developer screen keeps its own pair). A standard-position Actions bar was also added to the
  **menu**, so the toggle reaches it. The toggle **never shows on a gameplay level scene**
  (`level_1`/`level_2`): it is a **2D-UI** control, not part of the game — `DebugOverlay` skips scenes
  that root at a `Node3D` (the **Models** screen, rooted at a plain `Node`, keeps the toggle).
- **Debug 3D** (light-cyan labels/labels) — master `debug_3d` plus the dependent switches
  `Type` / `Name` / `Id` (describing the owning `Skeleton3D`), `Members`, `Skeleton` and
  `Mesh`. Renders per-member `Label3D` tags that follow the live pose.

Dependency rule: a column master being on is **not enough** — each dependent line/feature
takes effect only when it is _also_ selected, in sync with its master. When a column's
master is off, its **whole sub-rows** (the row label plus the buttons) are disabled and dimmed (visually greyed). When a
master is on but no dependent line is selected, that column shows nothing (the 2D border
and tooltips appear only once at least one of Type/Name/Id/Tab is selected; the 3D labels are
all hidden until their sub-toggles are selected).

The **Debug 3D** extras are: **Members** (per-limb labels CABEÇA/TRONCO/BRAÇO… via the same
`BodyParts` classifier used by the localized-damage colliders), **Skeleton** (white bone
lines rebuilt every frame from the live pose) and **Mesh** (a cyan AABB wireframe box around
each MeshInstance3D).

Beside the Debug 3D column, a **player-model preview** (same height as the columns) renders the
player robot in its own `SubViewport` (own `World3D`, camera and light), slowly rotating with its
idle animation. Because the preview model sits **outside** the `no_debug_overlay` group, the global
`DebugOverlay` scans it like any other skeleton, so the **Debug 3D** toggles (Skeleton / Mesh /
Members / Type / Name / Id) apply to it live — flipping any enabled/disabled button shows the effect
on the robot immediately.

Above the columns, a general section holds **Version HUD** (`hud_version`, the **first** toggle of the
section — shows this build's `build_id` in the bottom-right corner, the SAME string the `RoomManager`
compares in the network handshake; use it to confirm everyone is on the same published version), **HUD FPS** (`hud_fps`), **Health Monitor**
(`performance_hud`, the developer-row label for the Performance HUD; see below) and **Malha no Solo** (`show_grid`) — a 100 m × 100 m wireframe
floor grid drawn at the origin in any screen that contains 3D content (Modelos 3D, levels).
Because `main.gd` swaps screens in as children of the `Main` node (so `current_scene` always
stays `Main`, a plain `Node`), the grid detects the active loaded screen and looks for any
`Node3D` descendant rather than checking the root type; it is absent on the pure-2D screens
(menu/settings/developer).

## Performance indicators (Performance HUD + StabilityGuard)

Two complementary autoloads, both reading only from Godot's `Performance` singleton (engine-internal,
reliable, cross-platform). They replaced the old single "System Health" monitor.

**StabilityGuard** (`autoload/stability_guard.gd`) is an always-on crash/freeze safety net (no
toggle). Every 0.5 s it classifies into three states and acts on the transition: `NORMAL` (physics at
60 ticks/s), `THROTTLE` (physics dropped to 30 ticks/s + a warning signal) and `EMERGENCY`
(`get_tree().paused = true` + a full-screen overlay dismissable with **ESC**). It watches five
real-risk indicators: **free system RAM** (`OS.get_memory_info()` — acts when free RAM drops below the
limits; it previously used `MEMORY_STATIC`, which reads 0 in the release `.exe` and never fired),
**VRAM** (`RENDER_VIDEO_MEM_USED`), **collision pairs** (`PHYSICS_3D_COLLISION_PAIRS`), **node count**
(`OBJECT_NODE_COUNT`) and **FPS** (`TIME_FPS`, stuck-loop detection). Each threshold is an `@export`. It emits `state_changed` /
`throttle_activated` / `emergency_activated` / `recovered`, and the overlay runs in
`PROCESS_MODE_ALWAYS` so it lives through the pause.

**Performance HUD** (`autoload/performance_hud.gd` + `scenes2D/overlays/performance_bar.gd`) is a
global top-bar overlay, toggled by the developer screen's **Performance HUD** row
(`game/performance_hud`, default off). It's click-through (only the toggle button captures the mouse)
and idles while hidden. **Basic** mode shows `FPS | NET | RAM | CPU% | GPU% | ● StabilityGuard badge`
(CPU% from `TIME_PROCESS`, GPU% a draw-call proxy; **NET** shows the ENet round-trip **ping** —
client→server, or the host's average of its clients, colour-coded by latency; works through UDP tunnels
like playit.gg, and degrades to **N/D** only when offline; **RAM** = **system** memory as "used/total GB" via `OS.get_memory_info()`
— works in release, where `Performance.MEMORY_STATIC` would read 0). **Advanced** mode (▼/▲ toggle)
adds per-category columns — CPU (process/physics/load/nodes/objects/3D bodies/collision pairs), GPU
(draw calls/triangles/VRAM/texture mem.) and Memory (system RAM/resources) — each value colored by
threshold.

> Note: replacing System Health dropped its real per-process CPU sampling (a PowerShell `Get-Process`
> background thread) and its critical-spike beep; the HUD's CPU% is a frame-time proxy instead.

## Localization (EN/PT)

The UI language switches between **Português** and **English** via the **Locale** autoload
(`autoload/locale.gd`).

- **Per-scene dictionaries.** Each scene ships its own pair of flat JSON files inside a
  `Resources/` folder next to its `.tscn` — e.g. `scenes2D/menu/Resources/menu.pt.json` +
  `menu.en.json`. They share the **same keys** (the canonical authored source text of each
  Button/Label) mapping to that language's text. At boot Locale recursively scans
  `scenes2D/` and `scenes3D/`, finds every `*.pt.json` / `*.en.json`, and **merges** them
  into one lookup table per language — so adding a screen's `Resources/` dictionaries is all
  it takes (no autoload edit).
- The choice is persisted in the saved settings (`game/language`, default `pt`) and applied
  at startup. On `_ready`, Locale connects to `node_added`, so every Button/Label that enters
  the tree is translated automatically. `OptionButton`/`MenuButton` are skipped (their text is
  the live selection), and the first time it sees a node it stores the original text in a meta
  key, so language switches translate from the original rather than already-translated text.
- **Every screen carries the language buttons.** A `LangBar` with **Português** / **English**
  buttons now lives **inside the footer `Actions` bar** (as its last group, paths
  `UI/Actions/LangBar/…`) rather than as a separate bottom-right bar — a unified footer on menu,
  chooseplayer, settings, developer, levels, playonline, controls and models. Pressing one calls
  `Locale.set_language(...)`, which persists the choice and re-localizes the live tree in
  place (the active language's button is greyed out).
- **Code-driven text** (dynamic status lines, dropdown placeholders, the settings tab titles
  and confirmation dialogs, the Performance HUD and StabilityGuard overlay) can't be reached by the automatic
  Button/Label localizer, so those nodes join the `Locale.SKIP_GROUP` group and re-apply
  `Locale.tr_key(...)` themselves on the `language_changed` signal.

**Maintenance rule:** whenever you change or add a UI text in a scene, update the matching key
in **both** that scene's `Resources/<scene>.pt.json` and `.en.json` in the same change (PT gets
the Portuguese text, EN the English one) and validate both JSON files. Because Locale indexes
by the source text, changing the scene without updating the key breaks the translation.

## Settings

The settings screen has tabs — in order **`Resolution`, `Display`**, `Antialiasing`,
`Lighting`, `Effects`, `Audio` — with a **compact half-height tab strip** (tab font size 15) and a
consistent vertical rhythm (row/section spacing of 8).
Tab titles are themselves localized (they come from the child node names, so Locale translates
them in code). Most rows are a set of toggle buttons sharing a green → yellow → orange → red
color gradient that reads as cheap → expensive (e.g. performance vs. quality), with the green
button being the safe/low option. The **active** (selected) button appears **lit** — a bright fill
with a white glowing border — while the **unselected** options are now **much dimmer** (darkened),
making the current choice stand out even more.

- **Resolution** — a video-resolution dropdown (tinted light cyan to mark it as a selector; with a
  **minimum width fit to its widest item** so no text is truncated), resolution scale, and the scale
  filter (Bilinear / FSR / MetalFX…).
- **Display** — Display Mode (Window / Fullscreen / Exclusive Fullscreen), Vertical
  Synchronization, and FPS Limit (30…144 / Unlimited). The mode and FPS-limit buttons are
  colored along the same gradient (higher cap = more demanding = warmer color). In **Window** mode
  the game runs as a **normal OS window**: on entering it, the window is resized to the saved
  resolution and centered, so it can be dragged by its title bar (no longer stuck at full-screen size).
- **Antialiasing** — TAA, MSAA and FXAA. **TAA is disabled automatically** when the scaling filter
  is **FSR 2** or **MetalFX Temporal** (temporal upscalers already do temporal antialiasing and are
  incompatible with TAA — avoids the engine warning).
- **Lighting** — Shadow Mapping, GI Type/Quality, SSAO and SSIL.
- **Effects** — Bloom and Volumetric Fog.
- **Audio** — independent controls for background **Música** (the `Music` bus) and **Efeitos
  de Som** (the `SFX` bus, into which the `Outside`/`Reactor` gameplay buses route), each
  saved and applied globally. The **background music is per scene/level**, driven by the **MusicManager**
  autoload in an **infinite loop**, switching on every screen (see `audios/README.md`). By default a
  scene is **"Selecione…" = silent** (no music) until you assign it a track. The **"Manage Music"**
  button (next to the Music on/off, enabled only while music is on) opens the **Music Manager**:
  **assign** each scene/level a specific track, **"Padrão"** (resolve by the scene name,
  `audios/<scene-name>.<ext>`) or **"Selecione…"** (silence); assignments are persisted. Clicking a
  scene's picker **selects and highlights** it, and the **▶ Play · ⏸ Pause · ⏹ Stop** trio at the top
  acts on that row — ⏸/⏹ also **pause and stop whatever track the screen is playing**, and closing the
  window puts the scene's track back on air. A **🎲 Shuffle** button assigns a random track to every
  scene/level and saves it for next time; the **main menu draws a fresh track every time the game
  opens**. To the right of each row
  (**Música** and **Efeitos de Som**) sits an **equalizer-style volume control** (`VolumeBar`, 10
  gradient-colored segments): with audio on, click/drag to set that bus's volume from **1 to 100**.

**Live settings** — there is no "Apply" button: every option saves and applies the instant it
changes. The video-resolution dropdown is the exception: it asks for confirmation, applying
(and locking to windowed mode) on "Sim" or reverting to the saved choice on "Não". A **Reset**
button (next to "Voltar") restores the built-in common-hardware defaults — after the same
Sim/Não confirmation — saving and applying them immediately. With no stored config (fresh
install) the game also boots on those defaults. The main menu reads every stored setting from
disk and applies it (graphics, resolution and audio) before the menu is shown. A chosen
resolution is clamped to the visible screen (so a 4K/8K pick on a smaller monitor can't push
the window off-screen), and every screen's bottom button bar and top title label are anchored
full-width to their edge so they stay visible at any resolution.

## Requirements

This project targets **Godot 4.6.2 (stable)** — download it
[from the website](https://godotengine.org/download/) or
[build it from source](https://github.com/godotengine/godot). Git LFS is not required.

> **Note:** the repository is big, so expect a high wait time when opening the project for the
> first time.

## Running

Get the project from [zimerfeld/ZIMARO](https://github.com/zimerfeld/ZIMARO) — clone it or
[download a ZIP archive](https://github.com/zimerfeld/ZIMARO/archive/refs/heads/main.zip) — then
open it in Godot 4.6.2.

## Windows build (executable + desktop shortcut)

To produce a standalone Windows executable and a desktop shortcut, run:

```powershell
pwsh -File build_windows.ps1
```

It exports `build/windows/ZIMARO.exe` (release, **PCK embedded** → a single ~589 MB self-contained
file) with the Godot 4.6.2 headless CLI, and (re)creates a **ZIMARO** shortcut on the Desktop using
`build/icon.ico` (rasterized once from `icon.svg`). Requires Godot 4.6.2 + its export templates
installed; the `.ico` is generated only on the first run (needs Python 3 with Pillow) and reused
afterwards. The `build/` folder and `export_presets.cfg` are git-ignored.

Before exporting, the script **automatically closes** any running `ZIMARO.exe` instance (and clears a
stray `.tmp`), avoiding the *"Failed to rename temporary file"* error when the game is open — this only
happens on an actual rebuild (unchanged turns are skipped).

The **boot splash** opens on a **black screen with no Godot logo** (`application/boot_splash/show_image=false`
+ `bg_color=black` + `minimum_display_time=0` in `project.godot`), so the window just appears dark until
the menu loads — no engine watermark.

## Project structure

2D screens and UI live under `scenes2D/`, 3D levels under `scenes3D/`, and the reusable 3D
asset library under `library3D/`:

- `scenes2D/` — all 2D screens and UI:
  - `main` — entry scene. `main.gd` is a router that swaps screens in as children (reacting to
    the `replace_main_scene` / `quit` signals) instead of calling `SceneTree.change_scene`, so
    `current_scene` stays `main`.
  - `menu`, `chooseplayer`, `levels`, `settings`, `developer`, `playonline` — the navigation
    screens.
  - `controls2D` — reusable UI widgets (cyberpunk HUD, minimap, vitals, ability bar, crosshair,
    pause menu, scanlines, log feed, etc.).
  - `controls` — a 2D controls viewer (the 2D analog of the Models screen) that browses and
    previews the `controls2D` widgets through a dropdown.
  - `cyberpunkhud` — assembled HUD screen built from `controls2D` widgets.
- `scenes3D/` — 3D levels and tools: `level_1`, `level_2`, and the `models` viewer.
- `library3D/` — 3D asset library, organized by type: `characters`, `propulsores`, `structures`,
  `weapons`, plus `geometry` and `textures` support folders. New model folders dropped in here
  show up automatically in the Models viewer.
- `effects_shared/` — cross-character helpers: `limb_colliders.gd` (per-limb native colliders for
  localized damage), `limb_config.gd` (`LimbConfig` — damage multipliers + sub-members + owners +
  collider offsets/scales store, **one file per model in the model's own folder**
  `library3D/<cat>/<model>/limb_config.json`, with a writable `user://` override for in-game edits), the **body-plan hierarchy**
  `body_parts.gd` (`BodyParts` base +
  `body_parts_biped/quadruped/crawler.gd` subclasses, bone → member classification) and
  `body_plans.gd` (`BodyPlans` factory), and shared blast/shadow assets.
- `autoload/` — global singletons: `crash_handler.gd`, `player_selection.gd`, `debug_overlay.gd`,
  `locale.gd`, `stability_guard.gd`, `performance_hud.gd`, `music_manager.gd` (per-scene/level
  background music, looping). `Settings` lives in `scenes2D/settings/config.gd`.
- `<scene>/Resources/*.pt.json` + `*.en.json` — per-scene UI language dictionaries, scanned and
  merged by the `Locale` autoload.
- `themes/` — shared theme resources.
- `ZIMARO/` — project documentation vault (mirrors this README).

Screen flow:

```
menu ─┬─ Play Offline ─► chooseplayer ─► levels ─► level_1 / level_2
      ├─ Play Online ──► playonline (Manage Rooms / Join Rooms)
      │                    ├─ Host ───► host_session   (start rooms; per room: Play / Observe / Restart / Stop)
      │                    └─ Client ─► client_session (browse rooms; per room: Play)
      │                                   └─ Play ─► chooseplayer ─► spawn into the chosen room
      ├─ settings
      ├─ developer ──┬─ models    (3D model viewer for library3D assets)
      │              └─ controls  (2D controls viewer for controls2D widgets)
      └─ quit
```

`main.gd` is the router: each screen emits `replace_main_scene` and `main` swaps it in, so the
back buttons (and <kbd>Escape</kbd>) navigate to the previous screen the same way. Every 2D screen
grabs an initial focus on entry so the **arrow keys** navigate between its buttons (shared helper
`UINav`, autoload). <kbd>Escape</kbd> follows a single rule everywhere: it first **cancels an active
field edit** (a focused `LineEdit`/`SpinBox` — e.g. the online IP/port) and only a second press
leaves the screen; on the `menu` it opens a **"Quit Zimaro?" confirmation** (Yes/No) instead of
quitting outright. The `settings`
screen applies and persists every change immediately and the `menu` re-applies all stored settings
on entry. The `developer` screen and the `settings` "Debug" tab toggle the `DebugOverlay`, and the
developer "Performance HUD" row toggles the `PerformanceHUD` overlay (and `StabilityGuard` runs
always-on). The `Locale` autoload switches
the UI language (EN/PT) from the Português/English buttons present on every screen. The
`cyberpunkhud` scene is a standalone assembled-HUD preview, not part of this navigation flow.

Folder and subfolder layout:

```
ZIMARO/
├─ scenes2D/             # 2D screens, UI and reusable widgets
│  ├─ main/              # entry scene + router (main.gd swaps screens in)
│  ├─ menu/              # main menu
│  ├─ chooseplayer/      # character picker (3D preview)
│  ├─ levels/            # level selector
│  ├─ settings/          # settings screen + Settings autoload (config.gd)
│  ├─ developer/         # developer tools menu (debug toggles, links to viewers)
│  ├─ playonline/        # online entry: Host/Client role → room manager/browser
│  ├─ host_session/      # server: room manager (start + Play/Observe/Restart/Stop per room)
│  ├─ client_session/    # client: room browser (Play into a running room)
│  ├─ controls/          # 2D widget viewer (analog of the Models screen)
│  └─ controls2D/        # reusable HUD widgets: crosshair, minimap_panel, vitals_panel, volume_bar, …
├─ scenes3D/             # 3D levels and tools
│  ├─ level_1/ level_2/               # playable levels
│  ├─ spectator_camera/  # free-fly no-collision camera to Observe a room (host) — WASD + Space
│  └─ models/            # 3D model viewer/inspector for the library3D assets
├─ library3D/            # reusable 3D asset library, organized by type
│  ├─ characters/        # players + enemies
│  ├─ propulsores/       # propulsion props (forklift)
│  ├─ structures/        # static structures (door, core, lights, props, structure)
│  ├─ weapons/           # weapons (pistola_infantil, bomb)
│  ├─ geometry/          # shared meshes/materials (.tres)
│  └─ textures/          # shared textures
├─ audios/               # per-scene/level background tracks (infinite loop; see audios/README.md)
├─ effects_shared/       # cross-character helpers: limb_colliders.gd, body_parts.gd, …
├─ autoload/             # singletons: crash_handler, player_selection, debug_overlay, locale, stability_guard, performance_hud, music_manager
│                        #   (Settings lives in scenes2D/settings/config.gd)
│                        # UI dictionaries live per scene: <scene>/Resources/*.pt.json + *.en.json (read by Locale)
├─ themes/               # shared Theme resources (ui_theme.tres, cyberpunk.tres)
├─ addons/               # Godot editor plugins (godot_ai — the MCP server)
├─ ZIMARO/               # project documentation vault (mirrors this README)
├─ screenshots/          # captured preview images
└─ project.godot · default_bus_layout.tres · file_format.sh   # project config · audio buses · formatter
```

## Native Godot building blocks

Everything in the game is built from **native Godot nodes and resources** — there is no custom
C++/GDExtension node. The only project-specific abstractions are pure-logic `RefCounted` helpers with
no node of their own (`BodyParts` and its body-plan subclasses + the `BodyPlans` factory,
`WeaponParts`, `LimbConfig`, `LaserShooter`, `CannonShooter`), which just orchestrate native nodes.
By subsystem:

- **Physics & collision:** `StaticBody3D`, `CharacterBody3D`, `RigidBody3D`, `Area3D`,
  `CollisionShape3D` (and `BoxShape3D`/`CapsuleShape3D`/`SphereShape3D`/`CylinderShape3D`), `RayCast3D`.
- **Meshes & geometry:** `MeshInstance3D`, `ArrayMesh`, and primitives (`BoxMesh`, `CylinderMesh`,
  `SphereMesh`, `PrismMesh`…).
- **Skeleton & animation:** `Skeleton3D`, `BoneAttachment3D`, `Skin`, `AnimationPlayer`,
  `AnimationTree`, `SkeletonModifier3D`.
- **Camera, light & environment:** `Camera3D`, `SpringArm3D`, `Marker3D`, `DirectionalLight3D`/
  `OmniLight3D`/`SpotLight3D`, `WorldEnvironment`, `Sky`.
- **Particles & materials:** `CPUParticles3D`, `GPUParticles3D`, `StandardMaterial3D`, `ShaderMaterial`.
- **Audio:** `AudioStreamPlayer3D`, `AudioStreamPlayer`, `AudioStream`/`AudioStreamWAV`,
  `AudioStreamRandomizer`.
- **Networking:** `MultiplayerSynchronizer`, `MultiplayerSpawner`, `SceneReplicationConfig`.
- **2D UI (`Control` tree):** `Button`, `Label`, containers, `OptionButton`, `ProgressBar`,
  `CanvasLayer`, `Theme`.

The per-limb hitbox system is the canonical example: `limb_colliders.gd` is a plain `Node3D` that
**assembles** native `StaticBody3D` + `CollisionShape3D` + `BoneAttachment3D`. The Obsidian note
[`recursos-nativos-godot`](<ZIMARO/🧩 Sistemas/🧱 recursos-nativos-godot.md>) has the full inventory.

## Controls

- Mouse or <kbd>Gamepad Right Stick</kbd>: Look around
- <kbd>W</kbd>/<kbd>A</kbd>/<kbd>S</kbd>/<kbd>D</kbd>, <kbd>Arrow keys</kbd>, <kbd>Gamepad Left Analog Stick</kbd> or <kbd>Gamepad D-Pad</kbd>: Move
- <kbd>Space</kbd>, <kbd>Gamepad A/Cross</kbd>: Jump — **variable height**: hold to complete the full jump arc
  (maximum height and distance, animation plays to the end); release mid-rise to smoothly cut the jump short
- <kbd>Right Mouse Button</kbd>, <kbd>Gamepad Left Trigger (L2)</kbd> (press to toggle, or hold and release): Aim
- <kbd>Left Mouse Button</kbd>, <kbd>Gamepad Right Trigger (R2)</kbd>: Shoot (only while aiming)
- <kbd>Arrow keys</kbd> / <kbd>Gamepad D-Pad</kbd> (in menus): Move focus between buttons
- <kbd>Escape</kbd>, <kbd>Gamepad Start</kbd>: Cancel an active field edit, else go back / to main menu (the menu asks to confirm quitting). **In an offline match it asks to confirm — "Leave the match?" (Yes → back to the level select, No → resume) — pausing the game while you decide.**
- <kbd>F11</kbd> or <kbd>Alt + Enter</kbd>: Toggle fullscreen
- <kbd>F3</kbd>: Toggle debugging information (such as FPS counter)

## Code formatting

All text files in this project must follow a consistent format, enforced by
[`file_format.sh`](file_format.sh). Always apply it before committing changes:

- UTF-8 encoding **without BOM**
- LF (Unix) line endings
- No trailing whitespace
- A trailing newline at end of file

Run the formatter from the repository root:

```bash
bash file_format.sh
```

On Windows, run it from Git Bash. It requires `dos2unix` and `perl` (`recode` is optional). A
common cause of `Parse Error: Expected '['` when loading a `.tscn`/`.tres` is a stray UTF-8 BOM —
running the formatter removes it.

> **Tip:** after moving or renaming scenes/resources, also reopen the project in the Godot editor
> once so it rebuilds `.godot/uid_cache.bin` and reimports moved assets (this clears
> `invalid UID … using text path instead` warnings).

## Documentation & knowledge base

`README.md` is a high-level bilingual summary; this file (`README.en-US.md`) and
[`README.pt-BR.md`](README.pt-BR.md) hold the extensive, detailed documentation, and the
[`ZIMARO/`](ZIMARO) vault mirrors them with per-system notes. **All three README files are kept
up to date at the end of every change** so they remain a reliable knowledge base for any analysis or
decision-making.

## Useful links

- [Main website](https://godotengine.org)
- [Source code](https://github.com/godotengine/godot)
- [Documentation](http://docs.godotengine.org)
- [Community hub](https://godotengine.org/community)
- [Other demos](https://github.com/godotengine/godot-demo-projects)

## License

© 2026 Renato Zimerfeld. This work is licensed under the **Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License (CC BY-NC-ND 4.0)** — you are free to share it for non-commercial purposes with appropriate credit, but you may **not** use it commercially and may **not** distribute modified versions. See [LICENSE.md](LICENSE.md) for the full terms.

# ZIMARO — Full documentation (English)

> Detailed, extensive English documentation. For the high-level bilingual summary see
> [README.md](README.md); the Portuguese version is [README.pt-BR.md](README.pt-BR.md).
> The [`OBSIDIAN/`](OBSIDIAN) vault mirrors this content with per-system notes.

ZIMARO is a third-person shooter sandbox made using [Godot Engine](https://godotengine.org).

- Help keep this project always updated 💜

[![GitHub Sponsor](https://img.shields.io/badge/Sponsor-zimerfeld-EA4AAA?style=for-the-badge&logo=githubsponsors&logoColor=white)](https://github.com/sponsors/zimerfeld) &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; [![Ko-fi](https://img.shields.io/badge/Ko--fi-Buy%20me%20a%20coffee-FF5E2B?style=for-the-badge&logo=ko-fi&logoColor=white)](https://ko-fi.com/C0D621FCGD)

## Overview

Built on the [Godot Engine](https://godotengine.org), ZIMARO is a small
third-person shooter sandbox. At a high level it offers:

- **Menu-driven flow** — a main menu leads to character selection, a level picker, a
  settings screen, a developer screen, and online play.
- **Playable characters** — selectable player variants that move, aim, jump and shoot,
  with first-person camera control and a local health HUD.
- **Enemies** — a ground enemy (Red Robot) that approaches, aims and fires a black **cannon
  ball** (a recolored, red-glowing version of the player's shot), and a flying bomber
  (Criatura Alada) that orbits the player and drops bombs.
- **Red Robot AI** — its runtime behaviors and decisions live in a dedicated AI script
  (`library3D/characters/red_robot/IA/red_robot_ai.gd`): **1.5× faster reload** (first and
  subsequent shots); it **opens fire** as soon as the player enters weapon range and is more than
  10 m away; and if the player gets to **10 m or closer**, the robot **runs away in the opposite
  direction** while still facing/aiming at and shooting the player.
- **Enemy HUD** — the shared top-screen *boss bar* shows the enemy's name, health and distance and,
  when the enemy has an attack/shooting mechanism, also its **weapon range in meters**.
- **Localized damage** — per-limb native 3D colliders sized to each character's mesh, so hits to
  different body parts deal different damage (headshots deal extra). The members come from the
  model's **body plan**, chosen by a `body_type` (**biped** = head/torso/2 arms/2 legs — the
  default; **quadruped** = head/torso/4 legs; **crawler** = head/torso only), classified by the
  `BodyParts` hierarchy via the `BodyPlans` factory. Shots pass through the generic body collider
  to land on the limb colliders. **Sub-members** — protruding parts that get their OWN box collider
  (e.g. the Red Robot's **rear leg guard plates** and the Player's **shoulder plates**, which the
  limb capsule wouldn't wrap) — are now **editable in the Models screen** (add/remove + a bonus-%
  each), not hardcoded; each part is grouped and labeled under the limb it belongs to by name
  (e.g. "PLACA BRAÇO E", "PLACA PERNA D"), even when it's attached to another bone in the skeleton.
  The per-limb multiplier is **per-model and editable in the Models screen**: each member/sub-member
  gets a **FLOATING bonus-% field next to its label, over the 3D model** (a "Set" checkbox + value;
  **no value is required** — without its own value a sub-member **inherits the owner member's**, then
  the plan default). Each sub-member's **owner** is chosen **explicitly** (logical grouping only — it
  never changes the mesh; reassigning asks for confirmation) in a right-docked panel. Everything is
  saved to `data/limb_config.json` and read at runtime via `LimbConfig`; the default multiplier comes
  from the body plan (head +50%, rest ×1).
- **Reusable shooting** — the cannon-bullet and hitscan-laser firing are isolated into
  reusable components (`CannonShooter` / `LaserShooter` in `effects_shared/`) that any model
  can use; the player and Red Robot both fire via `CannonShooter`.
- **Multiple levels** — a simple arena (Level 1), a bomber encounter (Level 2), a full
  complex level (Level Base), plus online (host/connect) play.
- **3D model library + viewer** — reusable 3D assets organized by type under `library3D/`,
  browsable in-game through the Models screen (category → model → part) with toggles, in
  order, for rotation, **Animação**, **Efeitos especiais** (everything linked to the model
  that no other toggle covers — particles, lights, bone-mounted laser/muzzle meshes),
  **Audio** (every sound the model emits — movement, motor, shots, explosions, voices),
  colliders, **member labels** (a browser-owned toggle for the "Membro: …" tags over each
  collider, independent of the Debug 3D screen) and **per-limb damage** (bonus-% fields **floating
  next to each member/sub-member over the model**, for characters, plus a right-docked panel to
  add/remove protruding `PART_*` colliders and set each one's **owner member**). Each toggle is the master switch for its category (no
  sound/animation plays while its toggle is off — including sound driven by animation tracks) and
  the toggle states are persisted between visits (the damage panel aside — it opens closed). An
  animation plays only when **the toggle is on AND a clip is
  picked** in the "Animação" dropdown (there is no default-clip auto-play anymore). The
  "Animação" and "Efeitos Especiais" dropdowns appear only for the assembled "Modelo completo"
  view. "Efeitos Especiais" lists, right after "Selecione…", a **"Todos"** option and shows every
  kind of effect the model has (lights/luminosity, smoke, particles, decals, fog…); picking one
  isolates a single effect. Picking a
  value in any selector (Categoria → Prefixo → Modelo → Parte) resets every dropdown below it to
  "Selecione…". **Every
  selector choice is persisted** (alongside the toggles), and reopening the screen restores the
  chain exactly as it was left — without auto-selecting any item: the first selector with no saved
  choice sits on "Selecione…" ready to continue, and if a saved choice no longer exists in the
  library that selector (and the ones below it) are disabled. Navigation is guided purely by the
  sequential dropdown gating (no status line). Drag to hand-rotate the
  model up to 180° on both axes. Toggling any option acts on the live preview in place — it
  never reloads the model nor changes the camera/rotation. For Personagens and Armas, a
  **member tooltip stack** floats over each member's collider: each line has its **own color**
  (Membro = cyan-blue, Tipo = orange, Nome = green, ID = yellow), **the same color applied to the
  toggle** that turns it on, and stacks from different members **never overlap** — when they would
  collide on screen one is pushed to another position (each set stays whole, "one below the other").
  Driven by the Models screen's **own** dedicated toggles (Rótulos + Tipo/Nome/ID toggles) —
  the Models scene is fully decoupled from the global **Debug 3D** overlay (its root is in the
  `no_debug_overlay` group), so Debug 2D/3D only affect actual game levels. Being exempt from the
  global overlay, the screen shows its **own scene-name label** — anchored **inside the damage panel**
  (right-docked, its inner bottom-left corner), shown together with the panel. Skinned characters
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
saved settings (`game` section) and apply immediately (`DebugOverlay.refresh()`).

The developer screen lays the toggles out in **two columns**, whose tooltips use distinct
light colors so you can tell them apart:

- **Debug 2D** (light-yellow labels/tooltips) — master `debug_2d` plus the dependent line
  switches `Type` / `Name` / `Id`. Controls the 2D overlay (a colored border + a
  TYPE/Name/ID tooltip) on every `Control`, in **every scene with no exception** — including Models
  and the Damage editor (which opt out of the **3D** overlay via `no_debug_overlay`) — and also over
  the bottom-left **scene-name label**.
- **Debug 3D** (light-cyan labels/labels) — master `debug_3d` plus the dependent switches
  `Type` / `Name` / `Id` (describing the owning `Skeleton3D`), `Members`, `Skeleton` and
  `Mesh`. Renders per-member `Label3D` tags that follow the live pose.

Dependency rule: a column master being on is **not enough** — each dependent line/feature
takes effect only when it is _also_ selected, in sync with its master. When a column's
master is off, its sub-toggle buttons are disabled and dimmed (visually greyed). When a
master is on but no dependent line is selected, that column shows nothing (the 2D border
and tooltips appear only once at least one of Type/Name/Id is selected; the 3D labels are
all hidden until their sub-toggles are selected).

The **Debug 3D** extras are: **Members** (per-limb labels CABEÇA/TRONCO/BRAÇO… via the same
`BodyParts` classifier used by the localized-damage colliders), **Skeleton** (white bone
lines rebuilt every frame from the live pose) and **Mesh** (a cyan AABB wireframe box around
each MeshInstance3D).

Above the columns, a general section holds **HUD FPS** (`hud_fps`), **Performance HUD**
(`performance_hud`, see below) and **Malha no Solo** (`show_grid`) — a 100 m × 100 m wireframe
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
real-risk indicators: **static RAM** (`MEMORY_STATIC`), **VRAM** (`RENDER_VIDEO_MEM_USED`),
**collision pairs** (`PHYSICS_3D_COLLISION_PAIRS`), **node count** (`OBJECT_NODE_COUNT`) and **FPS**
(`TIME_FPS`, stuck-loop detection). Each threshold is an `@export`. It emits `state_changed` /
`throttle_activated` / `emergency_activated` / `recovered`, and the overlay runs in
`PROCESS_MODE_ALWAYS` so it lives through the pause.

**Performance HUD** (`autoload/performance_hud.gd` + `scenes2D/overlays/performance_bar.gd`) is a
global top-bar overlay, toggled by the developer screen's **Performance HUD** row
(`game/performance_hud`, default off). It's click-through (only the toggle button captures the mouse)
and idles while hidden. **Basic** mode shows `FPS | NET | RAM | CPU% | GPU% | ● StabilityGuard badge`
(CPU% from `TIME_PROCESS`, GPU% a draw-call proxy; **NET** degrades to **N/D** since the project has
no optional `NetworkManager`). **Advanced** mode (▼/▲ toggle) adds per-category columns — CPU
(process/physics/load/nodes/objects/3D bodies/collision pairs), GPU (draw calls/triangles/VRAM/
texture mem.) and Memory (static RAM/resources) — each value colored by threshold.

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
- **Every screen carries the language buttons.** A bottom-right `LangBar` with **Português** /
  **English** buttons (the same pattern as the menu) is present on menu, chooseplayer,
  settings, developer, levels, playonline, controls and models. Pressing one calls
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
`Lighting`, `Effects`, `Audio` — with a consistent vertical rhythm (row/section spacing of 8).
Tab titles are themselves localized (they come from the child node names, so Locale translates
them in code). Most rows are a set of toggle buttons sharing a green → yellow → orange → red
color gradient that reads as cheap → expensive (e.g. performance vs. quality), with the green
button being the safe/low option.

- **Resolution** — a video-resolution dropdown (tinted light cyan to mark it as a selector),
  resolution scale, and the scale filter (Bilinear / FSR / MetalFX…).
- **Display** — Display Mode (Window / Fullscreen / Exclusive Fullscreen), Vertical
  Synchronization, and FPS Limit (30…144 / Unlimited). The mode and FPS-limit buttons are
  colored along the same gradient (higher cap = more demanding = warmer color).
- **Antialiasing** — TAA, MSAA and FXAA.
- **Lighting** — Shadow Mapping, GI Type/Quality, SSAO and SSIL.
- **Effects** — Bloom and Volumetric Fog.
- **Audio** — independent controls for background **Música** (the `Music` bus) and **Efeitos
  de Som** (the `SFX` bus, into which the `Outside`/`Reactor` gameplay buses route), each
  saved and applied globally.

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
- `scenes3D/` — 3D levels and tools: `level_1`, `level_2`, `level_base`, and the `models` viewer.
- `library3D/` — 3D asset library, organized by type: `characters`, `propulsores`, `structures`,
  `weapons`, plus `geometry` and `textures` support folders. New model folders dropped in here
  show up automatically in the Models viewer.
- `effects_shared/` — cross-character helpers: `limb_colliders.gd` (per-limb native colliders for
  localized damage), `limb_config.gd` (`LimbConfig` — per-model damage multipliers + sub-members
  store, `data/limb_config.json`), the **body-plan hierarchy** `body_parts.gd` (`BodyParts` base +
  `body_parts_biped/quadruped/crawler.gd` subclasses, bone → member classification) and
  `body_plans.gd` (`BodyPlans` factory), and shared blast/shadow assets.
- `autoload/` — global singletons: `crash_handler.gd`, `player_selection.gd`, `debug_overlay.gd`,
  `locale.gd`, `stability_guard.gd`, `performance_hud.gd`. `Settings` lives in `scenes2D/settings/config.gd`.
- `<scene>/Resources/*.pt.json` + `*.en.json` — per-scene UI language dictionaries, scanned and
  merged by the `Locale` autoload.
- `ui/`, `themes/` — shared theme resources. `tools/` — headless helper scripts.
- `OBSIDIAN/` — project documentation vault (mirrors this README).

Screen flow:

```
menu ─┬─ play ───────► chooseplayer ─► levels ─► level_1 / level_2 / level_base
      ├─ play online ─► playonline ──► level_base
      ├─ settings
      ├─ developer ──┬─ models    (3D model viewer for library3D assets)
      │              └─ controls  (2D controls viewer for controls2D widgets)
      └─ quit
```

`main.gd` is the router: each screen emits `replace_main_scene` and `main` swaps it in, so the
back buttons (and <kbd>Escape</kbd>) navigate to the previous screen the same way. The `settings`
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
│  ├─ playonline/        # host/connect online screen
│  ├─ controls/          # 2D widget viewer (analog of the Models screen)
│  └─ controls2D/        # reusable HUD widgets: crosshair, minimap_panel, vitals_panel, …
├─ scenes3D/             # 3D levels and tools
│  ├─ level_1/ level_2/ level_base/   # playable levels
│  └─ models/            # 3D model viewer/inspector for the library3D assets
├─ library3D/            # reusable 3D asset library, organized by type
│  ├─ characters/        # players + enemies
│  ├─ propulsores/       # propulsion props (forklift)
│  ├─ structures/        # static structures (door, core, lights, props, structure)
│  ├─ weapons/           # weapons (pistola_infantil, bomb)
│  ├─ geometry/          # shared meshes/materials (.tres)
│  └─ textures/          # shared textures
├─ effects_shared/       # cross-character helpers: limb_colliders.gd, body_parts.gd, …
├─ autoload/             # singletons: crash_handler, player_selection, debug_overlay, locale, stability_guard, performance_hud
│                        #   (Settings lives in scenes2D/settings/config.gd)
│                        # UI dictionaries live per scene: <scene>/Resources/*.pt.json + *.en.json (read by Locale)
├─ ui/  themes/          # shared Theme resources (ui_theme.tres, cyberpunk.tres)
├─ tools/  _gen/         # headless GDScript generators for 3D assets (gen_*.gd)
├─ addons/               # Godot editor plugins (godot_ai — the MCP server)
├─ OBSIDIAN/             # project documentation vault (mirrors this README)
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
[`recursos-nativos-godot`](OBSIDIAN/CLAUDE/sistemas/recursos-nativos-godot.md) has the full inventory.

## Controls

- Mouse or <kbd>Gamepad Right Stick</kbd>: Look around
- <kbd>W</kbd>/<kbd>A</kbd>/<kbd>S</kbd>/<kbd>D</kbd>, <kbd>Arrow keys</kbd>, <kbd>Gamepad Left Analog Stick</kbd> or <kbd>Gamepad D-Pad</kbd>: Move
- <kbd>Space</kbd>, <kbd>Gamepad A/Cross</kbd>: Jump
- <kbd>Right Mouse Button</kbd>, <kbd>Gamepad Left Trigger (L2)</kbd> (press to toggle, or hold and release): Aim
- <kbd>Left Mouse Button</kbd>, <kbd>Gamepad Right Trigger (R2)</kbd>: Shoot (only while aiming)
- <kbd>Escape</kbd>, <kbd>Gamepad Start</kbd>: Go to main menu/quit
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
[`OBSIDIAN/`](OBSIDIAN) vault mirrors them with per-system notes. **All three README files are kept
up to date at the end of every change** so they remain a reliable knowledge base for any analysis or
decision-making.

## Useful links

- [Main website](https://godotengine.org)
- [Source code](https://github.com/godotengine/godot)
- [Documentation](http://docs.godotengine.org)
- [Community hub](https://godotengine.org/community)
- [Other demos](https://github.com/godotengine/godot-demo-projects)

## License

See [LICENSE.md](LICENSE.md) for details.

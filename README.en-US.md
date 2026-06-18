# Third Person Shooter Demo — Full documentation (English)

> Detailed, extensive English documentation. For the high-level bilingual summary see
> [README.md](README.md); the Portuguese version is [README.pt-BR.md](README.pt-BR.md).
> The [`OBSIDIAN/`](OBSIDIAN) vault mirrors this content with per-system notes.

Third person shooter demo made using [Godot Engine](https://godotengine.org).

- Help keep this project always updated 💜

[![GitHub Sponsor](https://img.shields.io/badge/Sponsor-zimerfeld-EA4AAA?style=for-the-badge&logo=githubsponsors&logoColor=white)](https://github.com/sponsors/zimerfeld) &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; [![Ko-fi](https://img.shields.io/badge/Ko--fi-Buy%20me%20a%20coffee-FF5E2B?style=for-the-badge&logo=ko-fi&logoColor=white)](https://ko-fi.com/C0D621FCGD)

## Overview

Starting from the original Godot TPS demo, this project grows it into a small
third-person shooter sandbox. At a high level it offers:

- **Menu-driven flow** — a main menu leads to character selection, a level picker, a
  settings screen, a developer screen, and online play.
- **Playable characters** — selectable player variants that move, aim, jump and shoot,
  with first-person camera control and a local health HUD.
- **Enemies** — a ground enemy (Red Robot) that approaches, aims and fires a black **cannon
  ball** (a recolored, red-glowing version of the player's shot), and a flying bomber
  (Criatura Alada) that orbits the player and drops bombs.
- **Localized damage** — per-limb native 3D colliders (head, torso, arms, legs) sized to
  each character's mesh, so hits to different body parts deal different damage (headshots
  deal extra). Shots pass through the generic body collider to land on the limb colliders.
- **Reusable shooting** — the cannon-bullet and hitscan-laser firing are isolated into
  reusable components (`CannonShooter` / `LaserShooter` in `effects_shared/`) that any model
  can use; the player and Red Robot both fire via `CannonShooter`.
- **Multiple levels** — a simple arena (Level 1), a bomber encounter (Level 2), a full
  complex level (Level Base), plus online (host/connect) play.
- **3D model library + viewer** — reusable 3D assets organized by type under `library3D/`,
  browsable in-game through the Models screen (category → model → part) with toggles, in
  order, for rotation, **Animação**, **Efeitos especiais** (everything linked to the model
  that no other toggle covers — particles, lights, bone-mounted laser/muzzle meshes),
  **Audio** (every sound the model emits — movement, motor, shots, explosions, voices) and
  colliders. Each toggle is the master switch for its category (no sound/animation plays
  while its toggle is off, regardless of the dropdown — including sound driven by animation
  tracks) and the toggle states are persisted between visits. The "Animação" and "Efeitos
  Especiais" dropdowns appear only for the assembled "Modelo completo" view; the effects one
  isolates a single effect when picked. Picking a value in any selector (Categoria → Prefixo
  → Modelo → Parte) resets every dropdown below it to "Selecione…". A red status line tracks
  the drill-down and floats directly **below the combo it is about**. Drag to hand-rotate the
  model up to 180° on both axes. Toggling any option acts on the live preview in place — it
  never reloads the model nor changes the camera/rotation. For Personagens and Armas, a
  name label (CABEÇA, TRONCO, BRAÇO…) floats over each member's collider; skinned characters
  are framed/centered from their posed colliders so they spin in place instead of drifting.
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
  TYPE/Name/ID tooltip) on every `Control`.
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

Above the columns, a general section holds **HUD FPS** (`hud_fps`), **System Health**
(`system_health`, see below) and **Malha no Solo** (`show_grid`) — a 100 m × 100 m wireframe
floor grid drawn at the origin in any screen that contains 3D content (Modelos 3D, levels).
Because `main.gd` swaps screens in as children of the `Main` node (so `current_scene` always
stays `Main`, a plain `Node`), the grid detects the active loaded screen and looks for any
`Node3D` descendant rather than checking the root type; it is absent on the pure-2D screens
(menu/settings/developer).

## System Health monitor

The developer screen's **System Health** row toggles a global monitoring overlay
(`autoload/system_health.gd`, autoload **SystemHealth**) — a **draggable floating panel** (grab
its title bar with the left mouse button to move it; it always stays within the screen, and its
position is remembered between runs — a settings **Reset** sends it back to the top-right corner).
It shows: **FPS**, the **real per-process CPU usage** (`CPU`), the game's static memory
(`Mem. Jogo`), the video memory (`Mem. Vídeo`) and the system RAM used (`Mem. Sistema` = total −
free physical RAM, e.g. 12.6 / 16.2 GB = 78%).

CPU is the actual usage of the Godot process, matching what the OS Task Manager shows for it:
Godot has no API for it, so a **background thread** samples it from the OS (`Get-Process … .CPU`
via PowerShell on Windows) and turns successive readings into a percentage across the logical
cores. It reads **N/D** until the first delta is ready, or on non-Windows platforms. (GPU
per-process and CPU temperature are not reliably available from the engine, so they are not shown.)

When the system RAM reaches the **90%** safe limit — or CPU stays over it for a few seconds (short
spikes are tolerated) — the panel turns its alert line red, and, if the in-panel "Pausar ao atingir
o limite" switch is on (default), it **pauses processing** (`get_tree().paused`) to keep a low-spec
machine from freezing or crashing the OS, offering a **Retomar** button to resume. The overlay keeps
running while paused (`PROCESS_MODE_ALWAYS`); resuming latches auto-pause off until usage falls back
under the limit, so it doesn't immediately re-pause.

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
  and confirmation dialogs, the System Health panel) can't be reached by the automatic
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

Get the project from [zimerfeld/TPSDEMO](https://github.com/zimerfeld/TPSDEMO) — clone it or
[download a ZIP archive](https://github.com/zimerfeld/TPSDEMO/archive/refs/heads/main.zip) — then
open it in Godot 4.6.2.

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
  localized damage), `body_parts.gd` (bone → limb classification), and shared blast/shadow assets.
- `autoload/` — global singletons: `crash_handler.gd`, `player_selection.gd`, `debug_overlay.gd`,
  `locale.gd`, `system_health.gd`. `Settings` lives in `scenes2D/settings/config.gd`.
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
developer "System Health" row toggles the `SystemHealth` monitor. The `Locale` autoload switches
the UI language (EN/PT) from the Português/English buttons present on every screen. The
`cyberpunkhud` scene is a standalone assembled-HUD preview, not part of this navigation flow.

Folder and subfolder layout:

```
TPSDEMO/
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
├─ autoload/             # singletons: crash_handler, player_selection, debug_overlay, locale, system_health
│                        #   (Settings lives in scenes2D/settings/config.gd)
│                        # UI dictionaries live per scene: <scene>/Resources/*.pt.json + *.en.json (read by Locale)
├─ ui/  themes/          # shared Theme resources (ui_theme.tres, cyberpunk.tres)
├─ tools/  _gen/         # headless GDScript generators for 3D assets (gen_*.gd)
├─ addons/               # Godot editor plugins (godot_ai — the MCP server)
├─ OBSIDIAN/             # project documentation vault (mirrors this README)
├─ screenshots/          # captured preview images
└─ project.godot · default_bus_layout.tres · file_format.sh   # project config · audio buses · formatter
```

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

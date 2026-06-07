# Third Person Shooter Demo

Third person shooter demo made using [Godot Engine](https://godotengine.org).

Check out this demo on the asset library: https://godotengine.org/asset-library/asset/678

![Screenshot of TPS demo](screenshots/screenshot.webp)

## Godot versions

- The [`master`](https://github.com/godotengine/tps-demo) branch is compatible with the latest stable Godot version (currently 4.x).
- If you are using an older version of Godot, use the appropriate branch for your Godot version:

  - [`3.x`](https://github.com/godotengine/tps-demo/tree/3.x) branch
  for Godot 3.4.x and 3.5.x.
  - [`3.3`](https://github.com/godotengine/tps-demo/tree/3.3) branch
  for Godot 3.3.x.
  - [`3.2`](https://github.com/godotengine/tps-demo/tree/3.2) branch
  for Godot 3.2.2 or 3.2.3.
  - [`3.2.1`](https://github.com/godotengine/tps-demo/tree/3.2.1) branch
  for Godot 3.2.0 or 3.2.1.
  - [`3.1`](https://github.com/godotengine/tps-demo/tree/3.1) branch
  for Godot 3.1.x.

> **Note**
>
> The repository is big, so expect a high wait time when opening the project for
> the first time.

## Git LFS

Git LFS is no longer required for the current `master` or `3.x` branches.

You only need Git LFS if you are checking out the `3.1` or `3.2.1` branches.
Those branches have instructions for Git LFS in their README files.

## Running

You need [Godot Engine](https://godotengine.org) to run this demo project.
Download the latest stable version [from the website](https://godotengine.org/download/),
or [build it from source](https://github.com/godotengine/godot).

You can either download from the Godot Asset Library, clone this repository, or
[download a ZIP archive](https://github.com/godotengine/tps-demo/archive/master.zip).

## Project structure

UI screens live under `scenes2D/`, 3D content under `scenes3D/`:

- `scenes2D/` — `menu`, `settings`, `chooseplayer`, `developer`, `levels`
- `scenes3D/` — `players`, `enemies`, `door`, `level_1`, `level_base`, `models`
- `autoload/` — global singletons: `config.gd` (registered as `Settings`),
  `crash_handler.gd`, `player_selection.gd`, `debug_overlay.gd`
- `main/main.tscn` is the entry scene. `main.gd` is a router that swaps screens
  in as children — reacting to the `replace_main_scene` / `quit` signals —
  instead of using `SceneTree.change_scene`, so `current_scene` stays `main`.

Screen flow:

```
menu ─┬─ chooseplayer ─► levels ─► level_1 / level_base
      ├─ settings
      ├─ developer ─► models        (3D model viewer for level_base assets)
      └─ play online ─► level_base
```

The `developer` screen and the `settings` "Debug" tab toggle the `DebugOverlay`
(FPS HUD, ground grid, and per-node TYPE/ID tooltips on 2D and 3D nodes).

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

On Windows, run it from Git Bash. It requires `dos2unix` and `perl`
(`recode` is optional). A common cause of `Parse Error: Expected '['` when
loading a `.tscn`/`.tres` is a stray UTF-8 BOM — running the formatter removes it.

> **Tip:** after moving or renaming scenes/resources, also reopen the project in
> the Godot editor once so it rebuilds `.godot/uid_cache.bin` and reimports moved
> assets (this clears `invalid UID … using text path instead` warnings).

## Useful links

- [Main website](https://godotengine.org)
- [Source code](https://github.com/godotengine/godot)
- [Documentation](http://docs.godotengine.org)
- [Community hub](https://godotengine.org/community)
- [Other demos](https://github.com/godotengine/godot-demo-projects)

## License

See [LICENSE.md](LICENSE.md) for details.

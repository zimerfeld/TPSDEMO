---
tipo: procedimento
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-23
---

# 🔌 Godot MCP (Claude Code)

> **Goal:** connect Claude Code to the **live Godot editor** through MCP — run the game, read the
> console and inspect scenes straight from the prompt — and record the **headless** commands used to
> reimport assets and validate code without opening the editor.

## ⚡ TL;DR

MCP comes from the THIRD-PARTY addon **`addons/godot_ai/`** ([hi-godot/godot-ai](https://github.com/hi-godot/godot-ai)),
already in the repository. Enable it under **Project → Project Settings → Plugins → Godot AI**, then
pick your client in the **Godot AI** dock and press **Configure**. The plugin starts the server itself
(WebSocket).

## ⚙️ Step by step (enabling)

1. **Requirements:** Godot 4.3+ (this project uses **4.6.2**), the Python installer
   [`uv`](https://docs.astral.sh/uv/) and an MCP client (Claude Code).
   - Install `uv` on Windows: `powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"`
2. The addon already lives in `addons/godot_ai/` — if missing, copy it into the project's `addons/` folder.
3. Enable the plugin: **Project → Project Settings → Plugins → Godot AI**.
4. In the **Godot AI** dock, select the MCP client and press **Configure**. No manual setup needed.
5. Check: Claude now exposes `godot` tools (run project, stop, read console, version…).

## 🧰 What MCP can do

| Tool | Use |
|---|---|
| `run_project` | runs the game (optionally a specific scene) |
| `stop_project` | stops execution |
| `get_debug_output` | reads console output and runtime **errors** |
| `launch_editor` · `get_godot_version` · `get_project_info` | open editor / inspect project |

## 🖥️ Headless (no editor) — the most used commands

Executable sits in a same-named folder: `C:\GODOT\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe`

- **Reimport assets** (after swapping a `.glb`) — this is the RIGHT way, see [[🗿 biblioteca-de-modelos (EN)]]:
  `--headless --path C:\GODOT\ZIMARO --import`
- **Validate code / measure performance** with a throwaway `res://_test_x.gd` (`extends SceneTree`):
  `--headless --path C:\GODOT\ZIMARO --script res://_test_x.gd`
  Delete the script afterwards (cleanup rule).

## 📏 Rules it honours

- **Close the running game and the Godot editor** before touching code (project rule; hooks live in
  `.claude/settings.json`). See [[💻 Rodar no Editor (Dev) (EN)]].
- **Never commit/publish** — leave it for the user to review.

## 🛟 Troubleshooting

- **`No active Godot process`** when stopping/reading the console: nothing is running — call
  `run_project` first.
- **ESC no longer leaves the screen (Models/other):** the scene was opened **in isolation**
  (`run_project` with `scene:`). Screen switching goes through the `replace_main_scene` signal, and
  only **`main.tscn`** listens to it ([[🧭 main-gd (EN)]]) — run the project **without** naming a
  scene and navigate via the menu.
- **Bloated `.import` / missing texture** after reimporting: that was the **editor** reimporting.
  Always use `--headless --import`, and never kill Godot mid-import — see
  [[🗿 biblioteca-de-modelos (EN)]].
- **False negative in headless tests:** `set_bone_pose_rotation` does **not** change
  `get_bone_global_pose` without a real frame (`Skeleton3D` won't recompute) — validate pose/animation
  with the game running, not headless.

## 🔗 Links
- [[💻 Rodar no Editor (Dev) (EN)]] — run/develop through the editor
- [[🚀 Build Windows (Prod) (EN)]] — build the production `.exe`
- [[🏠 Home (EN)]] · [[📌 Backlog (EN)]]

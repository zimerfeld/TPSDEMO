---
tipo: procedimento
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 🚀 Build Windows (Prod)

> **Goal:** generate ZIMARO's "production" build — a self-contained Windows `.exe`
> (**embedded PCK**) + a Desktop shortcut, via the `build_windows.ps1` script at the project root.
> Run it at the end of every task that changes code/assets.

## ⚡ TL;DR — the single command

```powershell
pwsh -File build_windows.ps1
```

> `-Force` always builds (skips the "no changes" shortcut): `pwsh -File build_windows.ps1 -Force`.

## ⚙️ What the script does (in order)

1. **Exports** `build/windows/ZIMARO.exe` (release, **embedded PCK** → single file of ~589 MB)
   via the Godot 4.6.2 headless CLI (`godot --headless --export-release "Windows Desktop"`), using
   the preset in `export_presets.cfg` (preset `Windows Desktop`, `binary_format/embed_pck=true`,
   `x86_64` architecture).
2. **Icon** `build/icon.ico` — generated only the 1st time: rasterizes `res://icon.svg` via a
   temporary headless Godot tool script (`Texture2D.get_image().save_png`) and converts it to a
   multi-size `.ico` with Python 3 + Pillow. It is then reused (delete the file to regenerate).
3. **Shortcut** `ZIMARO.lnk` on the Desktop (via `WScript.Shell`), pointing to the `.exe`, with
   `IconLocation = build/icon.ico`.

## 🛟 Notes, rules and troubleshooting

- **Prerequisites:** Godot 4.6.2 at `C:\GODOT\Godot_v4.6.2-stable_win64.exe\…` + the 4.6.2 export
  templates installed. The `.ico` (1st generation) needs Python 3 with Pillow.
- ⚠️ **Export cache with a STALE scene (2026-07-03):** the export reuses converted scenes from the
  `.godot/exported/` cache, which **does not invalidate when a `.tscn` changes** — the exe shipped
  with the OUTDATED scene even with `-Force` (the rebuilt `levels` screen showing the old layout).
  **Definitive fix in the script itself:** `build_windows.ps1` now deletes `.godot/exported/`
  **before every export** (cost: re-converting the scenes, seconds). Residual symptom during
  investigations: ALWAYS validate the visual change in the build. Also watch out for
  **rewrite races** (formatting hook/external editor with the file open) — if the exe comes out
  "one edit behind", compare the `LastWriteTime` of the sources × exe before suspecting the code.
- The **icon is NOT embedded in the .exe** (that would require `rcedit`, an external binary not
  installed) — it lives only on the shortcut. Installing/configuring `rcedit` in the editor would
  allow embedding it into the executable itself.
- **Auto-closes an open instance before exporting (2026-06-21):** `Stop-RunningZimaro` kills any
  process whose **path** == `build/windows/ZIMARO.exe` (not just by name) and deletes an orphan
  `.tmp`, right before the export — otherwise the open window locks the file and Godot fails with
  *"Failed to rename temporary file … ZIMARO.tmp"*. It runs **only when it will actually build**
  (after the "no changes" skip), so it does not close the game on turns without source changes.
- **Boot splash without the Godot logo (2026-06-21):** `project.godot` → `[application]`
  `boot_splash/show_image=false` (removes the image/logo), `boot_splash/bg_color=Color(0,0,0,1)`
  (black background) and `boot_splash/minimum_display_time=0`. The window opens dark until the
  menu — no engine watermark. (In the Windows export the splash does NOT fully disappear; this is
  the most "masked" possible without a custom build.)
- `build/` and `export_presets.cfg` are **ignored by git** (see `.gitignore`); they stay local.
- **Skip if nothing changed:** without `-Force`, the script compares the `.exe` date with the
  newest source file (ignoring `.godot/`, `build/`, `.git/`, `OBSIDIAN/`, `.md`, `.ps1`) and
  **exits immediately** if the `.exe` is already up to date. `pwsh -File build_windows.ps1 -Force`
  always builds.
- **Automated by hook (2026-06-21):** there is a **`Stop`** hook in `.claude/settings.json`
  (project-only hooks; `pwsh … build_windows.ps1`, `async`, `timeout 180`) — it runs at the end of
  **every** Claude Code turn, but thanks to the skip-if-nothing-changed it only actually exports
  when some source changed. View/edit: the `.claude/settings.json` file itself, or `/hooks` in an
  interactive `claude` terminal. See the `build-exe-at-end-of-tasks` memory.
- **`UserPromptSubmit` hook that closes ZIMARO (2026-06-21):** also in `.claude/settings.json`, it
  runs on **every chat prompt** (before Claude processes the request) the PowerShell command
  `Get-Process ZIMARO -ErrorAction SilentlyContinue | Stop-Process -Force …; exit 0` — it closes
  any open instance of the game to release file locks before work/build. The `exit 0` prevents the
  hook from reporting an error when nothing is running. Redundant (on purpose) with the build's
  `Stop-RunningZimaro`, which covers the export instant.

## 🔗 Links
- [[💻 Rodar no Editor (Dev) (EN)|Run in the Editor (Dev)]] — run/develop locally before building
- [[🧱 recursos-nativos-godot (EN)|recursos-nativos-godot]] · [[🎬 fluxo-de-cenas (EN)|scene flow]]
- [[🏠 Home (EN)|Home]] · [[📌 Backlog (EN)|Backlog]]

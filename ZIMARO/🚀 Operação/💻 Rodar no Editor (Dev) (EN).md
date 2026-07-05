---
tipo: procedimento
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 💻 Run in the Editor (Dev)

> **Goal:** run and develop ZIMARO locally through the Godot editor — including the
> loopback multiplayer test with 2 instances on the same PC (no real network).

## ⚡ TL;DR

Open the project `C:\GODOT\ZIMARO` in **Godot 4.6.2**
(`C:\GODOT\Godot_v4.6.2-stable_win64.exe\…`) and **run the project** (F5). The main scene is
`main` ([[🧭 main-gd (EN)|main-gd]], the router), which opens the **menu** — see
[[🎬 fluxo-de-cenas (EN)|scene flow]].

## ⚙️ Step by step

1. **Close** any running instance of the game **and** the Godot editor before touching the code
   (project rule — see `CLAUDE.md`; there are hooks in `.claude/settings.json` that automatically
   close `ZIMARO.exe` on every prompt).
2. Open the project in the Godot 4.6.2 editor and run (F5). Navigation: menu → chooseplayer →
   levels → level_1/level_2 · settings · developer → models ([[🎬 fluxo-de-cenas (EN)|scene flow]]).
3. **Loopback multiplayer (2 instances on the SAME PC)** — full protocol in
   [[🧪 teste-salas-multiplayer (EN)|teste-salas-multiplayer]] (Test A, ✅ field-validated 2026-07-02):
   - Open **two** game windows (the `.exe` from `build/windows/ZIMARO.exe` or **two runs from the
     editor**). Window 1 = HOST, Window 2 = CLIENT.
   - **[HOST]** Menu → **Play Online** → Port `4383` → **"Manage Rooms"** → pick a Level →
     **"Start Room"**.
   - **[CLIENT]** Menu → **Play Online** → IP `127.0.0.1`, Port `4383` → **"Join Rooms"** →
     **Play**.
   - If it fails: run **from the editor** to see the console (`push_error`/RPC).
4. Windowless validation (used in sessions): **headless** Godot runs the game for ~300 frames to
   hunt script/runtime errors — the `ObjectDB leaked` / `resources still in use` warnings on forced
   shutdown (`--quit-after`) are benign.

## 📏 Rules it respects

- **Never commit/publish** — leave it for the user to review (GitFlow; active branch in
  [[📌 Backlog (EN)|Backlog]]).
- At the end of a task with user impact: update READMEs + vault and run the production build
  ([[🚀 Build Windows (Prod) (EN)|Build Windows (Prod)]]); zero errors/warnings.

## 🛟 Troubleshooting

- **Locked file / "Failed to rename temporary file":** some game instance was left open — close
  `ZIMARO.exe` (the project's hooks do this automatically).
- **Gray screen on the client when joining a room:** template/scene-cache — see
  [[🚪 salas (EN)|salas]] ("rooms are born clean"); more symptoms in the table of
  [[🧪 teste-salas-multiplayer (EN)|teste-salas-multiplayer]].

## 🔗 Links
- [[🚀 Build Windows (Prod) (EN)|Build Windows (Prod)]] — generate the production `.exe`
- [[🧪 teste-salas-multiplayer (EN)|teste-salas-multiplayer]] · [[🚪 salas (EN)|salas]] · [[🌐 multiplayer (EN)|multiplayer]] · [[🎬 fluxo-de-cenas (EN)|scene flow]]
- [[🏠 Home (EN)|Home]] · [[📌 Backlog (EN)|Backlog]]

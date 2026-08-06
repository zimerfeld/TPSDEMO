---
tipo: procedimento
projeto: ZIMARO
lang: en-US
atualizado: 2026-08-06
---

# 🪟 Two Windows Side by Side (Dev)

> **Goal:** test loopback multiplayer with **a single command** — two ZIMARO instances opened side
> by side (half the screen each), one hosting a room and the other joining it on its own, with no
> clicking. Replaces the manual walkthrough in
> [[💻 Rodar no Editor (Dev) (EN)|💻 Run in the Editor (Dev)]] (step 3).

## ⚡ TL;DR

```powershell
pwsh -File scripts/dual-window.ps1
```

**Left** window = server (hosts a room on Level 1). **Right** window = client (waits for the server
to come up, joins the room and spawns straight into gameplay). `ESC` in the client window leaves
the room and releases the mouse.

## ⚙️ How it works

Two pieces:

1. **`scripts/dual-window.ps1`** — detects the monitor's **working area** (width/height minus the
   taskbar), splits it in half and launches both instances with each role's arguments. Before
   launching it kills previous instances of the same executable (otherwise the port stays busy).
   It uses `build/windows/ZIMARO.exe` when present; otherwise (or with `-Editor`) it runs the
   project through the Godot binary with `--path`.
2. **`autoload/autopilot.gd`** (autoload `Autopilot`) — reads the command line's **user arguments**
   (everything after `--`) and drives the in-game flow. Without those arguments the autoload stays
   inert and the game runs exactly as before.

### Accepted arguments (after `--`)

| Argument | Effect |
| --- | --- |
| `autohost` | hosts the room server and creates the initial room |
| `autojoin` | connects as a client and joins the first running room |
| `port=<n>` | server port (default `4383`) |
| `address=<host>` | server IP/domain, `autojoin` only (default `127.0.0.1`) |
| `level=<1\|2\|res://…>` | level of the room created by `autohost` (default `1`) |
| `template=<id\|name>` | character template activated in the room; matches the **exact id** or a chunk of the **name** (accent/case-insensitive — `aerea` finds "Caça aérea"). `none` clears it; empty keeps whatever is active |
| `delay=<sec>` | wait before the 1st connection attempt (default `6`) |
| `retries=<n>` | extra attempts, every 2 s (default `15`) |
| `player=<name>` | player name for this instance (**not** persisted to Settings) |
| `win=<x,y,w,h>` | positions/sizes the window in screen pixels |

What the script actually runs:

```
ZIMARO.exe -- autohost port=4383 level=1 win=0,0,960,1032 player=HOST
ZIMARO.exe -- autojoin port=4383 address=127.0.0.1 delay=6 win=960,0,960,1032 player=CLIENTE
```

### Script parameters

`-Port` · `-Address` · `-Level` · `-Template` · `-Delay` · `-Retries` · `-Monitor <index>` (0-based) ·
`-Exe <path>` · `-Editor` (force running through the Godot binary) · `-NoKill` (don't kill previous
instances) · `-Preview <sec>` (review pause before launching, default `6`; `0` launches straight
away).

### Testing the ally bot (escort)

```powershell
pwsh -File scripts/dual-window.ps1 -Level 2 -Template aerea
```

Level 2 ships the default template **"Level 2 - Caça aérea"** (2 hostile creatures + **1 ally bot**).
With `-Template`, the autopilot activates the template **before** `start_room` (that's what applies
the characters) — you can watch the ally's [[🎮 player (EN)|guard stance]] straight from the host
grid (**Observe**) or by joining the room. Only the **host** gets `template=`: it's the one creating
the room.

### Review pause

Before launching, the script prints a block with **every parameter in use** — monitor and working
area, executable, port/address, level, client wait, each window's geometry and the **two full
command lines** — then counts down `-Preview` seconds (`Ctrl+C` cancels). That's the window of time
to check everything before the game takes over the screen.

## 🔌 In-game hook points

| File | What it does under autopilot |
| --- | --- |
| `scenes2D/main/main.gd` | applies the `win=` geometry right at boot |
| `scenes2D/menu/menu.gd` | reapplies the geometry and jumps straight to **playonline** |
| `scenes2D/playonline/playonline.gd` | fills port/address/name and hosts **or** connects (honouring `delay=`); a failed connection **retries silently** while attempts remain |
| `scenes2D/host_session/host_session.gd` | creates the initial room (once, and only if there are no rooms) |
| `scenes2D/client_session/client_session.gd` | joins the **first** room as soon as it shows up in the list (once) |
| `scenes2D/chooseplayer/chooseplayer.gd` | confirms the default character and moves on |
| `scenes3D/level_1/level_1.gd` · `level_2.gd` | reassert the geometry after `apply_graphics_settings` (which re-imposes the saved `display_mode`) — without it the **level** window went back to fullscreen and broke the side-by-side layout |

## 🛟 Troubleshooting

- **Both windows come up fullscreen, overlapping:** Settings starts in **exclusive fullscreen** and
  leaving that mode **doesn't settle on the same frame** — that's why `Autopilot` reasserts the
  geometry for ~30 frames (`REASSERT_FRAMES`) after every call. If it happens again, raise it.
- **Windows smaller than half the screen (125%/150% display scaling):** the script calls
  `SetProcessDPIAware()` before reading the working area. Without it Windows returns virtual
  coordinates.
- **Client never joins:** raise `-Delay` (the server pays the startup preload + room creation
  before accepting connections). The client already retries 15× every 2 s by default.
- **"Port in use" on the server:** a leftover instance from a previous run — run without `-NoKill`
  (the default) or kill `ZIMARO.exe` by hand.
- **Version handshake rejected:** both windows run the same build, so this only shows up when
  pointing `-Address` at another PC — see [[🛰️ hospedagem-online (EN)|🛰️ online-hosting]].

## 📏 Rules it honours

- **Never commit/publish** — leave it for the user to review (GitFlow).
- **Development** tool: without the command-line arguments the game is identical to production (no
  new code path runs).

## 🔗 Links
- [[💻 Rodar no Editor (Dev) (EN)|💻 Run in the Editor (Dev)]] — the equivalent manual walkthrough
- [[🧪 teste-salas-multiplayer (EN)|🧪 multiplayer-rooms-test]] · [[🚪 salas (EN)|🚪 rooms]] · [[🌐 multiplayer (EN)|🌐 multiplayer]]
- [[🛰️ hospedagem-online (EN)|🛰️ online-hosting]] · [[🚀 Build Windows (Prod) (EN)|🚀 Build Windows (Prod)]]
- [[🏠 Home (EN)|🏠 Home]] · [[📌 Backlog (EN)|📌 Backlog]]

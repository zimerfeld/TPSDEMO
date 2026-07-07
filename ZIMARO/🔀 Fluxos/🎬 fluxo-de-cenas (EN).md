---
tipo: fluxo
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-07
---

# 🎬 Scene Flow

`main.tscn` (Node, `main.gd`) is a **router** AND the **start screen**: it instantiates
each screen as a child of itself (it doesn't use `SceneTree.change_scene`), reacting to the
signals `replace_main_scene` and `quit`. Because of this, `get_tree().current_scene` stays
`main` throughout the whole game.

The opening lives in the `StartScreen` sub-tree (child of the root, already assembled in
`main.tscn`): a 3D robot (`player.glb`) on a **pedestal** as the background + a 2D overlay
(title/reading/status). After `minimum_wait_time` (~2 s) `main.gd` fades and swaps
`StartScreen` for the menu. There is no more `StartScreens/StartScreen.tscn` (removed).
`StartScreen` enters the `no_debug_overlay` group (no debug tooltips).

```
main.tscn (main.gd — router + start screen: robot on pedestal + overlay)
   └─► menu.tscn (menu.gd)
          ├─► Play Offline ─► chooseplayer.tscn ─► levels.tscn ─┬─► level_1.tscn
          │     (online_mode=false)                             └─► level_2.tscn   (loads the level directly)
          ├─► Play Online ──► chooseplayer.tscn ─► levels.tscn ─► playonline.tscn ─► chosen level
          │     (online_mode=true)                 (choose level)   (Host/Connect)
          ├─► settings.tscn (UI: settings.gd)
          ├─► developer.tscn ─┬─► models.tscn   (3D model viewer)
          │                   └─► controls.tscn (2D controls viewer)
          └─► Quit → quit
```

(`Exported.tscn` / the "Exported" gallery no longer exists — the button was removed from the
models screen. `cyberpunkhud` is a standalone preview scene, outside the navigation flow.)

---

## Folders

- **scenes2D/** (screens + UI): `main` (router), `menu`, `chooseplayer`, `levels`, `settings`, `developer`, `playonline`, `controls` (2D viewer) and `controls2D/` (reusable HUD widgets: crosshair, minimap_panel, vitals_panel, pause_menu, scanlines, cyberpunk_hud, …)
- **scenes3D/** (levels + 3D tools): `level_1`, `level_2`, `models` (viewer)
- **library3D/** (3D assets by type): `characters`, `propulsores`, `structures`, `weapons`, + `geometry`/`textures` (support)
- **effects_shared/** (helpers shared between characters): `limb_colliders.gd`, `body_parts.gd`, `weapon_parts.gd` + blast/shadow assets
- **autoload/**: `crash_handler`, `player_selection`, `debug_overlay` (**Settings** lives in `scenes2D/settings/config.gd`)
- **themes/**: themes (`ui_theme.tres`, `cyberpunk.tres`) · **addons/**: plugin `godot_ai` (MCP) · **ZIMARO/**: this vault

## Autoloads

- **Settings** → `scenes2D/settings/config.gd` (config manager: `config_file`, `DEFAULTS`, `save_settings()`)
- **CrashHandler** → global **NON-DESTRUCTIVE** error popup (2026-07-02): × / ESC / the **"Back"** button only
  CLOSE the window and return the focus to the calling scene — they **no longer quit the game** (a port/connection/
  validation error is recoverable). With `retry_callback`, it also shows **"Try Again"** (re-runs the action).
  Before, the button was "Close Game" and ×/ESC did `get_tree().quit()`; this even killed the game on a
  simple Models screen validation (`models.gd`, "bone is already a Member") — fixed alongside.
- **PlayerSelection** → chosen character
- **DebugOverlay** → debug overlays (see below)
- **UINav** → `autoload/ui_nav.gd` (keyboard navigation of the 2D screens: `focus_first`, `first_focusable`, `cancel_active_edit` — see [[#Keyboard navigation and ESC]])

---

## main.gd

- Entry point (`run/main_scene`)
- `change_scene_to_packed()` removes the children and instantiates the new screen
- Connects `quit` → `go_to_main_menu()` and `replace_main_scene` → scene change (if the screen has the signal)

## Screens (UI)

- **menu** — Play (→ chooseplayer), Settings (→ settings), Developer Mode (→ developer), **Play Online** (same sequence as offline: chooseplayer → levels → playonline), Quit. **The "Play Offline" and "Play Online" buttons differ only in the `PlayerSelection.online_mode` flag** — both open `chooseplayer`; it is the `levels` screen that, seeing the flag, loads the level directly (offline) or opens `playonline` (online). The "Play Offline" label comes from localization (`menu.*.json`, key `"PLAY"`). In `_ready` (before showing the screen) it **reads from disk and applies ALL configs** (2026-06-16): `Settings.load_settings()` + `apply_graphics_settings()` + `apply_window_resolution()` (resizes the window to the saved resolution if in Windowed mode) + `apply_audio_settings()` (Music/SFX mute).
- **settings** — `config.gd` (autoload **Settings**) + `settings.gd` (UI). Tabs Display / Resolution / Antialiasing / Lighting / Effects / Audio / **Debug**. **No "Apply" button (2026-06-16):** each option **persists + applies instantly** on change (signal `ButtonGroup.pressed` → `_apply_settings`). The **video resolution** is separate: it confirms in a dialog (Yes/No) — "Yes" applies and pins Windowed mode (otherwise the next apply would revert to fullscreen and undo it), "No" returns the dropdown to the persisted selection. The window is **limited to the screen's usable area** (`screen_get_usable_rect`) and centered, so a resolution larger than the monitor (4K/8K) doesn't push the window — and the footer button bar — off the visible area (`_apply_video_resolution` / `Settings.apply_window_resolution`). A **Reset** button (to the right of Back, 2026-06-16): same Yes/No confirmation → `Settings.reset_to_defaults()` (rewrites everything with `DEFAULTS`, a common-hardware baseline) + reloads controls + applies instantly. `DEFAULTS` is the single source: it also applies when there is no saved config (load_settings fills it). Only **Back** exits the screen. **Key defaults (2026-06-23):** Display Mode = **Exclusive Fullscreen**, FPS Limit = **60**, Resolution Scale = **Balanced** (`1/1.7`), Scale Filter = **Bilinear**, Bloom = **Off**, Volumetric Fog = **Off**. **Scale Filter (2026-06-23):** options **Bilinear · AMD FSR 1.0 · AMD FSR 2.2** (MetalFX only on macOS). FSR 2.2 was **re-added** and the silent revert to Bilinear in `load_settings` **removed** — all options persist. ⚠️ FSR 2.2 may trigger "Texture dimensions exceed device maximum" with a supersampling scale (Native); with the Balanced default (downscale) it is the correct use. **TAA × temporal upscaler (2026-06-26):** `use_taa` is applied as `taa AND not Settings.is_temporal_upscaler(scaling_3d_mode)` — **FSR 2 / MetalFX Temporal** already do temporal AA and are incompatible with TAA (the engine would turn TAA off and emit a warning), so `config.gd` (`apply_graphics_settings`) and `settings.gd` guarantee exclusivity via the helper `Settings.is_temporal_upscaler()`.
- **developer** — **(redone 2026-06-23)** only **General** (FPS HUD · Health Monitor) + **Debug 2D** (single column: Debug 2D · Show TYPE · Show Name · Show ID · **Show Tab** ← new, below Show ID: white tooltip with each 2D control's Tab/focus index) + **3D Models** / **2D Controls** buttons. The **entire Debug 3D column** and the **3D preview panel** were **removed** — 3D inspection (Mesh, Skeleton Lines, members, etc.) migrated to the **Models** screen (its own toggles over the preview). The global overlay no longer applies 3D overlays in levels/chooseplayer (only Debug 2D). See [[🐞 debug-overlay (EN)\|debug-overlay]] and [[🗿 biblioteca-de-modelos (EN)\|biblioteca-de-modelos]].
- **models** — 3D model browser/extractor: Category → Model → Mesh (distinct meshes), rotatable preview, "Save as 3D scene" (extracts to `library/extracted/`) and an "Exported" button. Details in [[🗿 biblioteca-de-modelos (EN)\|biblioteca-de-modelos]]
- **Exported** (`library/extracted/Exported.tscn`) — a gallery showing all scenes from `library/extracted/` side by side; returns to models
- **chooseplayer** — choose the character (a rotating 3D model) → levels
- **levels** — Level 1 / Level 2, asynchronous load. `_select_level()` branches: **offline** loads the level directly; **online** (`PlayerSelection.online_mode`) stores the path in `PlayerSelection.level_path` and opens `playonline`. Each row has a **template** button that opens the **Template Manager** (`scenes2D/level_templates/level_template_dialog.gd`, renamed from "Level Templates" in 2026-06-29; previously a native `Window`, **now a controller over `FloatingWindow`** — it inherits the 2D theme and Debug 2D works over it). The same window is opened by the `host_session` screen. Each spawn **entry** has a **"Entry name"** field (2026-07-01) that renames the text shown in the `Entries` dropdown (ex-`EntryPicker`); empty → automatic label `"N. faction model xN"`. The name is saved per entry in `LevelTemplateManager` (key `name`).
- **playonline** — only **Host / Connect** (port + address). **There is no level selector**: the level was already chosen in the `levels` screen (online flow) and comes in `PlayerSelection.level_path`; the headless dedicated server falls back to `level_1` (`DEFAULT_ROOM_LEVEL`, which enters directly here and opens a room). **The levels are playable online** — `level_1` and `level_2` gained `MultiplayerSpawner` + `PlayerSpawnpoints` (see [[🌐 multiplayer (EN)\|multiplayer]]).

---

## Keyboard navigation and ESC

Centralized in the **UINav** autoload (`autoload/ui_nav.gd`), applied by **all** the 2D screens
(`menu`, `settings`, `levels`, `chooseplayer`, `controls`, `developer`, `playonline`,
`host_session`, `client_session`):

- **Keyboard arrows** — Godot already maps `ui_up/down/left/right` to the arrows and computes the
  focus neighbors; only the **initial focus** was missing. Each screen focuses the 1st focusable control in
  `_ready` (deferred). `UINav.focus_first(self)` (1st in tree order) and `UINav.focus_tab_one(self)`
  (head of the ring, via `tab_one_control`) are equivalent for screens (with no `last` moved).
- **Focus on Tab = 1 when opening (2026-06-29)** — **every UI and window** starts with the **Tab = 1
  control** focused: screens call `UINav.focus_tab_one(self)`; the `FloatingWindow` focuses in `_grab_initial_focus`
  the `UINav.tab_one_control(self, _close_button)` (1st of the content/footer, NEVER the ×, which is last).
  `tab_one_control(root, last)` = head of the ring = `collect_focusables(root)` minus `last`, 1st item.
- **`menu` Tab order (2026-06-29)** — the desired sequence
  **Play (1) → PlayOnline (2) → Settings (3) → Developer (4) → Quit (5) → Portuguese (6) → English (7)
  → Debug 2D (8)** is the tree **order itself** (the 5 buttons of `MenuColumn`, then the `Actions` bar's `LangBar`
  and finally the **`Debug2D` toggle** the DebugOverlay injects at the END of `Actions`). Now
  `menu.gd` **wires the ring** with `UINav.wire_tab_ring(self)` (helper `_wire_tab_order`) in `_ready`
  (deferred), like `levels` and the sessions — closing `1 → … → 8 → 1` with increments of 1.
  There is **no** `focus_next`/`focus_previous` in the `.tscn` (a previous attempt to hardcode the ring on the 5
  buttons EXCLUDED language/Debug2D — it was reverted); the ring is built at runtime to include the injected
  `Debug2D` and respect the active language (which stays disabled/out of the ring). It **re-wires** when the
  DebugOverlay injects the toggle into `Actions` (signal `child_entered_tree`) and when a language button
  enables/disables (`_update_language_buttons`). Initial focus on Tab = 1 via `UINav.focus_tab_one`.
- **Navigation helpers `UINav` — see [[🔁 navegacao-tab (EN)\|navegacao-tab]]** — a dedicated note with the table of
  each helper (`wire_tab_ring`, `focus_tab_one`, `tab_one_control`, `focus_first`, `first_focusable`,
  `collect_focusables`, `cancel_active_edit`), the **scene×helper matrix**, the explanation of the Debug 2D
  `TAB: -` and the list of other project helpers (FloatingDialog/FloatingWindow/Locale/CrashHandler).
- **Shared Tab ring — `UINav.wire_tab_ring(root, last=null)` (2026-06-29)** — a single helper
  that collects **all** the focusable controls under `root` in **tree order** (= reading order: each
  control from top to bottom and, within a row/HBox, left to right) via `collect_focusables` and
  wires `focus_next`/`focus_previous` into a **closed ring** `1 → 2 → … → N → 1`. Guarantees **Tab indices
  incrementing by 1** (the "Tab" line of [[🐞 debug-overlay (EN)\|debug-overlay]]). The **`last`** parameter (optional):
  if given, that control goes to the **END of the ring** (highest index) — used by the floating windows' ×.
  Re-appliable when the focusable set changes (injected toggle, an enabling/disabling button).
- **Focus contained in floating windows — × LAST (2026-06-29)** — `FloatingWindow.wire_focus_ring()`
  (public) delegates to `UINav.wire_tab_ring(self, _close_button)`: the ring is `content → footer → ×
  (Close) → 1st`, with the **× always LAST** (highest Tab value of the window), even though the × comes EARLIER in
  the tree. Assembled on `popup_centered` (footer already created); the owner re-wires via `_win.wire_focus_ring()` when
  enabling/disabling fields. Includes **any focusable control** of the content (OptionButton/LineEdit/
  SpinBox), not just the footer. Without the ring, Tab **leaked to the background UI** and the **× was never reached**.
  For the Debug 2D **numbering** to reflect this, `DebugOverlay._tab_chain_start` starts counting **after
  the ×** when a floating window is open (the background is suppressed), so the × gets the **highest** `TAB: n`.
  Applies to every `FloatingDialog` (e.g. "Quit Zimaro ?") and to the **Template Manager** /
  **Music Manager** windows. The footer buttons have a **name by role** (before `@Button@…`):
  `confirm` → **`Yes`/`No`**, `alert` → **`Ok`** (the TEXT stays translated; only the node was named).
- **`levels` Tab order (2026-06-29)** — the screen wires the ring with `UINav.wire_tab_ring(self)` in
  `_ready` (deferred): **Level 1 (1) → Template 1 (2) → Level 2 (3) → Template 2 (4) → Back (5) →
  Portuguese (6) → English (7) → Debug 2D (8)**, reading order. *(The **Level Base** row was
  removed on 2026-07-01 along with the level — see [[🚪 salas (EN)\|salas]].)*
  It re-wires when the DebugOverlay **injects the `Debug2D` toggle** into `Actions` (signal `child_entered_tree`)
  and when a language button **enables/disables** (the active language stays out of the ring).
- **`playonline` Tab order (2026-06-29)** — the screen wires the ring with `UINav.wire_tab_ring(self)`
  (helper `_wire_tab_order`) in `_ready` (deferred), reading order: **Player name (1) → Port/spin (2)
  → Port history (3) → IP/Domain (4) → IP history (5) → optimization: Host render (6),
  Sync rate (7), Smoothing↔Response (8) → Manage Rooms (9) → Join Rooms (10) → Back (11)
  → Portuguese (12) → English (13) → Debug 2D (14)**. The 3 optimization columns are created in
  `_build_optimization_options` BEFORE wiring the ring, so they already enter the sequence. It re-wires when the
  DebugOverlay **injects the `Debug2D` toggle** into `Actions` (signal `child_entered_tree`) and when a language button
  **enables/disables** (`_update_language_buttons`). Initial focus on Tab = 1 via
  `UINav.focus_tab_one`. (Before, the screen only did `manage_rooms_button.grab_focus()`, with no explicit ring.)
- **Tab + Debug 2D in `host_session` / `client_session` (2026-06-29; static in 2026-06-30)** — before
  they were screens assembled ENTIRELY in code. **Now the fixed scaffold is STATIC in the `.tscn`** (panel with
  texture/veil/`SignalLayer` shader, title, `StartRow` with the pickers on the host, list, **`Actions`** bar +
  **`Back`** — renamed from `BackButton` in the 2026-07-03 name sweep, along with
  `ManageTemplates`/`Start`/`Levels`/`Templates`); the code only populates the pickers, assembles the
  dynamic **room rows** (`_refresh_rooms`)
  and adjusts the shader's `aspect`. The DebugOverlay injects the `Debug2D` into `Actions`. The **`tab_order` is numbered
  by CODE** in `_rewire_tab` (it can't be fixed in the `.tscn` because the number of rooms varies): the grid's controls
  → each room row's enabled buttons (disabled ones stay out) → **Back** → **Debug 2D**; initial
  focus on Tab = 1. `collect_focusables` ignores `is_queued_for_deletion()` (just-freed rows).
- **Tab ring on the remaining screens — `chooseplayer` / `settings` / `developer` / `controls` (2026-06-29)**
  — the four screens that still used only `UINav.focus_first` moved to the standard `focus_tab_one` +
  `_wire_tab_order` (→ `UINav.wire_tab_ring(self)`), re-wiring on the `Actions`' `child_entered_tree`
  (Debug 2D toggle) and on `_update_language_buttons`. Extra cases: **`settings`** re-wires on
  `TabContainer.tab_changed` (only the VISIBLE tab's focusables enter the ring); **`developer`** re-wires on
  `_update_subrows_enabled` (the Debug 2D sub-toggles enter/leave the ring with the master). With this,
  **all full screens** wire the ring — it becomes a project rule (`CLAUDE.md`). Only the `pause_menu`
  overlay remains (optional). Details/matrix in [[🔁 navegacao-tab (EN)\|navegacao-tab]].
- **ESC rule** (action `quit`, mapped to Esc + the gamepad's Select) — it always **first interrupts the
  filling of a field/selection** before going back a screen. In each screen's `_input`:
  `if UINav.cancel_active_edit(get_viewport(), <fallback>): consume and RETURN`. `cancel_active_edit`
  ends the edit if the focus is a `LineEdit` (including a `SpinBox`'s internal editor — e.g. the IP/port
  of `playonline`), returning the focus to the `fallback`. **Only the 2nd ESC** (with no field being edited) navigates
  back. An `OptionButton`'s dropdown already closes on ESC natively (its own popup).
- **Quit confirmation in the menu** — `menu._on_quit_pressed` (the Quit button **and** ESC) opens a
  central `FloatingDialog.confirm` window **"Quit Zimaro ?"** (Yes/No); it only closes the game on "Yes". The
  strings are in `menu.*.json` (`"Deseja sair do Zimaro ?"`, `"Sair do jogo"`); Yes/No reuse the
  global `Locale` table (from `settings.*.json`).
- **Leave the match (ESC in a level, 2026-07-07)** — centralized in the `LevelExit` helper
  (`scenes3D/level_exit.gd`), called from `level_1`/`level_2`'s `_input` on the `quit` action.
  **Offline** (`PlayerSelection.online_mode == false`): opens a `FloatingDialog.confirm`
  **"Leave the match?"** (Yes/No) and **pauses the match** (`get_tree().paused = true`; the dialog gets
  `process_mode = ALWAYS` so it keeps responding while paused). **Yes** → unpause and emit
  `replace_main_scene(levels.tscn)` (back to the levels screen); **No / × / ESC** → unpause, recapture
  the mouse and **resume the match** where it left off. **Online** (host/client rooms): keeps the old
  behavior — ESC releases the mouse and emits `quit` (→ main menu). The strings
  (`"Abandonar a partida"`, `"Abandonar a partida ?"`) live in `levels.*.json`; Yes/No reuse the global
  `Locale` table.

---

## Signals Between Scenes

| Signal | Emitted by | Received by |
|---|---|---|
| `replace_main_scene(scene)` | menu, settings, chooseplayer, developer, models, Exported, levels, **level_1/level_2 (offline: Leave → levels)** | `main.gd` → scene change |
| `quit` | chooseplayer, developer, **level_1/level_2 (online: ESC → menu)** | `main.gd` → `go_to_main_menu()` |

---

## Related

- [[🧭 main-gd (EN)\|main-gd]]
- [[🌐 multiplayer (EN)\|multiplayer]]
- [[📄 formatacao (EN)\|formatacao]]

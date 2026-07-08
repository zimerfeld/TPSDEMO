---
tipo: backlog
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-07
---

# 🗂️ Prioritized Backlog — ZIMARO

> **Resumption point between sessions.** This note is self-sufficient: read it at the start of a
> new conversation to know **what is in progress, what is missing and in which order to attack**.
> Linked to [[🏠 Home (EN)|Home]]. Each item points to the system note where the detailed context lives.
>
> **Status convention:** 🟡 in progress · 🔴 not started · 🟢 done (awaiting validation) · ⚪ optional
>
> **Rules that apply when resuming (see `CLAUDE.md` / `REGRAS.md`):** never commit/publish — leave it
> for the user to review; close the game and the Godot editor before touching the code; at the end of a
> task with user impact, update the READMEs (`.md`/`.en-US`/`.pt-BR`) **and** this vault; run
> `build_windows.ps1` at the end; eliminate errors/warnings after compiling.

**Last review:** 2026-07-07 · **Active branch:** `feature/fable`

---

## 🟢 PT controls collision + release `.exe` update — SHIPPED (2026-07-07)

Three fronts in one session, all done:

1. **Controls ("Quick reference") collision fix in PT.** The landing page
   (`index.html`, **zimaro.zimerfeld.com** via GitHub Pages) forced the pills container to
   `display:block` in PT (`html[data-lang="pt"] .block.lang-pt{display:block}`), making the
   `.pill`s **inline** — and inline vertical padding overlapped the backgrounds between
   lines. **1-line CSS fix:** `html[data-lang="pt"] .pills.lang-pt.block{display:flex}`
   restores flex/wrap in PT only. Shipped as a hotfix straight to `main` (commit `4d79896`);
   Pages redeployed live. (ZIMMY's identical template had the same bug — fixed there too.)
2. **Release `.exe` updated.** The `ZIMARO.exe` asset of release **`202606251203`** was
   replaced (`gh release upload … --clobber`): **587 MB → 166 MB** (new build), and the
   release was **published** (`--draft=false`) — it had been a draft, invisible to the public.
3. **Git hygiene.** Removed the `com exe` commit from history (174 MB exe, which GitHub
   rejects for being >100 MB); `build/windows/*.exe` is now in `.gitignore`; clean recommit
   with icons + `.gitignore` only (`8fec39b`, pushed to `develop`).
4. **New release with today's tag + clean title.** Created release **`202607072141`**
   (`gh release create … --title "202607072141"`), now **Latest**: title = tag only (no
   "ZIMARO v0.1.0"), EN/PT notes reused without the version heading, `ZIMARO.exe` (166 MB)
   attached. The old `202606251203` was **kept** by choice.

**Procedure documented in the vault:** [[📦 Atualizar Asset da Release (GitHub) (EN)|Update the Release Asset (GitHub)]]
(PT/EN) under 🚀 Operação — how to swap/publish the binary with `gh` (bypassing git), and how
to create a **new release with a new tag** (title = tag only).

---

## 🟢 Landing page — PT title/subtitle line break — SHIPPED (2026-07-07)

The landing page (`index.html`, served at **zimaro.zimerfeld.com** via GitHub Pages) shares an i18n
template with the rule `html[data-lang="pt"] .lang-pt{display:inline}`, which forced **every** Portuguese
element to `inline` — including `h2`/`h3` — making the title/subtitle collapse into the following text when
the site opens in PT (EN was fine, since `h2`/`h3` are `block` by default). **1-line CSS fix:**
`html[data-lang="pt"] h2.lang-pt,html[data-lang="pt"] h3.lang-pt{display:block}` — restores the break only
on PT titles/subtitles, with no effect on EN. Shipped via GitFlow (release `develop`→`main`; the fix was
already on `develop` from an earlier session — only the promotion to production was missing) + tag
**`202607071915pt-heading-break`**; `CNAME` preserved; GitHub Pages deploy verified live.

> [!note] Unlike the game-code items below
> This is an isolated **page-content** tweak and was **already published** (with the user's authorization) —
> unlike the P0.x code items, which follow the "do not commit" rule and await review.

---

## 🟢 P0.5 — Template Manager working in the .exe — READY for review (2026-07-03)

End-to-end playtest on the **exported .exe** (menu → chooseplayer → levels → Template Manager →
"Arena Fable" template (Red Robot ×3 enemy) → solo match on Level 1 with spawn, combat, death and
respawn at ~60 FPS). **3 bugs found and fixed** (details in
[[🧩 templates-de-level (EN)|templates-de-level]]):

1. **Model dropdown empty in the build** — the `DirAccess` scan did not resolve the export's
   `*.tscn.remap` files (`level_template_manager.gd`, `_logical_name` helper same as the Models screen's).
2. **"Save and Use In This Level" did not activate a new template** (the generated id did not come back
   to the dialog; a repeated Save duplicated it) — `level_template_dialog.gd` now keeps the id from `upsert_template`.
3. **The template name got lost** when Adding/Removing an Entry — `text_changed` now writes it directly.

READMEs (3) + vault updated; `build_windows.ps1` run (531 MB, no errors). **Awaits the user's
commit/publish.** Suggested polish (not done): filter support scenes (bullet/impact_effect) out of the
Model dropdown; automatic suffix for repeated template names.

---

## 🟢 P0.6 — Visual environment of the levels (sky + fog + neon grid) — READY for review (2026-07-03)

Item 1 of the performance/attractiveness plan, **approved by the user and implemented**: procedural
sky with per-level identity (**Level 1 cyan / Level 2 amber**), exponential distance fog and an
**emissive neon grid floor** (shared shader `themes/level_grid_floor.gdshader`, pure math — no
textures/passes). The project's performance goal was registered in `CLAUDE.md` (min. 60 FPS on
minimal graphics hardware) and **validated on the `.exe`: 60 FPS on both levels, including in
combat**. Details: [[🌌 ambiente-dos-levels (EN)|ambiente-dos-levels]]. READMEs (3) updated. The exe
dropped from 531→174 MB because the user moved unused files on purpose (confirmed). **Awaits commit.**

---

## 🟢 P0 — Close the ongoing restructuring (`feature/restrutu`) — READY for review (2026-07-01)

**Status:** work finished and validated; **awaits the user's commit/publish** (rule: do not commit).
Done in this session: hunted orphan references to `level_base` (none in the code); removed the
**orphan localization keys** `"Level Base"` in `scenes2D/levels/Resources/levels.{en,pt}.json`;
confirmed the complete removal of the **Prefix filter** in `models.gd` (no leftovers); headless
validation on Godot 4.6.2 → the **editor imports clean** (autoloads compile without errors) and the
**game runs 300 frames with no script/runtime error** (only the benign `ObjectDB leaked` /
`resources still in use` warnings from `--quit-after`, normal in forced shutdown); the READMEs
(`.md`/`.en-US`/`.pt-BR`) already reflect `structures` + the **CORPO** fallback member and the removal
of `level_base.ogg`; vault synced ([[🏠 Home (EN)|Home]], [[🎬 fluxo-de-cenas (EN)|fluxo-de-cenas]]
Tab order of the `levels` screen, [[🚪 salas (EN)|salas]] historical note,
[[📄 formatacao (EN)|formatacao]]). **Only missing:** running `build_windows.ps1` (done at the end of
the session) and the **publish by the user**.

<details><summary>Original context of the restructuring (reference)</summary>

Restructuring branch with many changes not yet committed. Brought to a consistent, testable and
reviewable state.

- **Vault moved and renamed** `OBSIDIAN/CLAUDE/` → `OBSIDIAN/` → `ZIMARO/` (renamed to the project name; the vault root is now `C:\GODOT\ZIMARO\ZIMARO`,
  index in `000-INDEX.md`). The files show up as `D` (old path) + `??` (new path) in git.
- **Level template system** under construction: `scenes2D/level_templates/level_template_dialog.gd`,
  `library3D/structures/` (new, untracked), plus `scenes3D/models/`, `levels`, `net_spawn`,
  `player_selection`, `host_session`, `stability_guard`, `music_manager`. Relates to the memories
  *"rooms are born clean"* (nothing pre-spawned; enemies only via template) and *"fallback CORPO member"*.
- **Audio:** `audios/level_base.ogg` removed (+ `.import`); check that `MusicManager`/per-scene
  assignments no longer reference that file. See [[🔊 audio (EN)|audio]].

**Closure:** run the game and confirm it opens without errors (menu → level → models → rooms); zero
errors/warnings; update the 3 READMEs + affected vault notes; `build_windows.ps1`; **leave it for the
user to commit/publish** (do not commit). Systems: [[🚪 salas (EN)|salas]],
[[🗿 biblioteca-de-modelos (EN)|biblioteca-de-modelos]].

</details>

---

## 🟢 P0.7 — Folder cascade + Scenery Manager + reorganization repair (2026-07-03)

Big session, everything validated in-game on the `.exe` (166 MB, 60 FPS) — **awaits the user's commit**:

- **Repair of the user's folder reorganization** (characters → enemies/players/NPCs; removal of
  `structures/` and of the support folder `characters/player/`): restored from git ONLY the assets in
  use (player.glb + materials/textures, audio/, bullet/, muzzle mesh, limb_config) INTO
  `characters/players/player/`; rewrote the old paths in **72 files** (script preloads do not use UID
  and were breaking); the levels' `_spawnable_scenes` cleaned up (structures out, sceneries in);
  `user://level_templates.json` migrated.
- **Cascading navigation** in the Template Manager (characters) and the new **Scenery Manager**
  (sceneries) — see [[🧩 templates-de-level (EN)|templates-de-level]]. The `levels` screen with 2
  buttons per level (Tab renumbered 1-9); the "Palco Neon" scenery (4 box + 3 sphere + 2 pill)
  validated on the ground AND in an online room.
- **Ground-enemy speed calibrated on real-world standards** (research: walking ~1.4 m/s, jogging ~3,
  running 4.5): red_robot strafe 4.25→**2.4**, pressure 5.2→**3.2**, flee 6.0→**3.8** +
  **smooth acceleration** (`manual_accel` 6/s) in manual movement — no sliding, with weight.
- **ManageTemplates (host_session) fixed** (button renamed from `ManageTemplatesButton` in the
  2026-07-03 sweep): alert when no level is selected (previously a silent return = "broken button");
  validated by hosting a room at **127.0.0.1:4383**.
- **`levels` screen on a responsive grid**: `GridContainer` 3 columns (Level fixed 300 px | Template |
  Scenery), the manager columns with `SIZE_EXPAND_FILL` **splitting the rest of the screen half and
  half**, uniform 16 px spacing on both rows. See [[📐 layout-responsivo (EN)|layout-responsivo]].
- **`build_windows.ps1` hardened**: deletes `.godot/exported/` before every export — the cache does
  not invalidate when a `.tscn` changes and the exe shipped with a **stale scene** (cost a diagnostic
  cycle with headless probes and markers in the binary). See [[🚀 Build Windows (Prod) (EN)|Build Windows (Prod)]].

---

## 🟢 P0.10 — Folder reorganization repair (refs → flat paths) — READY for review (2026-07-03)

The project was in a **half-finished folder reorganization**: the character files went back to the
**flat** paths (`characters/player/`, `red_robot/`, `criatura_alada/`, `playera/`), but many references
still pointed to the reorganized paths (`characters/players/…`, `characters/enemies/…`).
The `uid://` ones resolved, but the **pure-string ones broke**: the `_spawnable_scenes` of
`level_1`/`level_2` (characters did not spawn) and the `chooseplayer`'s `load(player.glb)` (the
character-select screen failed). Detected via the resource errors in the build (present since the 1st
build of the session — **pre-existing**, not from the auto-fit). **Fixed** with 4 path rewrites across
**24 files** (~101 occurrences): `players/player/→player/`, `players/playera/→playera/`,
`enemies/red_robot/→red_robot/`, `enemies/criatura_alada/→criatura_alada/`. **Purposely preserved**
`enemies/enemy_health_bar.gd` (the only file that genuinely stayed in `enemies/`, referenced by
red_robot/criatura). Validated headless (no resource errors) + rebuild. **Awaits commit.**

---

## 🟢 P0.9 — Locomotion capsule auto-fit per model — READY for review (2026-07-03)

The **physical blocking** between characters stopped using a default capsule (0.5×2.0) equal for all
and became **proportional to the model**, derived from the same limb boxes that `LimbColliders`
already measures — keeping **1 shape per character** (cheap, stable, deterministic for the netcode).
New method `LimbColliders.fit_locomotion_capsule` (radius = torso+legs footprint; height = vertical
extent; base anchored on the ground; no-op if there are no limbs → preserves the authored capsule).
Wired in `player.gd` and `red_robot.gd` after `build_for`. The criatura_alada (flying, no
`LimbColliders` in gameplay) keeps its authored capsule. **Validated** by a deterministic headless
probe (radius 0.250 ≠ arms 0.575; height 1.800; base 0.000 — 3/3 OK). Details:
[[🩸 dano-localizado (EN)|dano-localizado]] · [[🎮 player (EN)|player]]. It answered the user's
question about using the LimbColliders for physical blocking (localized damage already worked that
way). **Awaits commit.**

---

## 🟢 P0.8 — Variable jump + control-name sweep — READY for review (2026-07-03)

- **Variable jump (hold/release):** holding **space** = full jump animation + maximum distance
  (full ballistic arc, previous behavior preserved); **releasing mid-ascent** = SMOOTH cut of the jump
  (exponential damping `JUMP_CUT_DAMPING = 14.0/s` on the vertical velocity — no jerk) and the
  animation transitions to `jump_down` at the anticipated apex. Implementation: new synced state
  `jump_held` in the `PlayerInputSynchronizer` (seeded `true` in the `jump()` RPC so the 1st frame is
  not cut by replication delay; replicated in the InputSynchronizer's `SceneReplicationConfig`), cut
  restricted to real jumps via the `_jump_active` flag (falling off a ledge is NOT damped). Bots do
  not jump (AI), so they are unaffected. See [[🎮 player (EN)|player]].
- **Sweep of the 2D control names:** done (details in the crossed-out P2 item below). Two new project
  rules in `CLAUDE.md` (do not repeat Type/acronyms in the Name; review dependencies when changing a
  control) and the global dead-code cleanup rule reinforced (after every addition/deletion/modification).
- Validation: headless game 300 frames **without errors**; `%UniqueName`×`.tscn` consistency verified
  in host_session/client_session/playonline. **Awaits the user's commit.**

---

## 🟡 P1 — Validate multiplayer rooms on a real network

Phases 1–3 of the multi-level server are **implemented**. Progress on 2026-07-01:

- ✅ **Code review of the room flow** (`RoomManager` + `host_session` + `client_session` + the levels'
  `_ready` + lazy template + visibility filters): **consistent, no bugs found**. Verified the
  host-plays flows (`host_spawn_in_room`/`host_leave_room`), client-joins (`client_join_room`/`join_room`),
  stop/restart (`notify_room_closed`/`notify_room_restarted`), isolation by `room_id` and the
  deterministic replication path `/root/RoomManager/Room<id>/Level`.
- ✅ **Self-sufficient test protocol** created: [[🧪 teste-salas-multiplayer (EN)|teste-salas-multiplayer]]
  (local loopback `127.0.0.1` → LAN → internet via **playit.gg UDP**; default port `4383`).
- ✅ **Test A (loopback `127.0.0.1`, 2 instances) FIELD-VALIDATED (2026-07-02):** host creates a room,
  client joins and spawns (scenery, not gray), "(1 connection)", client↔host replication. **Netcode
  proven.** UI tweaks in the same session: **non-destructive** error window (× / ESC / "Back" only
  close it; fixes as a bonus the accidental quit in the Models screen validation) + **race guard** on
  the client's "Play" (do not spawn into a stopped room during `chooseplayer`).
  See [[🧪 teste-salas-multiplayer (EN)|teste-salas-multiplayer]] · [[🚪 salas (EN)|salas]].
- ⬜ **Field execution on a REAL network is missing** (needs hardware/network):
  - **Test B/C (real network):** 2 PCs (LAN and then internet via playit.gg) — **depends on the user**.

Full context: [[🚪 salas (EN)|salas]] · [[🌐 multiplayer (EN)|multiplayer]] · [[🛰️ hospedagem-online (EN)|hospedagem-online]].

---

## 🟡 P1.5 — Enemy AI: behavior + parameterization screen

User feedback (2026-07-02) on the current automatic AI. Split into **behavior** (code, in progress)
and **parameterization** (UI, postponed by the user's decision). Context: [[🤖 inimigos (EN)|inimigos]],
[[🧠 red-robot-ai-gd (EN)|red-robot-ai-gd]], `red_robot_ai.gd` / `criatura_alada_ai.gd` / `red_robot.gd`.

**Behavior (code) — ✅ DONE (2026-07-02, see [[🤖 inimigos (EN)|inimigos]] "AI refinement"):**
- ✅ **Ground enemy does not "slide":** `_match_locomotion_cadence` scales the locomotion
  AnimationPlayer's `speed_scale` so the cadence matches the real speed (no skating); outside manual
  mode it returns to 1.0. Code only (no touching the `.tscn`/blend tree). Tunables
  `walk_natural_speed`/`gait_speed_scale`.
- ✅ **Less rigid formation:** `formation_cohesion` 0.55→0.32, `formation_band` 5→7 m, the slot heading
  oscillates smoothly (`formation_wander`) → organic.
- ✅ **Target = nearest player (multiplayer):** `_players_in_range` + `_pick_target()` with hysteresis
  (`TARGET_SWITCH_MARGIN`); any enemy shoots at any player in range (red_robot + criatura).
- ✅ **Aerial smooth/contextual altitude:** interpolated layer switching (`_alt_bias`):
  threatened→climbs (escape), imminent bombing→descends (precision), otherwise cruise; vertical rate limited.
- ✅ **Faction marking (structural):** `AIConfig.faction`/`set_faction`/`is_hostile`/`is_neutral`
  (hostile/neutral/ally), hostile defaults for the enemies. **No neutral character yet** — field ready to plug in.
- 🔴 **NEUTRAL behavior logic (pending — depends on a neutral character):** a neutral only engages
  if THREATENED (getting shot) or by randomness. The marking already exists; the character and the logic are missing.

**Parameterization (UI — POSTPONED, this is the "next item" the user mentioned):**
- 🔴 In each model's **AI window** (Artificial Intelligence), add a **button next to each toggle**;
  when clicked, it **closes the AI window** and opens a dedicated **parameterization window**.
- 🔴 The parameterization window exposes the **limits**: altitude (min/max flight), speed, **fire cadence**, etc.
- 🔴 **Same style standards** as the other windows (fields, **Back** button and **× close** in the top corner):
  Back/× **close the window and reopen the respective AI window of the model that called it**.
- The UI base already exists: `FloatingWindow`/`FloatingDialog` (same modal/style pattern). Today the
  parameters are `@export`s in the AI scripts + `AIConfig` (boolean toggles only for now) → extend
  `AIConfig` for numeric values per model. See [[🚪 salas (EN)|salas]] (windows) and
  [[🧠 red-robot-ai-gd (EN)|red-robot-ai-gd]].

---

## 🔴 P2 — UI: pending rollouts

- **Responsive layout (containers):** migrate the remaining 2D screens from absolute-offset
  positioning to the `Margin → VBox → HBox` skeleton with `stretch` disabled. **Pilot done: `developer`.**
  Replicate to menu/settings/chooseplayer/levels/playonline/sessions. See [[📐 layout-responsivo (EN)|layout-responsivo]].
- ~~**Rename 2D controls (sweep)**~~ — ✅ **DONE on 2026-07-03** (all screens): no repeating the
  Type in the Name, no type acronyms, `OptionButton` in the plural; `Actions` preserved (the DebugOverlay
  looks it up by name). Rules registered in the project's `CLAUDE.md`. Renames: `BackButton→Back`
  (host/client session), `StartButton→Start`, `ManageTemplatesButton→ManageTemplates`,
  `LevelPicker→Levels`, `TemplatePicker→Templates`, `HostRenderPicker→HostRenderModes`,
  `SyncRatePicker→SyncRates`, `InterpPicker→Interpolations`, `ScopeLabel→Scope`/`OptionLabel→Caption`
  (playonline ×3 columns), 7×`Label→Caption` (Models screen selectors), room rows
  (`RoomLabel→RoomInfo`, `PlayButton→Play`, `Observe/Restart/Stop` without the Button suffix),
  template dialog (`ModelBox→ModelColumn`, `ModelValueLabel→ModelValue`, `CountSpin→Count`,
  `EntryPicker→Entries`, `FactionPickers→Factions`, `PlacementPicker→Placements`,
  `FolderPickers%d→Folders%d`), music manager (`ListenPicker→ListenTracks`, `TrackLabel_→Track_`,
  `TrackPicker_→Tracks_`), Models' Damage window (`Bone→Bones`, `Owner→Owners`).
  All code dependencies reviewed (`%`, `$`, `get_node`, signals); headless validation 300 frames without errors.

---

## ⚪ P3 — Polish / minor pending items

- **`pause_menu`** (`Control` overlay, 3 buttons + 3 sliders): wire `UINav.wire_tab_ring(self)` +
  initial `grab_focus` so it is not left out of the Tab ring. It is a pause overlay (no scene change) →
  **optional/secondary**. See [[🔁 navegacao-tab (EN)|navegacao-tab]] (§ Coverage and pending items).

---

## How to resume (quick checklist)

1. Read this note + [[🏠 Home (EN)|Home]] and the notes linked from the item you will attack.
2. Close any running Zimaro and the Godot editor **before** touching the code.
3. Attack by priority (P0 → P3); within each item, the "full context" lives in the system note.
4. When done: zero errors/warnings → update READMEs + vault → `build_windows.ps1` → **leave for review** (do not commit).

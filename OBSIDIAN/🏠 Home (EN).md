---
tipo: moc
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 🏠 ZIMARO — Neuron Vault

> 🇧🇷 Leia esta página em português → [[🏠 Home]]

> [!abstract] 🧠 What this vault is
> Claude's persistent memory for the **ZIMARO** project — a third-person shooter sandbox
> built with **Godot 4**, featuring server-authoritative multiplayer. The vault is updated at the
> end of every relevant task and mirrors the actual state of the code.

## ⚡ Executive summary

- **What it is:** a third-person shooter sandbox (Godot 4.x) with combat, per-limb localized damage, AI enemies and **online multiplayer** with simultaneous rooms (server-authoritative, ENet/UDP).
- **Repository:** `C:\GODOT\ZIMARO` · GitHub: [zimerfeld/ZIMARO](https://github.com/zimerfeld/ZIMARO) (open source, portfolio).
- **Stack:** Godot 4.6.2 · GDScript · Windows build via `build_windows.ps1` (single .exe with embedded PCK).
- **Differentiators:** multi-level rooms on the same server (SubViewport+World3D), per-limb hitbox damage (headshot), per-level Template/Scenery managers, EN/PT i18n on every screen.
- **Performance goal:** minimum **60 FPS** on minimal graphics hardware, using only cheap techniques (procedural sky, emissive shaders, fog) — validated on the `.exe`.
- **Current state:** several P0 items done and awaiting the user's commit/review; room netcode proven on loopback; real-network validation (2 PCs) still pending. See [[📌 Backlog (EN)|Backlog]].
- **Business angle:** open-source product in the zimerfeld portfolio (social proof via GitHub stars/downloads); funding via GitHub Sponsors and Ko-fi → [[💜 Financiamento e Patrocínio (EN)|Funding & Sponsorship]].

## 🧭 Navigation by priority

### 1️⃣ 🔑 Impact — Key Files
> Files that, when touched, have a big impact on the system.
- [[🎮 player-gd (EN)|player-gd]] — `library3D/characters/players/player/player.gd`: player core (movement/camera/state)
- [[🕹️ player-input-gd (EN)|player-input-gd]] — `player_input.gd`: input capture and sync (PlayerInputSynchronizer)
- [[🤖 red-robot-gd (EN)|red-robot-gd]] — `red_robot.gd`: Red Robot enemy body/states
- [[🧠 red-robot-ai-gd (EN)|red-robot-ai-gd]] — `IA/red_robot_ai.gd`: Red Robot reactive AI (target, formation, fire cadence)
- [[💥 bullet-gd (EN)|bullet-gd]] — `bullet.gd`: projectile and hit RPC
- [[🦿 limb-colliders-gd (EN)|limb-colliders-gd]] — `effects_shared/limb_colliders.gd`: per-limb hitboxes + locomotion capsule auto-fit
- [[🦴 body-parts-gd (EN)|body-parts-gd]] — `effects_shared/body_parts.gd` (+ body plans): body partitioning
- [[💚 health-bar-gd (EN)|health-bar-gd]] — `health_bar.gd`: player health bar
- [[🩹 enemy-health-bar-gd (EN)|enemy-health-bar-gd]] — `controls2D/enemy_health_bar.gd`: enemy health bar (HUD)
- [[🧭 main-gd (EN)|main-gd]] — `scenes2D/main/main.gd`: scene router (the game's entry point)

### 2️⃣ 🧩 Reuse — Systems
> Subsystems reused by several parts of the project.
- [[🎮 player (EN)|player]] — movement, physics, animation, camera
- [[🤖 inimigos (EN)|enemies]] — Red Robot: reactive AI (1.5× reload + retreat ≤10 m), states, HUD with range
- [[🔫 combate-tiro (EN)|combat/shooting]] — bullet, hit RPC, cooldown
- [[🌐 multiplayer (EN)|multiplayer]] — server-authoritative architecture
- [[🚪 salas (EN)|rooms]] — multi-level server: simultaneous rooms (SubViewport+World3D) + management grid
- [[🛰️ hospedagem-online (EN)|online hosting]] — playing over the internet: playit.gg (UDP) · Tailscale/ZeroTier · port forwarding (ngrok does NOT work)
- [[❤️ sistema-de-vida (EN)|health system]] — HP, health bar, respawn
- [[🩸 dano-localizado (EN)|localized damage]] — per-weapon damage, per-limb Area3D hitboxes, headshot
- [[🗿 biblioteca-de-modelos (EN)|model library]] — Models screen: mesh browser/extractor, Exported gallery, Structures category + CORPO fallback member
- [[🧩 templates-de-level (EN)|level templates]] — per-level Template (characters) and Scenery managers: cascading folder navigation, independent actives
- [[🌌 ambiente-dos-levels (EN)|level environment]] — procedural sky + fog + neon grid floor shader (Level 1 cyan / Level 2 amber), 60 FPS on the .exe
- [[🔊 audio (EN)|audio]] — buses (Master/Outside/Reactor/Music/SFX), background music per scene/level (MusicManager) + Music Manager UI
- [[🐞 debug-overlay (EN)|debug overlay]] — DebugOverlay + 2-column developer screen (Debug 2D yellow / Debug 3D cyan), grid, 3D labels
- [[⚡ performance-hud (EN)|performance HUD]] — PerformanceHUD (FPS/NET/RAM/CPU/GPU bar) + StabilityGuard (crash/freeze protection)
- [[🗣️ localizacao (EN)|localization]] — EN/PT language: Locale autoload + per-scene dictionaries, persisted, buttons on ALL screens
- [[🧱 recursos-nativos-godot (EN)|native Godot resources]] — which NATIVE nodes/resources the game uses, per subsystem; node-less RefCounted helpers

### 3️⃣ 🔀 Usage — Flows
> Step-by-step usage flows.
- [[🎬 fluxo-de-cenas (EN)|scene flow]] — main (router) → menu → chooseplayer→levels→level_1/level_2 · settings · developer→models
- [[⌨️ fluxo-de-input (EN)|input flow]] — capture → synchronization → movement
- [[🎯 fluxo-de-tiro (EN)|shooting flow]] — aim → shoot → bullet → hit → damage
- [[🧪 teste-salas-multiplayer (EN)|multiplayer room testing]] — room test protocol (local loopback → LAN → internet via playit.gg)

## 🚀 Operations
- [[💻 Rodar no Editor (Dev) (EN)|Run in the Editor (Dev)]] — open the project in the Godot 4.6.2 editor and run; multiplayer loopback with 2 instances
- [[🚀 Build Windows (Prod) (EN)|Build Windows (Prod)]] — `pwsh -File build_windows.ps1` → single `.exe` (embedded PCK) + Desktop shortcut

## 🔖 Conventions
- [[📄 formatacao (EN)|file formatting]] — UTF-8 without BOM, LF, no trailing whitespace, final newline + UID cache rebuild
- [[🔽 dropdowns (EN)|dropdowns]] — every OptionButton starts with "Selecione..." (item 0, default); cascades reset dependents
- [[📌 ancoragem-ui (EN)|UI anchoring]] — footer button bars use BOTTOM_WIDE; resolution capped to the usable screen
- [[📐 layout-responsivo (EN)|responsive layout]] — containers (not absolute offsets); Margin→VBox→HBox skeleton; pilot: developer
- [[🔁 navegacao-tab (EN)|Tab navigation]] — `UINav` helpers (focus/Tab): `wire_tab_ring`, `focus_tab_one`, `focus_first`, `cancel_active_edit`

## 💼 Business
- [[💜 Financiamento e Patrocínio (EN)|Funding & Sponsorship]] — GitHub Sponsors + Ko-fi, FUNDING.yml, social proof in the READMEs

## 🧭 Meta
- [[📌 Fatos-Chave (EN)|Key Facts]] — folder organization, autoloads, extra screens, engine/network/HUD at a glance

## 📌 Resuming work
- [[📌 Backlog (EN)|Backlog]] — **start here** when picking the project back up in another session

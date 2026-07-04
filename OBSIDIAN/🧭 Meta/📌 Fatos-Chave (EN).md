---
tipo: meta
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 📌 Project Key Facts

> Quick facts for immediate orientation (formerly "Quick Notes" of the old index).

- **Organization:** **scenes2D/** (UI screens: menu, settings, chooseplayer, developer, levels) and **scenes3D/** (players, enemies, door, level_1, level_2, models)
- **Autoloads:** **Settings** (`scenes2D/settings/config.gd`), **Locale** (`autoload/locale.gd`), **CrashHandler**, **PlayerSelection**, **DebugOverlay**, **StabilityGuard** (`autoload/stability_guard.gd`), **PerformanceHUD** (`autoload/performance_hud.gd`), **MusicManager** (`autoload/music_manager.gd` — per-scene background music, on loop)
- **Extra screens:** **developer** (debug toggles) → **models** (3D model browser/extractor) → **Exported** (gallery of `library/extracted/`); **settings** with a Debug tab
- **Engine:** **Godot 4.x**
- **Network mode:** **ENet / OfflineMultiplayerPeer** (server-authoritative)
- **Player:** `CharacterBody3D` with root motion
- **Enemy:** `CharacterBody3D` with a laser raycast
- **HUD:** CanvasLayer per player (local only)

## 🔗 Links
- [[🏠 Home (EN)|Home]] · [[🎬 fluxo-de-cenas (EN)|Scene Flow]] · [[🌐 multiplayer (EN)|Multiplayer]]

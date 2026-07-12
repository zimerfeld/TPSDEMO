---
tipo: meta
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# 📌 Hechos Clave del Proyecto

> Hechos rápidos para orientación inmediata (antes "Notas Rápidas" del índice antiguo).

- **Organización:** **scenes2D/** (pantallas de UI: menu, settings, chooseplayer, developer, levels) y **scenes3D/** (players, enemies, door, level_1, level_2, models)
- **Autoloads:** **Settings** (`scenes2D/settings/config.gd`), **Locale** (`autoload/locale.gd`), **CrashHandler**, **PlayerSelection**, **DebugOverlay**, **StabilityGuard** (`autoload/stability_guard.gd`), **PerformanceHUD** (`autoload/performance_hud.gd`), **MusicManager** (`autoload/music_manager.gd` — música de fondo por escena, en bucle)
- **Pantallas extra:** **developer** (toggles de debug) → **models** (navegador/extractor de modelos 3D) → **Exported** (galería de `library/extracted/`); **settings** con una pestaña Debug
- **Motor:** **Godot 4.x**
- **Modo de red:** **ENet / OfflineMultiplayerPeer** (autoridad en el servidor)
- **Jugador:** `CharacterBody3D` con root motion
- **Enemigo:** `CharacterBody3D` con un raycast láser
- **HUD:** CanvasLayer por jugador (solo local)

## 🔗 Enlaces
- [[🏠 Home (ES)|Inicio]] · [[🎬 fluxo-de-cenas (ES)|Flujo de Escenas]] · [[🌐 multiplayer (ES)|Multiplayer]]

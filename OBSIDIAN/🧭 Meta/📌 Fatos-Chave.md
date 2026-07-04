---
tipo: meta
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-07-04
---

# 📌 Fatos-Chave do projeto

> Fatos rápidos para orientação imediata (ex-"Notas Rápidas" do índice antigo).

- **Organização:** **scenes2D/** (telas de UI: menu, settings, chooseplayer, developer, levels) e **scenes3D/** (players, enemies, door, level_1, level_2, models)
- **Autoloads:** **Settings** (`scenes2D/settings/config.gd`), **Locale** (`autoload/locale.gd`), **CrashHandler**, **PlayerSelection**, **DebugOverlay**, **StabilityGuard** (`autoload/stability_guard.gd`), **PerformanceHUD** (`autoload/performance_hud.gd`), **MusicManager** (`autoload/music_manager.gd` — música de fundo por cena, em loop)
- **Telas extras:** **developer** (toggles de debug) → **models** (navegador/extrator de modelos 3D) → **Exported** (galeria de `library/extracted/`); **settings** com aba Debug
- **Motor:** **Godot 4.x**
- **Modo de rede:** **ENet / OfflineMultiplayerPeer** (server-authoritative)
- **Player:** `CharacterBody3D` com root motion
- **Inimigo:** `CharacterBody3D` com laser raycast
- **HUD:** CanvasLayer por player (local apenas)

## 🔗 Ligações
- [[🏠 Home]] · [[🎬 fluxo-de-cenas]] · [[🌐 multiplayer]]

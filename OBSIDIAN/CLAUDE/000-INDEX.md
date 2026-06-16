# TPS Demo — Índice do Cofre Claude

> Memória viva do projeto Godot 4 Third Person Shooter Demo.
> Repositório: `C:\GODOT\TPSDEMO` | GitHub: [zimerfeld/TPSDEMO](https://github.com/zimerfeld/TPSDEMO)

---

## Sistemas

| Nota | Resumo |
|---|---|
| [[sistemas/player]] | Movimento, física, animação, câmera |
| [[sistemas/inimigos]] | Red Robot — IA, estados, laser |
| [[sistemas/combate-tiro]] | Bullet, RPC hit, cooldown |
| [[sistemas/multiplayer]] | Arquitetura server-authoritative |
| [[sistemas/sistema-de-vida]] | HP, barra de vida, respawn |
| [[sistemas/dano-localizado]] | Dano por arma, hitboxes Area3D por membro, headshot |
| [[sistemas/biblioteca-de-modelos]] | Tela Models: navegador/extrator de malhas, galeria Exported, grupo Level Base |

---

## Fluxos

| Nota | Resumo |
|---|---|
| [[fluxos/fluxo-de-cenas]] | main (roteador) → menu → chooseplayer→levels→level_1/level_base · settings · developer→models |
| [[fluxos/fluxo-de-input]] | Captura → sincronização → movimento |
| [[fluxos/fluxo-de-tiro]] | Aim → shoot → bullet → hit → dano |

---

## Arquivos-Chave

| Arquivo | Nota |
|---|---|
| `library3D/characters/players/player/player.gd` | [[arquivos-chave/player-gd]] |
| `library3D/characters/players/player/player_input.gd` | [[arquivos-chave/player-input-gd]] |
| `library3D/characters/players/player/health_bar.gd` | [[arquivos-chave/health-bar-gd]] |
| `library3D/characters/enemies/enemy_health_bar.gd` | [[arquivos-chave/enemy-health-bar-gd]] |
| `effects_shared/limb_colliders.gd` | [[arquivos-chave/limb-colliders-gd]] |
| `library3D/characters/red_robot/red_robot.gd` | [[arquivos-chave/red-robot-gd]] |
| `library3D/characters/player/bullet/bullet.gd` | [[arquivos-chave/bullet-gd]] |
| `scenes2D/main/main.gd` | [[arquivos-chave/main-gd]] |

---

## Convenções

| Nota | Resumo |
|---|---|
| [[convencoes/formatacao]] | Formatação de arquivos (UTF-8 sem BOM, LF, sem trailing ws, newline final) + rebuild do cache de UIDs |
| [[convencoes/dropdowns]] | Todo OptionButton começa com "Selecione..." (item 0, default); cascata reseta dependentes e a tela |

---

## Notas Rápidas

- Organização: **scenes2D/** (telas de UI: menu, settings, chooseplayer, developer, levels) e **scenes3D/** (players, enemies, door, level_1, level_base, models)
- Autoloads: **Settings** (`scenes2D/settings/config.gd`), **CrashHandler**, **PlayerSelection**, **DebugOverlay**
- Telas extras: **developer** (toggles de debug) → **models** (navegador/extrator de modelos 3D) → **Exported** (galeria de `library/extracted/`); **settings** com aba Debug
- Motor: **Godot 4.x**
- Modo de rede: **ENet / OfflineMultiplayerPeer** (server-authoritative)
- Player: `CharacterBody3D` com root motion
- Inimigo: `CharacterBody3D` com laser raycast
- HUD: CanvasLayer por player (local apenas)

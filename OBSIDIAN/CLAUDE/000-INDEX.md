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

---

## Fluxos

| Nota | Resumo |
|---|---|
| [[fluxos/fluxo-de-cenas]] | main → menu → level_1 / final_level |
| [[fluxos/fluxo-de-input]] | Captura → sincronização → movimento |
| [[fluxos/fluxo-de-tiro]] | Aim → shoot → bullet → hit → dano |

---

## Arquivos-Chave

| Arquivo | Nota |
|---|---|
| `player/player.gd` | [[arquivos-chave/player-gd]] |
| `player/player_input.gd` | [[arquivos-chave/player-input-gd]] |
| `player/health_bar.gd` | [[arquivos-chave/health-bar-gd]] |
| `enemies/enemy_health_bar.gd` | [[arquivos-chave/enemy-health-bar-gd]] |
| `effects_shared/glass_hitboxes.gd` | [[arquivos-chave/glass-hitboxes-gd]] |
| `enemies/red_robot/red_robot.gd` | [[arquivos-chave/red-robot-gd]] |
| `player/bullet/bullet.gd` | [[arquivos-chave/bullet-gd]] |
| `main/main.gd` | [[arquivos-chave/main-gd]] |

---

## Convenções

| Nota | Resumo |
|---|---|
| [[convencoes/formatacao]] | Formatação de arquivos (UTF-8 sem BOM, LF, sem trailing ws, newline final) + rebuild do cache de UIDs |

---

## Notas Rápidas

- Motor: **Godot 4.x**
- Modo de rede: **ENet / OfflineMultiplayerPeer** (server-authoritative)
- Player: `CharacterBody3D` com root motion
- Inimigo: `CharacterBody3D` com laser raycast
- HUD: CanvasLayer por player (local apenas)

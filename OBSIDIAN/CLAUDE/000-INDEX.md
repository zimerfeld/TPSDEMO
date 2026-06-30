# ZIMARO — Índice do Cofre Claude

> Memória viva do projeto Godot 4 ZIMARO (sandbox de tiro em terceira pessoa).
> Repositório: `C:\GODOT\ZIMARO` | GitHub: [zimerfeld/ZIMARO](https://github.com/zimerfeld/ZIMARO)

---

## 💜 Financiamento / Patrocínio
Canais de doação configurados no repositório (badges no topo dos READMEs + botão **Sponsor**):
- **GitHub Sponsors:** [zimerfeld](https://github.com/sponsors/zimerfeld) · **Ko-fi:** [C0D621FCGD ☕](https://ko-fi.com/C0D621FCGD)
- **`.github/FUNDING.yml`:** criado com `github: zimerfeld` e `ko_fi: C0D621FCGD` (exibe o botão nativo Sponsor com ambos).
- **Prova social no README:** badges de **stars** e **downloads de releases** do GitHub (`shields.io/github/stars` e `/downloads/.../total`) + frase "por que doar" (manutenção no tempo livre, novas features e correções). Projeto não vai pro NuGet — a métrica pública é o GitHub.

---

## Sistemas

| Nota | Resumo |
|---|---|
| [[sistemas/player]] | Movimento, física, animação, câmera |
| [[sistemas/inimigos]] | Red Robot — IA reativa (recarga 1,5× + recuo ≤10 m), estados, HUD com alcance |
| [[sistemas/combate-tiro]] | Bullet, RPC hit, cooldown |
| [[sistemas/multiplayer]] | Arquitetura server-authoritative |
| [[sistemas/hospedagem-online]] | Jogar pela internet: playit.gg (UDP) · Tailscale/ZeroTier · port forwarding (ngrok NÃO serve) |
| [[sistemas/salas]] | Servidor multi-level: salas simultâneas (SubViewport+World3D) + grade de gerência (Fase 1, lado host) |
| [[sistemas/sistema-de-vida]] | HP, barra de vida, respawn |
| [[sistemas/dano-localizado]] | Dano por arma, hitboxes Area3D por membro, headshot |
| [[sistemas/biblioteca-de-modelos]] | Tela Models: navegador/extrator de malhas, galeria Exported, grupo Level Base |
| [[sistemas/audio]] | Buses (Master/Outside/Reactor/Music/SFX), controles Música × Efeitos de Som; música de fundo por cena/level em loop infinito (autoload MusicManager + pasta `Audios/`) + Gerenciador de Música nas settings (ouvir/atribuir por cena) |
| [[sistemas/debug-overlay]] | DebugOverlay + tela developer em 2 colunas (Debug 2D amarelo / Debug 3D ciano), grid, rótulos 3D |
| [[sistemas/performance-hud]] | Indicadores de performance: PerformanceHUD (barra FPS/NET/RAM/CPU/GPU, developer) + StabilityGuard (proteção crash/freeze sempre-ligada) |
| [[sistemas/localizacao]] | Idioma EN/PT: autoload Locale + dicionários por cena em Resources/*.pt/en.json, persistido, botões em TODAS as telas |
| [[sistemas/recursos-nativos-godot]] | Quais nós/recursos NATIVOS o jogo usa (StaticBody3D, CollisionShape3D, MeshInstance3D…), por subsistema; helpers RefCounted sem nó |
| [[sistemas/build-windows]] | Build Windows: `build_windows.ps1` → `.exe` (PCK embutido) + atalho no Desktop com ícone; rodar ao fim de cada tarefa |

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
| `effects_shared/body_parts.gd` (+ planos corporais) | [[arquivos-chave/body-parts-gd]] |
| `library3D/characters/red_robot/red_robot.gd` | [[arquivos-chave/red-robot-gd]] |
| `library3D/characters/red_robot/IA/red_robot_ai.gd` | [[arquivos-chave/red-robot-ai-gd]] |
| `library3D/characters/player/bullet/bullet.gd` | [[arquivos-chave/bullet-gd]] |
| `scenes2D/main/main.gd` | [[arquivos-chave/main-gd]] |

---

## Convenções

| Nota | Resumo |
|---|---|
| [[convencoes/formatacao]] | Formatação de arquivos (UTF-8 sem BOM, LF, sem trailing ws, newline final) + rebuild do cache de UIDs |
| [[convencoes/dropdowns]] | Todo OptionButton começa com "Selecione..." (item 0, default); cascata reseta dependentes e a tela |
| [[convencoes/ancoragem-ui]] | Barras de botões no rodapé usam BOTTOM_WIDE (largura total); resolução limitada à tela útil |
| [[convencoes/layout-responsivo]] | Organizar controles com Containers (não offsets absolutos); esqueleto Margin→VBox→HBox; piloto: developer |
| [[convencoes/navegacao-tab]] | Helpers `UINav` (foco/Tab): `wire_tab_ring` (anel), `focus_tab_one`, `focus_first`, `cancel_active_edit`; por que o Debug 2D mostra `TAB: -`; matriz cena×helper |

---

## Notas Rápidas

- Organização: **scenes2D/** (telas de UI: menu, settings, chooseplayer, developer, levels) e **scenes3D/** (players, enemies, door, level_1, level_base, models)
- Autoloads: **Settings** (`scenes2D/settings/config.gd`), **Locale** (`autoload/locale.gd`), **CrashHandler**, **PlayerSelection**, **DebugOverlay**, **StabilityGuard** (`autoload/stability_guard.gd`), **PerformanceHUD** (`autoload/performance_hud.gd`), **MusicManager** (`autoload/music_manager.gd` — música de fundo por cena, em loop)
- Telas extras: **developer** (toggles de debug) → **models** (navegador/extrator de modelos 3D) → **Exported** (galeria de `library/extracted/`); **settings** com aba Debug
- Motor: **Godot 4.x**
- Modo de rede: **ENet / OfflineMultiplayerPeer** (server-authoritative)
- Player: `CharacterBody3D` com root motion
- Inimigo: `CharacterBody3D` com laser raycast
- HUD: CanvasLayer por player (local apenas)

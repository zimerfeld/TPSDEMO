---
tipo: moc
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-07-06
---

# 🏠 ZIMARO — Cofre de Neurônios

> 🇺🇸 Read this page in English → [[🏠 Home (EN)]]

> 🇪🇸 Lea esta página en español → [[🏠 Home (ES)]]

> [!abstract] 🧠 O que é este cofre
> Memória persistente do Claude para o projeto **ZIMARO** — sandbox de tiro em terceira pessoa
> feito em **Godot 4**, com multiplayer server-authoritative. O cofre é atualizado ao fim de cada
> tarefa relevante e espelha o estado real do código.
>
> 📁 **Pasta do cofre:** `ZIMARO/` na raiz do repositório (`C:\GODOT\ZIMARO\ZIMARO`) — renomeada
> de `OBSIDIAN/` para o nome do projeto em 2026-07-05.

## ⚡ Resumo executivo

- **O que é:** sandbox de tiro em 3ª pessoa (Godot 4.x) com combate, dano localizado por membro, inimigos com IA e **multiplayer online** por salas simultâneas (server-authoritative, ENet/UDP).
- **Repositório:** `C:\GODOT\ZIMARO` · GitHub: [zimerfeld/ZIMARO](https://github.com/zimerfeld/ZIMARO) (open source, portfólio).
- **Stack:** Godot 4.6.2 · GDScript · build Windows via `build_windows.ps1` (.exe com PCK embutido).
- **Diferenciais:** salas multi-level no mesmo servidor (SubViewport+World3D), dano por hitbox de membro (headshot), gerenciadores de Templates/Cenários por level, i18n EN/PT/ES em todas as telas.
- **Meta de performance:** mínimo **60 FPS** em hardware gráfico mínimo, só com técnicas baratas (céu procedural, shaders emissivos, fog) — validada no `.exe`.
- **Estado atual:** vários P0 prontos aguardando commit/review do usuário; netcode de salas provado em loopback; falta validação em rede real (2 PCs). Ver [[📌 Backlog (PT)|📌 Backlog]].
- **Ângulo de negócio:** produto open source do portfólio zimerfeld (prova social por stars/downloads no GitHub); financiamento via GitHub Sponsors e Ko-fi → [[💜 Financiamento e Patrocínio (PT)|💜 Financiamento e Patrocínio]].

## 🧭 Navegação por prioridade

### 1️⃣ 🔑 Impacto — Arquivos-Chave
> Arquivos que, se manipulados, têm grande impacto no sistema.
- [[🎮 player-gd (PT)|🎮 player-gd]] — `library3D/characters/players/player/player.gd`: núcleo do player (movimento/câmera/estado)
- [[🕹️ player-input-gd (PT)|🕹️ player-input-gd]] — `player_input.gd`: captura e sincronização de input (PlayerInputSynchronizer)
- [[🤖 red-robot-gd (PT)|🤖 red-robot-gd]] — `red_robot.gd`: corpo/estados do inimigo Red Robot
- [[🧠 red-robot-ai-gd (PT)|🧠 red-robot-ai-gd]] — `IA/red_robot_ai.gd`: IA reativa do Red Robot (alvo, formação, cadência)
- [[💥 bullet-gd (PT)|💥 bullet-gd]] — `bullet.gd`: projétil e RPC de hit
- [[🦿 limb-colliders-gd (PT)|🦿 limb-colliders-gd]] — `effects_shared/limb_colliders.gd`: hitboxes por membro + auto-fit da cápsula de locomoção
- [[🦴 body-parts-gd (PT)|🦴 body-parts-gd]] — `effects_shared/body_parts.gd` (+ planos corporais): particionamento do corpo
- [[💚 health-bar-gd (PT)|💚 health-bar-gd]] — `health_bar.gd`: barra de vida do player
- [[🩹 enemy-health-bar-gd (PT)|🩹 enemy-health-bar-gd]] — `controls2D/enemy_health_bar.gd`: barra de vida dos inimigos (HUD)
- [[🧭 main-gd (PT)|🧭 main-gd]] — `scenes2D/main/main.gd`: roteador de cenas (porta de entrada do jogo)

### 2️⃣ 🧩 Reutilização — Sistemas
> Subsistemas reutilizados por várias partes do projeto.
- [[🎮 player (PT)|🎮 player]] — movimento, física, animação, câmera
- [[🤖 inimigos (PT)|🤖 inimigos]] — Red Robot: IA reativa (recarga 1,5× + recuo ≤10 m), estados, HUD com alcance
- [[🔫 combate-tiro (PT)|🔫 combate-tiro]] — bullet, RPC hit, cooldown
- [[⚔️ facções (PT)|⚔️ facções]] — lados em runtime (hostil/aliado/neutro): sem fogo amigo, targeting por facção, neutros dinâmicos
- [[🌐 multiplayer (PT)|🌐 multiplayer]] — arquitetura server-authoritative
- [[🚪 salas (PT)|🚪 salas]] — servidor multi-level: salas simultâneas (SubViewport+World3D) + grade de gerência
- [[🛰️ hospedagem-online (PT)|🛰️ hospedagem-online]] — jogar pela internet: playit.gg (UDP) · Tailscale/ZeroTier · port forwarding (ngrok NÃO serve)
- [[❤️ sistema-de-vida (PT)|❤️ sistema-de-vida]] — HP, barra de vida, respawn
- [[🩸 dano-localizado (PT)|🩸 dano-localizado]] — dano por arma, hitboxes Area3D por membro, headshot
- [[🗿 biblioteca-de-modelos (PT)|🗿 biblioteca-de-modelos]] — tela Models: navegador/extrator de malhas, galeria Exported, categoria Structures + membro CORPO de fallback
- [[🧩 templates-de-level (PT)|🧩 templates-de-level]] — Gerenciadores de Templates (personagens) e de Cenários por level: navegação em cascata, ativos independentes
- [[🌌 ambiente-dos-levels (PT)|🌌 ambiente-dos-levels]] — céu procedural + fog + piso-grade neon por shader (Level 1 ciano / Level 2 âmbar), 60 FPS no .exe
- [[🌀 fundos-2D-animados (PT)|🌀 fundos-2D-animados]] — fundos animados das telas 2D por shader (portal/vórtice); regra da emenda do `atan()` no eixo esquerdo
- [[🔊 audio (PT)|🔊 audio]] — buses (Master/Outside/Reactor/Music/SFX), música de fundo por cena/level (MusicManager) + Gerenciador de Música
- [[🐞 debug-overlay (PT)|🐞 debug-overlay]] — DebugOverlay + tela developer em 2 colunas (Debug 2D amarelo / Debug 3D ciano), grid, rótulos 3D
- [[⚡ performance-hud (PT)|⚡ performance-hud]] — PerformanceHUD (barra FPS/NET/RAM/CPU/GPU) + StabilityGuard (proteção crash/freeze)
- [[🗣️ localizacao (PT)|🗣️ localizacao]] — idioma EN/PT/ES: autoload Locale + dicionários por cena, persistido, botões em TODAS as telas
- [[🧱 recursos-nativos-godot (PT)|🧱 recursos-nativos-godot]] — quais nós/recursos NATIVOS o jogo usa, por subsistema; helpers RefCounted sem nó

### 3️⃣ 🔀 Uso — Fluxos
> Fluxos de uso passo a passo.
- [[🎬 fluxo-de-cenas (PT)|🎬 fluxo-de-cenas]] — main (roteador) → menu → chooseplayer→levels→level_1/level_2 · settings · developer→models
- [[⌨️ fluxo-de-input (PT)|⌨️ fluxo-de-input]] — captura → sincronização → movimento
- [[🎯 fluxo-de-tiro (PT)|🎯 fluxo-de-tiro]] — aim → shoot → bullet → hit → dano
- [[🧪 teste-salas-multiplayer (PT)|🧪 teste-salas-multiplayer]] — protocolo de teste das salas (loopback local → LAN → internet playit.gg)

## 🚀 Operação
- [[💻 Rodar no Editor (Dev) (PT)|💻 Rodar no Editor (Dev)]] — abrir o projeto no editor Godot 4.6.2 e rodar; loopback multiplayer com 2 instâncias
- [[🚀 Build Windows (Prod) (PT)|🚀 Build Windows (Prod)]] — `pwsh -File build_windows.ps1` → `.exe` único (PCK embutido) + atalho no Desktop
- [[🔌 MCP do Godot (PT)|🔌 MCP do Godot]] — ligar o Claude Code ao editor pelo addon `godot_ai`; comandos headless (`--import`, `--script`)

## 🔖 Convenções
- [[📄 formatacao (PT)|📄 formatacao]] — UTF-8 sem BOM, LF, sem trailing ws, newline final + rebuild do cache de UIDs
- [[🔽 dropdowns (PT)|🔽 dropdowns]] — todo OptionButton começa com "Selecione..." (item 0, default); cascata reseta dependentes
- [[📌 ancoragem-ui (PT)|📌 ancoragem-ui]] — barras de botões no rodapé usam BOTTOM_WIDE; resolução limitada à tela útil
- [[📐 layout-responsivo (PT)|📐 layout-responsivo]] — containers (não offsets absolutos); esqueleto Margin→VBox→HBox; piloto: developer
- [[🔁 navegacao-tab (PT)|🔁 navegacao-tab]] — helpers `UINav` (foco/Tab): `wire_tab_ring`, `focus_tab_one`, `focus_first`, `cancel_active_edit`

## 💼 Negócio
- [[💜 Financiamento e Patrocínio (PT)|💜 Financiamento e Patrocínio]] — GitHub Sponsors + Ko-fi, FUNDING.yml, prova social nos READMEs

## 🧭 Meta
- [[📌 Fatos-Chave (PT)|📌 Fatos-Chave]] — organização de pastas, autoloads, telas extras, motor/rede/HUD em uma olhada

## 📌 Retomada
- [[📌 Backlog (PT)|📌 Backlog]] — **comece por aqui** ao retomar o projeto em outra sessão

## ⚖️ Licença
- **CC BY-NC-ND 4.0** (Creative Commons Atribuição-NãoComercial-SemDerivações 4.0 Internacional) · © 2026 Renato Zimerfeld — compartilhamento não comercial com atribuição; **sem uso comercial** e **sem derivações**. Fonte da verdade: `LICENSE.md` na raiz; nomeada nos READMEs (`README.md`, `README.en-US.md`, `README.pt-BR.md`).

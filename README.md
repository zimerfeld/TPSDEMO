# ZIMARO

> 🇬🇧 A small third-person shooter sandbox built on the [Godot Engine](https://godotengine.org).
>
> 🇧🇷 Um pequeno sandbox de tiro em terceira pessoa construído sobre a [Godot Engine](https://godotengine.org).

[![GitHub stars](https://img.shields.io/github/stars/zimerfeld/ZIMARO?style=for-the-badge&logo=github)](https://github.com/zimerfeld/ZIMARO/stargazers) &nbsp; [![GitHub downloads](https://img.shields.io/github/downloads/zimerfeld/ZIMARO/total?style=for-the-badge&logo=github&label=Downloads)](https://github.com/zimerfeld/ZIMARO/releases)

This game is built and maintained in my free time. If you enjoy ZIMARO, a sponsorship helps keep new features and fixes coming. 💜
Este jogo é construído e mantido no meu tempo livre. Se você curte o ZIMARO, um patrocínio ajuda a manter novas funcionalidades e correções chegando. 💜

[![GitHub Sponsor](https://img.shields.io/badge/Sponsor-zimerfeld-EA4AAA?style=for-the-badge&logo=githubsponsors&logoColor=white)](https://github.com/sponsors/zimerfeld) &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; [![Ko-fi](https://img.shields.io/badge/Ko--fi-Buy%20me%20a%20coffee-FF5E2B?style=for-the-badge&logo=ko-fi&logoColor=white)](https://ko-fi.com/C0D621FCGD)

![Screenshot of ZIMARO](screenshots/screenshot.png)

> 🇬🇧 **This file is a high-level bilingual summary.** Full, detailed docs:
> **[📖 English → README.en-US.md](README.en-US.md)** · **[📖 Português → README.pt-BR.md](README.pt-BR.md)**
>
> 🇧🇷 **Este arquivo é um resumo bilíngue de alto nível.** Documentação completa e detalhada:
> **[📖 English → README.en-US.md](README.en-US.md)** · **[📖 Português → README.pt-BR.md](README.pt-BR.md)**

---

## Overview · Visão geral

🇬🇧 Built on the Godot Engine, ZIMARO is a small third-person
shooter sandbox: a menu-driven flow (character selection, level picker, settings, developer screen,
online play), playable characters that move/aim/jump/shoot, ground and flying enemies (the Red
Robot has a reactive AI that reloads faster, opens fire in range and flees when you close in),
per-limb localized damage, several levels, a browsable 3D model library, reusable cyberpunk HUD
widgets, debug tooling, EN/PT localization and live (no-Apply) settings.

🇧🇷 Construído sobre a Godot Engine, o ZIMARO é um pequeno sandbox de tiro em
terceira pessoa: fluxo por menus (seleção de personagem, seletor de fases, configurações, tela de
desenvolvedor, jogo online), personagens jogáveis que se movem/miram/pulam/atiram, inimigos
terrestres e voadores (o Red Robot tem uma IA reativa que recarrega mais rápido, abre fogo no
alcance e recua quando você se aproxima), dano localizado por membro, várias fases, biblioteca de
modelos 3D navegável,
widgets de HUD cyberpunk reutilizáveis, ferramentas de debug, localização EN/PT e configurações ao
vivo (sem botão Aplicar).

## Features · Funcionalidades

🇬🇧 Highlights: localized damage (native per-limb 3D colliders, headshots deal extra) with a
per-model, per-limb damage multiplier you can edit right in the Models viewer (saved to one file per
character, in the model's own folder `library3D/<cat>/<model>/limb_config.json`, with a writable `user://` override for in-game edits) where the body type (biped/quadruped/crawler) defines the members and
protruding sub-members (plates, guards) are editable too; a Models viewer with per-category master toggles (rotation, animation,
special effects, audio, colliders — with live X/Y/Z offset & scale inputs (plus a Save button) for the
isolated member/sub-member collider — member labels — incl. a Bone toggle floating the chosen loose
bone's name) and selector dropdowns — both persisted between
visits, with the drill-down chain restored on reopen; a
developer screen whose debug overlay is split into **Debug 2D** (light
yellow) and **Debug 3D** (light cyan) columns — a master alone shows nothing, each dependent line
must also be selected — with a live **player-model preview** beside the Debug 3D column (a rotating
robot in its own viewport) that reflects the enabled/disabled toggles in real time; performance indicators built on Godot's `Performance` singleton — a toggleable
**Performance HUD** top bar (FPS/NET/RAM/CPU/GPU + a basic/advanced view) plus an always-on
**StabilityGuard** that throttles physics and force-pauses with a full-screen overlay before RAM/VRAM/
collision-pairs/node-count/FPS can freeze or crash the machine;
a floor grid for 3D screens; and an EN/PT localization system where **every screen carries
Português/English buttons** and each scene ships its own JSON dictionaries
(`<scene>/Resources/*.pt.json` + `*.en.json`), merged at load.

🇧🇷 Destaques: dano localizado (colliders 3D nativos por membro, headshots causam dano extra) com um
multiplicador de dano por modelo e por membro **editável na própria tela Models** (salvo em um arquivo
por personagem, na pasta do próprio modelo `library3D/<cat>/<modelo>/limb_config.json`, com override gravável em `user://` para edições no jogo), em que o tipo de corpo (bípede/quadrúpede/rastejante) define os membros e
os sub-membros salientes (placas, guardas) também são editáveis; um visualizador Models com toggles mestres por categoria (rotação, animação,
efeitos especiais, áudio, colliders — com inputs X/Y/Z de afastamento e escala ao vivo (mais botão
Salvar) para o collider do membro/sub-membro isolado — rótulos de membro — incl. um toggle Osso que faz flutuar o nome
do osso avulso escolhido) e dropdowns de seleção — ambos persistidos
entre visitas, com a cadeia de navegação restaurada ao reabrir; uma tela developer cujo overlay de
debug é dividido nas
colunas **Debug 2D** (amarelo claro) e **Debug 3D** (ciano claro) — o master sozinho não mostra
nada, cada linha dependente também precisa ser selecionada — com uma **pré-visualização do modelo do
player** ao lado da coluna Debug 3D (um robô girando no próprio viewport) que reflete os botões
ativado/desativado em tempo real; indicadores de performance sobre o
singleton `Performance` do Godot — uma barra **Performance HUD** opcional (FPS/NET/RAM/CPU/GPU + visão
básica/avançada) mais um **StabilityGuard** sempre-ligado, que reduz a física e pausa à força com um
overlay de tela cheia antes que RAM/VRAM/collision pairs/contagem de nós/FPS congelem ou travem a
máquina; uma
malha no solo
para telas 3D; e um sistema de localização EN/PT em que **toda tela tem botões Português/English** e
cada cena traz seus próprios dicionários JSON (`<cena>/Resources/*.pt.json` + `*.en.json`),
mesclados no carregamento.

> 🇬🇧 **On the per-limb hitboxes:** you didn't reinvent Godot's physics; you automated the authoring
> of hitboxes that would be unfeasible to maintain at scale by hand.
>
> 🇧🇷 **Sobre as hitboxes por membro:** você não reinventou a física do Godot; você automatizou a
> autoria de hitboxes que, manualmente, seriam inviáveis de manter em escala.

## Requirements & running · Requisitos e execução

🇬🇧 Requires **Godot 4.6.2** ([download](https://godotengine.org/download/)). Get the project from
[zimerfeld/ZIMARO](https://github.com/zimerfeld/ZIMARO) (clone or ZIP) and open it in Godot. Git
LFS is not required.

🇧🇷 Requer **Godot 4.6.2** ([download](https://godotengine.org/download/)). Pegue o projeto em
[zimerfeld/ZIMARO](https://github.com/zimerfeld/ZIMARO) (clone ou ZIP) e abra no Godot. Git LFS não
é necessário.

## Project structure · Estrutura do projeto

🇬🇧 `scenes2D/` (screens, UI, reusable widgets) · `scenes3D/` (levels + Models viewer) · `library3D/`
(3D assets by type) · `effects_shared/` (cross-character helpers) · `autoload/` (global singletons:
crash_handler, player_selection, debug_overlay, locale, stability_guard, performance_hud; Settings is
`scenes2D/settings/config.gd`) · per-scene `Resources/*.pt.json` + `*.en.json` (UI dictionaries) ·
`OBSIDIAN/` (documentation vault).

🇧🇷 `scenes2D/` (telas, UI, widgets reutilizáveis) · `scenes3D/` (fases + visualizador Models) ·
`library3D/` (assets 3D por tipo) · `effects_shared/` (helpers entre personagens) · `autoload/`
(singletons globais: crash_handler, player_selection, debug_overlay, locale, stability_guard, performance_hud; o
Settings é `scenes2D/settings/config.gd`) · `Resources/*.pt.json` + `*.en.json` por cena (dicionários
da UI) · `OBSIDIAN/` (cofre de documentação).

🇬🇧 **Windows build:** `pwsh -File build_windows.ps1` → `build/windows/ZIMARO.exe` (embedded PCK) + a
desktop shortcut with the app icon. · 🇧🇷 **Build Windows:** `pwsh -File build_windows.ps1` → o `.exe`
com PCK embutido + atalho no Desktop com o ícone.

## Controls · Controles

🇬🇧 Move (WASD / arrows / stick), look (mouse / right stick), jump (Space), aim (RMB / L2), shoot
(LMB / R2, only while aiming), menu/quit (Escape), fullscreen (F11 / Alt+Enter), debug info (F3).

🇧🇷 Mover (WASD / setas / analógico), olhar (mouse / analógico direito), pular (Espaço), mirar
(botão direito / L2), atirar (botão esquerdo / R2, só mirando), menu/sair (Escape), tela cheia (F11 /
Alt+Enter), info de debug (F3).

## Code formatting · Formatação de código

🇬🇧 All text files use UTF-8 **without BOM**, LF endings, no trailing whitespace, and a trailing
newline — enforced by [`file_format.sh`](file_format.sh) (run `bash file_format.sh` from Git Bash).

🇧🇷 Todos os arquivos de texto usam UTF-8 **sem BOM**, quebras LF, sem espaços ao fim e com quebra de
linha final — garantido por [`file_format.sh`](file_format.sh) (rode `bash file_format.sh` no Git Bash).

## Documentation · Documentação

🇬🇧 The detailed docs ([README.en-US.md](README.en-US.md) / [README.pt-BR.md](README.pt-BR.md)) and
the [`OBSIDIAN/`](OBSIDIAN) vault are the project knowledge base and are kept up to date at the end of
every change.

🇧🇷 As docs detalhadas ([README.en-US.md](README.en-US.md) / [README.pt-BR.md](README.pt-BR.md)) e o
cofre [`OBSIDIAN/`](OBSIDIAN) são a base de conhecimento do projeto e são mantidos atualizados ao
final de cada mudança.

## License · Licença

🇬🇧 / 🇧🇷 See / Veja [LICENSE.md](LICENSE.md).

---

📖 **Full documentation · Documentação completa:** [English (README.en-US.md)](README.en-US.md) · [Português (README.pt-BR.md)](README.pt-BR.md)

# ZIMARO

> ![EN](screenshots/screenshotGB.png) A small third-person shooter sandbox built on the [Godot Engine](https://godotengine.org).
>
> ![PT](screenshots/screenshotBR.png) Um pequeno sandbox de tiro em terceira pessoa construído sobre a [Godot Engine](https://godotengine.org).

[![GitHub stars](https://img.shields.io/github/stars/zimerfeld/ZIMARO?style=for-the-badge&logo=github)](https://github.com/zimerfeld/ZIMARO/stargazers) &nbsp; [![GitHub downloads](https://img.shields.io/github/downloads/zimerfeld/ZIMARO/total?style=for-the-badge&logo=github&label=Downloads)](https://github.com/zimerfeld/ZIMARO/releases)

This game is built and maintained in my free time. If you enjoy ZIMARO, a sponsorship helps keep new features and fixes coming. 💜
Este jogo é construído e mantido no meu tempo livre. Se você curte o ZIMARO, um patrocínio ajuda a manter novas funcionalidades e correções chegando. 💜

[![GitHub Sponsor](https://img.shields.io/badge/Sponsor-zimerfeld-EA4AAA?style=for-the-badge&logo=githubsponsors&logoColor=white)](https://github.com/sponsors/zimerfeld) &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; [![Ko-fi](https://img.shields.io/badge/Ko--fi-Buy%20me%20a%20coffee-FF5E2B?style=for-the-badge&logo=ko-fi&logoColor=white)](https://ko-fi.com/C0D621FCGD)

![Screenshot of ZIMARO](screenshots/screenshot.png)

> ![EN](screenshots/screenshotGB.png) **This file is a high-level bilingual summary.** Full, detailed docs:
> **[📖 English → README.en-US.md](README.en-US.md)** · **[📖 Português → README.pt-BR.md](README.pt-BR.md)**
>
> ![PT](screenshots/screenshotBR.png) **Este arquivo é um resumo bilíngue de alto nível.** Documentação completa e detalhada:
> **[📖 English → README.en-US.md](README.en-US.md)** · **[📖 Português → README.pt-BR.md](README.pt-BR.md)**

---

## Overview · Visão geral

![EN](screenshots/screenshotGB.png) Built on the Godot Engine, ZIMARO is a small third-person
shooter sandbox: a menu-driven flow (character selection, level picker, settings, developer screen,
online play), playable characters that move/aim/jump/shoot (the shot waits for the aim to settle),
allied bots that give the player covering fire, ground and flying enemies (the Red Robot has a
reactive AI that reloads faster, opens fire in range and flees when you close in — enemies now move
with individual variation, no longer slide (animation cadence matched to speed), target the closest
player in their alert radius, and the flyer varies its height smoothly to dive-bomb or escape fire),
per-limb localized damage, several levels, a browsable 3D model library (with a model-orientation axis gizmo), reusable cyberpunk HUD
widgets, per-scene looping background music, debug tooling, EN/PT localization and live (no-Apply) settings.

![PT](screenshots/screenshotBR.png) Construído sobre a Godot Engine, o ZIMARO é um pequeno sandbox de tiro em
terceira pessoa: fluxo por menus (seleção de personagem, seletor de fases, configurações, tela de
desenvolvedor, jogo online), personagens jogáveis que se movem/miram/pulam/atiram (o tiro espera a
mira assentar), bots aliados que dão cobertura ao jogador, inimigos terrestres e voadores (o Red
Robot tem uma IA reativa que recarrega mais rápido, abre fogo no alcance e recua quando você se
aproxima — e os inimigos agora se movem com variação individual, **não deslizam mais** (cadência da
animação casada à velocidade), miram o **player mais próximo** no raio de alerta, e a criatura voadora
**varia a altura suavemente** para mergulhar e bombardear ou subir e escapar de tiros), dano
localizado por membro, várias fases, biblioteca de
modelos 3D navegável (com gizmo de eixos de orientação),
widgets de HUD cyberpunk reutilizáveis, música de fundo por cena em loop, ferramentas de debug, localização EN/PT e configurações ao
vivo (sem botão Aplicar).

## Features · Funcionalidades

![EN](screenshots/screenshotGB.png) Highlights: localized damage (native per-limb 3D colliders, headshots deal extra) with a
per-model, per-limb damage multiplier you can edit right in the Models viewer (saved to one file per
character, in the model's own folder `library3D/<cat>/<model>/limb_config.json`, with a writable `user://` override for in-game edits) where the body type (biped/quadruped/crawler) defines the members and
protruding sub-members (plates, guards) are editable too (and any model with no classified member — e.g. Structures like the bronze statues — gets a single fallback **CORPO** member wrapping the whole model, so a collider can always be defined); a Models viewer with per-category master toggles (rotation, animation,
special effects, audio, colliders — plus, per selected member/sub-member/loose bone, a **collider-geometry
dropdown** (sphere/box/capsule, or "Selecione…" = no collider on a member) and a reusable floating dialog
with live X/Y/Z **offset & scale** that persist instantly and are read back when a character spawns —
member labels — incl. a Bone toggle floating the chosen loose
bone's name) and selector dropdowns — both persisted between
visits, with the drill-down chain restored on reopen; a
developer screen whose debug overlay is split into **Debug 2D** (light
yellow) and **Debug 3D** (light cyan) columns — a master alone shows nothing, each dependent line
must also be selected — with a live **player-model preview** beside the Debug 3D column (a rotating
robot in its own viewport) that reflects the enabled/disabled toggles in real time; performance indicators built on Godot's `Performance` singleton — a toggleable
**Performance HUD** top bar (FPS/NET/RAM/CPU/GPU + a basic/advanced view) plus an always-on
**StabilityGuard** that throttles physics and (in single-player) force-pauses with a full-screen overlay
before RAM/VRAM/collision-pairs/node-count/FPS can freeze or crash the machine — limits calibrated for
real 3D levels, and during an online session it only throttles (never pauses, to avoid breaking netcode);
a floor grid for 3D screens; and an EN/PT localization system where **every screen carries
Português/English buttons** and each scene ships its own JSON dictionaries
(`<scene>/Resources/*.pt.json` + `*.en.json`), merged at load. Online play is **rooms-based**: pick **Host** or **Client** on the Play Online screen. **Host** opens a
room manager to start levels as isolated rooms and, per room, **Play** into it, **Observe** with a
free-fly no-collision camera, **Restart** or **Stop** it (both warn the room's clients with a distinct
"level stopped/restarted by host" notice); **Client** opens a room browser that lists the
running rooms with a **Play** button. Each player's chosen variant/colour shows for everyone,
and other players/enemies are smoothed with a timestamped interpolation buffer for a flicker-free,
high-FPS client view. A pre-session **Optimization** selector picks interpolation (Smooth/Balanced/
Responsive), sync rate (30/60 Hz) and host render (Window/Pure-server); every option (plus the last
Port/IP) is persisted and restored, and the Host/Client screens are full-screen like the rest of the UI.
Each 2D screen (Levels, Play Online, Settings, Developer) carries its own lightweight **animated shader
background** that evokes its purpose (Play Online also frames its border with a **braided-metal wire**
looped by slow, alternating **electric energy**), and every **confirmation window** is built on one reusable
floating-window control (`FloatingWindow`, a `controls2D` scene) — centered text, equal-width buttons, a
standard × close and a modal backdrop — the same base other floating windows can reuse.

![PT](screenshots/screenshotBR.png) Destaques: dano localizado (colliders 3D nativos por membro, headshots causam dano extra) com um
multiplicador de dano por modelo e por membro **editável na própria tela Models** (salvo em um arquivo
por personagem, na pasta do próprio modelo `library3D/<cat>/<modelo>/limb_config.json`, com override gravável em `user://` para edições no jogo), em que o tipo de corpo (bípede/quadrúpede/rastejante) define os membros e
os sub-membros salientes (placas, guardas) também são editáveis (e todo modelo sem membro classificado — ex.: Estruturas como as estátuas de bronze — ganha um único membro **CORPO** de fallback que envolve o modelo inteiro, para sempre dar para definir um collider); um visualizador Models com toggles mestres por categoria (rotação, animação,
efeitos especiais, áudio, colliders — e, por membro/sub-membro/osso avulso selecionado, um **dropdown de
geometria do collider** (esfera/caixa/cápsula, ou "Selecione…" = sem collider no membro) e uma janela
flutuante reutilizável com **afastamento e escala** X/Y/Z ao vivo, que persistem na hora e são relidos
quando um personagem entra em cena — rótulos de membro — incl. um toggle Osso que faz flutuar o nome
do osso avulso escolhido) e dropdowns de seleção — ambos persistidos
entre visitas, com a cadeia de navegação restaurada ao reabrir; uma tela developer cujo overlay de
debug é dividido nas
colunas **Debug 2D** (amarelo claro) e **Debug 3D** (ciano claro) — o master sozinho não mostra
nada, cada linha dependente também precisa ser selecionada — com uma **pré-visualização do modelo do
player** ao lado da coluna Debug 3D (um robô girando no próprio viewport) que reflete os botões
ativado/desativado em tempo real; indicadores de performance sobre o
singleton `Performance` do Godot — uma barra **Performance HUD** opcional (FPS/NET/RAM/CPU/GPU + visão
básica/avançada) mais um **StabilityGuard** sempre-ligado, que reduz a física e (em jogo solo) pausa à força com um
overlay de tela cheia antes que RAM/VRAM/collision pairs/contagem de nós/FPS congelem ou travem a
máquina — com limites calibrados para os níveis 3D reais e, em sessão online, só estrangulando a física
(nunca pausa, p/ não quebrar o netcode); uma
malha no solo
para telas 3D; e um sistema de localização EN/PT em que **toda tela tem botões Português/English** e
cada cena traz seus próprios dicionários JSON (`<cena>/Resources/*.pt.json` + `*.en.json`),
mesclados no carregamento. O jogo online é **por salas**: escolha **Host** ou **Client** na tela Jogar
Online. **Host** abre um gerenciador de salas para iniciar levels como salas isoladas e, por sala,
**Jogar** nela, **Observar** com uma câmera livre sem colisão, **Reiniciar** ou **Parar** (ambos avisam
os clientes daquela sala com um aviso distinto "nível parado/reiniciado pelo host"); **Client**
abre um navegador que lista as salas em execução com um botão **Jogar**. A variante/cor escolhida por cada
jogador aparece para todos, e os outros players/inimigos são suavizados por um buffer de interpolação
com snapshots datados para uma visão do cliente sem flicker e com FPS alto. Um seletor de **Otimização**
pré-sessão escolhe interpolação (Suave/Equilibrado/Responsivo), taxa de sync (30/60 Hz) e render do host
(Janela/Servidor puro); todas as opções (mais a última Porta/IP) são persistidas e recarregadas, e as
telas Host/Client são em tela cheia, no padrão do resto da UI.
Cada tela 2D (Níveis, Jogar Online, Configurações, Developer) tem seu próprio **fundo animado por shader**
(leve) que remete à sua função (a Jogar Online ainda emoldura a borda com um **fio de metal trançado**
percorrido por uma **energia elétrica** lenta e alternada), e toda **janela de confirmação** é montada sobre um controle de janela
flutuante reutilizável (`FloatingWindow`, uma cena `controls2D`) — texto centralizado, botões de largura
uniforme, um × de fechar padrão e fundo modal — a mesma base que outras janelas flutuantes podem reusar.
A **janela de erro global é recuperável** — fechar (× / ESC / **Voltar**) só volta à cena que a chamou,
sem encerrar o jogo. *(EN: the global error window is recoverable — closing it just returns to the calling
scene and never quits the game.)*

> ![EN](screenshots/screenshotGB.png) **On the per-limb hitboxes:** you didn't reinvent Godot's physics; you automated the authoring
> of hitboxes that would be unfeasible to maintain at scale by hand.
>
> ![PT](screenshots/screenshotBR.png) **Sobre as hitboxes por membro:** você não reinventou a física do Godot; você automatizou a
> autoria de hitboxes que, manualmente, seriam inviáveis de manter em escala.

## Requirements & running · Requisitos e execução

![EN](screenshots/screenshotGB.png) Requires **Godot 4.6.2** ([download](https://godotengine.org/download/)). Get the project from
[zimerfeld/ZIMARO](https://github.com/zimerfeld/ZIMARO) (clone or ZIP) and open it in Godot. Git
LFS is not required.

![PT](screenshots/screenshotBR.png) Requer **Godot 4.6.2** ([download](https://godotengine.org/download/)). Pegue o projeto em
[zimerfeld/ZIMARO](https://github.com/zimerfeld/ZIMARO) (clone ou ZIP) e abra no Godot. Git LFS não
é necessário.

## Project structure · Estrutura do projeto

![EN](screenshots/screenshotGB.png) `scenes2D/` (screens, UI, reusable widgets) · `scenes3D/` (levels + Models viewer) · `library3D/`
(3D assets by type) · `effects_shared/` (cross-character helpers) · `autoload/` (global singletons:
crash_handler, player_selection, debug_overlay, locale, stability_guard, performance_hud; Settings is
`scenes2D/settings/config.gd`) · per-scene `Resources/*.pt.json` + `*.en.json` (UI dictionaries) ·
`OBSIDIAN/` (documentation vault).

![PT](screenshots/screenshotBR.png) `scenes2D/` (telas, UI, widgets reutilizáveis) · `scenes3D/` (fases + visualizador Models) ·
`library3D/` (assets 3D por tipo) · `effects_shared/` (helpers entre personagens) · `autoload/`
(singletons globais: crash_handler, player_selection, debug_overlay, locale, stability_guard, performance_hud; o
Settings é `scenes2D/settings/config.gd`) · `Resources/*.pt.json` + `*.en.json` por cena (dicionários
da UI) · `OBSIDIAN/` (cofre de documentação).

![EN](screenshots/screenshotGB.png) **Windows build:** `pwsh -File build_windows.ps1` → `build/windows/ZIMARO.exe` (embedded PCK) + a
desktop shortcut with the app icon. · ![PT](screenshots/screenshotBR.png) **Build Windows:** `pwsh -File build_windows.ps1` → o `.exe`
com PCK embutido + atalho no Desktop com o ícone.

## Controls · Controles

![EN](screenshots/screenshotGB.png) Move (WASD / arrows / stick), look (mouse / right stick), jump (Space), aim (RMB / L2), shoot
(LMB / R2, only while aiming), menu focus with arrow keys, back/quit (Escape — cancels a field edit
first; the menu confirms before quitting), fullscreen (F11 / Alt+Enter), debug info (F3).

![PT](screenshots/screenshotBR.png) Mover (WASD / setas / analógico), olhar (mouse / analógico direito), pular (Espaço), mirar
(botão direito / L2), atirar (botão esquerdo / R2, só mirando), foco dos menus com as setas,
voltar/sair (Escape — cancela primeiro um campo em edição; o menu confirma antes de sair), tela
cheia (F11 / Alt+Enter), info de debug (F3).

## Code formatting · Formatação de código

![EN](screenshots/screenshotGB.png) All text files use UTF-8 **without BOM**, LF endings, no trailing whitespace, and a trailing
newline — enforced by [`file_format.sh`](file_format.sh) (run `bash file_format.sh` from Git Bash).

![PT](screenshots/screenshotBR.png) Todos os arquivos de texto usam UTF-8 **sem BOM**, quebras LF, sem espaços ao fim e com quebra de
linha final — garantido por [`file_format.sh`](file_format.sh) (rode `bash file_format.sh` no Git Bash).

## Documentation · Documentação

![EN](screenshots/screenshotGB.png) The detailed docs ([README.en-US.md](README.en-US.md) / [README.pt-BR.md](README.pt-BR.md)) and
the [`OBSIDIAN/`](OBSIDIAN) vault are the project knowledge base and are kept up to date at the end of
every change.

![PT](screenshots/screenshotBR.png) As docs detalhadas ([README.en-US.md](README.en-US.md) / [README.pt-BR.md](README.pt-BR.md)) e o
cofre [`OBSIDIAN/`](OBSIDIAN) são a base de conhecimento do projeto e são mantidos atualizados ao
final de cada mudança.

## License · Licença

![EN](screenshots/screenshotGB.png) / ![PT](screenshots/screenshotBR.png) See / Veja [LICENSE.md](LICENSE.md).

---

📖 **Full documentation · Documentação completa:** [English (README.en-US.md)](README.en-US.md) · [Português (README.pt-BR.md)](README.pt-BR.md)

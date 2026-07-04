---
tipo: fluxo
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-07-04
---

# 🎬 Fluxo de Cenas

`main.tscn` (Node, `main.gd`) é um **roteador** E a **tela inicial**: instancia
cada tela como filha de si mesmo (não usa `SceneTree.change_scene`), reagindo aos
sinais `replace_main_scene` e `quit`. Por isso `get_tree().current_scene` continua
sendo `main` durante todo o jogo.

A abertura vive na sub-árvore `StartScreen` (filha da raiz, já montada em
`main.tscn`): robô 3D (`player.glb`) sobre um **pedestal** como fundo + overlay 2D
(título/leitura/status). Após `minimum_wait_time` (~2 s) `main.gd` faz fade e troca
a `StartScreen` pelo menu. Não há mais `StartScreens/StartScreen.tscn` (removido).
A `StartScreen` entra no grupo `no_debug_overlay` (sem tooltips de debug).

```
main.tscn (main.gd — roteador + tela inicial: robô no pedestal + overlay)
   └─► menu.tscn (menu.gd)
          ├─► Jogar Offline ─► chooseplayer.tscn ─► levels.tscn ─┬─► level_1.tscn
          │     (online_mode=false)                              └─► level_2.tscn   (carrega o nível direto)
          ├─► Jogar Online ──► chooseplayer.tscn ─► levels.tscn ─► playonline.tscn ─► nível escolhido
          │     (online_mode=true)                  (escolhe nível)   (Host/Connect)
          ├─► settings.tscn (UI: settings.gd)
          ├─► developer.tscn ─┬─► models.tscn   (visualizador de modelos 3D)
          │                   └─► controls.tscn (visualizador de controles 2D)
          └─► Sair → quit
```

(`Exported.tscn` / galeria "Exportados" não existe mais — o botão foi removido da tela
models. `cyberpunkhud` é cena avulsa de preview, fora do fluxo de navegação.)

---

## Pastas

- **scenes2D/** (telas + UI): `main` (roteador), `menu`, `chooseplayer`, `levels`, `settings`, `developer`, `playonline`, `controls` (viewer 2D) e `controls2D/` (widgets de HUD reutilizáveis: crosshair, minimap_panel, vitals_panel, pause_menu, scanlines, cyberpunk_hud, …)
- **scenes3D/** (níveis + ferramentas 3D): `level_1`, `level_2`, `models` (viewer)
- **library3D/** (assets 3D por tipo): `characters`, `propulsores`, `structures`, `weapons`, + `geometry`/`textures` (suporte)
- **effects_shared/** (helpers entre personagens): `limb_colliders.gd`, `body_parts.gd`, `weapon_parts.gd` + assets de blast/sombra
- **autoload/**: `crash_handler`, `player_selection`, `debug_overlay` (o **Settings** fica em `scenes2D/settings/config.gd`)
- **themes/**: temas (`ui_theme.tres`, `cyberpunk.tres`) · **addons/**: plugin `godot_ai` (MCP) · **OBSIDIAN/**: este cofre

## Autoloads

- **Settings** → `scenes2D/settings/config.gd` (gerenciador de config: `config_file`, `DEFAULTS`, `save_settings()`)
- **CrashHandler** → popup global de erro **NÃO-DESTRUTIVO** (2026-07-02): × / ESC / botão **"Voltar"** só
  FECHAM a janela e devolvem o foco à cena que chamou — **não encerram mais o jogo** (erro de porta/conexão/
  validação é recuperável). Com `retry_callback`, mostra também **"Tentar Novamente"** (re-executa a ação).
  Antes o botão era "Fechar Jogo" e ×/ESC davam `get_tree().quit()`; isso inclusive matava o jogo numa
  simples validação da tela Models (`models.gd`, "osso já é Membro") — corrigido junto.
- **PlayerSelection** → personagem escolhido
- **DebugOverlay** → overlays de debug (ver abaixo)
- **UINav** → `autoload/ui_nav.gd` (navegação por teclado das telas 2D: `focus_first`, `first_focusable`, `cancel_active_edit` — ver [[#Navegação por teclado e ESC]])

---

## main.gd

- Entry point (`run/main_scene`)
- `change_scene_to_packed()` remove os filhos e instancia a nova tela
- Conecta `quit` → `go_to_main_menu()` e `replace_main_scene` → troca de cena (se a tela tiver o sinal)

## Telas (UI)

- **menu** — Jogar (→ chooseplayer), Configurações (→ settings), Modo Developer (→ developer), **Jogar Online** (mesma sequência do offline: chooseplayer → levels → playonline), Sair. **Os botões "Jogar Offline" e "Jogar Online" só diferem na flag `PlayerSelection.online_mode`** — ambos abrem `chooseplayer`; é a tela `levels` que, vendo a flag, carrega o nível direto (offline) ou abre `playonline` (online). O rótulo "Jogar Offline" vem da localização (`menu.*.json`, chave `"PLAY"`). No `_ready` (antes de exibir a tela) **lê do disco e aplica TODAS as configs** (2026-06-16): `Settings.load_settings()` + `apply_graphics_settings()` + `apply_window_resolution()` (redimensiona a janela p/ a resolução salva se em modo Janela) + `apply_audio_settings()` (mute de Música/SFX).
- **settings** — `config.gd` (autoload **Settings**) + `settings.gd` (UI). Abas Display / Resolution / Antialiasing / Lighting / Effects / Audio / **Debug**. **Sem botão "Aplicar" (2026-06-16):** cada opção **persiste + aplica na hora** ao mudar (sinal `ButtonGroup.pressed` → `_apply_settings`). A **resolução de vídeo** é à parte: confirma num diálogo (Sim/Não) — "Sim" aplica e fixa o modo Janela (senão o próximo apply voltaria pra fullscreen e desfaria), "Não" volta o dropdown pra seleção persistida. A janela é **limitada à área útil da tela** (`screen_get_usable_rect`) e centralizada, então uma resolução maior que o monitor (4K/8K) não empurra a janela — e a barra de botões do rodapé — pra fora do visível (`_apply_video_resolution` / `Settings.apply_window_resolution`). Botão **Reset** (à direita de Voltar, 2026-06-16): mesma confirmação Sim/Não → `Settings.reset_to_defaults()` (reescreve tudo com `DEFAULTS`, baseline de hardware comum) + recarrega controles + aplica na hora. `DEFAULTS` é fonte única: vale também quando não há config salva (load_settings preenche). Só **Voltar** sai da tela. **Padrões-chave (2026-06-23):** Modo de Exibição = **Tela Cheia Exclusiva**, Limite de FPS = **60**, Escala de Resolução = **Equilibrado** (`1/1.7`), Filtro de Escala = **Bilinear**, Bloom = **Desativado**, Névoa Volumétrica = **Desativado**. **Filtro de Escala (2026-06-23):** opções **Bilinear · AMD FSR 1.0 · AMD FSR 2.2** (MetalFX só no macOS). O FSR 2.2 foi **re-adicionado** e o revert silencioso p/ Bilinear no `load_settings` **removido** — todas as opções persistem. ⚠️ FSR 2.2 pode disparar "Texture dimensions exceed device maximum" com escala em supersampling (Nativo); com o default Equilibrado (downscale) é o uso correto dele. **TAA × upscaler temporal (2026-06-26):** o `use_taa` é aplicado como `taa AND not Settings.is_temporal_upscaler(scaling_3d_mode)` — **FSR 2 / MetalFX Temporal** já fazem AA temporal e são incompatíveis com TAA (a engine desligaria o TAA e emitiria warning), então `config.gd` (`apply_graphics_settings`) e `settings.gd` garantem a exclusividade via o helper `Settings.is_temporal_upscaler()`.
- **developer** — **(refeito 2026-06-23)** só **Geral** (HUD FPS · Monitor de Saúde) + **Debug 2D** (coluna única: Debug 2D · Show TYPE · Show Name · Show ID · **Show Tab** ← novo, abaixo de Show ID: tooltip branco com o índice de Tab/foco de cada controle 2D) + botões **Modelos 3D** / **Controles 2D**. A **coluna Debug 3D inteira** e o **painel de preview 3D** foram **removidos** — a inspeção 3D (Malha, Linhas do Esqueleto, membros, etc.) migrou para a tela **Models** (toggles próprios sobre o preview). O overlay global não aplica mais overlays 3D em levels/chooseplayer (só Debug 2D). Ver [[🐞 debug-overlay]] e [[🗿 biblioteca-de-modelos]].
- **models** — navegador/extrator de modelos 3D: Categoria → Modelo → Malha (malhas distintas), preview rotacionável, "Salvar como cena 3D" (extrai p/ `library/extracted/`) e botão "Exportados". Detalhes em [[🗿 biblioteca-de-modelos]]
- **Exported** (`library/extracted/Exported.tscn`) — galeria que exibe todas as cenas de `library/extracted/` lado a lado; volta para models
- **chooseplayer** — escolhe personagem (modelo 3D girando) → levels
- **levels** — Level 1 / Level 2, load assíncrono. `_select_level()` ramifica: **offline** carrega o nível direto; **online** (`PlayerSelection.online_mode`) guarda o caminho em `PlayerSelection.level_path` e abre `playonline`. Cada linha tem um botão de **template** que abre o **Gerenciador de Templates** (`scenes2D/level_templates/level_template_dialog.gd`, renomeado de "Templates de Level" em 2026-06-29; antes um `Window` nativo, **agora um controlador sobre `FloatingWindow`** — herda o tema 2D e o Debug 2D funciona sobre ele). A mesma janela é aberta pela tela `host_session`. Cada **entrada** de spawn tem um campo **"Nome da entrada"** (2026-07-01) que renomeia o texto exibido no dropdown `Entries` (ex-`EntryPicker`); vazio → rótulo automático `"N. facção modelo xN"`. O nome é salvo por entrada em `LevelTemplateManager` (chave `name`).
- **playonline** — só **Host / Connect** (porta + endereço). **Não há seletor de nível**: o nível já foi escolhido na tela `levels` (fluxo online) e vem em `PlayerSelection.level_path`; o servidor dedicado headless faz fallback p/ `level_1` (`DEFAULT_ROOM_LEVEL`, que entra direto aqui e abre uma sala). **Os níveis são jogáveis online** — `level_1` e `level_2` ganharam `MultiplayerSpawner` + `PlayerSpawnpoints` (ver [[🌐 multiplayer]]).

---

## Navegação por teclado e ESC

Centralizado no autoload **UINav** (`autoload/ui_nav.gd`), aplicado por **todas** as telas 2D
(`menu`, `settings`, `levels`, `chooseplayer`, `controls`, `developer`, `playonline`,
`host_session`, `client_session`):

- **Setas do teclado** — o Godot já mapeia `ui_up/down/left/right` para as setas e calcula os
  vizinhos de foco; só faltava o **foco inicial**. Cada tela dá foco ao 1º controle focável no
  `_ready` (deferido). `UINav.focus_first(self)` (1º em ordem de árvore) e `UINav.focus_tab_one(self)`
  (cabeça do anel, via `tab_one_control`) são equivalentes p/ telas (sem `last` movido).
- **Foco no Tab = 1 ao abrir (2026-06-29)** — **toda UI e janela** começa com o **controle de Tab = 1
  em foco**: telas chamam `UINav.focus_tab_one(self)`; a `FloatingWindow` foca em `_grab_initial_focus`
  o `UINav.tab_one_control(self, _close_button)` (1º do conteúdo/rodapé, NUNCA o ×, que é o último).
  `tab_one_control(root, last)` = cabeça do anel = `collect_focusables(root)` menos `last`, 1º item.
- **Ordem de Tab do `menu` (2026-06-29)** — a sequência desejada
  **Play (1) → PlayOnline (2) → Settings (3) → Developer (4) → Quit (5) → Português (6) → English (7)
  → Debug 2D (8)** é a própria **ordem da árvore** (os 5 botões do `MenuColumn`, depois a `LangBar` da
  `Actions` e por fim o **toggle `Debug2D`** que o DebugOverlay injeta no FIM da `Actions`). Agora o
  `menu.gd` **liga o anel** com `UINav.wire_tab_ring(self)` (helper `_wire_tab_order`) no `_ready`
  (deferido), igual à `levels` e às sessões — fechando `1 → … → 8 → 1` com índices incrementais de 1.
  **Não** há `focus_next`/`focus_previous` no `.tscn` (uma tentativa anterior de hardcodar o anel nos 5
  botões EXCLUÍA idioma/Debug2D — foi revertida); o anel é montado em runtime para incluir o `Debug2D`
  injetado e respeitar o idioma ativo (que fica desabilitado/fora do anel). **Re-liga** quando o
  DebugOverlay injeta o toggle na `Actions` (sinal `child_entered_tree`) e quando um botão de idioma
  habilita/desabilita (`_update_language_buttons`). Foco inicial no Tab = 1 via `UINav.focus_tab_one`.
- **Helpers de navegação `UINav` — ver [[🔁 navegacao-tab]]** — nota dedicada com a tabela de
  cada helper (`wire_tab_ring`, `focus_tab_one`, `tab_one_control`, `focus_first`, `first_focusable`,
  `collect_focusables`, `cancel_active_edit`), a **matriz cena×helper**, a explicação do `TAB: -` do
  Debug 2D e a lista de outros helpers do projeto (FloatingDialog/FloatingWindow/Locale/CrashHandler).
- **Anel de Tab compartilhado — `UINav.wire_tab_ring(root, last=null)` (2026-06-29)** — helper único
  que coleta **todos** os controles focáveis sob `root` em **ordem de árvore** (= ordem de leitura: cada
  controle do topo p/ baixo e, numa linha/HBox, da esquerda p/ a direita) via `collect_focusables` e
  amarra `focus_next`/`focus_previous` num **anel fechado** `1 → 2 → … → N → 1`. Garante **índices de
  Tab incrementais de 1** (linha "Tab" do [[🐞 debug-overlay]]). O parâmetro **`last`** (opcional):
  se informado, esse controle vai p/ o **FIM do anel** (maior índice) — usado pelo × das janelas
  flutuantes. Reaplicável quando o conjunto de focáveis muda (toggle injetado, botão que habilita/desabilita).
- **Foco contido nas janelas flutuantes — × por ÚLTIMO (2026-06-29)** — `FloatingWindow.wire_focus_ring()`
  (público) delega a `UINav.wire_tab_ring(self, _close_button)`: o anel fica `conteúdo → rodapé → ×
  (Close) → 1º`, com o **× sempre por ÚLTIMO** (maior valor de Tab da janela), mesmo o × vindo ANTES na
  árvore. Montado no `popup_centered` (rodapé já criado); o dono re-liga via `_win.wire_focus_ring()` ao
  habilitar/desabilitar campos. Inclui **qualquer controle focável** do conteúdo (OptionButton/LineEdit/
  SpinBox), não só o rodapé. Sem o anel o Tab **vazava para a UI de fundo** e o **× nunca era alcançado**.
  Para a **numeração** do Debug 2D refletir isso, `DebugOverlay._tab_chain_start` começa a contar **depois
  do ×** quando há janela flutuante aberta (o fundo está suprimido), então o × recebe o **maior** `TAB: n`.
  Vale para todo `FloatingDialog` (ex.: "Deseja sair do Zimaro ?") e p/ as janelas **Gerenciador de
  Templates** / **Gerenciador de Música**. Os botões do rodapé têm **nome por papel** (antes `@Button@…`):
  `confirm` → **`Yes`/`No`**, `alert` → **`Ok`** (o TEXTO segue traduzido; só o nó foi nomeado).
- **Ordem de Tab da `levels` (2026-06-29)** — a tela liga o anel com `UINav.wire_tab_ring(self)` no
  `_ready` (deferido): **Level 1 (1) → Template 1 (2) → Level 2 (3) → Template 2 (4) → Voltar (5) →
  Português (6) → English (7) → Debug 2D (8)**, ordem de leitura. *(A linha **Level Base** foi
  removida em 2026-07-01 junto com o nível — ver [[🚪 salas]].)*
  Re-liga quando o DebugOverlay **injeta o toggle `Debug2D`** na `Actions` (sinal `child_entered_tree`)
  e quando um botão de idioma **habilita/desabilita** (o idioma ativo fica fora do anel).
- **Ordem de Tab da `playonline` (2026-06-29)** — a tela liga o anel com `UINav.wire_tab_ring(self)`
  (helper `_wire_tab_order`) no `_ready` (deferido), ordem de leitura: **Player name (1) → Porta/spin (2)
  → Histórico de porta (3) → IP/Domínio (4) → Histórico de IP (5) → otimização: Render do host (6),
  Taxa de sync (7), Suavização↔Resposta (8) → Gerenciar Salas (9) → Entrar em Salas (10) → Voltar (11)
  → Português (12) → English (13) → Debug 2D (14)**. As 3 colunas de otimização são criadas em
  `_build_optimization_options` ANTES de ligar o anel, então já entram na sequência. Re-liga quando o
  DebugOverlay **injeta o toggle `Debug2D`** na `Actions` (sinal `child_entered_tree`) e quando um botão
  de idioma **habilita/desabilita** (`_update_language_buttons`). Foco inicial no Tab = 1 via
  `UINav.focus_tab_one`. (Antes a tela só fazia `manage_rooms_button.grab_focus()`, sem anel explícito.)
- **Tab + Debug 2D em `host_session` / `client_session` (2026-06-29; estáticas em 2026-06-30)** — antes
  eram telas montadas INTEIRAS em código. **Agora o scaffold fixo é ESTÁTICO no `.tscn`** (painel com
  textura/véu/`SignalLayer` shader, título, `StartRow` com pickers no host, lista, barra **`Actions`** +
  **`Back`** — renomeado de `BackButton` na varredura de nomes de 2026-07-03, junto com
  `ManageTemplates`/`Start`/`Levels`/`Templates`); o código só popula os pickers, monta as
  **linhas de sala** dinâmicas (`_refresh_rooms`)
  e ajusta o `aspect` do shader. O DebugOverlay injeta o `Debug2D` na `Actions`. O **`tab_order` é numerado
  por CÓDIGO** no `_rewire_tab` (não dá p/ fixar no `.tscn` porque o nº de salas varia): controles da grade
  → botões habilitados de cada linha de sala (desabilitados ficam fora) → **Voltar** → **Debug 2D**; foco
  inicial no Tab = 1. `collect_focusables` ignora `is_queued_for_deletion()` (linhas recém-liberadas).
- **Anel de Tab nas telas restantes — `chooseplayer` / `settings` / `developer` / `controls` (2026-06-29)**
  — as quatro telas que ainda usavam só `UINav.focus_first` passaram ao padrão `focus_tab_one` +
  `_wire_tab_order` (→ `UINav.wire_tab_ring(self)`), re-ligando no `child_entered_tree` da `Actions`
  (toggle Debug 2D) e no `_update_language_buttons`. Casos extras: **`settings`** re-liga no
  `TabContainer.tab_changed` (só os focáveis da aba VISÍVEL entram no anel); **`developer`** re-liga no
  `_update_subrows_enabled` (as sub-toggles do Debug 2D entram/saem do anel com o master). Com isso,
  **todas as telas cheias** ligam o anel — vira regra do projeto (`CLAUDE.md`). Resta só o overlay
  `pause_menu` (opcional). Detalhes/matriz em [[🔁 navegacao-tab]].
- **Regra do ESC** (ação `quit`, mapeada a Esc + Select do gamepad) — sempre **interrompe primeiro o
  preenchimento de um campo/seleção** antes de voltar de tela. No `_input` de cada tela:
  `if UINav.cancel_active_edit(get_viewport(), <fallback>): consome e RETORNA`. `cancel_active_edit`
  encerra a edição se o foco é um `LineEdit` (inclui o editor interno de um `SpinBox` — ex.: IP/porta
  do `playonline`), devolvendo o foco ao `fallback`. **Só o 2º ESC** (sem campo em edição) navega de
  volta. O dropdown de `OptionButton` já fecha no ESC nativamente (popup próprio).
- **Confirmação de saída no menu** — `menu._on_quit_pressed` (botão Sair **e** ESC) abre um
  janela `FloatingDialog.confirm` central **"Deseja sair do Zimaro ?"** (Sim/Não); só fecha o jogo no "Sim". As
  strings ficam em `menu.*.json` (`"Deseja sair do Zimaro ?"`, `"Sair do jogo"`); Sim/Não reusam a
  tabela global do `Locale` (de `settings.*.json`).

---

## Sinais Entre Cenas

| Sinal | Emitido por | Recebido por |
|---|---|---|
| `replace_main_scene(scene)` | menu, settings, chooseplayer, developer, models, Exported, levels | `main.gd` → troca de cena |
| `quit` | chooseplayer, developer | `main.gd` → `go_to_main_menu()` |

---

## Relacionado

- [[🧭 main-gd]]
- [[🌐 multiplayer]]
- [[📄 formatacao]]

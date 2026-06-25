# Fluxo de Cenas

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
          │     (online_mode=false)                              ├─► level_2.tscn   (carrega o nível direto)
          │                                                      └─► level_base.tscn
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
- **scenes3D/** (níveis + ferramentas 3D): `level_1`, `level_2`, `level_base`, `models` (viewer)
- **library3D/** (assets 3D por tipo): `characters`, `propulsores`, `structures`, `weapons`, + `geometry`/`textures` (suporte)
- **effects_shared/** (helpers entre personagens): `limb_colliders.gd`, `body_parts.gd`, `weapon_parts.gd` + assets de blast/sombra
- **autoload/**: `crash_handler`, `player_selection`, `debug_overlay` (o **Settings** fica em `scenes2D/settings/config.gd`)
- **themes/**: temas (`ui_theme.tres`, `cyberpunk.tres`) · **addons/**: plugin `godot_ai` (MCP) · **OBSIDIAN/**: este cofre

## Autoloads

- **Settings** → `scenes2D/settings/config.gd` (gerenciador de config: `config_file`, `DEFAULTS`, `save_settings()`)
- **CrashHandler** → popup global de erro
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
- **settings** — `config.gd` (autoload **Settings**) + `settings.gd` (UI). Abas Display / Resolution / Antialiasing / Lighting / Effects / Audio / **Debug**. **Sem botão "Aplicar" (2026-06-16):** cada opção **persiste + aplica na hora** ao mudar (sinal `ButtonGroup.pressed` → `_apply_settings`). A **resolução de vídeo** é à parte: confirma num diálogo (Sim/Não) — "Sim" aplica e fixa o modo Janela (senão o próximo apply voltaria pra fullscreen e desfaria), "Não" volta o dropdown pra seleção persistida. A janela é **limitada à área útil da tela** (`screen_get_usable_rect`) e centralizada, então uma resolução maior que o monitor (4K/8K) não empurra a janela — e a barra de botões do rodapé — pra fora do visível (`_apply_video_resolution` / `Settings.apply_window_resolution`). Botão **Reset** (à direita de Voltar, 2026-06-16): mesma confirmação Sim/Não → `Settings.reset_to_defaults()` (reescreve tudo com `DEFAULTS`, baseline de hardware comum) + recarrega controles + aplica na hora. `DEFAULTS` é fonte única: vale também quando não há config salva (load_settings preenche). Só **Voltar** sai da tela. **Padrões-chave (2026-06-23):** Modo de Exibição = **Tela Cheia Exclusiva**, Limite de FPS = **60**, Escala de Resolução = **Equilibrado** (`1/1.7`), Filtro de Escala = **Bilinear**, Bloom = **Desativado**, Névoa Volumétrica = **Desativado**. **Filtro de Escala (2026-06-23):** opções **Bilinear · AMD FSR 1.0 · AMD FSR 2.2** (MetalFX só no macOS). O FSR 2.2 foi **re-adicionado** e o revert silencioso p/ Bilinear no `load_settings` **removido** — todas as opções persistem. ⚠️ FSR 2.2 pode disparar "Texture dimensions exceed device maximum" com escala em supersampling (Nativo); com o default Equilibrado (downscale) é o uso correto dele.
- **developer** — **(refeito 2026-06-23)** só **Geral** (HUD FPS · Monitor de Saúde) + **Debug 2D** (coluna única: Debug 2D · Show TYPE · Show Name · Show ID · **Show Tab** ← novo, abaixo de Show ID: tooltip branco com o índice de Tab/foco de cada controle 2D) + botões **Modelos 3D** / **Controles 2D**. A **coluna Debug 3D inteira** e o **painel de preview 3D** foram **removidos** — a inspeção 3D (Malha, Linhas do Esqueleto, membros, etc.) migrou para a tela **Models** (toggles próprios sobre o preview). O overlay global não aplica mais overlays 3D em levels/chooseplayer (só Debug 2D). Ver [[sistemas/debug-overlay]] e [[sistemas/biblioteca-de-modelos]].
- **models** — navegador/extrator de modelos 3D: Categoria → Modelo → Malha (malhas distintas), preview rotacionável, "Salvar como cena 3D" (extrai p/ `library/extracted/`) e botão "Exportados". Detalhes em [[sistemas/biblioteca-de-modelos]]
- **Exported** (`library/extracted/Exported.tscn`) — galeria que exibe todas as cenas de `library/extracted/` lado a lado; volta para models
- **chooseplayer** — escolhe personagem (modelo 3D girando) → levels
- **levels** — Level 1 / Level 2 / Level Base, load assíncrono. `_select_level()` ramifica: **offline** carrega o nível direto; **online** (`PlayerSelection.online_mode`) guarda o caminho em `PlayerSelection.level_path` e abre `playonline`.
- **playonline** — só **Host / Connect** (porta + endereço). **Não há seletor de nível**: o nível já foi escolhido na tela `levels` (fluxo online) e vem em `PlayerSelection.level_path`; `_selected_level()` faz fallback p/ `level_base` (ex.: servidor dedicado headless, que entra direto aqui). `_on_host_pressed`/`_on_connect_pressed` carregam esse nível. **Agora os 3 níveis são jogáveis online** — `level_1` e `level_2` ganharam `MultiplayerSpawner` + `PlayerSpawnpoints` (ver [[sistemas/multiplayer]]).

---

## Navegação por teclado e ESC

Centralizado no autoload **UINav** (`autoload/ui_nav.gd`), aplicado por **todas** as telas 2D
(`menu`, `settings`, `levels`, `chooseplayer`, `controls`, `developer`, `playonline`):

- **Setas do teclado** — o Godot já mapeia `ui_up/down/left/right` para as setas e calcula os
  vizinhos de foco; só faltava o **foco inicial**. Cada tela chama `UINav.focus_first(self)` no
  `_ready` (deferido) — dá foco ao 1º controle focável visível e não desabilitado, em ordem de
  árvore. O `menu` já focava o botão Play; o `playonline` foca o botão **Host**.
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

- [[arquivos-chave/main-gd]]
- [[sistemas/multiplayer]]
- [[convencoes/formatacao]]

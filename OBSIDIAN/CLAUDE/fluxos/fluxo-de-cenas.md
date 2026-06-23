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
- **ui/** + **themes/**: temas (`ui_theme.tres`, `cyberpunk.tres`) · **tools/**+**_gen/**: geradores headless `gen_*.gd` · **addons/**: plugin `godot_ai` (MCP) · **OBSIDIAN/**: este cofre

## Autoloads

- **Settings** → `scenes2D/settings/config.gd` (gerenciador de config: `config_file`, `DEFAULTS`, `save_settings()`)
- **CrashHandler** → popup global de erro
- **PlayerSelection** → personagem escolhido
- **DebugOverlay** → overlays de debug (ver abaixo)

---

## main.gd

- Entry point (`run/main_scene`)
- `change_scene_to_packed()` remove os filhos e instancia a nova tela
- Conecta `quit` → `go_to_main_menu()` e `replace_main_scene` → troca de cena (se a tela tiver o sinal)

## Telas (UI)

- **menu** — Jogar (→ chooseplayer), Configurações (→ settings), Modo Developer (→ developer), **Jogar Online** (mesma sequência do offline: chooseplayer → levels → playonline), Sair. **Os botões "Jogar Offline" e "Jogar Online" só diferem na flag `PlayerSelection.online_mode`** — ambos abrem `chooseplayer`; é a tela `levels` que, vendo a flag, carrega o nível direto (offline) ou abre `playonline` (online). O rótulo "Jogar Offline" vem da localização (`menu.*.json`, chave `"PLAY"`). No `_ready` (antes de exibir a tela) **lê do disco e aplica TODAS as configs** (2026-06-16): `Settings.load_settings()` + `apply_graphics_settings()` + `apply_window_resolution()` (redimensiona a janela p/ a resolução salva se em modo Janela) + `apply_audio_settings()` (mute de Música/SFX).
- **settings** — `config.gd` (autoload **Settings**) + `settings.gd` (UI). Abas Display / Resolution / Antialiasing / Lighting / Effects / Audio / **Debug**. **Sem botão "Aplicar" (2026-06-16):** cada opção **persiste + aplica na hora** ao mudar (sinal `ButtonGroup.pressed` → `_apply_settings`). A **resolução de vídeo** é à parte: confirma num diálogo (Sim/Não) — "Sim" aplica e fixa o modo Janela (senão o próximo apply voltaria pra fullscreen e desfaria), "Não" volta o dropdown pra seleção persistida. A janela é **limitada à área útil da tela** (`screen_get_usable_rect`) e centralizada, então uma resolução maior que o monitor (4K/8K) não empurra a janela — e a barra de botões do rodapé — pra fora do visível (`_apply_video_resolution` / `Settings.apply_window_resolution`). Botão **Reset** (à direita de Voltar, 2026-06-16): mesma confirmação Sim/Não → `Settings.reset_to_defaults()` (reescreve tudo com `DEFAULTS`, baseline de hardware comum) + recarrega controles + aplica na hora. `DEFAULTS` é fonte única: vale também quando não há config salva (load_settings preenche). Só **Voltar** sai da tela.
- **developer** — toggles estilo Disabled/Enabled (HUD FPS · Malha no Solo · Debug 2D · Debug 3D · Show TYPE · Show Name · Show ID · **Show Membros** · **Show Skeleton3D** · **Show Mesh3D**) + botões **Modelos 3D** / **Controles 2D**. **Três sub-switches do Debug 3D (2026-06-17):** só fazem efeito **enquanto Debug 3D está ligado**, e seus botões ficam **desabilitados** com Debug 3D desligado (`developer.gd._update_debug3d_subrows_enabled`, lista `_DEBUG3D_SUBROWS`):
  - **Show Membros** — rótulos de membro (CABEÇA/TRONCO/BRAÇO…). `_line_visible("member")` = `debug_3d AND show_members`; o scan de `Skeleton3D` só ocorre com Debug 3D ligado. (Rótulo era "Membros:" → agora **"Show Membros:"**.)
  - **Show Skeleton3D** — desenha os **ossos** como linhas brancas (um `MeshInstance3D` com `ImmediateMesh` preso ao `Skeleton3D`, redesenhado **a cada frame** em `_process` a partir de `get_bone_global_pose`, então acompanha a animação). `_add_skeleton_lines`/`_update_skeleton_lines`.
  - **Show Mesh3D** — desenha a **caixa AABB** (wireframe ciano) de cada `MeshInstance3D`, filha da malha (segue o transform). `_add_mesh_box`.
  - Gizmos marcados com `_DBG3D_META`, ignorados pelo scan e removidos no `refresh()` via `_remove_3d_gizmos` (**`free()` imediato** — evita colisão de nome com o gizmo recriado no mesmo frame).
- **models** — navegador/extrator de modelos 3D: Categoria → Modelo → Malha (malhas distintas), preview rotacionável, "Salvar como cena 3D" (extrai p/ `library/extracted/`) e botão "Exportados". Detalhes em [[sistemas/biblioteca-de-modelos]]
- **Exported** (`library/extracted/Exported.tscn`) — galeria que exibe todas as cenas de `library/extracted/` lado a lado; volta para models
- **chooseplayer** — escolhe personagem (modelo 3D girando) → levels
- **levels** — Level 1 / Level 2 / Level Base, load assíncrono. `_select_level()` ramifica: **offline** carrega o nível direto; **online** (`PlayerSelection.online_mode`) guarda o caminho em `PlayerSelection.level_path` e abre `playonline`.
- **playonline** — só **Host / Connect** (porta + endereço). **Não há seletor de nível**: o nível já foi escolhido na tela `levels` (fluxo online) e vem em `PlayerSelection.level_path`; `_selected_level()` faz fallback p/ `level_base` (ex.: servidor dedicado headless, que entra direto aqui). `_on_host_pressed`/`_on_connect_pressed` carregam esse nível. **Agora os 3 níveis são jogáveis online** — `level_1` e `level_2` ganharam `MultiplayerSpawner` + `PlayerSpawnpoints` (ver [[sistemas/multiplayer]]).

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

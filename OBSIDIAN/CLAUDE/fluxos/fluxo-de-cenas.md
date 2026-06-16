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
          ├─► chooseplayer.tscn ─► levels.tscn ─┬─► level_1.tscn
          │                                     └─► level_base.tscn
          ├─► settings.tscn (UI: settings.gd)
          ├─► developer.tscn ─► models.tscn ─► Exported.tscn (galeria)
          ├─► (Play Online: host / connect) ─► level_base.tscn
          └─► Sair → quit
```

---

## Pastas

- **scenes2D/** (telas de UI): `menu`, `settings`, `chooseplayer`, `developer`, `levels`
- **scenes3D/** (conteúdo 3D): `players`, `enemies`, `door`, `level_1`, `level_base`, `models`

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

- **menu** — Jogar (→ chooseplayer), Configurações (→ settings), Modo Developer (→ developer), Play Online (→ level_base), Sair. No `_ready` (antes de exibir a tela) **lê do disco e aplica TODAS as configs** (2026-06-16): `Settings.load_settings()` + `apply_graphics_settings()` + `apply_window_resolution()` (redimensiona a janela p/ a resolução salva se em modo Janela) + `apply_audio_settings()` (mute de Música/SFX).
- **settings** — `config.gd` (autoload **Settings**) + `settings.gd` (UI). Abas Display / Resolution / Antialiasing / Lighting / Effects / Audio / **Debug**. **Sem botão "Aplicar" (2026-06-16):** cada opção **persiste + aplica na hora** ao mudar (sinal `ButtonGroup.pressed` → `_apply_settings`). A **resolução de vídeo** é à parte: confirma num diálogo (Sim/Não) — "Sim" aplica e fixa o modo Janela (senão o próximo apply voltaria pra fullscreen e desfaria), "Não" volta o dropdown pra seleção persistida. A janela é **limitada à área útil da tela** (`screen_get_usable_rect`) e centralizada, então uma resolução maior que o monitor (4K/8K) não empurra a janela — e a barra de botões do rodapé — pra fora do visível (`_apply_video_resolution` / `Settings.apply_window_resolution`). Botão **Reset** (à direita de Voltar, 2026-06-16): mesma confirmação Sim/Não → `Settings.reset_to_defaults()` (reescreve tudo com `DEFAULTS`, baseline de hardware comum) + recarrega controles + aplica na hora. `DEFAULTS` é fonte única: vale também quando não há config salva (load_settings preenche). Só **Voltar** sai da tela.
- **developer** — toggles HUD FPS / Malha no Solo (estilo Disabled/Enabled) + botão **Modelos 3D**
- **models** — navegador/extrator de modelos 3D: Categoria → Modelo → Malha (malhas distintas), preview rotacionável, "Salvar como cena 3D" (extrai p/ `library/extracted/`) e botão "Exportados". Detalhes em [[sistemas/biblioteca-de-modelos]]
- **Exported** (`library/extracted/Exported.tscn`) — galeria que exibe todas as cenas de `library/extracted/` lado a lado; volta para models
- **chooseplayer** — escolhe personagem (modelo 3D girando) → levels
- **levels** — Level 1 (`scenes3D/level_1`) ou Level Base (`scenes3D/level_base`), load assíncrono

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

# Fluxo de Cenas

`main.tscn` (Node, `main.gd`) é um **roteador**: instancia cada tela como filha
de si mesmo (não usa `SceneTree.change_scene`), reagindo aos sinais
`replace_main_scene` e `quit`. Por isso `get_tree().current_scene` continua sendo
`main` durante todo o jogo.

```
main.tscn (main.gd — roteador)
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

- **menu** — Jogar (→ chooseplayer), Configurações (→ settings), Modo Developer (→ developer), Play Online (→ level_base), Sair
- **settings** — `config.gd` (autoload **Settings**) + `settings.gd` (UI). Abas Display / Resolution / Antialiasing / Lighting / Effects / **Debug**
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

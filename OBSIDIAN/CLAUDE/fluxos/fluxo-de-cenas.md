# Fluxo de Cenas

```
main.tscn (Node, main.gd)
   │
   └─► menu.tscn (menu.gd)
          │  quit → go_to_main_menu()
          │
          ├─► levels.tscn (levels.gd)
          │       │  Level 1 Button
          │       ├─► level_1.tscn   ── carregamento assíncrono (load_threaded)
          │       │
          │       └─► final_level.tscn ── carregamento assíncrono
          │
          └─► settings.tscn (settings.gd)
```

---

## main.gd

- Entry point do jogo
- Gerencia troca de cenas com `change_scene_to_packed()`
- Conecta sinal `quit` → `go_to_main_menu()`
- Conecta sinal `replace_main_scene` → troca de cena

---

## levels.gd

- Botões **Level 1** e **Final Level**
- Carregamento assíncrono via `ResourceLoader.load_threaded_request()`
- ProgressBar durante loading
- `DoneTimer` → emite `replace_main_scene` ao terminar

---

## level_1.tscn / level_1.gd

- Cena simples para teste
- Spawna 1 player em `(0,1,0)` + 1 robô em `(10,1,0)`
- Modo offline (single-player)

## final_level.tscn / final_level.gd

- Cena completa com iluminação (SDFGI / VoxelGI / LightmapGI)
- Suporte multiplayer completo
- Spawn points para players e robôs
- Robôs respawnam após 15 s quando morrem

---

## Sinais Entre Cenas

| Sinal | Emitido por | Recebido por |
|---|---|---|
| `quit` | levels, level_1, final_level | `main.gd` → `go_to_main_menu()` |
| `replace_main_scene(scene)` | levels | `main.gd` → troca cena |

---

## Relacionado

- [[arquivos-chave/main-gd]]
- [[sistemas/multiplayer]]

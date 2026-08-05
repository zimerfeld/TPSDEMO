---
tipo: arquivo-chave
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-07-04
---

# 🧭 scenes2D/main/main.gd

**Estende:** `Node`

---

## Responsabilidades

- Entry point do jogo
- Controla troca de cenas
- Inicializa modo offline (`OfflineMultiplayerPeer`)
- Conecta sinais `quit` e `replace_main_scene` das cenas filhas
- No modo **Janela**, dá à janela tamanho/posição sãos (resolução salva + centralizada) → janela movível
- A cada troca de tela, dispara a **música de fundo** da cena via `MusicManager.play_for_scene()` (ver [[🔊 audio (PT)|🔊 audio]])

---

## Funções

```gdscript
func _ready():
    multiplayer.server_relay = false
    if headless: Engine.max_fps = 60
    get_window().mode = Settings.config_file.get_value("video", "display_mode")
    if get_window().mode == Window.MODE_WINDOWED:
        Settings.apply_window_resolution(get_window())   # janela normal/movível
    go_to_main_menu()

func go_to_main_menu():
    # fecha peer atual, cria OfflineMultiplayerPeer
    # carrega menu.tscn

func replace_main_scene(resource: PackedScene):
    call_deferred("change_scene_to_packed", resource)

func change_scene_to_packed(resource: PackedScene):
    # remove todos os filhos atuais
    # instancia e adiciona nova cena
    # MusicManager.play_for_scene(node)  → trilha da cena em loop
    # conecta sinais quit / replace_main_scene
```

---

## Fluxo de Sinais

```
menu.tscn → quit              → go_to_main_menu()
levels.tscn → replace_main_scene(scene) → change_scene_to_packed(scene)
level_1.tscn → quit           → go_to_main_menu()
level_2.tscn → quit           → go_to_main_menu()
```

---

## Caminho: `scenes2D/main/main.gd`

---

## Relacionado

- [[🎬 fluxo-de-cenas (PT)|🎬 fluxo-de-cenas]]

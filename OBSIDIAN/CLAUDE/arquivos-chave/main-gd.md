# main/main.gd

**Estende:** `Node`

---

## Responsabilidades

- Entry point do jogo
- Controla troca de cenas
- Inicializa modo offline (`OfflineMultiplayerPeer`)
- Conecta sinais `quit` e `replace_main_scene` das cenas filhas

---

## Funções

```gdscript
func _ready():
    multiplayer.server_relay = false
    if headless: Engine.max_fps = 60
    get_window().mode = Settings.config_file.get_value("video", "display_mode")
    go_to_main_menu()

func go_to_main_menu():
    # fecha peer atual, cria OfflineMultiplayerPeer
    # carrega menu.tscn

func replace_main_scene(resource: PackedScene):
    call_deferred("change_scene_to_packed", resource)

func change_scene_to_packed(resource: PackedScene):
    # remove todos os filhos atuais
    # instancia e adiciona nova cena
    # conecta sinais quit / replace_main_scene
```

---

## Fluxo de Sinais

```
menu.tscn → quit              → go_to_main_menu()
levels.tscn → replace_main_scene(scene) → change_scene_to_packed(scene)
level_1.tscn → quit           → go_to_main_menu()
level_base.tscn → quit       → go_to_main_menu()
```

---

## Caminho: `main/main.gd`

---

## Relacionado

- [[fluxos/fluxo-de-cenas]]

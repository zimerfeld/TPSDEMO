---
tipo: arquivo-chave
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# 🧭 scenes2D/main/main.gd

**Extends:** `Node`

---

## Responsabilidades

- El punto de entrada del juego
- Controla el cambio de escenas
- Inicializa el modo offline (`OfflineMultiplayerPeer`)
- Conecta las señales `quit` y `replace_main_scene` de las escenas hijas
- En modo **Window**, da a la ventana un tamaño/posición sensatos (resolución guardada + centrada) → ventana movible
- En cada cambio de pantalla, dispara la **música de fondo** de la escena vía `MusicManager.play_for_scene()` (ver [[🔊 audio (ES)|Audio]])

---

## Funciones

```gdscript
func _ready():
    multiplayer.server_relay = false
    if headless: Engine.max_fps = 60
    get_window().mode = Settings.config_file.get_value("video", "display_mode")
    if get_window().mode == Window.MODE_WINDOWED:
        Settings.apply_window_resolution(get_window())   # normal/movable window
    go_to_main_menu()

func go_to_main_menu():
    # closes the current peer, creates OfflineMultiplayerPeer
    # loads menu.tscn

func replace_main_scene(resource: PackedScene):
    call_deferred("change_scene_to_packed", resource)

func change_scene_to_packed(resource: PackedScene):
    # removes all current children
    # instantiates and adds the new scene
    # MusicManager.play_for_scene(node)  → the scene's track on loop
    # connects the quit / replace_main_scene signals
```

---

## Flujo de señales

```
menu.tscn → quit              → go_to_main_menu()
levels.tscn → replace_main_scene(scene) → change_scene_to_packed(scene)
level_1.tscn → quit           → go_to_main_menu()
level_2.tscn → quit           → go_to_main_menu()
```

---

## Path: `scenes2D/main/main.gd`

---

## Relacionado

- [[🎬 fluxo-de-cenas (ES)|Flujo de Escenas]]

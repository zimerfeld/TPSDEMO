---
tipo: arquivo-chave
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 🧭 scenes2D/main/main.gd

**Extends:** `Node`

---

## Responsibilities

- The game's entry point
- Controls scene switching
- Initializes offline mode (`OfflineMultiplayerPeer`)
- Connects the `quit` and `replace_main_scene` signals of the child scenes
- In **Window** mode, gives the window sane size/position (saved resolution + centered) → movable window
- On every screen switch, fires the scene's **background music** via `MusicManager.play_for_scene()` (see [[🔊 audio (EN)|Audio]])

---

## Functions

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

## Signal Flow

```
menu.tscn → quit              → go_to_main_menu()
levels.tscn → replace_main_scene(scene) → change_scene_to_packed(scene)
level_1.tscn → quit           → go_to_main_menu()
level_2.tscn → quit           → go_to_main_menu()
```

---

## Path: `scenes2D/main/main.gd`

---

## Related

- [[🎬 fluxo-de-cenas (EN)|Scene Flow]]

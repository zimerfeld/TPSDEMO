---
tipo: arquivo-chave
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 💚 library3D/characters/players/player/health_bar.gd

**Created on:** 2026-06-06
**Extends:** `CanvasLayer`

---

## Responsibilities

- Show the local player's health bar in the bottom-left corner
- **Show the player's own name at the top of the HUD** (above the HP) — the 3D label above the
  head is only for the **other** players; see [[🎮 player-gd (EN)|player.gd]]
- Show the text `HP: current / maximum`
- Change color according to HP percentage

---

## Node Structure (created programmatically)

```
CanvasLayer (layer=10)
  └─ PanelContainer  (bottom-left anchor, raised 72px from the edge)
       └─ VBoxContainer
            ├─ Label      (_name_label) player name (hidden when empty)
            ├─ Label      (_label)  "HP: 100 / 100"
            └─ ProgressBar (_bar)   min=0, max=100, size 200×18
```

> **Position:** anchored bottom-left with `offset_left=24`, `offset_bottom=-72`,
> `grow_horizontal=END`, `grow_vertical=BEGIN`. The 72px bottom margin prevents
> the HUD from being clipped at the screen edge (it was 16px before and clipped).

---

## Public API

```gdscript
func set_player_name(player_name: String) -> void   # name at the top of the HUD (hidden if empty)
func update_health(current: int, maximum: int) -> void
```

`update_health` updates the bar and label. It changes the fill color:

| HP % | Color |
|---|---|
| > 50% | Green `(0.1, 0.75, 0.1)` |
| 25–50% | Yellow `(0.9, 0.7, 0.0)` |
| < 25% | Red `(0.85, 0.1, 0.1)` |

---

## Style

- Panel background: dark gray `(0.05, 0.05, 0.05, 0.75)` semi-transparent
- Bar background: dark red `(0.25, 0.05, 0.05)`
- Rounded corners (radius 6 on the panel, 4 on the bar)
- White font, size 13

---

## Instantiation — guaranteed in every level scene

`_setup_health_bar()` is **idempotent** and fired by **two** (deferred) triggers:
1. `player.gd._ready()` — on every level load
2. the `player_id` setter — covers the **multiplayer client** case, where `player_id`
   arrives by replication after `_ready` (without this, the HUD would never be created in that level)

```gdscript
func _setup_health_bar() -> void:
    if _health_bar != null:          # idempotent — does not duplicate
        return
    if not _is_owned_locally():      # only the local player sees the HUD (same criterion as the 3D name)
        return
    _health_bar = preload("res://library3D/characters/players/player/health_bar.gd").new()
    _health_bar.name = "HealthBar"
    add_child(_health_bar)
    _health_bar.update_health(hp, MAX_HP)
    _health_bar.set_player_name(player_name)   # owner's name at the top of the HUD
    _apply_name_label()                        # hides the Label3D above the player's own head
```

> `_is_owned_locally()` resolves "is my player" by the same criterion in `player.gd`:
> `$InputSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id()` and not a bot
> (covers host id 1 and clients). It uses `$InputSynchronizer` — not the `@onready` — since it can run
> before `_ready`.

> **Why two triggers:** in `level_1` (single-player) the authority is already set in
> `_ready`. In an online level on a **client**, the player is created via `MultiplayerSpawner` and the
> authority is only resolved when `player_id` replicates — the setter trigger guarantees the HUD in that case.

---

## Path: `library3D/characters/players/player/health_bar.gd`

---

## Related

- [[❤️ sistema-de-vida (EN)|Health System]]
- [[🎮 player-gd (EN)|player.gd]]

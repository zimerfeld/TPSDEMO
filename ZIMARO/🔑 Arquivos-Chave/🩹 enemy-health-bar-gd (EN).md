---
tipo: arquivo-chave
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# 🩹 controls2D/enemy_health_bar.gd

**Created on:** 2026-06-06
**Extends:** `CanvasLayer`

---

## Responsibilities

- A shared **"boss bar"** style HUD at the top-center of the screen
- Shows the **enemy name** + a **health bar** with `remaining / total` text
- Shows the **distance** (m) and, when the enemy has a weapon, the **weapon range** (m)
- Shows the most recently hit enemy; **fades out on its own** after 6 s
- Hides immediately when the enemy dies

---

## Shared Singleton Pattern

A single instance per client, recreated if the node is freed (level change):

```gdscript
static var _instance = null

static func get_shared(parent: Node):
    if _instance != null and is_instance_valid(_instance):
        return _instance
    _instance = (preload("res://controls2D/enemy_health_bar.gd")).new()
    parent.add_child(_instance)   # parent = get_tree().current_scene
    return _instance
```

> `is_instance_valid()` avoids a dangling pointer after the previous scene is freed.

---

## Node Structure (created programmatically)

```
CanvasLayer (layer=9)
  └─ PanelContainer  (anchor: CENTER_TOP, grow horizontal BOTH, margin 16px)
       └─ VBoxContainer (centered)
            ├─ HBoxContainer (top row)
            │    ├─ Label (_name_label)  enemy name, font 16
            │    └─ Label (_dist_label)  distance "12.3 m", font 14
            ├─ ProgressBar (_bar)    260×20
            │    └─ Label (_hp_label) overlay "remaining / total" centered
            └─ Label (_range_label)  "Alcance/Range: 30 m", font 13 (hidden without a weapon)
```

---

## Public API

```gdscript
func show_enemy(enemy_name: String, current: int, maximum: int, distance := -1.0, weapon_range := -1.0) -> void
func hide_now() -> void
```

**Distance:** the top row is an `HBoxContainer` with the name (left) + distance (right, "12.3 m").
`player_input._update_enemy_focus()` computes `player.distance_to(enemy)` and passes it every frame.
`distance < 0` keeps the last known distance (e.g.: when hit without aiming).

**Weapon range (`weapon_range`):** a dedicated label below the bar, shown only when the enemy
has an attack/shoot mechanism (`weapon_range >= 0`); each enemy reports its own (e.g.: `red_robot`
passes `effective_range`). Text **"Range: N m"** (EN) or **"Alcance: N m"** (PT), chosen by
`/root/Locale.get_language()`. `weapon_range < 0` keeps the last value; when **switching enemies**
(different name) the previous distance and range are discarded so values don't leak.

- `show_enemy` shows the panel, restarts the auto-hide timer (`AUTO_HIDE_TIME = 6.0 s`)
- `_process(delta)` decrements the timer and hides the panel when it reaches zero

---

## Triggered by

1. **Hit:** `red_robot.gd.hit()` → `show_health_hud()` → `get_shared(...).show_enemy(...)`
2. **Player aim (enters):** `player_input.gd._update_enemy_focus()` → `collider.show_health_hud()`,
   **only while aiming is ACTIVE** (`aiming`) and **only when hitting a LIMB/SUB-MEMBER** (layer 32) —
   the locomotion capsule alone does not open the HUD. A protruding sub-member (e.g.: a leg plate)
   resolves the owner via `meta("character")`. See [[🕹️ player-input-gd (EN)|player_input.gd]].
3. **Player aim (leaves or is turned off):** `_update_enemy_focus()` calls `_clear_enemy_focus()` →
   `_focused_enemy.hide_health_hud()` → `hide_now()`
4. **Death:** `red_robot.gd` → `hide_health_hud()` → `hide_now()`

Guards:
- `if DisplayServer.get_name() == "headless": return` (a dedicated server doesn't build UI)
- `if dead: return` in `show_health_hud()` (a dead robot doesn't show a HUD when aimed at)

## Visibility

- **Aim:** appears when aiming (**aim active**) at a **limb/sub-member** of the enemy, and
  **disappears immediately** when the crosshair leaves it **or aiming is turned off** (via
  `_focused_enemy` tracking in `player_input.gd`).
- **Hit without aiming:** the 6 s auto-hide (`AUTO_HIDE_TIME`) serves as a fallback.

---

## Path: `controls2D/enemy_health_bar.gd`

---

## Related

- [[🤖 inimigos (EN)|Enemies]]
- [[🤖 red-robot-gd (EN)|red_robot.gd]]
- [[💚 health-bar-gd (EN)|health_bar.gd]]

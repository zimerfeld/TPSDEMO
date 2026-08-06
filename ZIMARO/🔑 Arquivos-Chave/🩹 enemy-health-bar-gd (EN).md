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

## Singleton pattern — one instance PER VIEWPORT (2026-08-06)

```gdscript
static var _instances: Dictionary = {}   # viewport id -> CanvasLayer

static func get_shared(source: Node):    # source = the enemy ITSELF
    var vp: Viewport = source.get_viewport() ...
    ...
    vp.add_child(inst)                   # born INSIDE the room's viewport
    _instances[vp.get_instance_id()] = inst

static func hide_all() -> void           # hides it across every viewport
```

> **Why it changed:** it used to be **one global instance** parented to `get_tree().current_scene`.
> On the host each room lives in its own **SubViewport**, but the HUD sat at the **HostSession**
> root — so the "running rooms" grid drew the health bar of an enemy from a match the host
> **wasn't even watching** (reported 2026-08-06). Parented to the enemy's viewport, it only shows
> when that room is rendered (playing or observing).
>
> `get_shared` returns `null` if the node isn't in the tree yet — callers check before using it.
>
> `hide_all()` is called when **leaving a room**: `host_session._set_observing(-1)` (back to the
> grid) and `client_session._exit_play()` (back to the browser) — otherwise the last hit enemy's
> bar would linger for up to `AUTO_HIDE_TIME` over the rooms screen.

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
2. **Player aim (enters):** `player_input.gd._update_enemy_focus()` → `collider.show_health_hud()`.
   The ray registers both the **body** and the **limb/SUB-MEMBER colliders** (layer 32); a
   protruding sub-member (e.g.: a leg plate) resolves the owner via `meta("character")`. See
   [[🕹️ player-input-gd (EN)|player_input.gd]].
3. **Player aim (leaves):** `_update_enemy_focus()` calls `_focused_enemy.hide_health_hud()` → `hide_now()`
4. **Death:** `red_robot.gd` → `hide_health_hud()` → `hide_now()`

Guards:
- `if DisplayServer.get_name() == "headless": return` (a dedicated server doesn't build UI)
- `if dead: return` in `show_health_hud()` (a dead robot doesn't show a HUD when aimed at)

## Visibility

- **Aim:** appears when the crosshair is placed on the enemy, **disappears immediately** when the aim leaves
  (via `_focused_enemy` tracking in `player_input.gd`).
- **Hit without aiming:** the 6 s auto-hide (`AUTO_HIDE_TIME`) serves as a fallback.

---

## Path: `controls2D/enemy_health_bar.gd`

---

## Related

- [[🤖 inimigos (EN)|Enemies]]
- [[🤖 red-robot-gd (EN)|red_robot.gd]]
- [[💚 health-bar-gd (EN)|health_bar.gd]]

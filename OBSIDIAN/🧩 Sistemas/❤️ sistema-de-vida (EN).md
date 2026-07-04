---
tipo: sistema
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-04
---

# ❤️ Health System

> Implemented on 2026-06-06.

---

## Modified / Created Files

| File | Action |
|---|---|
| `library3D/characters/players/player/player.gd` | Added HP, `hit()` with damage, `respawn()` RPC |
| `library3D/characters/players/player/health_bar.gd` | **NEW** — CanvasLayer with ProgressBar + Label |

---

## Variables in `player.gd`

```gdscript
const MAX_HP: int = 100
var hp: int = MAX_HP
var _health_bar = null   # reference to the CanvasLayer
```

---

## Damage Flow

```
bullet._physics_process()
  → collider.hit.rpc()           # called by the server
      → hit() runs on ALL peers (call_local)
          → hp -= 25
          → _health_bar.update_health(hp, MAX_HP)
          → if hp == 0 and it is the server:
              → respawn.rpc()    # runs on everyone
                  → hp = MAX_HP
                  → transform.origin = initial_position
```

---

## Health Bar — `library3D/characters/players/player/health_bar.gd`

- Extends `CanvasLayer` (layer = 10)
- Created programmatically (no .tscn)
- Created in `_setup_health_bar()` (idempotent), fired by **two** deferred triggers:
  `_ready()` **and** the `player_id` setter → **appears in every level scene**, including in multiplayer clients
- Visible **only to the local player** (`$InputSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id()`)
- Guards: `_health_bar != null` (does not duplicate) and `is_inside_tree()` (waits to enter the tree)
- Positioned in the **bottom-left corner** via `PRESET_BOTTOM_LEFT + 16px margin`

### Color behavior by HP

| Range | Color |
|---|---|
| > 50% | Green |
| 25–50% | Yellow |
| < 25% | Red |

---

## Balancing Parameters

| Parameter | Value | Where to change |
|---|---|---|
| Max HP | `100` | `MAX_HP` in `player.gd` |
| Damage per hit | `25` | `hit()` in `player.gd` |
| Hits to die | `4` | derived |

---

## Related

- [[🎮 player (EN)|Player]]
- [[🔫 combate-tiro (EN)|Combat/Shooting]]
- [[🎮 player-gd (EN)|player.gd]]
- [[💚 health-bar-gd (EN)|health_bar.gd]]

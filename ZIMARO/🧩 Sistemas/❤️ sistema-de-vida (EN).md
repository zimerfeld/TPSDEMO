---
tipo: sistema
projeto: ZIMARO
lang: en-US
atualizado: 2026-08-06
---

# ❤️ Health System

> Implemented on 2026-06-06.
> ⚠️ **Superseded as the death condition on 2026-08-06** — see [[🦴 hp-por-membro (EN)|🦴 hp-por-membro]].

---

## ⚠️ What changed on 2026-08-06

**Single** health no longer decides the defeat. It still exists, but it is now the **mirror of the sum
of the limbs' HP** (`hp = limbs.total_hp()`); what decides death is [[🦴 hp-por-membro (EN)|per-limb
HP]] — a character only goes down once **every limb** has been destroyed.

| | Before | Now |
|---|---|---|
| Player `MAX_HP` | 100 | **150** (15 per limb; see the calibration in the system note) |
| `hit()` | `hit(amount)` | `hit(amount, group)` — the limb that was hit travels along |
| Death | `hp <= 0` | `limbs.is_defeated()` (single health only as a fallback) |
| Respawn | `hp = MAX_HP` | same **+ `limbs.reset()`** |

The single-health fallback still applies to hits with **no identified limb** (splash, falling) and to
models that do not build limb colliders (e.g. `criatura_alada`).

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

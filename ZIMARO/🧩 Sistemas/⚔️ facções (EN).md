---
tipo: sistema
projeto: ZIMARO
lang: en-US
atualizado: 2026-07-08
---

# ⚔️ Faction System (runtime)

**Script:** `effects_shared/factions.gd` (`class_name Factions`, `RefCounted` — static methods only)

Defines which **side** each character is on in combat, **per-instance and mutable at runtime** —
distinct from [[🧠 red-robot-ai-gd (EN)|AIConfig]], which keeps a per-**model** static faction in JSON.
This is what powers **no friendly fire**, **targeting by side** and **neutrals switching sides**.

> Created 2026-07-08, replacing the duck-typing (`has_method("hit")`) that used to decide targeting
> and damage. The `AIConfig.faction` infra (which existed but was never read) is now the **seed**.

---

## Values

| Faction | Role |
|---|---|
| `hostile` | Enemies (red_robot, criatura_alada by default) — attack the opposite faction |
| `ally` | On the player's side (the human player and allied bots) |
| `neutral` | Attacks no one by default; when hit, aligns **against** the attacker (temporary) |

---

## How a node's faction resolves — `Factions.of(node)`

Precedence (highest → lowest):

1. **Temporary override** — a provoked neutral (metas `faction_override` + `faction_override_until`);
   expires on its own after `PROVOKE_DURATION_MS` (8 s) and reverts to base.
2. **Template placement** — meta `template_faction` (`enemy→hostile`, `friendly→ally`,
   `neutral→neutral`), written by `template_manager_base` at spawn. Takes precedence over the seed.
3. **Model seed** — meta `faction`, seeded in each entity's `_ready` via
   `Factions.seed_node(self, model_key)` = `AIConfig.faction(model_key)`.
4. **Inference** — fallback from the node's methods: has `add_camera_shake_trauma` → `ally`; has
   `show_health_hud` → `hostile`; otherwise `neutral`.

`base_of(node)` does the same **ignoring** the override (the neutral's "real" faction).

---

## API

```gdscript
Factions.seed_node(node, model_key)     # _ready: seed the model's base faction (AIConfig)
Factions.of(node) -> String             # effective faction now (honors temporary override)
Factions.base_of(node) -> String        # base faction (ignores override)
Factions.are_enemies(a, b) -> bool      # opposite sides (neutral is nobody's enemy)
Factions.same_side(a, b) -> bool        # same side (neutral shares no side)
Factions.can_damage(attacker, target) -> bool   # pure: neutral always; else opposite only
Factions.note_damage(attacker, target)          # on applying damage: provokes the hit neutral
```

---

## Where it plugs in

- **No friendly fire (damage)** — `bullet.gd` and `bomb.gd`:
  - Before applying damage, `Factions.can_damage(shooter/dropper, target)`. Same faction → **no damage**.
  - The **bullet phases through** an ally (collision exception) instead of exploding → it does not
    block the line of fire of whoever is behind. See [[🔫 combate-tiro (EN)|combate-tiro]].
  - When damage lands, `Factions.note_damage(...)` provokes a neutral target.
- **Targeting** — enemies target only the OPPOSITE faction, filtering by `are_enemies` at target
  **selection** (not at Area entry), to react to runtime faction changes:
  - `red_robot._pick_target` (see [[🤖 inimigos (EN)|inimigos]]), `criatura_alada._find_nearest_player`.
  - `player_bot_ai._is_valid_enemy` / `_is_ally` (allied bot only engages hostiles; see [[🎮 player (EN)|player]]).
- **Seeding** — `red_robot.gd`, `criatura_alada.gd`, `player.gd` call `seed_node` in `_ready`.

---

## Dynamic neutrals (momentary)

A neutral hit by a **projectile** (no need to change the `hit()` signature — the logic runs on the
projectile side, server-side, where the attacker is known):

- hit by an **ally** → becomes **hostile** (enemy of the allies) for ~8 s;
- hit by an **enemy** → becomes an **ally** for ~8 s;
- not shot for 8 s → reverts to **neutral**.

By default there is **no neutral character** in the game — place one with faction `neutral` via a
template to see it.

---

## Notes

- **Ally separation (2026-07-08):** multiple allied bots no longer stack — each uses **separation
  steering** (a push away from other allies within `separation_radius`), spreading them out on the
  orbit / in combat. Detail in [[🎮 player (EN)|player]].
- The runtime faction is not **replicated** to clients (not needed: damage and targeting are server-authoritative).

---

## Related

- [[🤖 inimigos (EN)|inimigos]] · [[🎮 player (EN)|player]] · [[🔫 combate-tiro (EN)|combate-tiro]] · [[🧠 red-robot-ai-gd (EN)|red-robot-ai-gd]]

---
tipo: sistema
projeto: ZIMARO
lang: en-US
atualizado: 2026-08-06
---

# 🦴 Per-Limb HP (defeat condition)

> Implemented on 2026-08-06. Replaces the **single health bar** as the death condition:
> a character only goes down once **every limb and sub-limb** has been destroyed.
> New file: `effects_shared/limb_health.gd` (`class_name LimbHealth`).

---

## The idea

Every limb/sub-limb with a gameplay collider has **its own HP**. Damage goes to the limb that was hit,
not to a global bar. The character's total health still exists — it is **split** across the limbs and
becomes a mirror of their sum (`health = limbs.total_hp()`), so bars that show the whole body keep
working.

The **percentage configured in the Models screen is still a DAMAGE multiplier**, exactly as before
(see [[🩸 dano-localizado (EN)|🩸 dano-localizado]]). A limb at 200% falls in half the shots. Nothing
had to be reconfigured per model.

---

## HP split

| Limb | Weight |
|---|---|
| HEAD | `HEAD_HP_WEIGHT` = **2.0** |
| Everything else | 1.0 |

`limb HP = total_health × weight / sum_of_weights`

Beefing up the head **thins the others by the same amount** — the total is still the character's
health; nobody gets free hit points.

---

## What counts toward the defeat

**Every limb/sub-limb the model actually builds** (i.e. has a gameplay collider). Limbs with no
percentage of their own in `LimbConfig` use the default 1× damage.

> ⚠️ The alternative — counting only limbs with a configured percentage — was **measured** and
> dropped: on red_robot it yielded 5 limbs (both shields, the fuel tank and the two rear leg guards),
> because its `limb_config.json` only defines `PART_FuelTank`. Head, torso, arms and legs were left
> out, meaning **hitting the head did nothing toward killing the enemy**. Counting by collider closes
> that hole without reconfiguring model by model.

---

## Propagation (what falls together)

```
parent limb destroyed  →  all of its sub-limbs fall
FACE sub-limb          →  takes the HEAD down (and its siblings with it)
ordinary sub-limb      →  does NOT take the parent limb down
```

"Face" is decided by the **owner limb being the HEAD** (`BodyParts.HEAD`), not by a list of bone
names — so it holds for any model, in any language. This is what makes precise aim worth it: the
brute-force path costs several hits on the head; through the eyes/mouth, **a single one**.

---

## Calibration (measured on 2026-08-06)

| Character | Total health | Head | Ordinary limb | Defeat |
|---|---|---|---|---|
| **Red Robot** | `max_health` = **550** | 92 | 46 | **7 shots** of 50 |
| **Player** | `MAX_HP` = **150** | 27 | 14 | **13 hits** of 10 · **11** aiming at the face |

Why these numbers:

- **Red Robot** — with the old 200, each limb held 18 HP and the player's shot (50) tore any piece off
  in one go, while the robot's own 10-damage cannon removed over half a limb per hit. 550 keeps the
  granularity sane. Between 200 and 550 the **shot count does not change** (the cost is the number of
  limbs, not the health); above ~560 each limb would need 2 shots and the defeat would jump to 12.
- **Player** — with the old 100, each limb had exactly 10 HP and fell to **one** hit: the player died
  in 6 hits, meaning the change had made them **more fragile** than before. 150 gives 15 per limb
  (2 hits each) and restores the ~10-hit balance of the single-health model.

---

## Overlay

Aiming at a limb makes the shared boss bar show **that limb's name and HP** — `Red Robot — CABEÇA`,
with `92` as the maximum — rather than the body's health. The limb is what must fall, so it is the
number that matters. See [[🤖 inimigos (EN)|🤖 inimigos]].

---

## Networking

`hit()` is `@rpc("call_local")`: **every peer applies the same damage** and lands on the same state.
No dictionary is replicated. The shooter passes the limb that was hit along with the damage:

```gdscript
character.hit.rpc(int(round(weapon_damage * mult)), String(collider.get_meta("group", "")))
```

---

## Factions

It holds for **enemies, friendlies and neutrals** — `player` uses the same system (with
`limbs.reset()` on respawn). `criatura_alada` does **not** build limb colliders, so it keeps single
health and merely accepts the new argument. See [[⚔️ facções (EN)|⚔️ facções]].

---

## 💥 Take-apart visual effect (2026-08-06)

`LimbHealth` emits **`limb_destroyed(group)`** for every limb that falls — including the ones dragged
down by propagation. The character wires that signal to **`LimbColliders.collapse_limb(group)`**, which:

1. **switches the limb's collider off** (a fallen piece takes no more hits);
2. **collapses the bone** via [[limb-debris]] → the piece **disappears from the mesh**, and whatever
   comes after it in the chain goes with it (the arm takes forearm, hand and the shield attached to it);
3. releases a **burst of sparks** (one-shot `CPUParticles3D`, unshaded material, self-freeing) at the
   bone's position — cheap, within the project's 60 FPS budget.

The **TORSO does not collapse**: it is the rig's root, and hiding it would take the whole character
along, standing limbs included. It only gets the sparks. On the player's **respawn**, `restore_limbs()`
brings the pieces back and re-enables the colliders.

> ⚠️ **VIRTUAL-METHOD TRAP (measured on 2026-08-06).** `LimbDebris` is a `SkeletonModifier3D` because
> the AnimationTree rewrites every bone's pose each frame — zeroing the scale anywhere else would be
> undone on the next one. **Godot 4.6 calls `_process_modification_with_delta(delta)`**; the
> argument-less `_process_modification()` still shows up in `ClassDB` but is **legacy**. Implementing
> only the delta-less version makes the modifier **never run, with no error at all** — colliders switch
> off, sparks fire, and the piece stays put (measured: 0 calls versus 22). We implement both.
>
> 🔍 **How to VERIFY:** reading `get_bone_pose_scale()` **from outside** returns `1.0` even with the limb
> gone — the read picks up the INPUT pose the animation just rewrote. The scale is only observable
> **inside** the pose pipeline: use a **second `SkeletonModifier3D` as a probe**, added AFTER
> `LimbDebris`, and read `get_bone_global_pose()` there. Measured that way: destroyed limb
> `(0.001, 0.001, 0.001)`, intact limb `(1.0, 1.0, 1.0)`.

---

## Known limitations
- Damage with **no identified limb** (splash, falling) still comes off the global health, otherwise
  those hits would do nothing at all.

---

## Files

| File | Role |
|---|---|
| `effects_shared/limb_health.gd` | **NEW** — `LimbHealth`: split, damage, propagation, defeat |
| `effects_shared/limb_debris.gd` | **NEW** — `LimbDebris`: collapses the bone (piece vanishes) + sparks |
| `effects_shared/limb_colliders.gd` | Stamps the `owner_group` meta (sub-limb's owner limb) |
| `library3D/characters/red_robot/red_robot.gd` | `limbs`, `hit(amount, group)`, per-limb overlay |
| `library3D/characters/player/player.gd` | `limbs`, `hit(amount, group)`, `reset()` on respawn |
| `library3D/characters/player/bullet/bullet.gd` | Passes the limb that was hit |
| `effects_shared/laser_shooter.gd` | Passes the limb that was hit |
| `library3D/characters/player/player_input.gd` | Limb under the crosshair → overlay |

Related: [[❤️ sistema-de-vida (EN)|❤️ sistema-de-vida]] · [[🩸 dano-localizado (EN)|🩸 dano-localizado]] · [[🗿 biblioteca-de-modelos (EN)|🗿 biblioteca-de-modelos]]

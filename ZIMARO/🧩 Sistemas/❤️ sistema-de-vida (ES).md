---
tipo: sistema
projeto: ZIMARO
lang: es-ES
atualizado: 2026-08-06
---

# ❤️ Sistema de vida

> Implementado el 2026-06-06.
> ⚠️ **Superado como condición de muerte el 2026-08-06** — ver [[🦴 hp-por-membro (ES)|🦴 hp-por-membro]].

---

## ⚠️ Qué cambió el 2026-08-06

La vida **única** dejó de decidir el abatimiento. Sigue existiendo, pero pasa a ser el **espejo de la
suma del HP de los miembros** (`hp = limbs.total_hp()`); quien decide la muerte es el
[[🦴 hp-por-membro (ES)|HP por miembro]] — el personaje solo cae cuando **todos los miembros** han sido
destruidos.

| | Antes | Ahora |
|---|---|---|
| `MAX_HP` del player | 100 | **150** (15 por miembro; ver la calibración en la nota del sistema) |
| `hit()` | `hit(amount)` | `hit(amount, group)` — el miembro alcanzado viaja con el daño |
| Muerte | `hp <= 0` | `limbs.is_defeated()` (vida única solo como respaldo) |
| Respawn | `hp = MAX_HP` | ídem **+ `limbs.reset()`** |

El respaldo de vida única sigue valiendo para golpes **sin miembro identificado** (explosión de área,
caída) y para modelos que no construyen colliders de miembro (p. ej. `criatura_alada`).

---

## Archivos modificados / creados

| Archivo | Acción |
|---|---|
| `library3D/characters/players/player/player.gd` | Añadido HP, `hit()` con daño, RPC `respawn()` |
| `library3D/characters/players/player/health_bar.gd` | **NUEVO** — CanvasLayer con ProgressBar + Label |

---

## Variables en `player.gd`

```gdscript
const MAX_HP: int = 100
var hp: int = MAX_HP
var _health_bar = null   # reference to the CanvasLayer
```

---

## Flujo de daño

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

## Barra de vida — `library3D/characters/players/player/health_bar.gd`

- Extiende `CanvasLayer` (layer = 10)
- Creada programáticamente (sin .tscn)
- Creada en `_setup_health_bar()` (idempotente), disparada por **dos** activadores diferidos:
  `_ready()` **y** el setter de `player_id` → **aparece en toda escena de nivel**, incluso en clientes multijugador
- Visible **solo para el jugador local** (`$InputSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id()`)
- Guardas: `_health_bar != null` (no duplica) e `is_inside_tree()` (espera a entrar en el árbol)
- Posicionada en la **esquina inferior izquierda** vía `PRESET_BOTTOM_LEFT + 16px de margen`

### Comportamiento del color según el HP

| Rango | Color |
|---|---|
| > 50% | Verde |
| 25–50% | Amarillo |
| < 25% | Rojo |

---

## Parámetros de balanceo

| Parámetro | Valor | Dónde cambiar |
|---|---|---|
| HP máximo | `100` | `MAX_HP` en `player.gd` |
| Daño por impacto | `25` | `hit()` en `player.gd` |
| Impactos para morir | `4` | derivado |

---

## Relacionado

- [[🎮 player (ES)|Player]]
- [[🔫 combate-tiro (ES)|Combate/Disparo]]
- [[🎮 player-gd (ES)|player.gd]]
- [[💚 health-bar-gd (ES)|health_bar.gd]]

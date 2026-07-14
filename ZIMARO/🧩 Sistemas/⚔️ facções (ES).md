---
tipo: sistema
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-08
---

# ⚔️ Sistema de Facciones (runtime)

**Script:** `effects_shared/factions.gd` (`class_name Factions`, `RefCounted` — solo métodos estáticos)

Define en qué **bando** está cada personaje en combate, **por instancia y mutable en tiempo de
ejecución** — a diferencia de [[🧠 red-robot-ai-gd (ES)|AIConfig]], que guarda una facción estática
por **modelo** en JSON. Esto es lo que hace posible el **sin fuego amigo**, el **targeting por bando**
y los **neutrales que cambian de bando**.

> Creado el 2026-07-08, sustituyendo el duck-typing (`has_method("hit")`) que antes decidía el
> targeting y el daño. La infra `AIConfig.faction` (que existía pero nunca se leía) es ahora la **semilla**.

---

## Valores

| Facción | Rol |
|---|---|
| `hostile` | Enemigos (red_robot, criatura_alada por defecto) — atacan a la facción opuesta |
| `ally` | Del bando del jugador (el jugador humano y los bots aliados) |
| `neutral` | No ataca a nadie por defecto; al ser golpeado, se alinea **contra** el atacante (temporal) |

---

## Cómo se resuelve la facción de un nodo — `Factions.of(node)`

Precedencia (mayor → menor):

1. **Override temporal** — un neutral provocado (metas `faction_override` + `faction_override_until`);
   expira por sí solo tras `PROVOKE_DURATION_MS` (8 s) y vuelve a la base.
2. **Colocación por template** — meta `template_faction` (`enemy→hostile`, `friendly→ally`,
   `neutral→neutral`), escrita por `template_manager_base` en el spawn. Tiene precedencia sobre la semilla.
3. **Semilla del modelo** — meta `faction`, sembrada en el `_ready` de cada entidad vía
   `Factions.seed_node(self, model_key)` = `AIConfig.faction(model_key)`.
4. **Inferencia** — fallback a partir de los métodos del nodo: tiene `add_camera_shake_trauma` → `ally`;
   tiene `show_health_hud` → `hostile`; en otro caso `neutral`.

`base_of(node)` hace lo mismo **ignorando** el override (la facción "real" del neutral).

---

## API

```gdscript
Factions.seed_node(node, model_key)     # _ready: sembrar la facción base del modelo (AIConfig)
Factions.of(node) -> String             # facción efectiva ahora (respeta el override temporal)
Factions.base_of(node) -> String        # facción base (ignora el override)
Factions.are_enemies(a, b) -> bool      # bandos opuestos (el neutral no es enemigo de nadie)
Factions.same_side(a, b) -> bool        # mismo bando (el neutral no comparte bando)
Factions.can_damage(attacker, target) -> bool   # puro: neutral siempre; si no, solo opuestos
Factions.note_damage(attacker, target)          # al aplicar daño: provoca al neutral golpeado
```

---

## Dónde se conecta

- **Sin fuego amigo (daño)** — `bullet.gd` y `bomb.gd`:
  - Antes de aplicar daño, `Factions.can_damage(shooter/dropper, target)`. Misma facción → **sin daño**.
  - La **bala atraviesa** a un aliado (excepción de colisión) en vez de explotar → no bloquea la
    línea de tiro de quien esté detrás. Ver [[🔫 combate-tiro (ES)|combate-tiro]].
  - Cuando el daño impacta, `Factions.note_damage(...)` provoca a un objetivo neutral.
- **Targeting** — los enemigos apuntan solo a la facción OPUESTA, filtrando por `are_enemies` en la
  **selección** de objetivo (no en la entrada al Area), para reaccionar a cambios de facción en runtime:
  - `red_robot._pick_target` (ver [[🤖 inimigos (ES)|inimigos]]), `criatura_alada._find_nearest_player`.
  - `player_bot_ai._is_valid_enemy` / `_is_ally` (el bot aliado solo engancha hostiles; ver [[🎮 player (ES)|player]]).
- **Sembrado** — `red_robot.gd`, `criatura_alada.gd`, `player.gd` llaman a `seed_node` en `_ready`.

---

## Neutrales dinámicos (momentáneos)

Un neutral golpeado por un **proyectil** (sin necesidad de cambiar la firma de `hit()` — la lógica corre
del lado del proyectil, en el servidor, donde se conoce al atacante):

- golpeado por un **aliado** → se vuelve **hostile** (enemigo de los aliados) durante ~8 s;
- golpeado por un **enemigo** → se vuelve **ally** durante ~8 s;
- no recibe disparos durante 8 s → vuelve a **neutral**.

Por defecto **no hay ningún personaje neutral** en el juego — coloca uno con facción `neutral` mediante
un template para verlo.

---

## Notas

- **Separación de aliados (2026-07-08):** varios bots aliados ya no se amontonan — cada uno usa
  **separation steering** (un empuje que lo aleja de otros aliados dentro de `separation_radius`),
  repartiéndolos en la órbita / en combate. Detalle en [[🎮 player (ES)|player]].
- La facción en runtime no se **replica** a los clientes (no hace falta: el daño y el targeting tienen
  autoridad de servidor).

---

## Relacionado

- [[🤖 inimigos (ES)|inimigos]] · [[🎮 player (ES)|player]] · [[🔫 combate-tiro (ES)|combate-tiro]] · [[🧠 red-robot-ai-gd (ES)|red-robot-ai-gd]]

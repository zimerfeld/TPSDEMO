---
tipo: arquivo-chave
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# 🧠 library3D/characters/red_robot/IA/red_robot_ai.gd

**Created on:** 2026-06-18
**Extends:** `Node` · **`class_name RedRobotAI`**

---

## Responsabilidades

Centraliza los **comportamientos y decisiones** de combate del Red Robot en runtime. El cuerpo
(`red_robot.gd`) instancia esta IA como hijo en `_ready()` (nombre `IA`) y la consulta cada frame.
Mantiene la física, la animación y el disparo en el cuerpo; solo las **reglas de decisión** y los
ajustables viven aquí, fáciles de ajustar sin tocar la máquina de estados.

---

## Ajustables (`@export`)

| Var | Value | Efecto |
|---|---|---|
| `fire_rate_multiplier` | `1.5` | Recarga **1.5× más rápida** (1.º y siguientes disparos) |
| `flee_distance` | `10.0 m` | Jugador a esta distancia o menos → el robot se retira disparando |
| `flee_speed` | `6.0 m/s` | Velocidad al huir del jugador |
| `formation_cohesion` | `0.55` | Fuerza del retorno al slot de formación asignado |
| `formation_band` | `5.0 m` | Tolerancia antes de que el robot sea traído de vuelta al slot |
| `speed_variation` | `±0.18` | Variación de velocidad por individuo (rompe el lockstep) |

---

## API

```gdscript
enum Action { APPROACH, ENGAGE, FLEE }

func reload_time(base_wait: float) -> float        # base_wait / fire_rate_multiplier
func decide(distance, effective_range) -> Action   # FLEE / ENGAGE / APPROACH
func should_shoot(distance, effective_range) -> bool  # distance <= effective_range
```

- `decide()`: `dist ≤ flee_distance` → **FLEE**; `dist ≤ range` → **ENGAGE**; en caso contrario **APPROACH**.
- `reload_time()`: usado por el cuerpo para `shoot_reload = ai.reload_time(SHOOT_WAIT)`.

---

## Cómo lo usa el cuerpo (`red_robot.gd`)

- **Recarga acelerada:** `shoot_reload` reemplaza a `SHOOT_WAIT` en todos los reinicios de
  `shoot_countdown` (1.º disparo incluido).
- **Retirada (FLEE):** cuando `decide(...) == FLEE`, `_flee_movement()` encara al jugador (frente +Z) y
  fija la velocidad en la dirección opuesta (`-fwd * flee_speed`), sobreescribiendo el root motion; las piernas
  reproducen `walk` y el fuego continúa (el jugador está dentro del alcance).
- **Disparo:** la lógica de puntería ya solo dispara dentro de `effective_range`, cubriendo ENGAGE y FLEE.

---

## Path: `library3D/characters/red_robot/IA/red_robot_ai.gd`

---

## Individualización + formación (2026-06-25)

- **Sin lockstep:** `_ready` inicializa por instancia `_strafe_sign` (aleatorio ±1), `_phase` y
  `_speed_mult` (`1 ± speed_variation`); los reinicios de `_strafe_cooldown` en `_choose_strafe_sign`
  usan `randf_range` (≈0.45–1.6 s) en lugar de periodos fijos (~1 s). De este modo el escuadrón **no camina
  idénticamente cada segundo**. RNG del servidor (el movimiento es autoritativo del servidor; los clientes interpolan).
- **Formación asignada:** en la 1.ª llamada de `movement_plan`, captura `_slot_bearing` de
  `origin - target_position` (la dirección de spawn vista desde el jugador). Durante strafe/engage, añade un
  **sesgo de retorno** al punto `player + slot_dir * preferred` cuando la holgura supera `formation_band`,
  ponderado por `formation_cohesion`. El robot **rodea libremente** pero tiende a **volver a su lugar**.
- **Velocidad:** las velocidades `flee/strafe/pressure` salen multiplicadas por `_speed_mult`.

---

## Relacionado

- [[🤖 red-robot-gd (ES)|red_robot.gd]]
- [[🤖 inimigos (ES)|Enemigos]]
- [[🩸 dano-localizado (ES)|Daño Localizado]]

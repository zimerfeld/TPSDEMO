---
tipo: arquivo-chave
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# 🤖 library3D/characters/red_robot/red_robot.gd

**Extends:** `CharacterBody3D`

---

## Responsabilidades

- IA con 3 estados: APPROACH / AIM / SHOOTING
- Raycast láser que detecta al jugador y aplica un impacto
- Sistema de HP (`health: int = 5`)
- Muerte con física ragdoll (las piezas explotan como RigidBody3D)
- Reaparición gestionada por el nivel (señal `exploded`)

---

## Variables exportadas / sincronizadas

```gdscript
const HIT_DAMAGE: int = 50          # damage per shot taken
@export var enemy_name: String = "Red Robot"
@export var max_health: int = 200
@export var health: int = 200
@export var state: State = State.APPROACH
@export var dead: bool = false
@export var target_position: Vector3
@export var aim_preparing: float
```

---

## Método `hit()` (RPC call_local)

```gdscript
health = maxi(health - HIT_DAMAGE, 0)   # -50 per shot → dies in 4 shots
# animates a random hit (hit1/hit2/hit3)
if health <= 0:
    dead = true
    # hides model, disables collision
    # parts explode (shield1/shield2/head)
    # emits the exploded signal
    # server: queue_free() after 10s
```

---

## Láser

- `RayCast3D` disparado desde la posición del hueso `RayFrom`
- Un shader recorta la malla del rayo según la longitud de la colisión
- Partículas `LaserEmber` posicionadas en el centro del rayo
- Al golpear al jugador: `player.add_camera_shake_trauma(13.0)` tras un retardo de 0.1s

---

## Muerte (piezas)

| Node | Type |
|---|---|
| `PartShield1` / `PartShield2` | `RigidBody3D` |
| `PartHead` | `RigidBody3D` |
| `DetachSpark1/2` | `CPUParticles3D` |

---

## Path: `library3D/characters/red_robot/red_robot.gd`

---

## Arma, precisión y daño (actualizado)

- `weapon_damage`, `aim_accuracy = 1.0` (100%), `effective_range = 30 m`
- Solo dispara cuando el jugador está dentro del alcance (puntería precisa)
- `hit(amount)` recibe daño del arma del atacante; el proyectil (CannonShooter) aplica
  daño localizado a los colisionadores de miembro del jugador
- `show_health_hud(distance)` muestra la distancia **y el alcance del arma** (`effective_range`) en el HUD
- Ver [[🩸 dano-localizado (ES)|Daño Localizado]]

---

## IA (`IA/red_robot_ai.gd`)

Los comportamientos/decisiones en runtime viven en un script de IA dedicado
([[🧠 red-robot-ai-gd (ES)|red_robot_ai.gd]], `class_name RedRobotAI`), instanciado como hijo en `_ready()`
y consultado cada frame por el cuerpo (`red_robot.gd`):

- **Recarga 1.5× más rápida** — `shoot_reload = ai.reload_time(SHOOT_WAIT)` = `SHOOT_WAIT / 1.5`;
  usado en el 1.º disparo y en todos los reinicios de `shoot_countdown` (aplica al 1.º y al siguiente).
- **Enganche (Engage)** — dispara siempre que el jugador está dentro de `effective_range` (la puntería de disparo ya
  hace ese test); en la práctica, abre fuego en el rango `10 m < dist ≤ range`.
- **Retirada (FLEE)** — cuando `dist ≤ flee_distance` (10 m), `_flee_movement()` orienta el cuerpo
  para **encarar al jugador** (frente +Z) y fija la velocidad en la **dirección opuesta**
  (`-fwd * flee_speed`), sobreescribiendo el root motion; las piernas reproducen `walk` y el fuego continúa.
- Ajustables en la IA: `fire_rate_multiplier = 1.5`, `flee_distance = 10.0`, `flee_speed = 6.0`.

---

## Relacionado

- [[🤖 inimigos (ES)|Enemigos]]
- [[🧠 red-robot-ai-gd (ES)|red_robot_ai.gd]]
- [[🩸 dano-localizado (ES)|Daño Localizado]]
- [[🎯 fluxo-de-tiro (ES)|Flujo de Disparo]]

---
tipo: sistema
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-08
---

# 🤖 Sistema de enemigos — Red Robot

**Script:** `library3D/characters/red_robot/red_robot.gd`
**Escena:** `library3D/characters/red_robot/red_robot.tscn`

---

## 🔁 Máquina de estados

```
APPROACH ──► AIM ──► SHOOTING
    ▲          │
    └──────────┘ (missed / left sight)
```

| Estado | Comportamiento |
|---|---|
| `APPROACH (0)` | Camina hacia el jugador, gira para encararlo |
| `AIM (1)` | Se detiene, prepara el disparo, cuenta `AIM_TIME = 1.0 s` |
| `SHOOTING (2)` | Dispara una bala de cañón; espera la recarga antes de la siguiente |

> **Retirada (FLEE):** además de los 3 estados, una decisión de la [[🧠 red-robot-ai-gd (ES)|IA]] anula
> el movimiento cuando el jugador llega a **≤ 10 m**: el robot abre espacio en la dirección opuesta (no es
> un `State` de la máquina, es una anulación de movimiento por fotograma). Desde 2026-07-08 las **piernas giran hacia la
> dirección de avance** (mecánica anti-deslizamiento — ver abajo), así que **gira y corre** en lugar de retroceder de espaldas;
> la **torreta/cañón sigue apuntando al jugador** de forma independiente.

---

## 🎛️ Parámetros

| Constante | Valor |
|---|---|
| `PLAYER_AIM_TOLERANCE_DEGREES` | `15°` |
| `SHOOT_WAIT` | `6.0 s` (recarga base) |
| `shoot_reload` | `SHOOT_WAIT / 1.5 ≈ 4.0 s` (recarga efectiva vía IA — 1.5× más rápida) |
| `AIM_TIME` | `1.0 s` |
| `AIM_PREPARE_TIME` | `0.5 s` |
| `BLEND_AIM_SPEED` | `0.05` |
| `effective_range` | `30 m` (alcance del arma; mostrado en el HUD) |
| `PlayerDetectionArea` | `SphereShape3D` radio `30 m` (= `effective_range`) |

> La recarga efectiva (1.º y disparos posteriores) viene de la [[🧠 red-robot-ai-gd (ES)|IA]]
> (`fire_rate_multiplier = 1.5`), no directamente de `SHOOT_WAIT`.
>
> El **radio de detección (30 m)** se igualó al `effective_range` para que el robot **detecte y abra
> fuego a 30 m** (antes 20 m impedía disparar a pleno alcance).

---

## 🧮 Variables de estado (Exportadas / Sincronizadas)

| Var | Tipo | Descripción |
|---|---|---|
| `health` | `int` | Salud del robot (por defecto: `200`) |
| `max_health` | `int` | Salud máxima para el HUD (por defecto: `200`) |
| `HIT_DAMAGE` | `const int` | Daño por disparo = `50` (muere en 4 disparos) |
| `enemy_name` | `String` | Nombre mostrado en el HUD (por defecto: `"Red Robot"`) |
| `state` | `State` | Estado actual de la IA |
| `dead` | `bool` | Si fue destruido |
| `target_position` | `Vector3` | Posición del jugador objetivo |

---

## ❤️ HUD de salud (Boss Bar)

- `controls2D/enemy_health_bar.gd` — `CanvasLayer` compartido en la **parte superior central**
- Activado por:
  - `hit()` → `show_health_hud()` (al ser impactado)
  - **la puntería del jugador entra** → `player_input._update_enemy_focus()` llama a `show_health_hud()`
  - **la puntería del jugador sale** → llama a `hide_health_hud()` (desaparece de inmediato)
- `show_health_hud()` y `hide_health_hud()` son **públicas**; show está protegido por `if dead: return`
- Desaparece: de inmediato cuando la puntería sale o al morir; fallback de 6 s si es impactado sin puntería
- Muestra `enemy_name` + barra `restante / total` + **distancia (m)** + **alcance del arma (m)**
  (`show_health_hud(distance)` transmite `effective_range`; el HUD solo muestra el alcance cuando se le informa)
- Ver [[🩹 enemy-health-bar-gd (ES)|enemy-health-bar-gd]]

---

## 📡 RPC `hit()`

```gdscript
@rpc("call_local")
func hit() -> void:
    health = maxi(health - HIT_DAMAGE, 0)   # -50 per shot
    _show_health_hud()                 # updates boss bar
    # plays a random hit animation (hit1/hit2/hit3)
    if health <= 0:
        # destroys: parts explode, emits exploded signal
        _hide_health_hud()             # hides boss bar
        # the server does queue_free() after 10s
```

> **Balanceo:** `200 HP ÷ 50 daño = 4 disparos para morir`.

---

## 🔦 Láser

- `RayCast3D` en `RayFrom` (BoneAttachment en el esqueleto)
- Comprueba la línea de visión antes de `AIM → SHOOTING`
- Si impacta al jugador: llama a `player.add_camera_shake_trauma(13.0)` tras 0.1 s
- Recorta el shader del láser según la longitud del rayo

---

## 🌱 Spawn

- **level_1:** aparece en cada `RobotSpawnpoints/*`; respawn automático tras 15 s

---

## 📶 Señal

- `exploded` — emitida al morir; el nivel la conecta para el respawn

---

## 🦿 Colisionadores de miembros (daño localizado)

- `_setup_limb_colliders()` en `_ready` (si `not dead`) crea colisionadores 3D nativos (`StaticBody3D` + `BoxShape3D`) por miembro
- Usa `effects_shared/limb_colliders.gd` sobre `RedRobotModel/Armature/Skeleton3D` (`head_bone_names = ["mouth_eyes", "L-EYE", "R-EYE"]` — los ojos van a la HEAD para que el headshot no sea diminuto; 2026-06-18)
- Capa 32 (bit6); la bala del jugador colisiona físicamente y aplica daño localizado
- **Cápsula de locomoción auto-ajustada (2026-07-03):** tras `build_for`, `red_robot.gd` llama a
  `lc.fit_locomotion_capsule(collision_shape, self)` — el bloqueo físico pasa a ser proporcional al modelo
  (radio a partir de la huella del torso+piernas, altura a partir de la extensión vertical), en lugar de la cápsula por defecto. Ver
  [[🩸 dano-localizado (ES)|dano-localizado]] ("Auto-ajuste por modelo de la cápsula de locomoción").
- Ver [[🦿 limb-colliders-gd (ES)|limb-colliders-gd]]

---

## 🧠 Refinamiento de IA — deslizamiento, objetivo, vuelo, facción (2026-07-02)

Feedback del usuario validado en la Prueba A. Cuatro frentes de comportamiento + marcado de facción
(parámetros/límites vendrán en una pantalla dedicada — ver [[📌 Backlog (ES)|Backlog]] P1.5):

- **Fin del "deslizamiento" (unidades terrestres):** el movimiento MANUAL (strafe/retirada/formación, `_apply_direct_movement`)
  usaba `velocity = dir × speed` FIJA mientras reproducía `walk` a su cadencia natural → los pies patinaban. Ahora
  `_match_locomotion_cadence(speed)` escala el `speed_scale` del AnimationPlayer de locomoción (resuelto desde
  `animation_tree.anim_player`) para que la **cadencia de las piernas coincida con la velocidad real** → sin patinar
  (y una huida más rápida = las piernas ciclan más rápido). Fuera del modo manual, `_reset_locomotion_cadence()` vuelve a
  1.0 (APPROACH ya usa root motion, pies bloqueados). Ajustables: `walk_natural_speed` (2.2), `gait_speed_scale`.
  **Solo código** — el `.tscn` del AnimationTree NO se tocó (no hay nodo TimeScale; escalar el AnimationPlayer
  lo resuelve sin editar el árbol de blend de 10k líneas).
- **Formación menos rígida:** `formation_cohesion` 0.55→**0.32**, `formation_band` 5→**7 m**, y el rumbo del slot
  ahora **oscila suavemente** (`formation_wander` 0.5 rad, fase individual) → el punto "respira" en lugar de
  converger a coordenadas fijas. Menos pragmático, más orgánico.
- **Objetivo = jugador más cercano (multiplayer):** antes, el objetivo era el **1.º jugador** que entraba en el radio
  (`_on_area_body_entered` ponía `player = body`, objetivo único). Ahora `_players_in_range` mantiene a TODOS los
  jugadores en el radio de alerta y `_pick_target()` elige el **más cercano** cada fotograma, con **histéresis**
  (`TARGET_SWITCH_MARGIN` 2.5 m) para que no oscile. **Cualquier enemigo dispara a cualquier jugador** en el radio. También se aplica
  a la Criatura Alada (`_find_nearest_player`/`_collect_players` — antes `_find_player` cogía el 1.º).
- **Vuelo aéreo con altitud suave y contextual (Criatura Alada):** el bamboleo sinusoidal fijo pasó a ser un
  **cambio de capa** interpolado (`_alt_bias`, ease exponencial independiente del framerate): **AMENAZADA** (recibió un disparo, ventana `_recent_hit_t`
  de 3 s) → **asciende** hasta `escape_altitude_above_target` (24 m) para escapar; **a punto de bombardear**
  (`_bomb_cd ≤ 1.2 s` en PATROL) → **desciende** hasta `dive_altitude_above_target` (7.5 m) para precisión; de lo contrario
  crucero (`preferred_altitude_above_target` 14 m). La tasa vertical del cuerpo está limitada (`climb_speed × 1.6`)
  → el ascenso/descenso siempre es suave. El escape tiene prioridad sobre el bombardeo.
- **Marcado de facción (estructural):** `AIConfig.faction(model_key)` / `set_faction` (JSON por modelo, clave
  `"faction"`, precedencia user:// como los comportamientos). Valores `hostile`/`neutral`/`ally`; por defecto: red_robot
  y criatura_alada = **hostile**, player = **ally**. Todavía **no hay personaje neutral** — el campo existe y se
  lee (`is_hostile`/`is_neutral`), listo para la lógica "neutral solo reacciona si es amenazado (disparo/aleatoriedad)".

---

## 🚶 Locomoción realista — zancada emparejada + piernas encarando el avance (2026-07-08)

Corrección del "deslizamiento" de los enemigos terrestres. Reemplaza el intento anterior (sección 2026-07-02), que **no
funcionó**: escalar `AnimationPlayer.speed_scale` es **ignorado** cuando un `AnimationTree` controla la
animación — la cadencia nunca aceleraba de verdad.

**Diagnóstico (medido):** la animación `Walk` tiene una zancada natural de **~0.8 m/s** (su hueso de root-motion
`MASTER` recorre 2 m en 2.5 s), pero el código asumía `walk_natural_speed = 2.2` y la IA conducía
el cuerpo a 2.4–3.8 m/s en modo manual → el cuerpo se movía 3–4.75× más rápido que los pies. Además de eso,
`Walk` es **solo hacia adelante**: moverse de lado/hacia atrás con ella siempre desliza.

**Solución (3 frentes):**

1. **Cadencia vía el árbol (de verdad):** un nuevo nodo `AnimationNodeTimeScale` **`locomotion_scale`** insertado
   en el árbol de blend entre `state` y `aiming` (edita el `.tscn`). `_match_locomotion_cadence(speed)`
   ahora escribe `parameters/locomotion_scale/scale` (el mecanismo que el `AnimationTree` respeta), ya no el
   `speed_scale` del player. Rango `[0.6, 2.6]`.
2. **Zancada calibrada en tiempo de ejecución:** `_calibrate_walk_natural_speed()` en `_ready` mide la zancada real
   de `Walk` (desplazamiento horizontal de MASTER ÷ duración) → `walk_natural_speed ≈ 0.8`. Se mantiene correcta incluso si
   el artista reexporta la animación. El `@export` (0.8) es solo un fallback.
3. **Las piernas encaran el avance + desplazamiento desde root motion:** en modo manual `_face_move_direction` gira
   suavemente el **cuerpo** (`body_turn_rate` 7 rad/s) para encarar hacia donde camina, y la velocidad viene del
   **propio `get_root_motion_position()` de la animación** proyectado a lo largo de ese encaramiento. Como el cuerpo encara su
   movimiento, la pisada aterriza exactamente sobre el suelo recorrido → **sin deslizamiento en ninguna dirección**. La
   **torreta/cañón apunta al jugador por separado** (el blendspace `aim`), así que camina en una dirección y dispara
   al jugador.

**Nota de red:** la escala no se replica; en el cliente `_match_remote_cadence` estima la velocidad a partir de la
posición **interpolada** y empareja la cadencia local (el cuerpo ya llega encarando en la dirección correcta,
calculada en el servidor) → pies bloqueados también en el cliente.

**Velocidades de IA reducidas** a la banda que la zancada sostiene (cadencia ~1.75–2.5×): `strafe_speed` 2.4→**1.4**,
`pressure_speed` 3.2→**1.8**, `flee_speed` 3.8→**2.0**. APPROACH sigue con root motion natural (~0.8 m/s),
pies ya bloqueados. Por encima de 2.6× de zancada, la velocidad se **limita** (nunca desliza; solo se acota). Ajustables (rumbo
a la pantalla de parametrización de IA): `walk_natural_speed`, `body_turn_rate`, `gait_speed_scale`, y las velocidades
de IA.

---

### Suavizado de dirección (anti-jitter, 2026-07-08)

Como el cuerpo ahora **encara la dirección de avance**, el rumbo crudo de la IA (giros de strafe, re-búsqueda
de objetivo, sondas de geometría) hacía **temblar** al robot. Correcciones: `move_dir_response` (4.0) **filtra el
rumbo** antes de girar el cuerpo; `body_turn_rate` 7→**5** rad/s (giro más pesado); y la IA ahora
**se compromete con cada dirección de strafe durante 1.6–3 s** (antes ~0.5 s), incluidos los giros de geometría y
reposicionamiento. Los cambios de dirección ahora llegan gradualmente.

### Selección de objetivo por facción (2026-07-08)

`_pick_target` filtra por `Factions.are_enemies(self, target)` → el robot apunta **solo a la
facción OPUESTA** (tú + bots aliados), nunca a otro hostil ni a un neutral. El filtro está en la
**selección** de objetivo (no en la entrada al Area) → reacciona a los neutrales provocados que se vuelven aliados. Ver [[⚔️ facções (ES)|facções]].

---

## 🚶 Movimiento individualizado + formación (2026-06-25)

Para que los enemigos **no caminen todos idénticamente cada segundo**, la IA (`red_robot_ai.gd`) siembra en el
`_ready` de cada robot su propia **señal de strafe**, una **fase** y un **multiplicador de velocidad**
(RNG del servidor — el movimiento es autoritativo del servidor, los clientes solo interpolan), y los **giros de strafe**
ahora usan periodos aleatorios (`randf_range`) en lugar de exactamente ~1 s, rompiendo el lockstep.

Cada robot también mantiene un **slot de formación designado**: la 1.ª vez, captura la dirección desde el
jugador (derivada del punto de spawn) como `_slot_bearing` y, durante el combate, gana un **sesgo de retorno suave**
hacia el punto `player + slot_dir * preferred` (`formation_cohesion`/`formation_band`).
Resultado: el pelotón **rodea/hace strafe libremente**, pero tiende a **volver a la formación** en lugar de amontonarse.
Ajustables: `formation_cohesion` (0.55), `formation_band` (5 m), `speed_variation` (±0.18).

La **Criatura Alada** tiene su oscilación de vuelo (`_t`/bob) **desincronizada** entre instancias mediante una
`_bob_phase` aleatoria sembrada en `_ready` (y reutilizada al reingresar en PATROL), para que varias criaturas
no suban/bajen sincronizadas. Ver [[🧠 red-robot-ai-gd (ES)|red-robot-ai-gd]].

---

## 🔗 Relacionado

- [[🔫 combate-tiro (ES)|combate-tiro]]
- [[🤖 red-robot-gd (ES)|red-robot-gd]]
- [[🧠 red-robot-ai-gd (ES)|red-robot-ai-gd]]
- [[🦿 limb-colliders-gd (ES)|limb-colliders-gd]]

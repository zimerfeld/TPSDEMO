---
tipo: sistema
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# 🎮 Sistema del jugador

**Clase:** `Player` extiende `CharacterBody3D`
**Script:** `library3D/characters/players/player/player.gd`
**Escena:** `library3D/characters/players/player/player.tscn`

---

## 🔢 Constantes

| Constante | Valor | Descripción |
|---|---|---|
| `MOTION_INTERPOLATE_SPEED` | `10.0` | Suavizado del vector de movimiento |
| `ROTATION_INTERPOLATE_SPEED` | `10.0` | Suavizado de la rotación |
| `MIN_AIRBORNE_TIME` | `0.1` s | Tiempo mínimo en el aire antes de habilitar un salto |
| `JUMP_SPEED` | `6.5` | Velocidad vertical del salto (antes 5.0 — salto más alto) |
| `JUMP_CUT_DAMPING` | `14.0` /s | Salto variable: amortiguación del ascenso cuando la barra espaciadora se SUELTA a mitad del salto (corte suave); mantenerla hasta el final = arco completo |
| `AIM_WARMUP_TIME` | `0.45` s | Tiempo apuntando antes del **1.er disparo** (espera a que la puntería se asiente) |
| `MAX_HP` | `100` | Salud máxima |

---

## 🧮 Variables de estado

| Variable | Tipo | Descripción |
|---|---|---|
| `hp` | `int` | Salud actual (disminuye con `hit()`) |
| `airborne_time` | `float` | Tiempo acumulado en el aire |
| `orientation` | `Transform3D` | Rotación/orientación del jugador |
| `root_motion` | `Transform3D` | Acumulador de root motion |
| `motion` | `Vector2` | Vector de movimiento del input |

---

## 📤 Exports (sincronizados vía ServerSynchronizer)

| Export | Tipo | Descripción |
|---|---|---|
| `player_id` | `int` | ID del peer propietario; el setter asigna la autoridad en el InputSynchronizer |
| `current_animation` | `Animations` | Estado de animación actual |

---

## ⚙️ Lógica principal

### `_physics_process(delta)`
- **Servidor:** llama a `apply_input()` — toda la física corre en el servidor
- **Cliente:** llama solo a `animate()` para el feedback visual

### `apply_input(delta)`
1. Interpola `motion` con `player_input.motion`
2. Gestiona el salto y el tiempo en el aire — **salto variable (2026-07-03):** con la barra espaciadora MANTENIDA, el ascenso
   sigue el arco balístico completo (máxima animación y distancia); con la barra espaciadora SOLTADA durante el
   ascenso de un salto real (`_jump_active`), la velocidad vertical se amortigua por `exp(-JUMP_CUT_DAMPING·delta)`
   hasta que la gravedad toma el control (la animación cambia a `jump_down` en el apex temprano). El estado del botón llega
   a través del nuevo `player_input.jump_held` (sincronizado; sembrado `true` en el RPC `jump()`)
3. Si apunta: se orienta por el cuaternión de la cámara → estado STRAFE → dispara una bala **solo después de
   `_aim_held_time ≥ AIM_WARMUP_TIME`** (el disparo espera a que la puntería se asiente; arregla el glitch del cliente)
4. Si camina: se orienta por la dirección del movimiento → estado WALK
5. Aplica el root motion → `move_and_slide()`
6. Hace respawn si `y < -40`

---

## 📡 RPCs

| RPC | Modo | Qué hace |
|---|---|---|
| `jump()` | `call_local` | Anima el salto + sonido |
| `land()` | `call_local` | Anima el aterrizaje + sonido |
| `shoot()` | `call_local` | Partículas + flash + cooldown + camera shake |
| `hit()` | `call_local` | `-25 HP`, actualiza el HUD; si `hp==0` llama a `respawn.rpc()` |
| `respawn()` | `call_local` | Reinicia el HP, teletransporta a `initial_position` |
| `add_camera_shake_trauma(amount)` | `call_local` | Trauma de cámara |

---

## 🧷 Nodos hijos relevantes

| Nodo | Tipo | Uso |
|---|---|---|
| `InputSynchronizer` | `PlayerInputSynchronizer` | Input + cámara + HUD |
| `AnimationTree` | `AnimationTree` | Árbol de blend de animaciones |
| `PlayerModel` | `Node3D` | Modelo 3D del robot |
| `FireCooldown` | `Timer` | **0.7 s** entre disparos (antes 0.4 — cadencia más espaciada) |
| `SoundEffects/*` | `AudioStreamPlayer` | Jump, Land, Shoot |

---

## 🦿 Colisionadores de miembros (daño localizado)

- `_setup_limb_colliders()` en `_ready` crea colisionadores 3D nativos (`StaticBody3D` + `BoxShape3D`) por miembro
- Usa `effects_shared/limb_colliders.gd` sobre `PlayerModel/Robot_Skeleton/Skeleton3D` (playera hereda de Player)
- Layer 16 (bit5); la bala colisiona físicamente. Al disparar, el jugador excluye sus propios colisionadores (`_exclude_own_limbs`)
- Ver [[🦿 limb-colliders-gd (ES)|limb-colliders-gd]]

### Cápsula de locomoción auto-ajustada (2026-07-03)
Justo después de `build_for`, `_setup_limb_colliders` llama a
`lc.fit_locomotion_capsule($CapsuleShape3D, self)`: la cápsula de **bloqueo físico** deja de ser la
por defecto (0.5×2.0) y pasa a ser **proporcional al modelo** — radio a partir de la huella (torso+piernas),
altura a partir de la extensión vertical, base anclada al suelo. Sigue siendo **1 forma por personaje** (barata,
estable, amigable con el netcode). Detalles y validación en [[🩸 dano-localizado (ES)|dano-localizado]] ("Auto-ajuste por
modelo de la cápsula de locomoción"). El red_robot hace lo mismo ([[🤖 inimigos (ES)|inimigos]]).

---

## 🤝 Bots aliados (`bot_controlled`)

- Con `bot_controlled = true` (facción amiga en las plantillas), el mismo `player.gd` es controlado por una
  IA dedicada `library3D/characters/players/player/IA/player_bot_ai.gd` (instanciada en
  `_apply_bot_controlled`), que **cubre al jugador**: se enfrenta a las amenazas cercanas al bot o al
  jugador, pero **sigue al jugador** y respeta una **correa** (`max_leash`/`soft_leash`) — fuera de ella,
  reagruparse tiene prioridad, así que el aliado **no se va corriendo del mapa**. El bot también pasa por el
  `AIM_WARMUP_TIME` (apunta antes de disparar).

---

## 🔗 Relacionado

- [[❤️ sistema-de-vida (ES)|sistema-de-vida]]
- [[🔫 combate-tiro (ES)|combate-tiro]]
- [[🌐 multiplayer (ES)|multiplayer]]
- [[🤖 inimigos (ES)|inimigos]]
- [[🎮 player-gd (ES)|player-gd]]
- [[🕹️ player-input-gd (ES)|player-input-gd]]
- [[🦿 limb-colliders-gd (ES)|limb-colliders-gd]]

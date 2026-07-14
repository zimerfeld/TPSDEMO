---
tipo: sistema
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# 🔫 Sistema de combate y disparo

---

## 🧩 Componentes

| Archivo | Rol |
|---|---|
| `library3D/characters/players/player/player.gd` | Instancia la bala, dispara el RPC `shoot()` |
| `library3D/characters/player/bullet/bullet.gd` | Física de la bala, detección de colisiones, llama a `hit.rpc()` |
| `library3D/characters/player/bullet/bullet.tscn` | Escena de la bala: CharacterBody3D + AnimationPlayer + OmniLight |

---

## 🔄 Ciclo de disparo

1. `player_input.shooting` (Input capturado en el cliente local, replicado al servidor)
2. El servidor comprueba `fire_cooldown.time_left == 0` **y** `_aim_held_time ≥ AIM_WARMUP_TIME` (puntería asentada)
3. El servidor instancia `bullet.tscn`, lo posiciona en `ShootFrom`, aplica la dirección
4. `shoot.rpc()` → `call_local` → partículas + destello + sonido + sacudida de cámara (trauma 0.35)

> 🐞 **Bug de la "bala fantasma atascada en el cañón" en el cliente (corregido 2026-06-24):** `apply_input()` se ejecuta
> en el servidor **y** en la predicción del cliente local. El bloque de disparo (y los RPC `jump`/`land`/`shoot`)
> se ejecutaban en ambos → el cliente instanciaba una bala `bullet.tscn` LOCAL que, al no ser el servidor, tenía
> `_physics_process` desactivado y **no se replicaba ni se destruía** → se quedaba atascada en el cañón
> "para siempre" (un efecto que "no desaparece"). **Solución** (`player.gd`): calcula `authoritative = is_server()` al
> principio de `apply_input` y encierra los efectos autoritativos (spawn de la bala + `shoot/jump/land.rpc()`)
> detrás de él. La predicción del **movimiento** (velocidad, `move_and_slide`, salto) sigue siendo local/responsiva;
> solo lo que es autoritativo pasó a ser exclusivo del servidor. Sin conexión (`OfflineMultiplayerPeer` =
> servidor) dispara con normalidad.

### 🎯 Dirección del disparo
```gdscript
var ray_from = camera.project_ray_origin(crosshair_center)
var ray_dir  = camera.project_ray_normal(crosshair_center)
# 1000-unit ray; collision → shoot_target = col.position
# No collision → shoot_target = ray_from + ray_dir * 1000
```

> 🐞 **Bug de la "bala torcida" en puntería→disparo muy rápido (corregido):** la bala sale desde `shoot_from` (cañón,
> unido al `player_model`). Al apuntar, el cuerpo rotaba hacia la cámara mediante un **slerp lento**
> (`ROTATION_INTERPOLATE_SPEED`); en un puntería→disparo en 1-2 fotogramas el cañón aún apuntaba en la ANTIGUA
> dirección mientras el `shoot_target` ya era el de la cámara → dirección incorrecta. **Solución** (`player.gd`,
> rama de puntería): al **entrar en puntería** (`_was_aiming` false → true) el cuerpo se **alinea con la cámara en
> el acto** (`orientation.basis = Basis(q_to)` + actualiza inmediatamente el `player_model`), sin slerp, antes de la
> prueba de disparo. Los fotogramas siguientes continúan con el slerp normal.

> 🎯 **Calentamiento de puntería (`AIM_WARMUP_TIME = 0.45 s`, 2026-06-25):** el disparo ahora solo ocurre
> después de que el jugador haya estado apuntando durante ≥ `AIM_WARMUP_TIME` (`_aim_held_time` se acumula en la rama de puntería
> de `apply_input`, se reinicia al salir de la puntería / en el aire). Así **la bala sale solo después de que la animación
> de puntería se asiente y el cañón esté alineado** — corrige el fallo en el jugador **cliente**, cuyo cuerpo se
> renderiza ~100 ms en el pasado y hacía que la bala pareciera salir antes de la puntería / fuera del cañón. Se aplica al
> host, al cliente y a los bots; no afecta a los disparos sostenidos (encerrados por el `FireCooldown`), solo al 1.º tras apuntar.

---

## 💥 Bala (`bullet.gd`)

| Propiedad | Valor |
|---|---|
| Velocidad | `20.0` u/s |
| Tiempo de vida | `5.0` s |
| Procesamiento de física | Solo **servidor** |
| Colisión del cliente | Desactivada (`disabled = true`) |

### En la colisión
```gdscript
if collider.has_method("hit"):
    collider.hit.rpc()   # hits any node with a hit() method
collision_shape.disabled = true
explode.rpc()
```

---

## ⏱️ Tiempo de recarga del disparo

- Timer `FireCooldown`: **0.7 s**, auto-start (era 0.4 — cadencia más espaciada)
- Comprobado en `apply_input()`: `fire_cooldown.time_left == 0`

---

## 🔵 Aspecto de la bala (bolita)

- La **bolita visible** = `MeshInstance3D` (SphereMesh, escala **0.13**) con material `StandardMaterial3D_ffosa`:
  **unshaded + azul HDR** `Color(0.14902, 0.74902, 1.50196)` (canal azul > 1 → "florece" en el glow). Antes era blanca sin color y dependía al 100% del glow de la escena; ahora es vívidamente azul incluso **sin** bloom.
- El color extra viene del `OmniLight3D` azul + la estela de partículas (`BulletBody/MainBody`, `Trail`).
- `CannonShooter.fire(...)` acepta `tint`/`ball_color`/`ball_scale` (alfa 0 = conserva el aspecto de origen, el disparo azul del jugador); `bullet.gd._apply_visuals()` lo aplica en todos los peers.
- ⚠️ El efecto de "orbe brillante" depende del **glow/bloom** del `Environment`. `level_1`/`level_2` tienen `glow_enabled` + `glow_hdr_threshold=0.9` + `glow_intensity` inline para que la bala florezca. El ajuste "bloom" (`config.gd`) activa/desactiva `glow_enabled` en tiempo de ejecución.

---

## 📍 Punto de aparición de la bala

- `ShootFrom`: `Marker3D` en `Robot_Skeleton/Skeleton3D/GunBone/ShootFrom`
- Desplazamiento: `(0, 0.4, 0)` relativo al hueso del cañón

---

## ✴️ Aniquilación mutua proyectil × proyectil (2026-06-24)

Cuando dos proyectiles colisionan — una bala del jugador, una bala de cañón del red_robot (ambas `bullet.tscn`)
o la bomba de la criatura (`bomb.tscn`) — **ambos se destruyen** con una explosión (puedes "derribar" la
bala de cañón/bomba del enemigo en pleno vuelo).

- **Colisión:** todos los proyectiles están en la **capa 4** (valor 8) y nada más usa esta capa. Las
  **máscaras** ganaron el bit 4 (bala `51→59`, bomba `3→11`) → ahora colisionan **solo entre sí**,
  sin tocar la colisión con el mundo/los personajes.
- **Detección:** ambos se unen al grupo `&"projectiles"` en `_ready`. En `move_and_collide` (servidor),
  si el `collider` está en este grupo → llama a `annihilate()` sobre sí mismo y sobre el otro y retorna (antes de la
  lógica de daño/fase). Es **idempotente** (guardas `hit`/`_done`), así que da igual cuál detecte
  primero ni si ambos detectan en el mismo fotograma.
- **`annihilate()`:** en la bala = explota + desactiva la colisión (mismo resultado que un impacto); en la bomba =
  `_explode(null)` (detona sin daño al jugador). Las explosiones/eliminaciones se replican vía los RPC `call_local`
  existentes + despawn del `MultiplayerSpawner` → **sin tráfico de red extra**.
- ⚠️ Best-effort: proyectiles muy rápidos y pequeños pueden "tunelar" en un fotograma; la bala de cañón
  (más grande, `ball_scale 2.5`) y la bomba son blancos fáciles.

---

## 📷 Sacudida de cámara

| Evento | Trauma |
|---|---|
| Disparar | `0.35` |
| Ser impactado | `0.75` |

---

## 🛡️ Daño por facción — sin fuego amigo (2026-07-08)

El daño ya no es "impacta a cualquiera salvo al propio tirador"; ahora respeta el
[[⚔️ facções (ES)|sistema de facciones]]:

- **`bullet.gd`** y **`bomb.gd`** comprueban `Factions.can_damage(shooter/dropper, target)` antes de
  aplicar daño. **Misma facción → sin daño.**
- La **bala ATRAVIESA** a un personaje de la misma facción (excepción de colisión, como ya hace con
  un cuerpo que posee colisionadores de miembros) en lugar de explotar → **no bloquea la línea de fuego** de
  quien esté detrás.
- Cuando el daño impacta, `Factions.note_damage(...)` **provoca** a un objetivo neutral (lo alinea contra el atacante).
- Solo el servidor aplica daño (autoritativo del servidor), así que la facción solo necesita existir en el servidor.

---

## 🔗 Relacionado

- [[🎮 player (ES)|player]]
- [[❤️ sistema-de-vida (ES)|sistema-de-vida]]
- [[💥 bullet-gd (ES)|bullet-gd]]
- [[⚔️ facções (ES)|facções]]

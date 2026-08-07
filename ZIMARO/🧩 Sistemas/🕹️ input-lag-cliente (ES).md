---
lang: es-ES
---

# 🕹️ Input lag del cliente

Investigación y corrección de la latencia de respuesta que siente quien juega como **cliente**
(2026-08-07). Notas hermanas: [[🕹️ input-lag-cliente (PT)|PT]] · [[🕹️ input-lag-cliente (EN)|EN]].
Ver también [[🚪 salas (ES)]] y [[🧩 templates-de-level (ES)]].

## El encuadre que cambió el diagnóstico

Levantamos 58 hipótesis de latencia y verificamos cada una contra el código; 29 se confirmaron. El
hallazgo que ordena todo: **casi todo número grande es simétrico** — host y cliente pagan igual
(calentamiento de puntería, vsync, interpolación de física, slerp del cuerpo, coste de GPU). Lo que
**solo paga el cliente**:

| Término asimétrico | Coste | Dónde |
| --- | --- | --- |
| El feedback del disparo solo vuelve por `shoot.rpc()` | RTT + ~35 ms | `player.gd` |
| Cuantización de la subida de input | 0–33 ms (media 16,7) | `player_input.gd` |
| `render_delay_ms` en la edad de los objetivos remotos | 60 ms (estaba en **100**) | `net_config.gd` |
| RTT del túnel playit | no medido | transporte |

Es decir: quejarse de "input lag" y tocar GPU/vsync no arreglaría nada — el host también los paga, y
el host no se queja.

## Qué se corrigió

- **Feedback del disparo predicho en el cliente** (`player.gd`). Lo sensorial (partícula, fogonazo,
  sonido, sacudida) salió de `shoot()` hacia `_play_shot_fx()`; el cliente dueño lo reproduce en el
  instante del clic y el `shoot()` del servidor, que llega después, lo reconoce y no lo repite
  (`SHOT_FX_DEDUPE_MS`). **La bala y el daño siguen 100% en el servidor** — solo se adelantó lo que el
  jugador ve y oye. Dos trampas evitadas: el gate local usa reloj propio (`_local_fx_at` + el
  `wait_time` del cooldown), **no** el `FireCooldown` (que solo inicia el servidor); y el **primer**
  disparo de cada sesión de puntería no se predice — el calentamiento local va por delante del
  servidor, y predecirlo dispararía el efecto antes de la autorización, de forma sistemática.
- **Subida del input desacoplada de `sync_hz`** (`player_input.gd` + `NetConfig.input_interval()`).
  La "Tasa de sincronización" dimensiona el **broadcast de estado** (muchas entidades × muchos
  peers); atarle un paquete de ~40 B con las teclas de un jugador ponía hasta 33 ms delante de cada
  acción para ahorrar ~2 KB/s. Ahora el cliente envía al ritmo del frame. **Guard obligatorio**
  `if not multiplayer.is_server()`: en el host ese mismo synchronizer es autoritativo y
  `apply_authority` es diferido — sin el guard sobrescribiría el intervalo que RoomManager aplicó.
- **`AIM_WARMUP_TIME` 0,45 → 0,25 s** y decaimiento en vez de puesta a cero en el aire. El suelo
  técnico es 0,20 s (el `xfade_time` del `AnimationNodeTransition` que asienta la pose del GunBone);
  por debajo vuelve el glitch de la bala fuera del cañón. Y un salto borraba todo el calentamiento de
  quien llevaba rato apuntando.
- **`reset_physics_interpolation()` tras el snap de `_reconcile`**. Con interpolación de física
  activa, la corrección de posición se dibujaba rasgando desde la posición antigua a la nueva.
- **Bug del SSAO** (`config.gd`): el segundo test era `if` y no `elif`, así que "Desactivado" caía en
  el `else` y **reactivaba** el efecto — y el mapeo estaba cambiado (Media pedía HIGH a resolución
  completa, el más caro de los tres). Corregido y desactivado de fábrica.
- **La bala avanza suave en el cliente** (`bullet.gd`): solo recibía el transform a 30 Hz y saltaba
  0,67 m por muestra. Ahora integra la posición por frame — solo visual, sin colisión, daño ni RPC.
  A propósito sin `NetInterp`: interpolar renderiza en el pasado y dejaría la bala detrás del cañón.
- **Preferencia de interpolación** de vuelta de "Suave" (100 ms) a "Equilibrado" (60 ms) — 40 ms de
  edad de los objetivos, sin una línea de código.

## Qué quedó fuera, y por qué

- **Dejar de replicar `.:motion` al dueño** (el servidor sobrescribe la predicción ~30×/s) y
  **reconciliación suave con umbral por RTT**: ambos tocan el mismo punto y tienen dependencia dura —
  la reconciliación va primero, si no se cambia "movimiento blando" por "teletransporte cada 2 m". Y
  no hay **ninguna evidencia medida** de que el snap se dispare hoy: instrumentar un contador antes.
- **Búfer de input con replay/rollback**: inviable en esta arquitectura, no es cuestión de riesgo. El
  movimiento es 100% root motion del `AnimationTree`, y el motor no ofrece snapshot/restore del
  estado de blend/xfade ni rebobinado del mundo físico.
- **Rig de cámara fuera de la interpolación de física**: 8–11 ms medidos en un harness headless, pero
  es **simétrico** y exige `top_level` + `get_global_transform_interpolated()`.
- **`frame_queue_size=1`**: valor inválido (el mínimo del motor es 2).
- **Compresión RANGE_CODER**: coste en microsegundos; cambiarla en un solo lado rompe la conexión
  antes del handshake de versión — fallo mudo.

## Bug registrado aparte

**`hp` no está en ningún `SceneReplicationConfig`.** Un `hit()`/`respawn()` perdido causa desincronía
**permanente** de vida/miembros en el HUD del cliente. No es latencia: es estado que nunca se
autocura. Merece su propia corrección.

## Cómo medirlo de verdad

Nada de lo anterior se cronometró dentro del juego — las cuentas vienen del código (rejillas de
16,7/33,3 ms, RTT). El camino honesto: encender el Performance HUD y registrar `NET`
(`PEER_ROUND_TRIP_TIME`), FPS y frame time en las cuatro combinaciones (host × cliente, loopback ×
túnel), antes y después. Para el disparo, instrumentar `Time.get_ticks_usec()` entre
`is_action_just_pressed("shoot")` y la entrada de `_play_shot_fx()`: el objetivo es que el delta del
cliente baje al mismo orden que el del host.

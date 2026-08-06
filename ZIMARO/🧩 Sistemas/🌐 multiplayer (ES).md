---
tipo: sistema
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# 🌐 Arquitectura multijugador

---

## Modelo: Server-Authoritative

```
                ┌─────────────────────┐
                │       SERVER        │
                │  - player physics   │
                │  - bullet physics   │
                │  - enemy AI         │
                └────────┬────────────┘
                         │ RPC / MultiplayerSynchronizer
              ┌──────────┼──────────┐
         ┌────▼───┐  ┌───▼────┐ ┌──▼─────┐
         │Client 1│  │Client 2│ │Client N│
         │ animate│  │ animate│ │ animate│
         └────────┘  └────────┘ └────────┘
```

---

## Nodos de sincronización

### `ServerSynchronizer` (en `player.tscn`)
Replica servidor → clientes:
- `net_transform` (proxy de `transform` para interpolación — ver la sección anti-flicker)
- `net_model_transform` (proxy de `PlayerModel:transform`)
- `player_id`
- `motion`
- `current_animation`
- `spawn_position`

### `InputSynchronizer` (PlayerInputSynchronizer)
Replica cliente-propietario → servidor:
- `aiming`
- `shoot_target`
- `motion`
- `shooting`
- `jumping` (vía RPC)

---

## Patrón de procesamiento

| Código | Corre en |
|---|---|
| `player.apply_input()` | Solo servidor |
| `player.animate()` | Solo clientes |
| `bullet._physics_process()` | Solo servidor |
| `red_robot._physics_process()` | Solo servidor |
| `criatura_alada._physics_process()` | Solo servidor (el cliente solo interpola — ver anti-flicker) |
| `bomb._physics_process()` | Solo servidor (el cliente recibe el `global_transform` replicado) |
| `player_input._process()` | Solo el peer propietario (`authority`) |

---

## RPCs principales

| RPC | Declaración | Dirección típica |
|---|---|---|
| `player.hit()` | `call_local` | Servidor → todos |
| `player.respawn()` | `call_local` | Servidor → todos |
| `player.shoot()` | `call_local` | Servidor → todos |
| `player.jump()` / `land()` | `call_local` | Servidor → todos |
| `player_input.jump()` | `call_local` | Cliente → servidor |
| `red_robot.hit()` | `call_local` | Servidor → todos |
| `red_robot.play_shoot()` | `call_local` | Servidor → todos |
| `bullet.explode()` | `call_local` | Servidor → todos |

---

## Ciclo de vida del jugador

### Todos los niveles usan el mismo patrón (server-authoritative)
`level_1` y `level_2` tienen un `MultiplayerSpawner` (spawn_path → `SpawnedNodes`)
+ `PlayerSpawnpoints` (Marker3D) y, en `_ready`, **solo el servidor** genera al enemigo(s) y a los
jugadores:
```gdscript
if multiplayer.is_server():
    # enemy(ies) → spawned_nodes.add_child(...)   (replicated by the spawner)
    add_player(1, spawn_point)                    # host/offline = peer 1
    for id in multiplayer.get_peers(): add_player(id, ...)
    multiplayer.peer_connected.connect(add_player)
    multiplayer.peer_disconnected.connect(del_player)
# add_player: player.name = str(id); player.player_id = id (→ authority of the InputSynchronizer)
```
- **Offline** (OfflineMultiplayerPeer): `is_server()` = true, `get_peers()` = vacío →
  genera solo el jugador 1. El **mismo script** sirve offline y online.
- **Modo "Host Only"** (`PlayerSelection.spectator_host`): con `spawn_host=false`, el **`NetSpawn`**
  añade una **cámara libre no replicada** en lugar del jugador del host.
  Centralizado en `NetSpawn._add_spectator_camera` **(2026-06-24)** → funciona en todos los niveles (antes
  esto lo gestionaba un único nivel; los demás lo ignoraban y creaban un jugador incluso en "Host Only").
  Ver [[🛰️ hospedagem-online (ES)\|hospedagem-online]].
- El `_spawnable_scenes` de cada spawner lista los **jugadores** (`player` + `playera`), el
  **enemigo del nivel** (`red_robot` en level_1/base, `criatura_alada` en level_2), la
  **bala** y, en level_2, la **bomba** de la criatura (ambas disparadas bajo `SpawnedNodes`, necesitan replicar).
- Los niveles se eligen en el flujo de **Play Online** (chooseplayer → levels → playonline);
  ver [[🎬 fluxo-de-cenas (ES)\|fluxo-de-cenas]].

---

## Posición de spawn del cliente (`spawn_position`)

El transform replicado **no llega a tiempo** al cliente que entra: el jugador nacía en **(0,0,0)** y
**se caía del mapa** (el host iba bien). Solución determinista (el mismo mecanismo fiable que
`player_id`):

- `player.gd` tiene **`@export var spawn_position: Vector3`** con un setter que llama a
  `_apply_spawn_position()` (fija `global_position`, `initial_position`, pone a cero `velocity` y
  `_has_prediction`, y `reset_physics_interpolation()`). Registrado en `ServerSynchronizer` como
  **propiedad de spawn** (`spawn=true`, `replication_mode=0` = solo en el paquete de spawn).
- **`NetSpawn._spawn`** (ver la sección anterior) fija `player.spawn_position = spawn_point.transform.origin`
  antes de `add_child`. En el cliente el setter se dispara cuando la propiedad llega → reposiciona.
- `playera` hereda todo (instancia `player.tscn` + `extends Player`).
- ⚠️ Centinela: `spawn_position == Vector3.ZERO` se ignora — **ningún spawnpoint puede estar
  exactamente en (0,0,0)** (los marcadores usan y ≥ 1). También arregla el respawn (usa `initial_position`).

---

## Autoridad de input en el cliente (timing del Spawner)

El `MultiplayerSpawner` crea al jugador en el cliente y **solo después** aplica la
propiedad `player_id` replicada — que define la autoridad del `InputSynchronizer`. Como
`InputSynchronizer._ready()` ya corrió antes de eso, no puede decidir "¿soy yo el propietario?"
solo en `_ready`.

- `player_input.gd` → método **`apply_authority()`** (reentrante): activa la cámara local
  (`make_current`) + la lectura de input cuando es el propietario; apaga `_process`/input
  en caso contrario. Llamado en `_ready` **y** de nuevo por el setter de `player_id`.
- `player.gd` → el setter de `player_id` llama a `$InputSynchronizer.apply_authority.call_deferred()`
  cuando ya está en el árbol (un cliente que entra).

> 🐞 **Síntoma si esto se rompe:** el cliente remoto "nace en el centro del mapa" (en realidad es
> la cámara atascada en el origen, porque no se llamó a `make_current`) y **no se mueve** (input
> apagado, `motion` queda en cero y nada llega al servidor). En el host no aparece porque allí
> `player_id` se fija **antes** del `add_child`.

---

## Suavizado del movimiento remoto (anti-flicker) — buffer de interpolación

En el **cliente**, los jugadores/robots remotos no tienen predicción (`apply_input` corre solo en el servidor): la pose
llega a través del `MultiplayerSynchronizer` ~30x/s. Aplicar ese transform en bruto genera **stutter/flicker**. La
solución "adecuada" para netcode sobre UDP es un **buffer de interpolación con snapshots con marca de tiempo**.

- **`effects_shared/net_interp.gd`** (`class_name NetInterp`, RefCounted): almacena las muestras
  `Transform3D` recibidas con su hora de llegada (`Time.get_ticks_msec()`) y devuelve el transform
  interpolado en el instante **(ahora − 100 ms)** (`RENDER_DELAY_MS`), vía `Transform3D.interpolate_with`
  (lerp del origen + slerp de la base). Renderizar "en el pasado" siempre garantiza 2 muestras alrededor → sin
  extrapolación. Barato (una búsqueda lineal corta + 1 interpolate por frame) → **no pesa en los FPS**.
- **Proxies replicados** en lugar del transform en bruto: el `ServerSynchronizer` del jugador ahora
  replica **`.:net_transform`** y **`.:net_model_transform`** (en vez de `.:transform` y
  `PlayerModel:transform`); el `red_robot` y la **`criatura_alada` (2026-06-24)** replican
  **`.:net_transform`** (en vez de `.:global_transform`). Sin esto la criatura **no tenía
  `MultiplayerSynchronizer` en absoluto** y quedaba **congelada en los clientes** (solo se simulaba en el host).
  - **Servidor**: refleja el estado real en los proxies cada frame (`net_transform = transform`).
  - **Cliente remoto** (`_interpolate_remote`): bufferiza los proxies y aplica el transform interpolado.
  - **Cliente PROPIETARIO**: usa `net_transform` como la **verdad del servidor** en `_reconcile` (el transform real
    ya NO es sobrescrito por el sync → predicción local más estable, sin peleas de snap).
- **Tasa de replicación** ~30 Hz (`replication_interval` 0.033) + **`reset_physics_interpolation()`**
  en cada salto (spawn/teleport) y en la 1.ª muestra interpolada (evita el "tirón" desde el origen).
- `net_transform` es una **propiedad de spawn** sembrada **solo en el servidor** en `_ready` (en el cliente el valor
  llega vía replicación de spawn; sembrar en el cliente interpolaría desde (0,0,0)).
- El **host no nota** nada: es el servidor, todo corre en física local a 60 Hz, sin sync.
- **Tuning**: `NetInterp.RENDER_DELAY_MS` (100 ms). Más alto = más suave pero más "atrasado";
  más bajo = más responsivo pero sensible al jitter de UDP.

---

## Variante/color por peer (loadout) — `NetSpawn`

Antes, el servidor generaba **todos** los jugadores desde SU propio `PlayerSelection.scene_path`
→ la variante/color que el **cliente** eligió (p. ej. `playera`) no aparecía. Centralizado en el autoload
**`NetSpawn`** (`autoload/net_spawn.gd`, path `/root/NetSpawn` igual en todos los peers → RPC
fiable):

- `chooseplayer` almacena **`PlayerSelection.variant_id`** (un índice en `PlayerSelection.VARIANTS`, mismo
  orden que el selector). Viaja como un **int** (no una ruta arbitraria) en el RPC.
- Cada nivel llama a **`NetSpawn.setup(spawned_nodes, player_spawn_points, not PlayerSelection.spectator_host)`**
  en `_ready` (reemplaza el `add_player`/`del_player` duplicado en los niveles). Los niveles pasan
  el mismo argumento → comportamiento "Host Only" uniforme **(2026-06-24)**.
  - **Host**: se genera a sí mismo (peer 1) con su propia variante. `spawn_host=false` en "Host Only"
    → `NetSpawn` añade la cámara libre en lugar del jugador.
  - **Escenario en ejecución**: `NetSpawn` almacena la ruta de la escena del nivel (`_server_scenario`) y
    se la responde al cliente vía los RPCs **`request_scenario`/`answer_scenario`** — usado por `playonline`
    para confirmar la reconexión solo cuando el cliente entra en el **mismo escenario**. Ver [[🛰️ hospedagem-online (ES)\|hospedagem-online]].
  - **Cliente que entra**: el servidor **reserva el spawn y ESPERA** a que el cliente informe la variante vía
    `register_loadout.rpc_id(1, variant_id)` (enviado en `connected_to_server`); solo entonces genera el
    modelo correcto. El `MultiplayerSpawner` replica la escena instanciada → el color/variante aparece en TODOS los
    peers (`playera.gd` aplica el tinte en el `_ready` de cada instancia). Fallback de 5 s → variante por defecto.
  - **Spawn points de un nivel ya destruido (2026-08-06).** `NetSpawn` es un autoload: **sobrevive al cambio
    de escena** y guarda los `Marker3D` del último `setup()`. El preload de arranque del
    [[⏳ loading-screen (ES)|LoadingScreen]] instancia un level de verdad durante unos frames — y como
    `OfflineMultiplayerPeer` hace que `is_server()` sea `true`, ese level registraba sus spawn points y la
    señal `peer_connected`; al liberarse, la cola quedaba con marcadores muertos. El primer cliente en
    conectar caía en `_take_point()` → **"Trying to return a previously freed instance"** (`net_spawn.gd:176`).
    Correcciones: `_take_point` **descarta** las entradas inválidas de la cola (y valida el sorteo de
    fallback) mediante el nuevo `_valid_point`; `_await_loadout` **sale temprano** si `_spawned_nodes` ya no
    existe (no hay dónde spawnear); `register_loadout`/`_loadout_timeout` revalidan el punto reservado y
    toman otro si murió durante la espera.

---

## Modo offline

- `main.gd` usa `OfflineMultiplayerPeer`
- `multiplayer.get_unique_id()` devuelve `1`
- `multiplayer.is_server()` devuelve `true`
- Todo el código funciona con normalidad

---

## Relacionado

- [[🎮 player (ES)\|player]]
- [[⌨️ fluxo-de-input (ES)\|fluxo-de-input]]
- [[🛰️ hospedagem-online (ES)\|hospedagem-online]] — jugar con amigos por internet (playit.gg / Tailscale / port forwarding)

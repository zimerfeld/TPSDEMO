# Arquitetura Multiplayer

---

## Modelo: Server-Authoritative

```
                ┌─────────────────────┐
                │       SERVIDOR      │
                │  - física do player │
                │  - física das balas │
                │  - IA dos inimigos  │
                └────────┬────────────┘
                         │ RPC / MultiplayerSynchronizer
              ┌──────────┼──────────┐
         ┌────▼───┐  ┌───▼────┐ ┌──▼─────┐
         │Client 1│  │Client 2│ │Client N│
         │ anima  │  │ anima  │ │ anima  │
         └────────┘  └────────┘ └────────┘
```

---

## Nós de Sincronização

### `ServerSynchronizer` (em `player.tscn`)
Replica do servidor → clientes:
- `net_transform` (proxy do `transform` p/ interpolação — ver seção anti-flicker)
- `net_model_transform` (proxy do `PlayerModel:transform`)
- `player_id`
- `motion`
- `current_animation`
- `spawn_position`

### `InputSynchronizer` (PlayerInputSynchronizer)
Replica do cliente-dono → servidor:
- `aiming`
- `shoot_target`
- `motion`
- `shooting`
- `jumping` (via RPC)

---

## Padrão de Processamento

| Código | Roda em |
|---|---|
| `player.apply_input()` | Apenas servidor |
| `player.animate()` | Apenas clientes |
| `bullet._physics_process()` | Apenas servidor |
| `red_robot._physics_process()` | Apenas servidor |
| `criatura_alada._physics_process()` | Apenas servidor (cliente só interpola — ver anti-flicker) |
| `bomb._physics_process()` | Apenas servidor (cliente recebe o `global_transform` replicado) |
| `player_input._process()` | Apenas o peer dono (`authority`) |

---

## RPCs Principais

| RPC | Declaração | Direção típica |
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

## Ciclo de Vida do Player

### Todos os níveis usam o mesmo padrão (server-authoritative)
`level_1`, `level_2` e `level_base` têm `MultiplayerSpawner` (spawn_path → `SpawnedNodes`)
+ `PlayerSpawnpoints` (Marker3D) e, no `_ready`, **só o servidor** spawna inimigo(s) e
players:
```gdscript
if multiplayer.is_server():
    # inimigo(s) → spawned_nodes.add_child(...)   (replicado pelo spawner)
    add_player(1, spawn_point)                    # host/offline = peer 1
    for id in multiplayer.get_peers(): add_player(id, ...)
    multiplayer.peer_connected.connect(add_player)
    multiplayer.peer_disconnected.connect(del_player)
# add_player: player.name = str(id); player.player_id = id (→ authority do InputSynchronizer)
```
- **Offline** (OfflineMultiplayerPeer): `is_server()` = true, `get_peers()` = vazio →
  spawna só o player 1. O **mesmo script** serve offline e online.
- **Modo "Hospedar Somente"** (`PlayerSelection.spectator_host`): com `spawn_host=false`, o **`NetSpawn`**
  (não mais só o `level_base`) adiciona uma **câmera livre não replicada** em vez do player do host.
  Centralizado em `NetSpawn._add_spectator_camera` **(2026-06-24)** → funciona nos **3 níveis** (antes
  só o `level_base` tratava; `level_1`/`level_2` ignoravam e criavam player mesmo no "Hospedar Somente").
  Ver [[sistemas/hospedagem-online]].
- `_spawnable_scenes` de cada spawner lista os **players** (`player` + `playera`), o
  **inimigo do nível** (`red_robot` no level_1/base, `criatura_alada` no level_2), a
  **bullet** e, no level_2, a **bomb** da criatura (ambos disparados sob `SpawnedNodes`, precisam replicar).
- Os níveis são escolhidos no fluxo **Jogar Online** (chooseplayer → levels → playonline);
  ver [[fluxos/fluxo-de-cenas]].

---

## Posição de spawn do cliente (`spawn_position`)

O transform replicado **não chega a tempo** no cliente que entra: o player nascia em **(0,0,0)** e
**caía do mapa** (o host ficava certo). Solução determinística (mesmo mecanismo confiável do
`player_id`):

- `player.gd` tem **`@export var spawn_position: Vector3`** com setter que chama
  `_apply_spawn_position()` (seta `global_position`, `initial_position`, zera `velocity` e
  `_has_prediction`, e `reset_physics_interpolation()`). Registrada no `ServerSynchronizer` como
  **spawn property** (`spawn=true`, `replication_mode=0` = só no pacote de spawn).
- **`NetSpawn._spawn`** (ver seção acima) seta `player.spawn_position = spawn_point.transform.origin`
  antes do `add_child`. No cliente o setter dispara ao chegar a property → reposiciona.
- `playera` herda tudo (instancia `player.tscn` + `extends Player`).
- ⚠️ Sentinela: `spawn_position == Vector3.ZERO` é ignorado — **nenhum spawnpoint pode ficar
  exatamente em (0,0,0)** (os markers usam y ≥ 1). Também conserta o respawn (usa `initial_position`).

---

## Autoridade do Input no cliente (timing do Spawner)

O `MultiplayerSpawner` cria o player no cliente e **só depois** aplica a propriedade
replicada `player_id` — que define a autoridade do `InputSynchronizer`. Como o
`InputSynchronizer._ready()` já rodou antes disso, ele não pode decidir "sou o dono?"
apenas no `_ready`.

- `player_input.gd` → método **`apply_authority()`** (reentrante): ativa câmera local
  (`make_current`) + leitura de input quando é o dono; desliga `_process`/input caso
  contrário. Chamado no `_ready` **e** de novo pelo setter de `player_id`.
- `player.gd` → setter de `player_id` chama `$InputSynchronizer.apply_authority.call_deferred()`
  quando já está na árvore (cliente que entra).

> 🐞 **Sintoma se isso quebrar:** cliente remoto "nasce no centro do mapa" (na verdade é
> a câmera presa no origin, pois `make_current` não foi chamado) e **não se move** (input
> desligado, `motion` fica zerado e nada chega ao servidor). No host não aparece porque lá
> o `player_id` é setado **antes** do `add_child`.

---

## Suavização do movimento remoto (anti-flicker) — buffer de interpolação

No **cliente**, players/robôs remotos não têm predição (o `apply_input` roda só no servidor): a pose
vem pelo `MultiplayerSynchronizer` ~30x/s. Aplicar esse transform cru gera **stutter/flicker**. A
solução "de verdade" para netcode sobre UDP é um **buffer de interpolação com snapshots datados**.

- **`effects_shared/net_interp.gd`** (`class_name NetInterp`, RefCounted): guarda as amostras de
  `Transform3D` recebidas com o horário de chegada (`Time.get_ticks_msec()`) e devolve o transform
  interpolado no instante **(agora − 100 ms)** (`RENDER_DELAY_MS`), via `Transform3D.interpolate_with`
  (lerp da origem + slerp da base). Render "no passado" garante sempre 2 amostras ao redor → sem
  extrapolar. Barato (busca linear curta + 1 interpolate por frame) → **não pesa no FPS**.
- **Proxies replicados** no lugar do transform cru: o `ServerSynchronizer` do player passou a
  replicar **`.:net_transform`** e **`.:net_model_transform`** (em vez de `.:transform` e
  `PlayerModel:transform`); o `red_robot` e a **`criatura_alada` (2026-06-24)** replicam
  **`.:net_transform`** (em vez de `.:global_transform`). Sem isto a criatura **não tinha
  `MultiplayerSynchronizer` algum** e ficava **parada nos clientes** (só simulava no host).
  - **Servidor**: espelha o estado real nos proxies a cada frame (`net_transform = transform`).
  - **Cliente remoto** (`_interpolate_remote`): bufferiza os proxies e aplica o transform interpolado.
  - **Cliente DONO**: usa `net_transform` como **verdade do servidor** na `_reconcile` (o transform
    real NÃO é mais sobrescrito pelo sync → predição local mais estável, sem briga de snap).
- **Taxa de replicação** ~30 Hz (`replication_interval` 0.033) + **`reset_physics_interpolation()`**
  em todo salto (spawn/teleporte) e na 1ª amostra interpolada (evita o "rasgo" a partir da origem).
- `net_transform` é **spawn property** semeada **só no servidor** no `_ready` (no cliente o valor
  chega pela replicação de spawn; semear no cliente faria interpolar a partir de (0,0,0)).
- O **host não percebe** nada: é o servidor, tudo roda em física local a 60 Hz, sem sync.
- **Tuning**: `NetInterp.RENDER_DELAY_MS` (100 ms). Mais alto = mais suave porém mais "atrasado";
  mais baixo = mais responsivo porém sensível a jitter de UDP.

---

## Variante/cor por peer (loadout) — `NetSpawn`

Antes, o servidor spawnava **todos** os players a partir da SUA própria `PlayerSelection.scene_path`
→ a variante/cor que o **cliente** escolheu (ex.: `playera`) não aparecia. Centralizado no autoload
**`NetSpawn`** (`autoload/net_spawn.gd`, caminho `/root/NetSpawn` igual em todos os peers → RPC
confiável):

- `chooseplayer` grava **`PlayerSelection.variant_id`** (índice em `PlayerSelection.VARIANTS`, mesma
  ordem do seletor). Trafega como **int** (não um caminho arbitrário) no RPC.
- Cada nível chama **`NetSpawn.setup(spawned_nodes, player_spawn_points, not PlayerSelection.spectator_host)`**
  no `_ready` (substitui o `add_player`/`del_player` duplicado em level_base/1/2). Os **3 níveis** passam
  o mesmo argumento → comportamento uniforme do "Hospedar Somente" **(2026-06-24)**.
  - **Host**: spawna a si mesmo (peer 1) com a própria variante. `spawn_host=false` no "Hospedar Somente"
    → `NetSpawn` adiciona a câmera livre em vez do player.
  - **Cenário em execução**: `NetSpawn` guarda o caminho da cena do nível (`_server_scenario`) e o
    responde ao cliente via os RPCs **`request_scenario`/`answer_scenario`** — usado pela `playonline`
    para só confirmar reconexão quando o cliente entra no **mesmo cenário**. Ver [[sistemas/hospedagem-online]].
  - **Cliente que entra**: o servidor **reserva o spawn e ESPERA** o cliente informar a variante via
    `register_loadout.rpc_id(1, variant_id)` (enviado quando `connected_to_server`); só então spawna o
    modelo certo. O `MultiplayerSpawner` replica a cena instanciada → a cor/variante aparece em TODOS
    os peers (a `playera.gd` aplica o tint no `_ready` de cada instância). Fallback de 5 s → variante padrão.

---

## Modo Offline

- `main.gd` usa `OfflineMultiplayerPeer`
- `multiplayer.get_unique_id()` retorna `1`
- `multiplayer.is_server()` retorna `true`
- Todo o código funciona normalmente

---

## Relacionado

- [[sistemas/player]]
- [[fluxos/fluxo-de-input]]
- [[sistemas/hospedagem-online]] — jogar com amigos pela internet (playit.gg / Tailscale / port forwarding)

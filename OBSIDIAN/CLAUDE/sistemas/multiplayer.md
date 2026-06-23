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
- `transform`
- `player_id`
- `motion`
- `current_animation`

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
- `_spawnable_scenes` de cada spawner lista os **players** (`player` + `playera`), o
  **inimigo do nível** (`red_robot` no level_1/base, `criatura_alada` no level_2) e a
  **bullet** (disparada sob `SpawnedNodes`, precisa replicar).
- Os níveis são escolhidos no fluxo **Jogar Online** (chooseplayer → levels → playonline);
  ver [[fluxos/fluxo-de-cenas]].

---

## Posição de spawn do cliente (`spawn_position`)

O `.:transform` é spawn property do `ServerSynchronizer`, mas **não chega a tempo** no
cliente que entra: o player nascia em **(0,0,0)** e **caía do mapa** (o host ficava certo).
Solução determinística (mesmo mecanismo confiável do `player_id`):

- `player.gd` tem **`@export var spawn_position: Vector3`** com setter que chama
  `_apply_spawn_position()` (seta `global_position`, `initial_position`, zera `velocity` e
  `_has_prediction`). Registrada no `ServerSynchronizer` como **spawn property** (`spawn=true`,
  `replication_mode=0` = só no pacote de spawn).
- `add_player` (todos os níveis) seta `player.spawn_position = spawn_point.transform.origin`
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

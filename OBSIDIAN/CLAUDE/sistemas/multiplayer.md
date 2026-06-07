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

### level_1 (single-player / local)
```gdscript
player.player_id = 1   # authority = peer 1 (local)
```

### level_base (multiplayer)
```gdscript
# Server spawna player para cada peer
add_player(peer_id, spawn_point)
# player.name = str(peer_id)
# player.player_id = peer_id  → authority do InputSynchronizer = peer_id
```

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

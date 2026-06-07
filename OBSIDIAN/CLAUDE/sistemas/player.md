# Sistema do Player

**Classe:** `Player` extends `CharacterBody3D`
**Script:** `scenes3D/players/player/player.gd`
**Cena:** `scenes3D/players/player/player.tscn`

---

## Constantes

| Constante | Valor | Descrição |
|---|---|---|
| `MOTION_INTERPOLATE_SPEED` | `10.0` | Suavização do vetor de movimento |
| `ROTATION_INTERPOLATE_SPEED` | `10.0` | Suavização da rotação |
| `MIN_AIRBORNE_TIME` | `0.1` s | Tempo mínimo no ar para ativar jump |
| `JUMP_SPEED` | `5.0` | Velocidade vertical do pulo |
| `MAX_HP` | `100` | Vida máxima |

---

## Variáveis de Estado

| Variável | Tipo | Descrição |
|---|---|---|
| `hp` | `int` | Vida atual (decresce com `hit()`) |
| `airborne_time` | `float` | Tempo acumulado no ar |
| `orientation` | `Transform3D` | Rotação/orientação do player |
| `root_motion` | `Transform3D` | Acumulador de root motion |
| `motion` | `Vector2` | Vetor de movimento do input |

---

## Exports (Sincronizados via ServerSynchronizer)

| Export | Tipo | Descrição |
|---|---|---|
| `player_id` | `int` | ID do peer dono; setter define authority no InputSynchronizer |
| `current_animation` | `Animations` | Estado atual da animação |

---

## Lógica Principal

### `_physics_process(delta)`
- **Servidor:** chama `apply_input()` — toda física roda no servidor
- **Cliente:** chama apenas `animate()` para feedback visual

### `apply_input(delta)`
1. Interpola `motion` com `player_input.motion`
2. Gerencia pulo e tempo no ar
3. Se aiming: orienta pelo quaternion da câmera → estado STRAFE → dispara bala
4. Se caminhando: orienta pela direção do movimento → estado WALK
5. Aplica root motion → `move_and_slide()`
6. Respawn se `y < -40`

---

## RPCs

| RPC | Modo | O que faz |
|---|---|---|
| `jump()` | `call_local` | Anima pulo + som |
| `land()` | `call_local` | Anima pouso + som |
| `shoot()` | `call_local` | Partículas + flash + cooldown + camera shake |
| `hit()` | `call_local` | `-25 HP`, atualiza HUD; se `hp==0` chama `respawn.rpc()` |
| `respawn()` | `call_local` | Reseta HP, teleporta para `initial_position` |
| `add_camera_shake_trauma(amount)` | `call_local` | Trauma na câmera |

---

## Nós Filhos Relevantes

| Nó | Tipo | Uso |
|---|---|---|
| `InputSynchronizer` | `PlayerInputSynchronizer` | Input + câmera + HUD |
| `AnimationTree` | `AnimationTree` | Blend tree de animações |
| `PlayerModel` | `Node3D` | Modelo 3D do robô |
| `FireCooldown` | `Timer` | 0.4 s entre tiros |
| `SoundEffects/*` | `AudioStreamPlayer` | Jump, Land, Shoot |

---

## Hitboxes de Vidro (visuais)

- `_setup_glass_hitboxes()` no `_ready` cria envólucros de vidro por membro
- Usa `effects_shared/glass_hitboxes.gd` sobre `PlayerModel/Robot_Skeleton/Skeleton3D`
- Só em clientes com tela (`!= "headless"`); ~26 envólucros (membros maiores)
- Ver [[arquivos-chave/glass-hitboxes-gd]]

---

## Relacionado

- [[sistemas/sistema-de-vida]]
- [[sistemas/combate-tiro]]
- [[sistemas/multiplayer]]
- [[arquivos-chave/player-gd]]
- [[arquivos-chave/player-input-gd]]
- [[arquivos-chave/glass-hitboxes-gd]]

# Sistema do Player

**Classe:** `Player` extends `CharacterBody3D`
**Script:** `library3D/characters/players/player/player.gd`
**Cena:** `library3D/characters/players/player/player.tscn`

---

## Constantes

| Constante | Valor | Descrição |
|---|---|---|
| `MOTION_INTERPOLATE_SPEED` | `10.0` | Suavização do vetor de movimento |
| `ROTATION_INTERPOLATE_SPEED` | `10.0` | Suavização da rotação |
| `MIN_AIRBORNE_TIME` | `0.1` s | Tempo mínimo no ar para ativar jump |
| `JUMP_SPEED` | `6.5` | Velocidade vertical do pulo (era 5.0 — pulo mais alto) |
| `JUMP_CUT_DAMPING` | `14.0` /s | Pulo variável: amortecimento da subida quando o espaço é SOLTO no meio do pulo (corte suave); segurar até o fim = arco completo |
| `AIM_WARMUP_TIME` | `0.45` s | Tempo mirando antes do **1º tiro** (espera a mira assentar) |
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
2. Gerencia pulo e tempo no ar — **pulo variável (2026-07-03):** com espaço SEGURO a subida segue o
   arco balístico completo (animação e distância máximas); com espaço SOLTO durante a subida de um
   pulo real (`_jump_active`), a velocidade vertical é amortecida por `exp(-JUMP_CUT_DAMPING·delta)`
   até a gravidade assumir (a animação vira `jump_down` no ápice antecipado). O estado do botão chega
   pelo novo `player_input.jump_held` (sincronizado; semeado `true` no RPC `jump()`)
3. Se aiming: orienta pelo quaternion da câmera → estado STRAFE → dispara bala **só após
   `_aim_held_time ≥ AIM_WARMUP_TIME`** (o tiro espera a mira assentar; corrige o glitch do cliente)
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
| `FireCooldown` | `Timer` | **0.7 s** entre tiros (era 0.4 — cadência mais espaçada) |
| `SoundEffects/*` | `AudioStreamPlayer` | Jump, Land, Shoot |

---

## Colliders de membro (dano localizado)

- `_setup_limb_colliders()` no `_ready` cria colliders 3D nativos (`StaticBody3D` + `BoxShape3D`) por membro
- Usa `effects_shared/limb_colliders.gd` sobre `PlayerModel/Robot_Skeleton/Skeleton3D` (playera herda de Player)
- Layer 16 (bit5); o bullet colide fisicamente. Ao atirar, o player exclui os próprios colliders (`_exclude_own_limbs`)
- Ver [[arquivos-chave/limb-colliders-gd]]

### Cápsula de locomoção auto-ajustada (2026-07-03)
Logo após `build_for`, o `_setup_limb_colliders` chama
`lc.fit_locomotion_capsule($CapsuleShape3D, self)`: a cápsula de **bloqueio físico** deixa de ser a
default (0,5×2,0) e passa a ser **proporcional ao modelo** — raio pelo footprint (tronco+pernas),
altura pela extensão vertical, base ancorada no chão. Continua **1 shape por personagem** (barato,
estável, netcode-friendly). Detalhes e validação em [[sistemas/dano-localizado]] ("Auto-fit da
cápsula de locomoção por modelo"). O red_robot faz o mesmo ([[sistemas/inimigos]]).

---

## Bots aliados (`bot_controlled`)

- Com `bot_controlled = true` (facção amiga nos templates), o mesmo `player.gd` é dirigido por uma
  IA dedicada `library3D/characters/players/player/IA/player_bot_ai.gd` (instanciada em
  `_apply_bot_controlled`), que **dá cobertura ao jogador**: engaja ameaças próximas do bot ou do
  jogador, mas **segue o jogador** e respeita uma **coleira** (`max_leash`/`soft_leash`) — fora dela,
  reagrupar tem prioridade, então o aliado **não corre até cair do mapa**. O bot também passa pelo
  `AIM_WARMUP_TIME` (mira antes de atirar).

---

## Relacionado

- [[sistemas/sistema-de-vida]]
- [[sistemas/combate-tiro]]
- [[sistemas/multiplayer]]
- [[sistemas/inimigos]]
- [[arquivos-chave/player-gd]]
- [[arquivos-chave/player-input-gd]]
- [[arquivos-chave/limb-colliders-gd]]

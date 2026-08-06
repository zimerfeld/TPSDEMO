---
tipo: sistema
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-07-04
---

# 🎮 Sistema do Player

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
- Ver [[🦿 limb-colliders-gd (PT)|🦿 limb-colliders-gd]]

### Cápsula de locomoção auto-ajustada (2026-07-03)
Logo após `build_for`, o `_setup_limb_colliders` chama
`lc.fit_locomotion_capsule($CapsuleShape3D, self)`: a cápsula de **bloqueio físico** deixa de ser a
default (0,5×2,0) e passa a ser **proporcional ao modelo** — raio pelo footprint (tronco+pernas),
altura pela extensão vertical, base ancorada no chão. Continua **1 shape por personagem** (barato,
estável, netcode-friendly). Detalhes e validação em [[🩸 dano-localizado (PT)|🩸 dano-localizado]] ("Auto-fit da
cápsula de locomoção por modelo"). O red_robot faz o mesmo ([[🤖 inimigos (PT)|🤖 inimigos]]).

---

## Bots aliados (`bot_controlled`)

- Com `bot_controlled = true` (facção amiga nos templates), o mesmo `player.gd` é dirigido por uma
  IA dedicada `library3D/characters/players/player/IA/player_bot_ai.gd` (instanciada em
  `_apply_bot_controlled`), que **dá cobertura ao jogador**: engaja ameaças próximas do bot ou do
  jogador, mas **segue o jogador** e respeita uma **coleira** (`max_leash`/`soft_leash`) — fora dela,
  reagrupar tem prioridade, então o aliado **não corre até cair do mapa**. O bot também passa pelo
  `AIM_WARMUP_TIME` (mira antes de atirar).

### Órbita + facção (2026-07-08)

- **Facção runtime:** o player (humano e bot) é semeado como **`ally`** no `_ready`
  (`Factions.seed_node`). O bot escolhe inimigo por `Factions.are_enemies` e aliado por `same_side`
  (não mais por "tem método `hit`"). Ver [[⚔️ facções (PT)|⚔️ facções]].
- **Orbita o player mais próximo:** a âncora passou a ser o **humano MAIS PRÓXIMO** (`_find_nearest_human_ally`,
  antes pegava o primeiro). Sem ameaça, `_follow_move` **circula** a âncora a `follow_distance`
  (mola radial de raio + componente tangencial `orbit_strength`, sentido individual) em vez de só
  chegar perto e parar.
- **Sem colidir:** `_sync_anchor_collision` mantém uma **exceção de colisão** entre o bot e a âncora
  (reaplicada quando o player mais próximo muda) → o aliado fica no entorno **sem empurrar** o player.
- **Separação entre aliados:** `_separation` (steering estilo boids) empurra cada aliado para longe dos
  OUTROS aliados dentro de `separation_radius` (peso `separation_strength`) → vários bots **se distribuem
  na órbita sem empilhar**, em vez de convergir para o mesmo ponto. A âncora fica de fora (já tratada
  pela órbita + exceção de colisão).
- **Sem fogo amigo:** as balas do aliado atravessam o player (ver [[🔫 combate-tiro (PT)|🔫 combate-tiro]]).

### ⚠️ Convenção INVERTIDA de movimento (2026-08-06)

O `input.motion` do bot é um vetor no frame da **câmera**, igual ao que o teclado produz. Mas o
`apply_input` usa `target = camera_x*motion.x + camera_z*motion.y` **só para ORIENTAR** o corpo
(`Basis.looking_at`) — o deslocamento vem do **root motion** da animação, que corre no `+Z` local
("The animation's forward/backward axis is reversed", `player.gd`). Resultado: o corpo **viaja no
sentido oposto ao `target`**, e a malha do GLB (que encara `+Z`) faz isso parecer certo em tela. Para
o humano tudo fecha porque a tecla W já manda `motion.y = -1`.

**Medido no harness:** um player *sem IA* com `motion=(0,-1)` desloca-se para `-camFwd`
(alinhamento **-1,00**). A IA projetava com o sinal errado — por isso o aliado **corria em linha reta
até cair**, ignorando posto e alvo, e **atirava numa direção com o projétil indo para outra**.

Três consertos em `player_bot_ai.gd`:

1. **`_world_dir_to_motion` projeta `-dir`** (e não `dir`).
2. **`_face_point` aponta o `-Z` do `camera_base` para o lado OPOSTO ao alvo** — a frente efetiva do
   corpo é o `+Z` dessa base — com o pitch espelhado junto.
3. **Vira ANTES de projetar:** a ida e a volta passam a usar a mesma base no mesmo quadro. Antes
   havia uma defasagem de um quadro que **realimentava** o erro a cada tick.

Depois: escolta converge para **2,53 m** (`follow_distance` 2,5) e para; mira e projétil ficam com
alinhamento **1,00** com o inimigo.

### Postura de segurança — `guard_stance` (2026-08-06)

Comportamento **padrão** do aliado (ligável/desligável na tela **Models → IA**). Ele deixa de ser um
caçador e passa a agir como um **segurança**: acompanha a uma distância segura, sem colidir e sem
correr sem direção.

| Regra | Como |
| --- | --- |
| **Posto** em vez de órbita | `_guard_station` calcula um ponto sempre a `follow_distance` do protegido. **Em paz:** diagonal **traseira** (`guard_back_ratio` 0.8 atrás + `guard_side_ratio` 0.6 ao lado), fora da linha de tiro dele e acompanhando quando ele vira. O lado sai do `_orbit_sign` sorteado, então dois aliados cobrem lados opostos. |
| **Se interpõe** (2026-08-06) | Com um inimigo a até `player_threat_radius` do protegido, o posto vai para a **frente**, na direção da ameaça (`guard_screen_ratio` 0.8) — o aliado fica **entre os dois**, mantendo o desvio lateral para não tapar o tiro. É daqui que vem a "reação": ele reposiciona sempre que a ameaça troca de lado, sem nunca sair dos `follow_distance`. |
| **Para ao chegar, com histerese** | Chega ao posto com `station_tolerance` (0,6 m) e só volta a andar quando ele se afasta `× settle_release` (2.2 → ≈1,3 m). A zona morta pequena dá reação; a histerese evita o tremor de corrigir a cada quadro. `scan_interval` 0.35 → **0.2 s** para perceber a ameaça mudar de lado mais rápido. |
| **Nunca encosta** | Abaixo de `min_standoff` (1,8 m) o único movimento possível é **recuar** — mesmo com a exceção de colisão física ativa. |
| **Não avança no inimigo** | Em combate, `_combat_move` devolve o mesmo movimento de posto; só recua se o inimigo passar de `preferred_combat_distance - combat_band`. Sem investida e **sem flanco** (`pressure_flank` fica suprimido nesta postura). |
| **Sem protegido, guarda o posto de origem** (2026-08-06) | `_hold_move` mantém o lugar onde o bot nasceu (`_home`, capturado no 1º `update_input`): volta se derivou, para ao chegar, mesma histerese. **Bug corrigido:** toda a postura dependia de `has_anchor`, e a âncora exige um **humano** (`_find_nearest_human_ally` ignora bots) — logo, com o host observando como espectador, na sala antes de o jogador entrar, ou depois de ele sair, o código caía no ramo antigo (avançar + flanquear) e o aliado **corria para cima do inimigo até morrer**. Agora, sem quem escoltar, ele guarda o posto e atira dali. |

**Números recalibrados junto** (defaults dos `@export`): `follow_distance` 5.5 → **2,5** m ·
`orbit_strength` 0.7 → **0.15** · `preferred_combat_distance` 18 → **12** m · `engage_range` 32 →
**16** m · `player_threat_radius` 24 → **18** m · `soft_leash` 14 → **6** m · `max_leash` 20 → **9** m.

> **Onde regular a "reação"** sem voltar a ser caçador: `station_tolerance` (menor = corrige antes),
> `settle_release` (menor = sai do posto mais fácil), `scan_interval` (menor = percebe antes) e
> `guard_screen_ratio` (maior = se adianta mais na direção da ameaça).

> Desligando `guard_stance` na tela Models, o aliado volta à **órbita** clássica descrita acima
> (com os números novos, portanto mais colado que antes).

---

## Relacionado

- [[❤️ sistema-de-vida (PT)|❤️ sistema-de-vida]]
- [[🔫 combate-tiro (PT)|🔫 combate-tiro]]
- [[🌐 multiplayer (PT)|🌐 multiplayer]]
- [[🤖 inimigos (PT)|🤖 inimigos]]
- [[🎮 player-gd (PT)|🎮 player-gd]]
- [[⚔️ facções (PT)|⚔️ facções]]
- [[🕹️ player-input-gd (PT)|🕹️ player-input-gd]]
- [[🦿 limb-colliders-gd (PT)|🦿 limb-colliders-gd]]

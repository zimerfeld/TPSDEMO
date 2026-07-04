---
tipo: sistema
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-07-04
---

# 🤖 Sistema de Inimigos — Red Robot

**Script:** `library3D/characters/red_robot/red_robot.gd`
**Cena:** `library3D/characters/red_robot/red_robot.tscn`

---

## Máquina de Estados

```
APPROACH ──► AIM ──► SHOOTING
    ▲          │
    └──────────┘ (missed / left sight)
```

| Estado | Comportamento |
|---|---|
| `APPROACH (0)` | Caminha em direção ao player, vira para encarar |
| `AIM (1)` | Para, prepara o tiro, conta `AIM_TIME = 1.0 s` |
| `SHOOTING (2)` | Dispara bala de canhão; espera a recarga antes do próximo |

> **Recuo (FLEE):** além dos 3 estados, uma decisão da [[🧠 red-robot-ai-gd|IA]] sobrepõe
> o movimento quando o player chega a **≤ 10 m**: o robô **corre no sentido oposto encarando o
> player** e continua atirando (não é um `State` da máquina, é um override de movimento por quadro).

---

## Parâmetros

| Constante | Valor |
|---|---|
| `PLAYER_AIM_TOLERANCE_DEGREES` | `15°` |
| `SHOOT_WAIT` | `6.0 s` (recarga-base) |
| `shoot_reload` | `SHOOT_WAIT / 1.5 ≈ 4.0 s` (recarga efetiva via IA — 1,5× mais rápida) |
| `AIM_TIME` | `1.0 s` |
| `AIM_PREPARE_TIME` | `0.5 s` |
| `BLEND_AIM_SPEED` | `0.05` |
| `effective_range` | `30 m` (alcance da arma; exibido no HUD) |
| `PlayerDetectionArea` | `SphereShape3D` raio `30 m` (= `effective_range`) |

> A recarga efetiva (1º e próximos tiros) vem da [[🧠 red-robot-ai-gd|IA]]
> (`fire_rate_multiplier = 1.5`), não de `SHOOT_WAIT` direto.
>
> O **raio de detecção (30 m)** foi igualado ao `effective_range` para o robô **detectar e abrir
> fogo a 30 m** (antes 20 m impedia atirar no alcance total).

---

## Variáveis de Estado (Exportadas / Sincronizadas)

| Var | Tipo | Descrição |
|---|---|---|
| `health` | `int` | Vida do robô (default: `200`) |
| `max_health` | `int` | Vida máxima para o HUD (default: `200`) |
| `HIT_DAMAGE` | `const int` | Dano por tiro = `50` (morre em 4 tiros) |
| `enemy_name` | `String` | Nome exibido no HUD (default: `"Red Robot"`) |
| `state` | `State` | Estado atual da IA |
| `dead` | `bool` | Se foi destruído |
| `target_position` | `Vector3` | Posição do player alvo |

---

## HUD de Vida (Boss Bar)

- `controls2D/enemy_health_bar.gd` — `CanvasLayer` compartilhado no **topo-centro**
- Acionado por:
  - `hit()` → `show_health_hud()` (ao ser atingido)
  - **mira do player entra** → `player_input._update_enemy_focus()` chama `show_health_hud()`
  - **mira do player sai** → chama `hide_health_hud()` (some imediatamente)
- `show_health_hud()` e `hide_health_hud()` são **públicos**; show guardado por `if dead: return`
- Some: imediatamente ao tirar a mira ou na morte; 6 s de fallback se atingido sem mira
- Mostra `enemy_name` + barra `restante / total` + **distância (m)** + **alcance da arma (m)**
  (`show_health_hud(distance)` repassa `effective_range`; o HUD só exibe o alcance quando informado)
- Ver [[🩹 enemy-health-bar-gd]]

---

## RPC `hit()`

```gdscript
@rpc("call_local")
func hit() -> void:
    health = maxi(health - HIT_DAMAGE, 0)   # -50 por tiro
    _show_health_hud()                 # atualiza boss bar
    # toca animação de hit aleatória (hit1/hit2/hit3)
    if health <= 0:
        # destrói: partes explodem, emite sinal exploded
        _hide_health_hud()             # esconde boss bar
        # servidor faz queue_free() após 10s
```

> **Balanceamento:** `200 HP ÷ 50 dano = 4 tiros para morrer`.

---

## Laser

- `RayCast3D` em `RayFrom` (BoneAttachment no skeleton)
- Verifica linha de visão antes de `AIM → SHOOTING`
- Se acerta o player: chama `player.add_camera_shake_trauma(13.0)` após 0.1 s
- Clipa o shader do laser pelo comprimento do raio

---

## Spawn

- **level_1:** spawn em cada `RobotSpawnpoints/*`; respawn automático após 15 s

---

## Sinal

- `exploded` — emitido ao morrer; o nível conecta para respawn

---

## Colliders de membro (dano localizado)

- `_setup_limb_colliders()` no `_ready` (se `not dead`) cria colliders 3D nativos (`StaticBody3D` + `BoxShape3D`) por membro
- Usa `effects_shared/limb_colliders.gd` sobre `RedRobotModel/Armature/Skeleton3D` (`head_bone_names = ["mouth_eyes", "L-EYE", "R-EYE"]` — os olhos entram na CABEÇA para o headshot não ficar minúsculo; 2026-06-18)
- Layer 32 (bit6); o bullet do player colide fisicamente e aplica dano localizado
- **Cápsula de locomoção auto-ajustada (2026-07-03):** após `build_for`, `red_robot.gd` chama
  `lc.fit_locomotion_capsule(collision_shape, self)` — o bloqueio físico vira proporcional ao modelo
  (raio pelo footprint tronco+pernas, altura pela extensão vertical), em vez da cápsula default. Ver
  [[🩸 dano-localizado]] ("Auto-fit da cápsula de locomoção por modelo").
- Ver [[🦿 limb-colliders-gd]]

---

## Refinamento de IA — deslize, alvo, voo, facção (2026-07-02)

Feedback do usuário validado no Teste A. Quatro frentes de comportamento + marcação de facção
(parâmetros/limites virão numa tela dedicada — ver [[📌 Backlog]] P1.5):

- **Fim do "deslizar" (terrestre):** o movimento MANUAL (strafe/recuo/formação, `_apply_direct_movement`)
  usava `velocity = dir × speed` FIXO tocando `walk` na cadência natural → pés patinavam. Agora
  `_match_locomotion_cadence(speed)` escala o `speed_scale` do AnimationPlayer de locomoção (resolvido de
  `animation_tree.anim_player`) para a **cadência das pernas casar com a velocidade real** → sem patinar
  (e flee mais rápido = pernas ciclam mais rápido). Fora do manual, `_reset_locomotion_cadence()` volta a
  1.0 (o APPROACH já usa root motion, pés travados). Tunáveis: `walk_natural_speed` (2.2), `gait_speed_scale`.
  **Só código** — o `.tscn` do AnimationTree NÃO foi tocado (não há nó TimeScale; escalar o AnimationPlayer
  resolve sem editar o blend tree de 10k linhas).
- **Formação menos rígida:** `formation_cohesion` 0.55→**0.32**, `formation_band` 5→**7 m**, e o rumo do slot
  passou a **oscilar suave** (`formation_wander` 0.5 rad, fase individual) → o ponto "respira" em vez de
  convergir para coordenadas fixas. Menos pragmático, mais orgânico.
- **Alvo = player mais próximo (multiplayer):** antes o alvo era o **1º player** que entrava no raio
  (`_on_area_body_entered` setava `player = body`, single-target). Agora `_players_in_range` guarda TODOS os
  players no raio de alerta e `_pick_target()` escolhe o **mais próximo** a cada quadro, com **histerese**
  (`TARGET_SWITCH_MARGIN` 2.5 m) para não oscilar. **Qualquer inimigo atira em qualquer player** no raio. Vale
  também para a Criatura Alada (`_find_nearest_player`/`_collect_players` — antes `_find_player` pegava o 1º).
- **Voo aéreo com altura suave e contextual (Criatura Alada):** o bob senoidal fixo virou **troca de camada**
  interpolada (`_alt_bias`, ease exponencial framerate-independente): **AMEAÇADA** (levou tiro, janela
  `_recent_hit_t` 3 s) → **sobe** até `escape_altitude_above_target` (24 m) p/ escapar; **prestes a bombardear**
  (`_bomb_cd ≤ 1.2 s` em PATROL) → **desce** até `dive_altitude_above_target` (7.5 m) p/ precisão; senão
  cruzeiro (`preferred_altitude_above_target` 14 m). A taxa vertical do corpo é limitada (`climb_speed × 1.6`)
  → subida/descida sempre suave. Escape tem prioridade sobre bombardeio.
- **Marcação de facção (estrutural):** `AIConfig.faction(model_key)` / `set_faction` (JSON por-modelo, chave
  `"faction"`, precedência user:// como os behaviors). Valores `hostile`/`neutral`/`ally`; defaults: red_robot
  e criatura_alada = **hostile**, player = **ally**. Ainda **não há personagem neutro** — o campo existe e é
  lido (`is_hostile`/`is_neutral`), pronto para a lógica "neutro só reage se ameaçado (tiro/aleatoriedade)".

---

## Movimento individualizado + formação (2026-06-25)

Para os inimigos **não andarem iguais a cada segundo**, a IA (`red_robot_ai.gd`) semeia no `_ready`
de cada robô um **sinal de strafe**, uma **fase** e um **multiplicador de velocidade** próprios
(RNG do servidor — movimento é server-autoritativo, clientes só interpolam), e os **flips de strafe**
passaram a usar períodos aleatórios (`randf_range`) em vez de exatamente ~1 s, quebrando o lockstep.

Cada robô também guarda um **slot de formação designado**: na 1ª vez, captura a direção a partir do
player (derivada do ponto de spawn) como `_slot_bearing` e, durante o combate, ganha um **viés suave
de retorno** ao ponto `player + slot_dir * preferred` (`formation_cohesion`/`formation_band`).
Resultado: o pelotão **circula/estrafa livre**, mas tende a **voltar à formação** em vez de amontoar.
Tunáveis: `formation_cohesion` (0.55), `formation_band` (5 m), `speed_variation` (±0.18).

A **Criatura Alada** teve a oscilação de voo (`_t`/bob) **dessincronizada** entre instâncias via uma
`_bob_phase` aleatória semeada no `_ready` (e reusada ao reentrar em PATROL), então várias criaturas
não sobem/descem em sincronia. Ver [[🧠 red-robot-ai-gd]].

---

## Relacionado

- [[🔫 combate-tiro]]
- [[🤖 red-robot-gd]]
- [[🧠 red-robot-ai-gd]]
- [[🦿 limb-colliders-gd]]

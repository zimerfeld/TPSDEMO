# Sistema de Inimigos — Red Robot

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

> **Recuo (FLEE):** além dos 3 estados, uma decisão da [[arquivos-chave/red-robot-ai-gd|IA]] sobrepõe
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

> A recarga efetiva (1º e próximos tiros) vem da [[arquivos-chave/red-robot-ai-gd|IA]]
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

- `library3D/characters/enemies/enemy_health_bar.gd` — `CanvasLayer` compartilhado no **topo-centro**
- Acionado por:
  - `hit()` → `show_health_hud()` (ao ser atingido)
  - **mira do player entra** → `player_input._update_enemy_focus()` chama `show_health_hud()`
  - **mira do player sai** → chama `hide_health_hud()` (some imediatamente)
- `show_health_hud()` e `hide_health_hud()` são **públicos**; show guardado por `if dead: return`
- Some: imediatamente ao tirar a mira ou na morte; 6 s de fallback se atingido sem mira
- Mostra `enemy_name` + barra `restante / total` + **distância (m)** + **alcance da arma (m)**
  (`show_health_hud(distance)` repassa `effective_range`; o HUD só exibe o alcance quando informado)
- Ver [[arquivos-chave/enemy-health-bar-gd]]

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

- **level_1:** `robot.position = Vector3(10, 1, 0)` (hardcoded)
- **level_base:** spawn em cada `RobotSpawnpoints/*`; respawn automático após 15 s

---

## Sinal

- `exploded` — emitido ao morrer; level_base conecta para respawn

---

## Colliders de membro (dano localizado)

- `_setup_limb_colliders()` no `_ready` (se `not dead`) cria colliders 3D nativos (`StaticBody3D` + `BoxShape3D`) por membro
- Usa `effects_shared/limb_colliders.gd` sobre `RedRobotModel/Armature/Skeleton3D` (`head_bone_names = ["mouth_eyes", "L-EYE", "R-EYE"]` — os olhos entram na CABEÇA para o headshot não ficar minúsculo; 2026-06-18)
- Layer 32 (bit6); o bullet do player colide fisicamente e aplica dano localizado
- Ver [[arquivos-chave/limb-colliders-gd]]

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
não sobem/descem em sincronia. Ver [[arquivos-chave/red-robot-ai-gd]].

---

## Relacionado

- [[sistemas/combate-tiro]]
- [[arquivos-chave/red-robot-gd]]
- [[arquivos-chave/red-robot-ai-gd]]
- [[arquivos-chave/limb-colliders-gd]]

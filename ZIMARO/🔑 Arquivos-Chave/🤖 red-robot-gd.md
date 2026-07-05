---
tipo: arquivo-chave
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-07-04
---

# 🤖 library3D/characters/red_robot/red_robot.gd

**Estende:** `CharacterBody3D`

---

## Responsabilidades

- IA com 3 estados: APPROACH / AIM / SHOOTING
- Laser raycast que detecta player e aplica hit
- Sistema de HP (`health: int = 5`)
- Morte com física ragdoll (partes explodem como RigidBody3D)
- Respawn gerenciado pelo nível (sinal `exploded`)

---

## Variáveis Exportadas / Sincronizadas

```gdscript
const HIT_DAMAGE: int = 50          # dano por tiro recebido
@export var enemy_name: String = "Red Robot"
@export var max_health: int = 200
@export var health: int = 200
@export var state: State = State.APPROACH
@export var dead: bool = false
@export var target_position: Vector3
@export var aim_preparing: float
```

---

## Método `hit()` (RPC call_local)

```gdscript
health = maxi(health - HIT_DAMAGE, 0)   # -50 por tiro → morre em 4 tiros
# anima hit aleatório (hit1/hit2/hit3)
if health <= 0:
    dead = true
    # oculta modelo, desabilita colisão
    # partes explodem (shield1/shield2/head)
    # emite sinal exploded
    # servidor: queue_free() após 10s
```

---

## Laser

- `RayCast3D` disparado da posição do osso `RayFrom`
- Shader clipa o mesh do raio pelo comprimento da colisão
- `LaserEmber` particles posicionados no meio do raio
- Ao acertar player: `player.add_camera_shake_trauma(13.0)` após delay 0.1s

---

## Morte (Partes)

| Nó | Tipo |
|---|---|
| `PartShield1` / `PartShield2` | `RigidBody3D` |
| `PartHead` | `RigidBody3D` |
| `DetachSpark1/2` | `CPUParticles3D` |

---

## Caminho: `library3D/characters/red_robot/red_robot.gd`

---

## Arma, precisão e dano (atualizado)

- `weapon_damage`, `aim_accuracy = 1.0` (100%), `effective_range = 30 m`
- Só dispara quando o player está dentro do alcance (mira precisa)
- `hit(amount)` recebe dano da arma do atacante; o projétil (CannonShooter) aplica dano
  localizado nos colliders de membro do player
- `show_health_hud(distance)` exibe distância **e o alcance da arma** (`effective_range`) no HUD
- Ver [[🩸 dano-localizado]]

---

## IA (`IA/red_robot_ai.gd`)

Os comportamentos/decisões em tempo de execução ficam num script de IA dedicado
([[🧠 red-robot-ai-gd]], `class_name RedRobotAI`), instanciado como filho em `_ready()`
e consultado a cada quadro pelo corpo (`red_robot.gd`):

- **Recarga 1,5× mais rápida** — `shoot_reload = ai.reload_time(SHOOT_WAIT)` = `SHOOT_WAIT / 1.5`;
  usado no 1º tiro e em todos os resets de `shoot_countdown` (vale para o 1º e os próximos).
- **Engajar** — atira sempre que o player está dentro de `effective_range` (a mira de tiro já
  faz esse teste); na prática, abre fogo na faixa `10 m < dist ≤ alcance`.
- **Recuar (FLEE)** — quando `dist ≤ flee_distance` (10 m), `_flee_movement()` orienta o corpo
  para **encarar o player** (frente +Z) e define a velocidade no **sentido oposto**
  (`-fwd * flee_speed`), sobrepondo o root motion; as pernas tocam `walk` e o tiro continua.
- Tunáveis na IA: `fire_rate_multiplier = 1.5`, `flee_distance = 10.0`, `flee_speed = 6.0`.

---

## Relacionado

- [[🤖 inimigos]]
- [[🧠 red-robot-ai-gd]]
- [[🩸 dano-localizado]]
- [[🎯 fluxo-de-tiro]]

# scenes3D/enemies/red_robot/red_robot.gd

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

## Caminho: `scenes3D/enemies/red_robot/red_robot.gd`

---

## Arma, precisão e dano (atualizado)

- `weapon_damage = 25`, `aim_accuracy = 1.0` (100%), `effective_range = 30 m`
- Só dispara quando o player está dentro do alcance (mira precisa)
- `hit(amount)` recebe dano da arma do atacante; `_damage_player()` aplica dano localizado
  no player via raio contra hitboxes (bit5)
- `show_health_hud(distance)` exibe a distância ao lado do nome no HUD
- Ver [[sistemas/dano-localizado]]

---

## Relacionado

- [[sistemas/inimigos]]
- [[sistemas/dano-localizado]]
- [[fluxos/fluxo-de-tiro]]

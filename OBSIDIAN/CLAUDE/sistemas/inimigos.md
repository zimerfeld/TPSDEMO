# Sistema de Inimigos — Red Robot

**Script:** `enemies/red_robot/red_robot.gd`  
**Cena:** `enemies/red_robot/red_robot.tscn`

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
| `AIM (1)` | Para, prepara o laser, conta `AIM_TIME = 1.0 s` |
| `SHOOTING (2)` | Dispara raio laser contínuo; espera `SHOOT_WAIT = 6.0 s` |

---

## Parâmetros

| Constante | Valor |
|---|---|
| `PLAYER_AIM_TOLERANCE_DEGREES` | `15°` |
| `SHOOT_WAIT` | `6.0 s` |
| `AIM_TIME` | `1.0 s` |
| `AIM_PREPARE_TIME` | `0.5 s` |
| `BLEND_AIM_SPEED` | `0.05` |
| `HIT_DAMAGE` | `50` (dano por tiro recebido) |

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

- `enemies/enemy_health_bar.gd` — `CanvasLayer` compartilhado no **topo-centro**
- Acionado por:
  - `hit()` → `show_health_hud()` (ao ser atingido)
  - **mira do player entra** → `player_input._update_enemy_focus()` chama `show_health_hud()`
  - **mira do player sai** → chama `hide_health_hud()` (some imediatamente)
- `show_health_hud()` e `hide_health_hud()` são **públicos**; show guardado por `if dead: return`
- Some: imediatamente ao tirar a mira ou na morte; 6 s de fallback se atingido sem mira
- Mostra `enemy_name` + barra `restante / total`
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
- **final_level:** spawn em cada `RobotSpawnpoints/*`; respawn automático após 15 s

---

## Sinal

- `exploded` — emitido ao morrer; final_level conecta para respawn

---

## Hitboxes de Vidro (visuais)

- `_setup_glass_hitboxes()` no `_ready` cria envólucros de vidro por membro
- Usa `effects_shared/glass_hitboxes.gd` sobre `RedRobotModel/Armature/Skeleton3D`
- Só em clientes com tela e se `not dead`; ~11 envólucros (Body, ombros, braços, mãos, pernas)
- Ver [[arquivos-chave/glass-hitboxes-gd]]

---

## Relacionado

- [[sistemas/combate-tiro]]
- [[arquivos-chave/red-robot-gd]]
- [[arquivos-chave/glass-hitboxes-gd]]

---
tipo: arquivo-chave
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-07-08
---

# 🧠 library3D/characters/red_robot/IA/red_robot_ai.gd

**Criado em:** 2026-06-18
**Estende:** `Node` · **`class_name RedRobotAI`**

---

## Responsabilidades

Centraliza os **comportamentos e decisões** de combate do Red Robot em tempo de execução. O corpo
(`red_robot.gd`) instancia esta IA como filha em `_ready()` (nome `IA`) e a consulta a cada quadro.
Mantém a física, a animação e o disparo no corpo; aqui ficam só as **regras de decisão** e os
tunáveis, fáceis de ajustar sem mexer na máquina de estados.

---

## Tunáveis (`@export`)

| Var | Valor | Efeito |
|---|---|---|
| `fire_rate_multiplier` | `1.5` | Recarga **1,5× mais rápida** (1º e próximos tiros) |
| `flee_distance` | `10.0 m` | Player a esta distância ou menos → o robô abre espaço |
| `flee_speed` | `2.0 m/s` | Velocidade ao abrir espaço (ajustada à passada — ver [[🤖 inimigos]] 2026-07-08) |
| `strafe_speed` | `1.4 m/s` | Passo lateral no combate reativo |
| `pressure_speed` | `1.8 m/s` | Reposicionamento sob pressão |
| `formation_cohesion` | `0.32` | Força do retorno ao slot de formação designado |
| `formation_band` | `7.0 m` | Tolerância antes de o robô ser puxado de volta ao slot |
| `speed_variation` | `±0.18` | Variação de velocidade por-indivíduo (quebra o lockstep) |

---

## API

```gdscript
enum Action { APPROACH, ENGAGE, FLEE }

func reload_time(base_wait: float) -> float        # base_wait / fire_rate_multiplier
func decide(distance, effective_range) -> Action   # FLEE / ENGAGE / APPROACH
func should_shoot(distance, effective_range) -> bool  # distance <= effective_range
```

- `decide()`: `dist ≤ flee_distance` → **FLEE**; `dist ≤ alcance` → **ENGAGE**; senão **APPROACH**.
- `reload_time()`: usado pelo corpo para `shoot_reload = ai.reload_time(SHOOT_WAIT)`.

---

## Como o corpo usa (`red_robot.gd`)

- **Recarga acelerada:** `shoot_reload` substitui `SHOOT_WAIT` em todos os resets de
  `shoot_countdown` (1º tiro incluso).
- **Recuo (FLEE):** quando `decide(...) == FLEE`, `movement_plan` devolve `direction = -forward`
  (sentido oposto ao player) e `speed = flee_speed`. Desde 2026-07-08 o corpo **vira as pernas para
  essa direção** e o passo sai do root motion (anti-deslize) → o robô **gira e corre**; a torre segue
  mirando/atirando à parte. Ver [[🤖 inimigos]] ("Locomoção realista").
- **Tiro:** a lógica de mira já só dispara dentro de `effective_range`, cobrindo ENGAGE e FLEE.

---

## Caminho: `library3D/characters/red_robot/IA/red_robot_ai.gd`

---

## Individualização + formação (2026-06-25)

- **Sem lockstep:** `_ready` semeia por instância `_strafe_sign` (aleatório ±1), `_phase` e
  `_speed_mult` (`1 ± speed_variation`); os resets de `_strafe_cooldown` em `_choose_strafe_sign`
  usam `randf_range` (≈0.45–1.6 s) no lugar de períodos fixos (~1 s). Assim o pelotão **não anda
  igual a cada segundo**. RNG do servidor (movimento é server-autoritativo; clientes interpolam).
- **Formação designada:** na 1ª chamada de `movement_plan`, captura `_slot_bearing` a partir de
  `origin - target_position` (direção do spawn vista do player). Durante strafe/engage, adiciona um
  **viés de retorno** ao ponto `player + slot_dir * preferred` quando a folga passa de `formation_band`,
  ponderado por `formation_cohesion`. O robô **circula livre** mas tende a **voltar ao seu lugar**.
- **Velocidade:** `flee/strafe/pressure speed` saem multiplicados por `_speed_mult`.

---

## Relacionado

- [[🤖 red-robot-gd]]
- [[🤖 inimigos]]
- [[🩸 dano-localizado]]

# library3D/characters/red_robot/IA/red_robot_ai.gd

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
| `flee_distance` | `10.0 m` | Player a esta distância ou menos → o robô recua atirando |
| `flee_speed` | `6.0 m/s` | Velocidade ao correr para longe do player |

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
- **Recuo (FLEE):** quando `decide(...) == FLEE`, `_flee_movement()` encara o player (frente +Z) e
  define a velocidade no sentido oposto (`-fwd * flee_speed`), sobrepondo o root motion; as pernas
  tocam `walk` e o tiro segue (o player está dentro do alcance).
- **Tiro:** a lógica de mira já só dispara dentro de `effective_range`, cobrindo ENGAGE e FLEE.

---

## Caminho: `library3D/characters/red_robot/IA/red_robot_ai.gd`

---

## Relacionado

- [[arquivos-chave/red-robot-gd]]
- [[sistemas/inimigos]]
- [[sistemas/dano-localizado]]

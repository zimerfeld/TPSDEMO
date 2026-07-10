---
tipo: sistema
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-07-08
---

# ⚔️ Sistema de Facções (runtime)

**Script:** `effects_shared/factions.gd` (`class_name Factions`, `RefCounted` — só métodos estáticos)

Define de que **lado** cada personagem está em combate, **por-instância e mutável em runtime** —
distinto do [[🧠 red-robot-ai-gd|AIConfig]], que guarda uma facção por-**modelo**, estática, em JSON.
É o que sustenta: **sem fogo amigo**, **targeting por lado** e **neutros que viram de lado**.

> Criado em 2026-07-08 substituindo o duck-typing (checar `has_method("hit")`) que antes decidia
> alvo e dano. A infra `AIConfig.faction` (que existia mas nunca era lida) agora é a **semente**.

---

## Valores

| Facção | Papel |
|---|---|
| `hostile` | Inimigos (red_robot, criatura_alada por padrão) — atacam a facção oposta |
| `ally` | Do lado do player (o player humano e os bots aliados) |
| `neutral` | Não ataca ninguém por padrão; ao ser atingido, alinha-se **contra** o atacante (temporário) |

---

## Como a facção de um nó é resolvida — `Factions.of(node)`

Precedência (maior → menor):

1. **Override temporário** — neutro provocado (metas `faction_override` + `faction_override_until`);
   expira sozinho após `PROVOKE_DURATION_MS` (8 s) e volta ao base.
2. **Colocação por template** — meta `template_faction` (`enemy→hostile`, `friendly→ally`,
   `neutral→neutral`), gravada pelo `template_manager_base` no spawn. Tem precedência sobre a semente.
3. **Semente do modelo** — meta `faction`, semeada no `_ready` de cada entidade via
   `Factions.seed_node(self, model_key)` = `AIConfig.faction(model_key)`.
4. **Inferência** — fallback pelos métodos do nó: leva `add_camera_shake_trauma` → `ally`; tem
   `show_health_hud` → `hostile`; senão `neutral`.

`base_of(node)` faz o mesmo **ignorando** o override (a facção "de verdade" do neutro).

---

## API

```gdscript
Factions.seed_node(node, model_key)     # _ready: semeia a facção-base do modelo (AIConfig)
Factions.of(node) -> String             # facção efetiva agora (respeita override temporário)
Factions.base_of(node) -> String        # facção-base (ignora override)
Factions.are_enemies(a, b) -> bool      # lados opostos (neutro não é inimigo de ninguém)
Factions.same_side(a, b) -> bool        # mesmo lado (neutro não compartilha lado)
Factions.can_damage(attacker, target) -> bool   # puro: neutro sempre; senão só opostos
Factions.note_damage(attacker, target)          # ao aplicar dano: provoca o neutro atingido
```

---

## Onde pluga

- **Sem fogo amigo (dano)** — `bullet.gd` e `bomb.gd`:
  - Antes de aplicar dano, `Factions.can_damage(shooter/dropper, alvo)`. Mesma facção → **sem dano**.
  - A **bala atravessa** o aliado (exceção de colisão) em vez de explodir → não bloqueia a linha de
    tiro de quem está atrás. Ver [[🔫 combate-tiro]].
  - Ao aplicar dano, `Factions.note_damage(...)` provoca um alvo neutro.
- **Targeting (alvo)** — inimigos miram só a facção OPOSTA, filtrando por `are_enemies` na **seleção**
  do alvo (não na entrada da Area), para reagir a mudanças de facção em runtime:
  - `red_robot._pick_target` (ver [[🤖 inimigos]]), `criatura_alada._find_nearest_player`.
  - `player_bot_ai._is_valid_enemy` / `_is_ally` (bot aliado só engaja hostis; ver [[🎮 player]]).
- **Semeadura** — `red_robot.gd`, `criatura_alada.gd`, `player.gd` chamam `seed_node` no `_ready`.

---

## Neutros dinâmicos (momentâneo)

Um neutro atingido por um **projétil** (não é preciso mudar a assinatura de `hit()` — a lógica roda no
lado do projétil, server-side, onde o atacante é conhecido):

- atingido por **aliado** → vira **hostil** (inimigo dos aliados) por ~8 s;
- atingido por **inimigo** → vira **aliado** por ~8 s;
- sem levar tiro por 8 s → volta a **neutro**.

Por padrão **não há personagem neutro** no jogo — coloque um com facção `neutral` via template para ver.

---

## Observações

- **Separação entre aliados (2026-07-08):** vários bots aliados não se empilham mais — cada um usa
  **separation steering** (empurrão para longe dos outros aliados dentro de `separation_radius`),
  distribuindo-os na órbita/combate. Detalhe em [[🎮 player]].
- A facção runtime não é **replicada** ao cliente (não precisa: dano e alvo são server-autoritativos).

---

## Relacionado

- [[🤖 inimigos]] · [[🎮 player]] · [[🔫 combate-tiro]] · [[🧠 red-robot-ai-gd]]

---
tipo: arquivo-chave
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-07-04
---

# 🦴 effects_shared/body_parts.gd (+ planos corporais)

**Criado/refatorado em:** 2026-06-20 · **Estende:** `RefCounted` (sem nó)

---

## O que é

A **hierarquia de PLANOS CORPORAIS**: classifica os ossos de um `Skeleton3D` em
**MEMBROS** (CABEÇA, TRONCO, BRAÇO, PERNA…) e dá os rótulos e multiplicadores de dano
padrão de cada membro. Usada pelos colliders de dano localizado
([[🦿 limb-colliders-gd|LimbColliders]]) e pelo overlay de Debug 3D
(`debug_overlay.gd`).

`BodyParts` deixou de ser uma classe só-estática e virou uma **BASE instanciável com
métodos VIRTUAIS** — porque `BodyParts.group_of(...)` **estático NÃO é polimórfico** no
GDScript: uma chamada estática sempre resolveria para a base, ignorando a subclasse. **Use
sempre uma INSTÂNCIA** (via [[#BodyPlans (factory)|BodyPlans]]).

---

## Arquivos

| Arquivo | `class_name` | Papel |
|---|---|---|
| `body_parts.gd` | `BodyParts` | **BASE**: CABEÇA/TRONCO + pipeline comum + estáticos universais |
| `body_parts_biped.gd` | `BodyPartsBiped extends BodyParts` | + BRAÇO E/D, PERNA E/D — **DEFAULT** |
| `body_parts_quadruped.gd` | `BodyPartsQuadruped extends BodyParts` | + 4 pernas (dianteira/traseira × E/D), sem braços |
| `body_parts_crawler.gd` | `BodyPartsCrawler extends BodyParts` | só herda — apenas CABEÇA/TRONCO |
| `body_plans.gd` | `BodyPlans` | **factory** que entrega a instância certa por `body_type` |

---

## Base `BodyParts`

- **Constantes universais:** `HEAD`/`TORSO` + `BASE_LABELS` (CABEÇA/TRONCO) + `EXCLUDE_KEYWORDS`
  (ossos auxiliares/mecânicos — ik, guard, piston, plate, eye… — que NÃO viram membro principal;
  podem ser promovidos a sub-membro por modelo).
- **Estáticos universais** (independem do plano, valem p/ todas as subclasses):
  - `side_of(name) -> "L"/"R"/""` — detecta o lado pelo nome: prefixo/sufixo `L-/R-`, `.l/_l`,
    `…L/…R` em MAIÚSCULA, **e** as palavras `left`/`right`/`esquerd`/`direit` (fallback).
  - `front_rear_of(name) -> "F"/"R"/""` — dianteira (front/fore/dianteira/frente) vs traseira
    (rear/hind/back/traseira); usado pelo quadrúpede p/ separar as 4 pernas.
- **Virtuais de instância** (a base trata só CABEÇA/TRONCO; subclasses estendem e caem na base via
  `super`):
  - `members() -> Array[String]` — grupos que o plano define (p/ a tela listar/rotular).
  - `group_of(bone, head_bones, torso_bones, leg_bones) -> String` — grupo do osso ou "".
    `head_bones`/`torso_bones` forçam ossos de nome genérico (ignoram exclusões).
  - `label_of(group) -> String` — rótulo legível (CABEÇA, BRAÇO E…).
  - `default_multiplier(group) -> float` — **default de dano** do membro: cabeça 1.5, resto 1.0.
  - `default_sub_members() -> Array[String]` — sub-membros padrão do plano (base: nenhum).

## Subclasses

- **`BodyPartsBiped`** — `ARM_L/ARM_R/LEG_L/LEG_R` (BRAÇO E/D, PERNA E/D). Lado por `side_of`.
  `wing` conta como BRAÇO (criaturas aladas). É o **DEFAULT** (player, red_robot).
- **`BodyPartsQuadruped`** — `LEG_FL/LEG_FR/LEG_RL/LEG_RR` (PERNA DIANT E/D, PERNA TRAS E/D), sem
  braços. `_leg_group` combina `front_rear_of` + `side_of`.
- **`BodyPartsCrawler`** — cobra/lesma/verme: **só herda** (corpo alongado = TRONCO). Subclasse fina,
  ponto de extensão futuro (ex.: segmentos de cauda como sub-membros).

## `BodyPlans` (factory)

`effects_shared/body_plans.gd` — **isolada** das classes p/ evitar acoplamento base↔subclasse
(a base não referencia as subclasses → sem ciclo de `extends`).

- `BodyPlans.for_type(body_type) -> BodyParts` — match: `quadruped`/`crawler`/`_ => biped`.
- `BodyPlans.default() -> BodyParts` — bípede (p/ quem não sabe o tipo, ex.: overlay de debug sobre
  esqueletos quaisquer de fase).
- `const TYPES = ["biped","quadruped","crawler"]` — valores válidos do `@export body_type`.

---

## Quem usa

- **`LimbColliders`** (`build_for`) resolve `_classifier = BodyPlans.for_type(body_type)` e
  classifica cada osso por `_classifier.group_of(...)`. O multiplicador default de cada membro vem
  de `_classifier.default_multiplier(group)` (o salvo por modelo vem de `LimbConfig`).
- **`debug_overlay.gd`** (`_add_3d_skeleton`) usa `BodyPlans.default()` p/ rotular esqueletos de fase.
- **`models.gd`** resolve o classificador por `_current_classifier()` (de `_MODEL_BODY_TYPE`) p/
  listar membros e descobrir os ossos AUXILIARES (cujo `group_of` dá "") como candidatos a sub-membro.

---

## Caminho: `effects_shared/body_parts.gd` (+ `body_parts_biped/quadruped/crawler.gd`, `body_plans.gd`)

---

## Relacionado

- [[🩸 dano-localizado]]
- [[🦿 limb-colliders-gd]]
- [[🗿 biblioteca-de-modelos]]
- [[🧱 recursos-nativos-godot]]

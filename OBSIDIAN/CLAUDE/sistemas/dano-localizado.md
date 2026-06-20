# Sistema de Dano por Arma + Hitboxes Localizadas

> Implementado em 2026-06-06; migrado para **colliders 3D nativos** em 2026-06-14.
> Dano pela **arma** do atacante, com **`StaticBody3D` por grupo de membro** e
> **dano localizado** (colisão física, não mais Area3D de "vidro").

---

## Dano atribuído à arma

| Personagem | `weapon_damage` (export) | Observação |
|---|---|---|
| Player | `50` | Atribuído a cada bullet disparado (`bullet.weapon_damage = weapon_damage`) |
| Enemy (Red Robot) | `25` | Aplicado ao player pelo laser |

`hit(amount: int)` agora recebe o valor de dano (antes era fixo).

---

## Grupos de hitbox (membros)

`effects_shared/limb_colliders.gd` classifica ossos em grupos e cria **um `StaticBody3D` por membro** (ajustado aos vértices skinados, AABB no espaço do osso-raiz), com metas `group` + `damage_multiplier`. A forma é escolhida por `make_member_shape()`:

A tabela abaixo é a do plano **bípede** (o default — ver **Hierarquia de planos corporais**
abaixo); os multiplicadores são os **defaults do PLANO** (`BodyParts.default_multiplier`).

| Grupo | Forma | Multiplicador (default do plano) |
|---|---|---|
| **CABEÇA** (head/neck) | `SphereShape3D` | `1.5` (+50%) |
| **TRONCO** (hips/spine/chest/body) | `BoxShape3D` | `1.0` |
| **BRAÇO D/E** (shoulder/arm/forearm/hand/**wing** + lado) | `CapsuleShape3D` (eixo longo) | `1.0` |
| **PERNA D/E** (thigh/shin/knee/foot/leg + lado) | `CapsuleShape3D` (eixo longo) | `1.0` |

> Os multiplicadores acima são **defaults do plano corporal** (cabeça +50%, resto 1.0). Desde
> 2026-06-20 cada modelo pode ter um multiplicador PRÓPRIO por membro, editável na tela Models e
> persistido em `res://data/limb_config.json` (ver **Multiplicadores editáveis por modelo** abaixo).
> Os MEMBROS em si dependem do `body_type` do modelo (bípede/quadrúpede/rastejante).

Lado detectado por sufixo `.L/.R` (player) ou prefixo `L-/R-` (enemy). `wing` conta
como BRAÇO (criaturas aladas: criatura_alada, robot_*_alado).

**Overrides por modelo** (`group_of(..., head_bones, torso_bones, leg_bones)` + exports
`head_bone_names`/`torso_bone_names`/`leg_bone_names` do `LimbColliders`): forçam bones que o
classificador descartaria. red_robot usa: HEAD=`mouth_eyes`+`L-EYE`/`R-EYE` (os olhos entram
na CABEÇA p/ o headshot não virar uma esfera minúscula só do painel do rosto — 2026-06-18),
TRONCO=`Bone.001`, e **PERNA=
`L-RearLegGuard`/`R-RearLegGuard`** (2026-06-18) — as **placas das pernas**, antes excluídas pela
palavra "guard", entram no collider da perna (lado pelo prefixo L-/R-). Os mesmos overrides são
aplicados no preview da tela Models (`models.gd` `_MODEL_LEG_BONES`). Bones de controle como
`L-LEGORIENT`/`L-LEGIK` continuam excluídos (não estão na lista).

**Ajuste fino do tamanho** (2026-06-16) — para os colliders ficarem mais justos ao
corpo: `CROSS_SHRINK = 0.82` (raio/largura/profundidade), `LENGTH_SHRINK = 0.95`
(eixo longo) e `LIMB_RADIUS_RATIO = 0.32` (teto do raio da cápsula como fração do
comprimento, garantindo que um membro de AABB quase cúbico — ex.: o braço direito do
player, que segura a arma — ainda leia como **cápsula** e não como bola).

---

## Hierarquia de planos corporais (2026-06-20)

Os MEMBROS de cada modelo vêm do seu **PLANO CORPORAL**. `effects_shared/body_parts.gd`
(`class_name BodyParts`) deixou de ser uma classe só-estática e virou uma **BASE instanciável
com métodos VIRTUAIS** — porque `BodyParts.group_of(...)` **estático NÃO é polimórfico** no
GDScript. **Use sempre uma INSTÂNCIA** (via `BodyPlans.for_type`/`.default`). Ver
[[arquivos-chave/body-parts-gd]] para a nota dedicada.

- **`BodyParts` (base)** — constantes universais `HEAD`/`TORSO` + `BASE_LABELS` (CABEÇA/TRONCO) +
  `EXCLUDE_KEYWORDS`. **Estáticos universais** (independem do plano): `side_of(name)` (L/R; detecta
  prefixo/sufixo `L-/R-`, `.l/_l`, `…L/…R` e as palavras `left`/`right`/`esquerd`/`direit`) e
  `front_rear_of(name)` (F/R: front/fore/dianteira vs rear/hind/back/traseira). **Virtuais de
  instância**: `members()`, `group_of(bone, head_bones, torso_bones, leg_bones)`, `label_of(group)`,
  `default_multiplier(group)` (cabeça 1.5, resto 1.0) e `default_sub_members()`.
- **`BodyPartsBiped`** (`extends BodyParts`) — acrescenta `ARM_L/ARM_R/LEG_L/LEG_R` (BRAÇO E/D,
  PERNA E/D). É o **DEFAULT**. `wing` conta como BRAÇO (criaturas aladas).
- **`BodyPartsQuadruped`** — acrescenta `LEG_FL/LEG_FR/LEG_RL/LEG_RR` (PERNA DIANT E/D, PERNA TRAS
  E/D), **sem braços**; usa `front_rear_of` + `side_of` p/ separar as 4 pernas.
- **`BodyPartsCrawler`** (cobra/lesma/verme) — **só herda**: apenas CABEÇA/TRONCO (corpo alongado =
  TRONCO). Ponto de extensão futuro.
- **`BodyPlans` (factory)** — `effects_shared/body_plans.gd`. `BodyPlans.for_type(body_type) ->
  BodyParts` (match: `quadruped`/`crawler`/`_ => biped`) e `BodyPlans.default()` (bípede). `const
  TYPES = ["biped","quadruped","crawler"]`. **Isolada** das classes p/ evitar ciclo
  base↔subclasse (a base não referencia as subclasses).

**`body_type`** — `LimbColliders` ganhou `@export_enum("biped","quadruped","crawler") var
body_type`, que escolhe o classificador via `BodyPlans.for_type` em `build_for`. `player.gd` e
`red_robot.gd` setam `lc.body_type = "biped"`. A tela Models espelha isso na const
`_MODEL_BODY_TYPE := {"red_robot":"biped","player":"biped"}` (o preview remove scripts, então o
@export não está disponível) + helpers `_body_type_for_current()`/`_current_classifier()`.

O **overlay de Debug 3D** (`debug_overlay.gd._add_3d_skeleton`) agora usa `var classifier :=
BodyPlans.default()` (instância bípede) em vez dos estáticos antigos, pois roda sobre esqueletos
quaisquer de fase.

---

## Multiplicadores editáveis por modelo (2026-06-20)

`effects_shared/limb_config.gd` (`class_name LimbConfig`, `RefCounted` com API estática) — antigo
`LimbDamage` (renomeado/substituído; `limb_damage.gd` + `data/limb_damage.json` foram **removidos**)
— guarda, **por modelo**, o multiplicador de cada membro/sub-membro **e** a lista de sub-membros, em
**`res://data/limb_config.json`**. O schema agora é **ANINHADO**:

```json
{
  "red_robot": {
    "damage": { "HEAD": 2.0, "PART_L-RearLegGuard": 1.0 },
    "sub_members": ["L-RearLegGuard", "R-RearLegGuard"]
  }
}
```

- Chave = **`model_key`** = nome da pasta do modelo (`"red_robot"`, `"player"`), o MESMO valor que
  `player.gd`/`red_robot.gd` passam em `LimbColliders.model_key`. `GROUP` = chave do plano
  (`HEAD`/`TORSO`/`ARM_L`/…/`LEG_FL`/…) ou `PART_<osso>` p/ sub-membro. Valor = **multiplicador**
  (`1.0` = normal, `1.5` = +50%).
- API estática: `get_multiplier(model_key, group, classifier)`, `set_multiplier(model_key, group,
  mult)`, `sub_members(model_key)`, `add_sub_member(model_key, bone)`, `remove_sub_member(model_key,
  bone)` (esta também apaga o `PART_<bone>` do `damage`) e `load_table`.
- O **default NÃO está mais em LimbConfig** — vem do **PLANO**: `get_multiplier` cai em
  `classifier.default_multiplier(group)` quando não há entrada salva. O arquivo só guarda ajustes
  do usuário, então sem JSON o comportamento é o default do plano (zero regressão).
- **Editor:** a tela Models tem o toggle **"Dano por membro"** que abre um painel com um `SpinBox`
  em **bônus %** por membro (cabeça `+50%` ⇒ multiplicador `1.5`); mudar grava via
  `LimbConfig.set_multiplier`. Só aparece para **personagem em "Modelo completo"**. Ver
  [[sistemas/biblioteca-de-modelos]]. `res://` é gravável só rodando pelo editor; o jogo só lê.

---

## Sub-membros configuráveis (2026-06-20)

**Sub-membros** = ossos auxiliares salientes PROMOVIDOS a collider PRÓPRIO em caixa (grupo único
`PART_<osso>`, p/ peças que a cápsula do membro não cobriria — ex.: as **placas das pernas** do
red_robot). Em `LimbColliders.build_for`, os sub-membros efetivos vêm da UNIÃO de **TRÊS fontes**:

1. o `@export standalone_part_bones` do nó,
2. `LimbConfig.sub_members(model_key)` (os editados na tela),
3. `classifier.default_sub_members()` (os do plano corporal).

O `red_robot.gd` **não hardcoda mais** `standalone_part_bones`: as placas (`L-RearLegGuard`/
`R-RearLegGuard`) foram **migradas p/ `data/limb_config.json`** (seed) e são editáveis na tela. A
tela Models removeu a const `_MODEL_STANDALONE_BONES`.

**Editor (subseção "Sub-membros"):** dentro do painel "Dano por membro", lista cada sub-membro
atual (`PART_*`) como uma linha com rótulo + `SpinBox` de bônus % + botão **× (remover)**, e uma
linha de **adicionar** (um `OptionButton` com os ossos AUXILIARES do esqueleto do preview — os
cujo `group_of` dá "" — + botão "Adicionar"). Adicionar/remover chama `LimbConfig.add_sub_member`/
`remove_sub_member` e **reconstrói** os colliders do preview (`_rebuild_member_colliders` →
`_clear_member_colliders` + `_ensure_member_colliders`), repondo gizmos/rótulos. Os membros
principais continuam editáveis como antes; só os `PART_*` ganharam a subseção. A leitura em jogo
(`bullet.gd`/`laser_shooter.gd` lendo a meta `damage_multiplier`) é **inalterada**.

---

## Camadas de colisão

| Bit | Valor | Uso |
|---|---|---|
| bit4 | `8` | Projétil (bullet) — `collision_layer` do bullet |
| bit5 | `16` | Colliders de membro do **player** |
| bit6 | `32` | Colliders de membro do **enemy** |

- Bullet: `layer = 8`, `mask = 51` (`3` mundo/corpos + `16` + `32`) para colidir fisicamente com os membros.
- Colliders de membro: `StaticBody3D` na layer 16/32, `mask = 0` (passivos — são atingidos, não detectam).

---

## Fluxo do dano (player → enemy)

```
bullet (server) colide fisicamente (move_and_collide) com um collider de membro do enemy
  → bullet._apply_hit(collider)
      → lê metas damage_multiplier + character; ignora se character == shooter
      → enemy.hit.rpc(round(weapon_damage * multiplicador))   [server]
      → bullet explode
Fallback: se o bullet acerta um corpo com hit() sem metas de membro → dano de TRONCO (1x)
          no mesmo _apply_hit (idempotente com _registered)
```

**Pass-through do corpo do personagem (2026-06-18):** o corpo genérico do personagem (cápsula/esfera
do `CharacterBody3D`) envolve a figura inteira, então seria atingido ANTES dos colliders de membro
(que abraçam a malha) — dano sempre 1×, sem headshot. No `bullet._physics_process`, se o
`move_and_collide` acerta um `CharacterBody3D` que tem o nó `LimbColliders`, a bala faz
`add_collision_exception_with(corpo)` e **continua voando**, atravessando o corpo até acertar o
collider de MEMBRO atrás dele. Isso resolveu o red_robot, cujo corpo era uma `SphereShape3D` de raio
~1,12 m que envolvia tudo e interceptava todo tiro. O corpo continua existindo para o inimigo andar no
chão e ser mirado/detectado (raios de mira do player usam `mask 0b11`); só sai do caminho do TIRO.

**Body collider = cápsula como o player (2026-06-18):** a esfera gigante de corpo do red_robot foi
trocada por uma **`CapsuleShape3D` (raio 0,5 / altura 2,0, em y=1)** — a MESMA lógica do `CollisionShape3D`
do player — então não há mais a esfera enorme. O nó continua `CollisionShape3D` (dependência de
`red_robot.gd`).

O atirador exclui os próprios colliders de membro do projétil (`player._exclude_own_limbs`)
para o tiro não nascer acertando o próprio braço/arma.

## Fluxo do dano (enemy → player)

`red_robot.shoot()` (server) **dispara uma bala de canhão** (não mais laser hitscan), via o
componente `CannonShooter`, na direção do player (com dispersão se `aim_accuracy < 1`). A bala voa e,
ao acertar um collider de MEMBRO do player (bit5), aplica `player.hit.rpc(weapon_damage * mult)` —
mesmo caminho localizado do tiro do player (`bullet._apply_hit`).

## Componentes de tiro reutilizáveis (2026-06-18)

Para reutilizar o tiro entre modelos, a lógica foi isolada em `effects_shared/`:

- **`CannonShooter`** (`cannon_shooter.gd`, `class_name`): `static fire(parent, origin, dir, damage,
  shooter, tint, ball_color, ball_scale)` → instancia o `bullet.tscn`, posiciona/orienta, exclui o
  corpo + colliders de membro do atirador e o lança. Cores opcionais (alpha 0 = visual padrão azul do
  player). Usado pelo **player** (azul, padrão) e pelo **red_robot** (bola PRETA + efeito VERMELHO,
  `ball_scale 2.5`).
- **`LaserShooter`** (`laser_shooter.gd`, `class_name`): `static fire(muzzle, beam_mesh, blast_scene,
  damage, hitbox_layer, exclude)` → laser hitscan (raycast + dano localizado + clip do feixe + blast).
  Extraído do laser antigo do red_robot; **disponível para reúso** (red_robot agora usa canhão; nenhum
  modelo usa o laser por enquanto).
- `bullet.gd` ganhou `tint`/`ball_color`/`ball_scale` (sentinela alpha 0 = não mexe → player intacto),
  aplicados em `_apply_visuals` (luz + CPUParticles do rastro + material da bola).

---

## BulletCache (armadilha resolvida)

`player.tscn` tem um nó `BulletCache` (bullet pré-instanciado, warm-up). Sem atirador,
ele causava 50 de dano no início. Correção: **bullet sem `shooter` fica inerte**
(`_ready`: `if shooter == null or not is_server: disable`). Cobre também clientes
(onde `shooter` não é replicado).

---

## Precisão e alcance do enemy

| Export | Default | Função |
|---|---|---|
| `aim_accuracy` | `1.0` | Chance de acertar ao disparar (100% = sempre) |
| `effective_range` | `30.0` m | Só dispara quando o player está dentro deste alcance |

O enemy aguarda aproximar (`shoot_countdown = 0`) enquanto o player está fora do alcance.

> **Raio de detecção = alcance:** a `PlayerDetectionArea` (`SphereShape3D`) tem **raio 30 m**,
> igual a `effective_range`, para o robô **detectar e começar a atirar a 30 m** (antes era 20 m,
> o que impedia abrir fogo no alcance total da arma).

---

## Tuning no inspector (nó do personagem)

Em `limb_colliders.gd` (nó `LimbColliders`): `enabled`, `padding`, **`body_type`**
(`@export_enum("biped","quadruped","crawler")`, default `biped` — escolhe o plano corporal via
`BodyPlans.for_type`; 2026-06-20), `head_bone_names` (`["mouth_eyes", "L-EYE", "R-EYE"]` no enemy),
`torso_bone_names` (força um osso de nome genérico para TRONCO — `["Bone.001"]` no red_robot, cujo
corpo não era reconhecido e ficava **sem collider de tronco**), `standalone_part_bones` (sub-membros
fixos no nó — UNIDOS aos de `LimbConfig` e do plano; o red_robot **não usa mais** este export, as
placas das pernas migraram p/ `limb_config.json`), `hitbox_layer` (16 player / 32 enemy) e
**`model_key`** (`"player"`/`"red_robot"` — chave dos multiplicadores/sub-membros em `LimbConfig`;
2026-06-20). Os exports de cor/raio do antigo sistema de vidro foram removidos.

> Verificado via MCP do Godot ([[godot-mcp]]): laser do enemy aplica 25 (arma),
> lookup de hitbox funcional, cache não causa mais dano no início, sem erros.

---

## Relacionado

- [[sistemas/combate-tiro]]
- [[sistemas/sistema-de-vida]]
- [[arquivos-chave/limb-colliders-gd]]
- [[arquivos-chave/body-parts-gd]]
- [[arquivos-chave/bullet-gd]]
- [[arquivos-chave/red-robot-gd]]
- [[arquivos-chave/enemy-health-bar-gd]]

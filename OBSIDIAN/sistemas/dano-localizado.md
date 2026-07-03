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
| **CABEÇA** (head/neck) | `SphereShape3D` (cápsula opcional — ver abaixo) | `1.5` (+50%) |
| **TRONCO** (hips/spine/chest/body) | `BoxShape3D` | `1.0` |
| **BRAÇO D/E** (shoulder/arm/forearm/hand/**wing** + lado) | `CapsuleShape3D` (eixo longo) | `1.0` |
| **PERNA D/E** (thigh/shin/knee/foot/leg + lado) | `CapsuleShape3D` (eixo longo) | `1.0` |

> Os multiplicadores acima são **defaults do plano corporal** (cabeça +50%, resto 1.0). Desde
> 2026-06-20 cada modelo pode ter um multiplicador PRÓPRIO por membro, editável na tela Models e
> persistido na pasta do modelo (`res://library3D/<cat>/<model_key>/limb_config.json`; override de
> runtime em `user://` — ver **Multiplicadores editáveis por modelo** abaixo).
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

**Forma da CABEÇA por modelo** (2026-06-21) — o `LimbColliders` tem um export
`head_shape` (`"sphere"` default ou `"capsule"`). O **player** usa `"capsule"`
(`player.gd` seta `lc.head_shape = "capsule"`): a cabeça vira uma **cápsula alinhada ao
eixo mais longo da cabeça** (mesma orientação do osso), mantendo o **raio cheio**
(`make_member_shape` chama `make_shape("capsule", aabb, cap_radius=false)`: com
`cap_radius=false` a cabeça pula TANTO o `CROSS_SHRINK` QUANTO o teto `LIMB_RADIUS_RATIO`
— fica com o raio integral para **cobrir toda a malha**, em vez de afinar). Demais
modelos seguem a esfera. O preview da tela Models espelha isso pela const
`_MODEL_HEAD_SHAPE := {"player":"capsule"}` (`models.gd`), igual ao gameplay.

**Ajuste fino do tamanho** (2026-06-16, largura reduzida em 2026-06-20) — para os
colliders ficarem mais justos ao corpo: `CROSS_SHRINK = 0.72`
(raio/largura/profundidade, **só dos membros** — a cabeça com `cap_radius=false` NÃO
aplica esse encolhimento), `LENGTH_SHRINK = 0.95` (eixo longo) e
`LIMB_RADIUS_RATIO = 0.32` (teto do raio da cápsula como fração do comprimento,
garantindo que um membro de AABB quase cúbico — ex.: o braço direito do player, que
segura a arma — ainda leia como **cápsula** e não como bola).

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

> [!note] Membro de fallback "CORPO" (2026-07-01)
> **Todo modelo tem ao menos UM membro editável.** Na tela Models, quando um modelo **não** tem
> nenhum membro classificado, `_add_mesh_member_colliders` (models.gd) sintetiza um único membro
> **`CORPO`** que envolve **todas as malhas visíveis** (AABB), com forma **box** por padrão — assim
> sempre há um alvo para definir collider/dano. Duas situações:
> - **Estruturas/Propulsores** (categorias **sem** plano corporal): o classificador **não** roda
>   (evita casar nomes como `horse_head` com CABEÇA por substring) → cai direto no `CORPO`.
> - **Personagens/Armas** cujo rig sem `Skeleton3D` não casou nenhuma malha → também recebem `CORPO`.
>
> O `CORPO` é um membro comum (meta `group="CORPO"`), então herda offset/escala/rotação/forma e o
> multiplicador de dano via `LimbConfig` (chave `CORPO` no `limb_config.json` do modelo), e o dropdown
> **Membro** passou a aparecer para **qualquer categoria** em "Modelo completo" (não só Personagens/Armas).
> Const `FALLBACK_MEMBER_GROUP`/`FALLBACK_MEMBER_LABEL` em `models.gd`.

---

## Multiplicadores editáveis por modelo (2026-06-20)

`effects_shared/limb_config.gd` (`class_name LimbConfig`, `RefCounted` com API estática) — antigo
`LimbDamage` (renomeado/substituído; `limb_damage.gd` + `data/limb_damage.json` foram **removidos**)
— guarda o multiplicador de cada membro/sub-membro, a lista de sub-membros **e** a relação de dono
de cada um. **UM ARQUIVO POR MODELO NA PASTA DO MODELO (2026-06-22):**
`res://library3D/<categoria>/<model_key>/limb_config.json` — junto da malha/cena, versionável e
editável no Godot (`_model_dir` resolve a pasta varrendo `library3D`, com cache). **Override gravável
de runtime:** como o `res://` é **somente-leitura no .exe exportado** (PCK embutido), edições feitas
RODANDO o jogo (tela Models no .exe) vão para `user://limb_config/<model_key>.json`, que tem
**precedência na leitura** — por isso o que você edita em tela é relido e aparece. No editor o save vai
direto pra pasta do modelo (fonte canônica) e **apaga** o override `user://` obsoleto daquele modelo.
> ⚠️ **Bug corrigido (2026-06-22):** antes a config era gravada em `res://data/limb_config/<key>.json`;
> no **.exe** o `res://` é read-only, então Adicionar sub-membro (ex.: "mouth"→CABEÇA) **falhava ao
> gravar** e o rebuild relia o disco sem ele → não aparecia na árvore nem no dropdown. Com o override
> `user://` a edição persiste e reflete em tela mesmo no .exe.

**Migração transparente (leitura, em ordem):** `user://` (override) → pasta do modelo → antigo
`res://data/limb_config/<key>.json` → combinado legado `res://data/limb_config.json`; o primeiro SAVE
grava no novo local sem perder dados. Schema de cada arquivo:

```json
{
  "damage": { "HEAD": 2.0, "PART_L-RearLegGuard": 1.0 },
  "sub_members": ["L-RearLegGuard", "R-RearLegGuard"],
  "sub_member_owners": { "L-RearLegGuard": "LEG_L", "R-RearLegGuard": "LEG_R" },
  "collider_offsets": { "HEAD": [0.0, 0.1, 0.0] },
  "collider_scales": { "HEAD": [1.2, 1.2, 1.2] },
  "collider_shapes": { "HEAD": "capsule", "TORSO": "none" }
}
```

- **`model_key`** = nome da pasta do modelo (`"red_robot"`, `"player"`), o MESMO valor que
  `player.gd`/`red_robot.gd` passam em `LimbColliders.model_key`; agora é o **nome do arquivo**.
  `GROUP` = chave do plano (`HEAD`/`TORSO`/`ARM_L`/…/`LEG_FL`/…) ou `PART_<osso>` p/ sub-membro.
  Valor = **multiplicador** (`1.0` = normal, `1.5` = +50%). `sub_member_owners` = membro-**DONO**
  EXPLÍCITO de cada sub-membro (agrupamento só lógico p/ herança; vazio = resolução automática).
  `collider_offsets` (2026-06-22) = **afastamento** `[x,y,z]` (metros, espaço local do collider)
  aplicado à `position` do `StaticBody3D`; `collider_rotations` (2026-06-25) = **rotação** `[x,y,z]`
  (GRAUS) aplicada ao `rotation_degrees` do `StaticBody3D`; `collider_scales` (2026-06-22) = **escala**
  `[x,y,z]` aplicada à forma do collider (em torno do centro). `collider_shapes` (2026-06-25) = **forma**
  escolhida na tela Models: `"sphere"`/`"box"`/`"capsule"` sobrescreve a forma automática, `"none"`
  (`SHAPE_NONE`) **suprime o collider** do membro/sub-membro (sem hitbox; o preview da tela Models ainda
  mostra o sub-membro suprimido na árvore via `include_suppressed`), ausente = forma automática do plano.
  Todos por membro/sub-membro, editáveis na tela Models (ver [[sistemas/biblioteca-de-modelos]]);
  ausente/zero(offset)/[1,1,1](escala) = neutro.
- API estática (2026-06-21): `effective_multiplier(model_key, group, classifier, owner_group="")`
  (COM herança), `get_multiplier(...)` (wrapper sem owner), `has_multiplier`/`clear_multiplier`
  (estado do checkbox "Definir"), `set_multiplier`, `sub_members`, `sub_member_owner(s)`,
  `set_sub_member_owner`, `add_sub_member(model_key, bone, owner="")`, `remove_sub_member` (apaga
  também o `PART_<bone>` do `damage`, o dono, o `collider_offsets`, o `collider_scales`, o
  `collider_rotations` e o `collider_shapes`), `collider_offset`/`set_collider_offset`,
  `collider_scale`/`set_collider_scale` (2026-06-22), `collider_rotation`/`set_collider_rotation`,
  `collider_shape`/`set_collider_shape` + const `SHAPE_NONE` (2026-06-25) e `load_table`.
- **Herança / "nenhum valor é obrigatório" (2026-06-21):** `effective_multiplier` — valor EXPLÍCITO
  do próprio grupo tem precedência; um `PART_*` SEM valor próprio **herda o do membro-DONO**
  (explícito do dono, senão default do plano do dono); sem nada, cai no `default_multiplier` do
  próprio grupo. `LimbColliders` carimba a meta `damage_multiplier` já RESOLVIDA (dono = explícito
  de `LimbConfig`, senão `resolve_sub_member_owner`). O arquivo só guarda ajustes do usuário (sem
  JSON = default do plano, zero regressão).
- **Editor:** a tela Models tem o toggle **"Dano"** (renomeado de "Dano por membro" em 2026-06-22) que abre um painel flutuante
  (`DamagePanel`, centralizado, **720 px de altura** — aumentado de 500 em 2026-06-20 para caber
  mais membros/sub-membros sem rolar) com um `SpinBox` em **bônus %** por membro (cabeça `+50%` ⇒
  multiplicador `1.5`); mudar grava via `LimbConfig.set_multiplier`. Só aparece para **personagem
  em "Modelo completo"**. Ver [[sistemas/biblioteca-de-modelos]]. `res://` é gravável só rodando
  pelo editor; o jogo só lê.

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

**A qual MEMBRO um sub-membro pertence (2026-06-21):** resolvido por
**`LimbColliders.resolve_sub_member_owner(skel, bone, classifier, head, torso, leg)`** (estático,
usado pelo agrupamento `_sub_member_owner_map`/herança de dano da tela Models). **NÃO** renomeia mais
o rótulo: desde 2026-06-22 o `_part_label` retorna o **nome ORIGINAL do osso** (ver abaixo). Camadas: (1) **NOME da própria peça** via `owner_hint` (palavras
de membro + lado, ignorando exclusões); (2) **sobe na HIERARQUIA** e, em cada ancestral, tenta
`owner_hint` e depois `group_of` (com overrides head/torso/leg). O passo (2) com `owner_hint` é o
que pega placas penduradas num osso AUX/IK cujo NOME diz o membro:
- **player** — `shoulderpad-adjust.L/.R` (filhas do `chest`): resolvem por (1), nome "shoulder" → **BRAÇO E/D**.
- **red_robot** — `L-Shield/R-Shield` (escudos do braço, filhos do `L-ARMIK`/`R-ARMIK`): (1) falha
  ("shield" não é palavra de membro), mas a subida acha o pai **`L-ARMIK`** cujo `owner_hint` dá
  **ARM** → **BRAÇO E/D** (só para AGRUPAR/herdar dano; o rótulo continua sendo o nome do osso).
- **red_robot** — `L-/R-RearLegGuard`: nome tem "leg" → **PERNA E/D** por (1).

O **rótulo MANTÉM o nome ORIGINAL do osso (2026-06-22):** `_part_label` foi simplificado para
`return bone_name`. O antigo rótulo derivado do dono **"PLACA \<MEMBRO\>"** (ex.: "PLACA BRAÇO E",
"PLACA PERNA D") foi **descartado a pedido** — adicionar um sub-membro a um membro só agrupa o dano,
nunca renomeia a peça. Seeds em `data/limb_config.json`: player = `shoulderpad-adjust.L/.R`; red_robot =
`L-/R-RearLegGuard` + `L-/R-Shield`. ⚠️ O osso idealmente tem **vértices skinados** próprios —
`shoulderpad.L/.R` (sem `-adjust`) têm 0 vértices e a região é deformada por `shoulderpad-adjust.L/.R`.
**Fallback para ossos sem vértices (2026-06-22):** um sub-membro promovido cujo osso NÃO tem vértices
dominantes (ex.: `Mouth`, ossos estruturais/vazios) **não somava mais um collider** e sumia da
árvore/dropdown da tela Models; agora `_collect_member_boxes` (passo 4, helper `_fallback_part_size`)
gera uma **pequena caixa centrada na origem (rest) do osso** (~20% do maior membro medido, escala-aware),
para o sub-membro **aparecer e poder receber dano**. (O realce laranja "Colisores de Esqueleto" e o rótulo do toggle "Esqueleto" (ex-"SubMembro"/"Osso"), que usam
`bone_vertex_box`, continuam exigindo vértices.) Ossos que já são MEMBRO (`L-Shoulder`/`R-Shoulder` →
BRAÇO) não entram na lista "Adicionar sub-membro" (que só oferece auxiliares, `group_of == ""`).

**Editor (painel "Dano"):** lista **todos os membros do plano** (`_plan_member_entries`,
mesma fonte do combo "Membro" desde 2026-06-21) e, **aninhado (↳, margem 24px) sob cada membro**,
seus sub-membros (`PART_*`) — agrupados pelo MESMO `_sub_member_owner_map`/`owner_hint` dos combos
(helper `_sub_members_by_owner`), para painel e dropdown concordarem; sub-membro sem dono na lista
vai para a seção **"Outros sub-membros"**. O painel é uma **árvore (Tree)**; cada folha de sub-membro
tem um **botão de lixeira à direita do nome** para removê-la ali mesmo — com **diálogo de confirmação**
("Deseja realmente remover associação do sub-membro: <nome> ?") (2026-06-22; substituiu o antigo botão
grande "Remover sub-membro" do rodapé — ver [[sistemas/biblioteca-de-modelos]]). No fim, a linha
de **adicionar** (`_build_damage_footer`): um `OptionButton` com os ossos AUXILIARES do esqueleto do
preview (os cujo `group_of` dá "") + o dropdown de **membro-dono** + botão "Adicionar".
**Cabeçalho mesclado (2026-06-27):** os rótulos "Adicionar sub-membro" e "Para Membro Dono" ficam
agora numa **única `HBoxContainer`** acima da linha (antes: um título solto + um rótulo dentro de um
`VBoxContainer` sobre o dropdown). "Adicionar sub-membro" usa `SIZE_EXPAND_FILL` (esquerda, sobre o
seletor de osso) e "Para Membro Dono" fica à direita.
**Títulos de coluna re-traduzidos (2026-06-27):** os cabeçalhos da árvore (Membro/Def/Bônus %/Dono)
**não** são `Label`/`Button`, então o auto-localizador do `Locale` não os alcançava e ficavam presos
no idioma da última construção. Agora `_apply_damage_tree_titles()` os reaplica via `tr_key` tanto em
`_refresh_damage_panel` quanto em `_on_language_changed` (ver [[sistemas/localizacao]]).
Adicionar/remover chama `LimbConfig.add_sub_member`/`remove_sub_member` e **reconstrói** os colliders
do preview (`_rebuild_member_colliders`), repondo gizmos/rótulos. A leitura em jogo (`bullet.gd`/
`laser_shooter.gd` lendo a meta `damage_multiplier`) é **inalterada**.

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

**Auto-fit da cápsula de locomoção por modelo (2026-07-03):** em vez da cápsula default (0,5×2,0)
IGUAL p/ todo modelo, o bloqueio físico agora é **proporcional ao modelo**, derivado dos MESMOS boxes
de membro que o `LimbColliders` já mede — mantendo **1 shape por personagem** (barato, estável e
determinístico, então servidor e cliente-predição concordam; não depende da pose animada). Método
`LimbColliders.fit_locomotion_capsule(shape_node, character)`, chamado logo após `build_for` em
`player.gd` e `red_robot.gd`:
- **RAIO = footprint em pé** (`_is_footprint_group`: **TRONCO + PERNAS** — `LEG_*` de qualquer plano).
  Braços (envergadura de um T-pose), cabeça (topo) e peças `PART_*` ficam **de fora** p/ não engordar
  o raio. `raio = 0,5 · max(footprint.x, footprint.z)`, com piso `MIN_BODY_CAPSULE_RADIUS = 0,12`.
- **ALTURA = extensão vertical total** (topo da cabeça → pés), com a **BASE ancorada no chão** do
  personagem (`bottom = min(aabb.min.y, 0)`) p/ a cápsula nunca **flutuar** (mantém `is_on_floor`).
- **Centro** no eixo do modelo (x/z do footprint) e no meio vertical. **Duplica** a forma p/ não mutar
  um sub-recurso compartilhado. **No-op** (devolve `{}`) se nada foi construído (ex.: criatura_alada,
  que não monta `LimbColliders` no gameplay; modelo sem membros classificados) → **preserva a cápsula
  autorada** como fallback seguro.
- Helpers internos: `member_boxes_in(space)` (AABBs por grupo no espaço do personagem, lendo a
  geometria REAL das formas — pós-encolhimento), `_shape_local_aabb` (sphere/box/capsule) e
  `_transform_aabb` (envelope dos 8 cantos, correto p/ cápsulas de membro rotacionadas).
- **Validado** por sonda headless determinística (bípede sintético ~1,8 m): raio **0,250** (footprint,
  NÃO os braços a 0,575), altura **1,800**, base **0,000** — os 3 critérios OK.

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

**Rede (2026-06-26):** o `BulletCache` carregava o `MultiplayerSynchronizer` do `bullet.tscn` para
dentro da cena replicada do player. Ao spawnar/despawnar o player via rede, esse sync gerava
`Node not found .../BulletCache/MultiplayerSynchronizer`, `Failed to get cached node from peer` e
`on_despawn_receive ERR_UNAUTHORIZED`. Correção: no `player.tscn`, override do sync do cache com
**`public_visibility = false`** (não replica) — afeta só o cache; balas reais (instâncias de
`bullet.tscn`) seguem replicando normalmente.

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

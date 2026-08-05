---
tipo: arquivo-chave
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-07-23
---

# 🦿 effects_shared/limb_colliders.gd

**Renomeado de `glass_hitboxes.gd` em:** 2026-06-14 · **Estende:** `Node3D`

---

## Responsabilidades

- Gerar **colliders 3D nativos** (`StaticBody3D` + `CollisionShape3D`) por **grupo de membro** de um `Skeleton3D`
- Cada membro → `BoneAttachment3D → StaticBody3D (BoxShape3D)`, preso ao **osso-raiz** (acompanha pose/animação)
- Os projéteis colidem **fisicamente** com esses corpos e o laser do enemy os atinge por **raycast contra corpos** → **dano localizado** ao personagem dono
- Os **MEMBROS** vêm do **plano corporal** do modelo, escolhido pelo `@export body_type` via a factory **`BodyPlans.for_type`** (instância de [[🦴 body-parts-gd (PT)|BodyParts]] — `_classifier`, resolvido em `build_for`). Bípede (default), quadrúpede ou rastejante.
- Multiplicador de dano por membro vem de **`LimbConfig`** (lido por `model_key`), com fallback ao default do **plano** (`_classifier.default_multiplier`): cabeça = +50% (`1.5`), demais = `1.0` (2026-06-20). Editável na tela Models (ver [[🩸 dano-localizado (PT)|🩸 dano-localizado]])
- **Sub-membros** (ossos salientes com collider PRÓPRIO `PART_<osso>`) = UNIÃO de 3 fontes em `_resolve_sub_members`: o `@export standalone_part_bones` + `LimbConfig.sub_members(model_key)` + `_classifier.default_sub_members()`
- **Sub-membros DISTAIS automáticos (2026-07-23):** com o `@export auto_distal_sub_members` (novo, `true` por padrão), **antebraço/mão** e **canela/pé** viram SUB-MEMBROS próprios (`PART_<osso>`, com collider e dano localizados) em vez de serem absorvidos no BRAÇO/PERNA. `player.gd` e `red_robot.gd` fazem **opt-out**. Medido: humanoide/monstro = **6 membros + 8 sub-membros**; player = **6 membros e 0 sub-membros**
- **Sem Area3D, sem visual de vidro, sem labels** (substituiu o antigo sistema de "hitboxes de vidro")
- Ver [[🩸 dano-localizado (PT)|🩸 dano-localizado]]

---

## Como funciona (posicionamento por vértices skinados)

1. Classifica os ossos em grupos via `_classifier.group_of` — uma **INSTÂNCIA** do plano corporal (`BodyPlans.for_type(body_type)`), pois `BodyParts.group_of` estático NÃO é polimórfico. Bípede dá CABEÇA/TRONCO/BRAÇO E-D/PERNA E-D; quadrúpede dá 4 pernas; rastejante só CABEÇA/TRONCO (ver [[🦴 body-parts-gd (PT)|🦴 body-parts-gd]])
2. Escolhe o **osso-raiz** de cada grupo (o mais raso na hierarquia)
3. Para cada **vértice skinado** da malha, pega o osso de maior peso e o converte ao espaço local do osso-raiz usando a **bind pose** da skin (`get_bind_pose`) → acumula um **AABB por membro** (+ `padding` de folga)
4. Cria `BoneAttachment3D` (no osso-raiz) → `StaticBody3D` + `CollisionShape3D (BoxShape3D)` do tamanho do AABB
5. Metas no `StaticBody3D`: `group`, `damage_multiplier` (de `LimbConfig.effective_multiplier(model_key, group, _classifier, owner_group)` — o `owner_group` só entra nos sub-membros, p/ a herança de dano), `member_label` (rótulo) e `character` (dono)
6. **Afastamento (offset) + Escala (2026-06-22):** `body.position = LimbConfig.collider_offset(model_key, group)` desloca o corpo inteiro (shape/gizmo/rótulo acompanham); `shape_node.scale = LimbConfig.collider_scale(model_key, group)` escala a forma em torno do centro. Ambos em espaço local do osso, editáveis ao vivo na tela Models (rows X/Y/Z de Afastamento e Escala + botão Salvar, com o toggle Colisores ligado); ver [[🗿 biblioteca-de-modelos (PT)|🗿 biblioteca-de-modelos]]. Vazio = offset zero / escala [1,1,1].

- **Fallback de sub-membro sem vértices (2026-06-22):** o passo 3 só gera AABB para grupos com **vértices dominantes**. Um sub-membro (`PART_*`) promovido cujo osso não tem vértices próprios (ex.: `Mouth`, ossos estruturais) ficava **sem collider** e sumia da tela Models. Agora o passo 4 de `_collect_member_boxes` (helper `_fallback_part_size`) cria uma **pequena caixa centrada na origem (rest) do osso** (~20% do maior membro medido) para ele **aparecer e poder receber dano**. Vale só para `PART_*` (membros sem vértices seguem sem collider).

- **Robô sem cabeça:** o rig do RedRobot não tem osso de cabeça padrão; usa `head_bone_names = ["mouth_eyes", "L-EYE", "R-EYE"]` para forçar a CABEÇA (rosto + olhos — os olhos, excluídos por "eye", entram p/ a esfera não ficar minúscula; 2026-06-18). Player tem os 6 grupos; enemy também resolve 6 (com o forçado).

- **Sub-membros (peças salientes):** ossos que recebem um collider PRÓPRIO (caixa) ajustado só aos seus vértices, em vez de serem absorvidos por um membro. Para peças SALIENTES que a cápsula do membro não cobriria — ex.: as **placas traseiras das pernas** do red_robot (`L-/R-RearLegGuard`). Internamente viram um grupo único `PART_<osso>` (reaproveita todo o pipeline), com shape **caixa**. O conjunto efetivo (`_sub_member_set`) é a UNIÃO de 3 fontes (`_resolve_sub_members`): `standalone_part_bones` (export) + `LimbConfig.sub_members(model_key)` + `_classifier.default_sub_members()`. `_classify()` intercepta esses ossos ANTES do classificador normal, então não poluem o membro vizinho. O red_robot **não usa mais** o export — as placas migraram p/ `limb_config.json` e são editáveis na tela (ver [[🩸 dano-localizado (PT)|🩸 dano-localizado]]).

- **Subdivisão AUTOMÁTICA das extremidades (2026-07-23):** `_classify()` passou a interceptar em **DOIS** casos, sempre ANTES do classificador de membro — (a) sub-membro **EXPLÍCITO** (`_sub_member_set`, as 3 fontes acima) e (b) **DISTAL automático**, via `_classifier.is_distal_sub_member(bone)` quando `auto_distal_sub_members` está ligado (antebraço/mão/canela/pé; ver [[🦴 body-parts-gd (PT)|🦴 body-parts-gd]]). O membro-**DONO** (só p/ HERANÇA de dano) é resolvido depois, em `_build_member_shape`: primeiro a escolha EXPLÍCITA salva (`LimbConfig.sub_member_owner`) e, na falta, `resolve_sub_member_owner` (`owner_hint` do próprio nome → sobe a hierarquia de ossos). Assim a mão herda o dano do BRAÇO e o pé o da PERNA, mas cada extremidade tem **hitbox e multiplicador próprios**. **OPT-OUT:** `player.gd` e `red_robot.gd` setam `auto_distal_sub_members = false` p/ manter o hitbox de BRAÇO/PERNA **INTEIRO** já ajustado; `models.gd` espelha o opt-out no preview (`_MODEL_NO_AUTO_DISTAL`), para a tela Models mostrar exatamente os mesmos membros do jogo.

---

## Refit em tempo real (preview da tela Models)

`refit(skel, max_groups = 0)` re-encaixa os colliders de membro/sub-membro à **pose ANIMADA atual** (o `BoneAttachment3D` já dá translação/rotação; o refit reajusta o **VOLUME** da caixa à dobra). A 1ª chamada monta o **cache de skinning** (`_build_refit_cache`, custo único — é lá que roda o caro `surface_get_arrays`); depois só se leem as poses ATUAIS dos ossos.

**Otimizações de 2026-07-23** (o refit era o que derrubava o FPS na tela Models):

- **Grupos INVARIANTES pulados (`_rc_dyn`).** O AABB de um grupo é calculado no espaço **LOCAL do seu osso-raiz**: `p = inv(gpose[raiz]) * gpose[osso] * bv`. Num grupo de **UM ÚNICO osso**, raiz == osso, os termos se cancelam e sobra `p = bv` — o AABB é **CONSTANTE**, independente da pose (o collider já acompanha o osso via `BoneAttachment3D`). Com a subdivisão, **13 de 14 grupos** viraram de osso único (só o **TRONCO** = quadril + peito é dinâmico), então refitar todos era recalcular o mesmo valor. Agora `_rc_dyn` lista só os grupos com **2+ ossos** e o refit percorre apenas eles.
- **RODÍZIO (`max_groups`).** Com `max_groups > 0`, cada chamada processa só esse tanto de grupos, avançando `_refit_cursor` até dar a volta. `models.gd` chama **todo frame** com `REFIT_GROUPS_PER_FRAME = 3` — substitui o antigo **throttle adaptativo**, que refazia tudo de uma vez a cada ~190 ms e causava engasgo. `0` (padrão) = todos de uma vez, como antes.
- **Cache ORDENADO por grupo (counting sort).** `_build_refit_cache` passou a ordenar os vértices por grupo via **counting sort**, guardando o intervalo contíguo de cada um em `_rc_gstart`/`_rc_gcount` — é o que permite refitar um **SUBCONJUNTO** de grupos sem varrer o cache inteiro. (O antigo `_rc_group`, um índice de grupo por vértice, deixou de existir.)
	- ⚠️ **Armadilha do GDScript** que motivou o counting sort: um `Packed*Array` guardado **DENTRO** de um `Array` vem **COPIADO** ao ser lido — acumular em "baldes" por grupo não funciona, os `append` se perdem **silenciosamente**.
- **Gizmo sob demanda.** `shape.get_debug_mesh()` **GERA** geometria a cada chamada; no refit ele só é chamado quando o gizmo está `is_visible_in_tree()`. Um gizmo escondido é atualizado no primeiro refit depois de reaparecer (defasagem máxima = um intervalo de refit).

**Ganho medido (humanoide):** 6,45 ms → 1,89 ms (após o cache de `LimbConfig`) → **0,318 ms por frame** (~1,9% de um frame de 60 FPS). O player, em opt-out da subdivisão, fica em **0,612 ms** com 6 grupos dinâmicos.

---

## Detecção (física, nativa)

- **Bullet → membro:** `bullet.gd` usa `move_and_collide`; ao acertar um collider de membro, `_apply_hit` lê `damage_multiplier`/`character` e aplica `character.hit.rpc(round(weapon_damage * mult))`. Fallback de corpo (capsule) = `1×`. O atirador exclui os próprios colliders (`player._exclude_own_limbs`).
- **Laser do enemy → membro do player:** `red_robot._damage_player` faz raycast com `collide_with_bodies = true` na layer 16.
- `bullet.tscn collision_mask = 51` (mundo/corpos `3` + membros `16` + `32`).

---

## Exports

| Export | Player / Enemy | Descrição |
|---|---|---|
| `enabled` | `true` | Liga/desliga a geração |
| `body_type` | `"biped"` | Plano corporal (`@export_enum` biped/quadruped/crawler) → classificador via `BodyPlans.for_type` (ver [[🦴 body-parts-gd (PT)|🦴 body-parts-gd]]) |
| `padding` | `0.03` | Folga (m) somada a cada lado da caixa |
| `head_bone_names` | `[] / ["mouth_eyes", "L-EYE", "R-EYE"]` | Bones forçados para CABEÇA |
| `head_shape` | `"capsule" (player) / "sphere"` | Forma do collider da CABEÇA (`@export_enum` sphere/capsule) |
| `head_scale` | `1.0 / 1.3` | Fator de escala do VOLUME da cabeça (red_robot = 1.3, headshot maior) — escala o AABB em torno do centro (2026-06-21) |
| `torso_shape` | `"box" / "sphere"` | Forma do collider do TRONCO (`@export_enum` box/sphere; red_robot = esfera) (2026-06-21) |
| `torso_bone_names` | `[] / ["Bone.001"]` | Bones forçados para TRONCO (osso genérico do enemy) |
| `leg_bone_names` | `[]` | Bones forçados para PERNA E/D |
| `standalone_part_bones` | `[] / []` | Sub-membros FIXOS no nó (collider PRÓPRIO) — UNIDOS aos de `LimbConfig` + do plano. O red_robot **não usa mais** (placas migraram p/ `limb_config.json`) |
| `hitbox_layer` | `16 / 32` | Layer dos colliders (player bit5, enemy bit6) |
| `model_key` | `"player" / "red_robot"` | Chave (nome da pasta) p/ buscar multiplicadores + sub-membros em [[🩸 dano-localizado (PT)\|LimbConfig]]; vazio = defaults do plano |
| `include_suppressed` | `false` (`true` só no preview da tela Models) | True: SUB-MEMBROS `SHAPE_NONE` ("Selecione...") ainda são construídos (forma auto, meta `suppressed`, sem gizmo) p/ ficarem na árvore/dropdown e poderem ser reconfigurados. False (gameplay): pulados, sem hitbox (2026-06-25) |
| `auto_distal_sub_members` | `false / false` (opt-out; **default `true`**) | Subdivisão AUTOMÁTICA das extremidades: antebraço/mão e canela/pé viram SUB-MEMBROS próprios (`PART_<osso>`, collider + dano localizados, herdando o BRAÇO/PERNA quando sem valor próprio) em vez de serem absorvidos no membro grande. Ligado por padrão (modelos novos); player/red_robot fazem opt-out p/ manter o hitbox INTEIRO já ajustado (2026-07-23) |

---

## Instanciação (por código)

`player.gd._setup_limb_colliders()` e `red_robot.gd._setup_limb_colliders()`:
```gdscript
var skel = <model>.get_node_or_null(^".../Skeleton3D") as Skeleton3D
var lc = preload("res://effects_shared/limb_colliders.gd").new()
lc.name = "LimbColliders"
lc.body_type = "biped"   # plano corporal → classificador (BodyPlans.for_type)
lc.model_key = "player"   # "red_robot" no enemy — chave dos multiplicadores/sub-membros em LimbConfig
lc.hitbox_layer = 16   # 32 no enemy
lc.auto_distal_sub_members = false   # opt-out: BRAÇO/PERNA INTEIROS (hitbox já ajustado)
add_child(lc)
lc.build_for(skel)   # resolve _classifier (body_type) + _sub_member_set (3 fontes)
```
Construídos em todos os peers (só o servidor simula os tiros). `get_limb_bodies()` lista os `StaticBody3D` criados (usado para excluir os próprios da colisão do projétil disparado).

> [!note] Override de FORMA + supressão por grupo (2026-06-25)
> `make_member_shape(group, aabb, head_kind, torso_kind, head_scale, shape_override="")` ganhou o
> param **`shape_override`**: `"sphere"/"box"/"capsule"` FORÇA a forma daquele grupo sobre a automática
> (a CABEÇA em cápsula mantém o raio cheio). `build_for`/`_build_member_shape`/`refit` leem
> `LimbConfig.collider_shape(model_key, group)` e passam o override; e `build_for` **pula** os grupos
> cujo `collider_shape == LimbConfig.SHAPE_NONE` (`"none"`) → o membro/sub-membro fica **sem collider**
> (exceto SUB-MEMBROS no preview da tela Models, via `include_suppressed` — ver tabela). Tudo
> escolhido na tela Models (dropdown de geometria à direita de Membro/Sub-membro/Esqueleto) e relido
> aqui no spawn. O caminho sem-esqueleto (`models.gd._add_mesh_member_colliders`) honra os mesmos
> dois. Ver [[🗿 biblioteca-de-modelos (PT)|🗿 biblioteca-de-modelos]] e [[🩸 dano-localizado (PT)|🩸 dano-localizado]].

- Player skeleton: `PlayerModel/Robot_Skeleton/Skeleton3D` (playera herda de Player)
- Enemy skeleton: `RedRobotModel/Armature/Skeleton3D`

---

## Caminho: `effects_shared/limb_colliders.gd`

---

## Relacionado

- [[🩸 dano-localizado (PT)|🩸 dano-localizado]]
- [[🦴 body-parts-gd (PT)|🦴 body-parts-gd]]
- [[🗿 biblioteca-de-modelos (PT)|🗿 biblioteca-de-modelos]]
- [[🎮 player (PT)|🎮 player]]
- [[🤖 inimigos (PT)|🤖 inimigos]]
- [[🎮 player-gd (PT)|🎮 player-gd]]
- [[🤖 red-robot-gd (PT)|🤖 red-robot-gd]]
- [[💥 bullet-gd (PT)|💥 bullet-gd]]

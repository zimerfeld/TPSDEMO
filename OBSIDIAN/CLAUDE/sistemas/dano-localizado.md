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

| Grupo | Forma | Multiplicador |
|---|---|---|
| **CABEÇA** (head/neck) | `SphereShape3D` | `1.5` (+50%) |
| **TRONCO** (hips/spine/chest/body) | `BoxShape3D` | `1.0` |
| **BRAÇO D/E** (shoulder/arm/forearm/hand/**wing** + lado) | `CapsuleShape3D` (eixo longo) | `1.0` |
| **PERNA D/E** (thigh/shin/knee/foot/leg + lado) | `CapsuleShape3D` (eixo longo) | `1.0` |

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

---

## Tuning no inspector (nó do personagem)

Em `limb_colliders.gd` (nó `LimbColliders`): `enabled`, `padding`, `head_bone_names`
(`["mouth_eyes", "L-EYE", "R-EYE"]` no enemy), `torso_bone_names` (força um osso de nome genérico para
TRONCO — `["Bone.001"]` no red_robot, cujo corpo não era reconhecido e ficava **sem
collider de tronco**), `hitbox_layer` (16 player / 32 enemy). Os exports de cor/raio
do antigo sistema de vidro foram removidos.

> Verificado via MCP do Godot ([[godot-mcp]]): laser do enemy aplica 25 (arma),
> lookup de hitbox funcional, cache não causa mais dano no início, sem erros.

---

## Relacionado

- [[sistemas/combate-tiro]]
- [[sistemas/sistema-de-vida]]
- [[arquivos-chave/limb-colliders-gd]]
- [[arquivos-chave/bullet-gd]]
- [[arquivos-chave/red-robot-gd]]
- [[arquivos-chave/enemy-health-bar-gd]]

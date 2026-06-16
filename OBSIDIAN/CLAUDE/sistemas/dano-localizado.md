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
Fallback: se o bullet acerta o CORPO (capsule) sem um membro → dano de TRONCO (1x)
          no mesmo _apply_hit (idempotente com _registered)
```

O atirador exclui os próprios colliders de membro do projétil (`player._exclude_own_limbs`)
para o tiro não nascer acertando o próprio braço/arma.

## Fluxo do dano (enemy → player)

`red_robot.shoot()` (server): roll de precisão → `_damage_player()` lança um raio
contra os colliders de membro do player (bit5, `collide_with_bodies`) → multiplicador do membro →
`player.hit.rpc(weapon_damage * mult)`.

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
(`["mouth_eyes"]` no enemy), `torso_bone_names` (força um osso de nome genérico para
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

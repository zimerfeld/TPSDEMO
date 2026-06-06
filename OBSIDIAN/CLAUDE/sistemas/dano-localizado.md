# Sistema de Dano por Arma + Hitboxes Localizadas

> Implementado em 2026-06-06. Substitui o dano fixo por dano da **arma** do atacante,
> com **hitboxes funcionais Area3D** por grupo de membro e **dano localizado**.

---

## Dano atribuído à arma

| Personagem | `weapon_damage` (export) | Observação |
|---|---|---|
| Player | `50` | Atribuído a cada bullet disparado (`bullet.weapon_damage = weapon_damage`) |
| Enemy (Red Robot) | `25` | Aplicado ao player pelo laser |

`hit(amount: int)` agora recebe o valor de dano (antes era fixo).

---

## Grupos de hitbox (exibidos)

`effects_shared/glass_hitboxes.gd` classifica ossos em grupos e cria **uma Area3D por osso**, marcada com grupo + multiplicador:

| Grupo | Multiplicador | Dano |
|---|---|---|
| **CABEÇA** (head/neck) | `1.5` | +50% |
| **TRONCO** (hips/spine/chest/body) | `1.0` | dano da arma |
| **BRAÇO D/E** (shoulder/arm/forearm/hand + lado) | `1.0` | dano da arma |
| **PERNA D/E** (thigh/shin/knee/foot/leg + lado) | `1.0` | dano da arma |

Lado detectado por sufixo `.L/.R` (player) ou prefixo `L-/R-` (enemy).

---

## Camadas de colisão

| Bit | Valor | Uso |
|---|---|---|
| bit4 | `8` | Projétil (bullet) — `collision_layer` do bullet |
| bit5 | `16` | Hitboxes do **player** |
| bit6 | `32` | Hitboxes do **enemy** |

- Bullet mantém `mask = 3` (física do mundo/corpos **inalterada**); ganhou `layer = 8` só para ser detectável pelas áreas.
- Áreas: `monitoring=true`, `mask = 8` (detectam o bullet).

---

## Fluxo do dano (player → enemy)

```
bullet (server) entra numa Area3D de membro do enemy
  → Area3D.body_entered → glass_hitboxes._on_hitbox_body_entered
      → ignora se body.shooter == dono (sem auto-dano)
      → bullet.register_hit(enemy, multiplicador)
          → enemy.hit.rpc(round(weapon_damage * multiplicador))   [server]
          → bullet explode
Fallback: se o bullet acerta o CORPO sem área específica → dano de TRONCO (1x)
          via bullet._fallback_body_damage (deferido; idempotente com _registered)
```

`collision_shape.set_deferred("disabled")` mantém a shape ativa no frame para a área registrar.

## Fluxo do dano (enemy → player)

`red_robot.shoot()` (server): roll de precisão → `_damage_player()` lança um raio
contra as hitboxes do player (bit5, `collide_with_areas`) → multiplicador do membro →
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

Em **Player** e **RedRobot** (grupo "Glass Hitboxes"): `hitbox_color`, `hitbox_radius`,
`hitbox_head_radius` — repassados ao `GlassHitboxes`. Também em `glass_hitboxes.gd`:
`glass_color`, `radius`, `head_radius`, `min_bone_length`, `hitbox_layer`, `detect_layer`.

> Verificado via MCP do Godot ([[godot-mcp]]): laser do enemy aplica 25 (arma),
> lookup de hitbox funcional, cache não causa mais dano no início, sem erros.

---

## Relacionado

- [[sistemas/combate-tiro]]
- [[sistemas/sistema-de-vida]]
- [[arquivos-chave/glass-hitboxes-gd]]
- [[arquivos-chave/bullet-gd]]
- [[arquivos-chave/red-robot-gd]]
- [[arquivos-chave/enemy-health-bar-gd]]

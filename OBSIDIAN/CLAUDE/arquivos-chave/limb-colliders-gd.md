# effects_shared/limb_colliders.gd

**Renomeado de `glass_hitboxes.gd` em:** 2026-06-14 · **Estende:** `Node3D`

---

## Responsabilidades

- Gerar **colliders 3D nativos** (`StaticBody3D` + `CollisionShape3D`) por **grupo de membro** de um `Skeleton3D`
- Cada membro → `BoneAttachment3D → StaticBody3D (BoxShape3D)`, preso ao **osso-raiz** (acompanha pose/animação)
- Os projéteis colidem **fisicamente** com esses corpos e o laser do enemy os atinge por **raycast contra corpos** → **dano localizado** ao personagem dono
- Cabeça = +50% de dano (multiplicador `1.5`); demais grupos = dano da arma (`1.0`)
- **Sem Area3D, sem visual de vidro, sem labels** (substituiu o antigo sistema de "hitboxes de vidro")
- Ver [[sistemas/dano-localizado]]

---

## Como funciona (posicionamento por vértices skinados)

1. Classifica os ossos em grupos (CABEÇA/TRONCO/BRAÇO E-D/PERNA E-D) via `BodyParts.group_of` (`effects_shared/body_parts.gd`)
2. Escolhe o **osso-raiz** de cada grupo (o mais raso na hierarquia)
3. Para cada **vértice skinado** da malha, pega o osso de maior peso e o converte ao espaço local do osso-raiz usando a **bind pose** da skin (`get_bind_pose`) → acumula um **AABB por membro** (+ `padding` de folga)
4. Cria `BoneAttachment3D` (no osso-raiz) → `StaticBody3D` + `CollisionShape3D (BoxShape3D)` do tamanho do AABB
5. Metas no `StaticBody3D`: `group`, `damage_multiplier`, `character` (dono)

- **Robô sem cabeça:** o rig do RedRobot não tem osso de cabeça padrão; usa `head_bone_names = ["mouth_eyes", "L-EYE", "R-EYE"]` para forçar a CABEÇA (rosto + olhos — os olhos, excluídos por "eye", entram p/ a esfera não ficar minúscula; 2026-06-18). Player tem os 6 grupos; enemy também resolve 6 (com o forçado).

- **Peças standalone (`standalone_part_bones`, 2026-06-18):** ossos que recebem um collider PRÓPRIO (caixa) ajustado só aos seus vértices, em vez de serem absorvidos por um membro. Para peças SALIENTES que a cápsula do membro não cobriria — ex.: as **placas traseiras das pernas** do red_robot (`L-/R-RearLegGuard`), que ficam atrás da perna. Internamente viram um grupo único `PART_<osso>` (reaproveita todo o pipeline), com shape **caixa**, multiplicador `1.0` e rótulo `PLACA PERNA E/D` (lado via `BodyParts.side_of`). `_classify()` intercepta esses ossos ANTES do classificador normal, então não poluem o membro vizinho.

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
| `padding` | `0.03` | Folga (m) somada a cada lado da caixa |
| `head_bone_names` | `[] / ["mouth_eyes", "L-EYE", "R-EYE"]` | Bones forçados para CABEÇA |
| `torso_bone_names` | `[] / ["Bone.001"]` | Bones forçados para TRONCO (osso genérico do enemy) |
| `leg_bone_names` | `[]` | Bones forçados para PERNA E/D |
| `standalone_part_bones` | `[] / ["L-RearLegGuard", "R-RearLegGuard"]` | Bones com collider PRÓPRIO (caixa) — placas salientes |
| `hitbox_layer` | `16 / 32` | Layer dos colliders (player bit5, enemy bit6) |

---

## Instanciação (por código)

`player.gd._setup_limb_colliders()` e `red_robot.gd._setup_limb_colliders()`:
```gdscript
var skel = <model>.get_node_or_null(^".../Skeleton3D") as Skeleton3D
var lc = preload("res://effects_shared/limb_colliders.gd").new()
lc.name = "LimbColliders"
lc.hitbox_layer = 16   # 32 no enemy
add_child(lc)
lc.build_for(skel)
```
Construídos em todos os peers (só o servidor simula os tiros). `get_limb_bodies()` lista os `StaticBody3D` criados (usado para excluir os próprios da colisão do projétil disparado).

- Player skeleton: `PlayerModel/Robot_Skeleton/Skeleton3D` (playera herda de Player)
- Enemy skeleton: `RedRobotModel/Armature/Skeleton3D`

---

## Caminho: `effects_shared/limb_colliders.gd`

---

## Relacionado

- [[sistemas/player]]
- [[sistemas/inimigos]]
- [[arquivos-chave/player-gd]]
- [[arquivos-chave/red-robot-gd]]
- [[arquivos-chave/bullet-gd]]

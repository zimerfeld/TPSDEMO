# effects_shared/glass_hitboxes.gd

**Criado em:** 2026-06-06 · **Atualizado:** hitboxes funcionais  
**Estende:** `Node3D`

---

## Responsabilidades

- Gerar **hitboxes funcionais com visual de vidro** por **grupo de membro** de um `Skeleton3D`
- Cada osso-membro → `BoneAttachment3D → Area3D (CollisionShape3D) + MeshInstance3D`
- As áreas detectam o **bullet** e aplicam **dano localizado** ao personagem dono
- Cabeça = +50% de dano; demais grupos = dano da arma
- Ver [[sistemas/dano-localizado]]

---

## Como funciona

1. Itera os ossos do `Skeleton3D`
2. Filtra por **nome** → grupo (CABEÇA/TRONCO/BRAÇO D-E/PERNA D-E)
3. Para cada osso-membro, usa o **maior segmento osso→filho** como direção/comprimento
4. Cria `BoneAttachment3D` (ligado ao osso) → `Area3D` (CollisionShape3D capsule) + `MeshInstance3D` de vidro
5. **Um `Label3D` por grupo** identifica o membro (CABEÇA, TRONCO, BRAÇO E/D, PERNA E/D)

## Volume, orientação e labels

- **Volume proporcional:** `raio = clamp(comprimento × radius_factor, radius, max_radius)`
  → cobre membros grandes (ex.: tronco/braços do robô). Cabeça usa `head_radius`.
- **Orientação:** a cápsula é alinhada à direção do osso e o `BoneAttachment3D` faz
  o hitbox **acompanhar o ângulo e o movimento** da mesh animada.
- **Label3D:** billboard, `no_depth_test`, `fixed_size`; um por grupo, no centro do membro.
- **Robô sem cabeça:** o rig do RedRobot não tem osso de cabeça (só olhos, excluídos),
  então o enemy tem TRONCO + 2 braços + 2 pernas (5 grupos); o player tem os 6.

### Filtro de nome
- **LIMB_KEYWORDS:** hips, pelvis, spine, chest, torso, body, neck, head, shoulder,
  upper_arm, forearm, hand, thigh, shin, calf, knee, foot, leg, arm
- **EXCLUDE_KEYWORDS:** ik, scaler, piston, pad, cover, guard, cable, flap, dongle,
  sight, mod, slider, rotator, orient, control, target, master, empty, eye, mouth,
  track, extender, recoil, booster, fuel, plate, heel, toe, core, aim, dead

> O rig do player tem **145 ossos** e o do enemy **64** — com dedos, IK, pistões etc.
> O filtro mantém só os membros grandes: ~26 cápsulas (player) / ~11 (enemy),
> com **6 labels** (player) e **5 labels** (enemy, sem cabeça).

---

## Exports (repassados pelo nó do personagem, ajustáveis no inspector)

| Export | Player / Enemy | Descrição |
|---|---|---|
| `enabled` | `true` | Liga/desliga a geração |
| `radius` | `0.1 / 0.15` | Raio mínimo |
| `radius_factor` | `0.4 / 0.45` | Fração do comprimento usada como raio (volume proporcional) |
| `max_radius` | `0.22 / 0.7` | Raio máximo |
| `head_radius` | `0.16 / 0.25` | Raio da cabeça |
| `glass_color` | azul / vermelho | Cor + transparência (alpha) |
| `min_bone_length` | `0.05` | Ignora segmentos menores |
| `show_labels` | `true` | Exibe Label3D por grupo |
| `label_color` / `label_pixel_size` | branco / `0.0009` | Estilo dos labels |
| `hitbox_layer` / `detect_layer` | `16(32) / 8` | Camadas (player bit5, enemy bit6) |

---

## Material de vidro

`StandardMaterial3D`: `TRANSPARENCY_ALPHA`, roughness `0.05`, `metallic_specular 0.95`,
`rim_enabled` (0.9), `cull_mode = DISABLED` (vê as duas faces).

---

## Instanciação (por código)

`player.gd._setup_glass_hitboxes()` e `red_robot.gd._setup_glass_hitboxes()`:
```gdscript
var skel = <model>.get_node_or_null(^".../Skeleton3D") as Skeleton3D
var gh = preload("res://effects_shared/glass_hitboxes.gd").new()
gh.name = "GlassHitboxes"
add_child(gh)
gh.build_for(skel)
```
Guardado por `DisplayServer.get_name() != "headless"` (servidor não monta visual).

- Player skeleton: `PlayerModel/Robot_Skeleton/Skeleton3D`
- Enemy skeleton: `RedRobotModel/Armature/Skeleton3D`

---

## Caminho: `effects_shared/glass_hitboxes.gd`

---

## Relacionado

- [[sistemas/player]]
- [[sistemas/inimigos]]
- [[arquivos-chave/player-gd]]
- [[arquivos-chave/red-robot-gd]]

# Sistema de Combate e Tiro

---

## Componentes

| Arquivo | Papel |
|---|---|
| `library3D/characters/players/player/player.gd` | Instancia a bala, dispara RPC `shoot()` |
| `library3D/characters/player/bullet/bullet.gd` | Física da bala, detecção de colisão, chama `hit.rpc()` |
| `library3D/characters/player/bullet/bullet.tscn` | Cena da bala: CharacterBody3D + AnimationPlayer + OmniLight |

---

## Ciclo de Tiro

1. `player_input.shooting` (Input capturado no cliente local)
2. Servidor verifica `fire_cooldown.time_left == 0`
3. Servidor instancia `bullet.tscn`, posiciona em `ShootFrom`, aplica direção
4. `shoot.rpc()` → `call_local` → partículas + flash + som + camera shake (trauma 0.35)

### Direção do Tiro
```gdscript
var ray_from = camera.project_ray_origin(crosshair_center)
var ray_dir  = camera.project_ray_normal(crosshair_center)
# Raio de 1000 unidades; colisão → shoot_target = col.position
# Sem colisão → shoot_target = ray_from + ray_dir * 1000
```

> 🐞 **Bug "bala torta" no aim→tiro muito rápido (corrigido):** a bala sai de `shoot_from` (cano,
> preso ao `player_model`). Ao mirar, o corpo girava p/ a câmera via **slerp lento**
> (`ROTATION_INTERPOLATE_SPEED`); num aim→tiro em 1-2 frames o cano ainda apontava p/ a direção
> ANTIGA enquanto o `shoot_target` já era o da câmera → direção errada. **Fix** (`player.gd`,
> branch de mira): no **aim-enter** (`_was_aiming` false → true) o corpo é **alinhado à câmera na
> hora** (`orientation.basis = Basis(q_to)` + atualiza já o `player_model`), sem slerp, antes do
> teste de disparo. Frames seguintes seguem com slerp normal.

---

## Bala (`bullet.gd`)

| Propriedade | Valor |
|---|---|
| Velocidade | `20.0` u/s |
| Tempo de vida | `5.0` s |
| Processamento de física | Apenas no **servidor** |
| Colisão de cliente | Desabilitada (`disabled = true`) |

### Ao colidir
```gdscript
if collider.has_method("hit"):
    collider.hit.rpc()   # atinge qualquer nó com método hit()
collision_shape.disabled = true
explode.rpc()
```

---

## Cooldown de Tiro

- `FireCooldown` Timer: **0.4 s**, auto-start
- Verificado em `apply_input()`: `fire_cooldown.time_left == 0`

---

## Aparência da bala (bolinha)

- A **bolinha visível** = `MeshInstance3D` (SphereMesh, escala **0.13**) com material `StandardMaterial3D_ffosa`:
  **unshaded + azul HDR** `Color(0.14902, 0.74902, 1.50196)` (canal azul > 1 → "estoura" no glow). Antes era branco sem cor e dependia 100% do glow do cenário; agora é azul vistoso mesmo **sem** bloom.
- Cor extra vem da `OmniLight3D` azul + rastro de partículas (`BulletBody/MainBody`, `Trail`).
- `CannonShooter.fire(...)` aceita `tint`/`ball_color`/`ball_scale` (alpha 0 = mantém o visual autorado, o tiro azul do player); `bullet.gd._apply_visuals()` aplica em todos os peers.
- ⚠️ O efeito "orbe brilhante" depende de **glow/bloom** do `Environment`. Só o `level_base` tinha glow afinado ([environment.tres](library3D/geometry/environment.tres)); `level_1`/`level_2` ganharam `glow_enabled` + `glow_hdr_threshold=0.9` + `glow_intensity` inline para a bala florescer igual. O setting "bloom" (`config.gd`) liga/desliga `glow_enabled` em runtime.

---

## Ponto de Spawn da Bala

- `ShootFrom`: `Marker3D` em `Robot_Skeleton/Skeleton3D/GunBone/ShootFrom`
- Offset: `(0, 0.4, 0)` relativo ao osso do cano

---

## Camera Shake

| Evento | Trauma |
|---|---|
| Atirar | `0.35` |
| Ser atingido | `0.75` |

---

## Relacionado

- [[sistemas/player]]
- [[sistemas/sistema-de-vida]]
- [[arquivos-chave/bullet-gd]]

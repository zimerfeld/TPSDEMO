# Sistema de Combate e Tiro

---

## Componentes

| Arquivo | Papel |
|---|---|
| `player/player.gd` | Instancia a bala, dispara RPC `shoot()` |
| `player/bullet/bullet.gd` | Física da bala, detecção de colisão, chama `hit.rpc()` |
| `player/bullet/bullet.tscn` | Cena da bala: CharacterBody3D + AnimationPlayer + OmniLight |

---

## Ciclo de Tiro

1. `player_input.shooting == true` (Input capturado no cliente local)
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

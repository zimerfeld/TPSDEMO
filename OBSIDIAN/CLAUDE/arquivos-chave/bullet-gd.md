# library3D/characters/player/bullet/bullet.gd

**Estende:** `CharacterBody3D`

---

## Responsabilidades

- Mover a bala em linha reta (`-transform.basis.z`)
- Detectar colisão e chamar `hit.rpc()` no alvo
- Auto-destruir após `5.0 s` ou ao colidir
- Tocar animação de explosão

---

## Constantes

```gdscript
const BULLET_VELOCITY: float = 20.0
var time_alive: float = 5.0
```

---

## Processamento

- Física roda **apenas no servidor** (`set_physics_process(false)` em clientes)
- Colisão **desabilitada em clientes** (`collision_shape.disabled = true`)

```gdscript
func _physics_process(delta):
    var col = move_and_collide(-delta * BULLET_VELOCITY * transform.basis.z)
    if col:
        if collider.has_method("hit"):
            collider.hit.rpc()
        explode.rpc()
```

---

## RPCs

| RPC | Modo | O que faz |
|---|---|---|
| `explode()` | `call_local` | Toca animação "explode", liga shadow no OmniLight |

---

## Dano por arma + localizado (atualizado)

- `weapon_damage` (atribuído pelo atirador), `shooter` (evita auto-dano), `_registered` (idempotente)
- `_apply_hit(collider)` — no `move_and_collide`: lê metas `damage_multiplier`/`character` do collider de membro → `character.hit.rpc(round(weapon_damage*mult))`
- Fallback de TRONCO (1x) no mesmo `_apply_hit` se acertou o corpo (capsule) sem um membro
- `collision_layer = 8` (bit4); `mask = 51` (mundo/corpos `3` + membros `16` + `32`) para colidir com os membros
- **Inerte se `shooter == null`** (cobre o `BulletCache` da cena e bullets em clientes)
- Ver [[sistemas/dano-localizado]]

---

## Relacionado

- [[sistemas/combate-tiro]]
- [[sistemas/dano-localizado]]
- [[fluxos/fluxo-de-tiro]]

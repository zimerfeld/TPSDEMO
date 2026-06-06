# player/bullet/bullet.gd

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
- `register_hit(target, mult)` — chamado por uma Area3D de membro → `target.hit.rpc(weapon_damage*mult)`
- `_fallback_body_damage` — dano de TRONCO (1x) se acertou o corpo sem área específica
- `collision_layer = 8` (bit4) para ser detectado pelas hitboxes; `mask = 3` inalterada
- **Inerte se `shooter == null`** (cobre o `BulletCache` da cena e bullets em clientes)
- Ver [[sistemas/dano-localizado]]

---

## Relacionado

- [[sistemas/combate-tiro]]
- [[sistemas/dano-localizado]]
- [[fluxos/fluxo-de-tiro]]

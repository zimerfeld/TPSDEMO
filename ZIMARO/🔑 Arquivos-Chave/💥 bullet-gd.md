---
tipo: arquivo-chave
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-07-04
---

# 💥 library3D/characters/player/bullet/bullet.gd

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
- Fallback de TRONCO (1x) no mesmo `_apply_hit` se acertou um corpo com `hit()` sem metas de membro
- **Pass-through do corpo do personagem (2026-06-18):** se o `move_and_collide` acerta um
  `CharacterBody3D` que tem o nó `LimbColliders` (player/enemy), a bala adiciona uma
  `add_collision_exception_with(corpo)` e **continua voando** — assim o tiro atravessa a cápsula/esfera
  genérica do corpo e atinge o collider de MEMBRO atrás dela (dano localizado de verdade, com headshot).
  Sem isso, a esfera de corpo do red_robot (raio ~1,12 m) interceptava todo tiro → sempre 1×.
- `collision_layer = 8` (bit4); `mask = 51` (mundo/corpos `3` + membros `16` + `32`) para colidir com os membros
- **Aparência configurável (2026-06-18):** `tint` (cor do efeito: luz + rastro), `ball_color` (cor da bola), `ball_scale` (tamanho) — sentinela alpha 0 = "não mexer" (mantém o tiro azul do player). Aplicados em `_apply_visuals()` no `_ready`. O **`CannonShooter`** (`effects_shared/cannon_shooter.gd`) instancia e configura o bullet; usado por player (azul) e red_robot (bola preta + efeito vermelho). Ver [[🩸 dano-localizado]].
- **Inerte se `shooter == null`** (cobre o `BulletCache` da cena e bullets em clientes)
- Ver [[🩸 dano-localizado]]

---

## Relacionado

- [[🔫 combate-tiro]]
- [[🩸 dano-localizado]]
- [[🎯 fluxo-de-tiro]]

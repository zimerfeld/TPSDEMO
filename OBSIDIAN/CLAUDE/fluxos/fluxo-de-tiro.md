# Fluxo de Tiro

---

## Diagrama Completo

```
[Cliente Dono]
  Input.is_action_pressed("shoot") → shooting = true
  Raycast da câmera → shoot_target = Vector3
        │
        │ [MultiplayerSynchronizer]
        ▼
[Servidor — apply_input()]
  shooting && fire_cooldown.time_left == 0
        │
        ▼
  bullet = bullet.tscn.instantiate()
  bullet.global_transform.origin = shoot_from.global_position
  bullet.look_at(shoot_origin + shoot_dir)
  get_parent().add_child(bullet, true)
  shoot.rpc()  ──────────────────────────────► [Todos os peers]
        │                                         partículas + flash + som
        │
        ▼ [bullet._physics_process — apenas servidor]
  move_and_collide(displacement)
        │
   colide? ──► collider.has_method("hit") ──► collider.hit.rpc()
        │                                          │
        │                                   [Todos os peers]
        │                                    hit() executa:
        │                                    - hp -= 25
        │                                    - HUD atualiza
        │                                    - camera shake 0.75
        │                                    - se hp==0 → respawn.rpc()
        ▼
  explode.rpc() ──► animação de explosão
  bullet.destroy() após animação [apenas servidor]
```

---

## Condições de Tiro (Servidor)

```gdscript
if player_input.shooting and fire_cooldown.time_left == 0:
    # instancia bala
```

- `fire_cooldown` é um `Timer` de **0.4 s** no player
- A bala tem exceção de colisão com o próprio player (`add_collision_exception_with(self)`)

---

## O que Pode Receber Hit

Qualquer nó com método `hit()`:
- **Player** — decrementa HP, camera shake, respawn se necessário
- **Red Robot** — decrementa `health`, anima hit, morte se `health == 0`

---

## Relacionado

- [[sistemas/combate-tiro]]
- [[sistemas/sistema-de-vida]]
- [[arquivos-chave/bullet-gd]]
- [[arquivos-chave/player-gd]]

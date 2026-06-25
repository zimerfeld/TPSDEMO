# Fluxo de Tiro

---

## Diagrama Completo

```
[Cliente Dono]
  Input.is_action_pressed("shoot") → shooting = true
  Raycast da câmera (exclui corpo/membros do próprio atirador + ignora acerto colado < 3 m) → shoot_target
        │
        │ [MultiplayerSynchronizer]
        ▼
[Servidor — apply_input()]
  shooting && fire_cooldown.time_left == 0
        │
        ▼
  shoot_dir degenerado (alvo < 0.5 m)? → usa -player_model.basis.z (rede; mira já corrigida no cliente)
  bullet = bullet.tscn.instantiate()
  bullet.transform = parent_inv * Transform3D(origin).looking_at(origin+dir)  # ANTES do add_child:
  get_parent().add_child(bullet, true)                                        # spawn replicado nasce no cano
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

## Correções de tiro online (2026-06-24)

- **Bala nascia FORA da arma no cliente:** o `global_transform` da bala é uma *spawn property*
  (`bullet.tscn`) e o `MultiplayerSpawner` tira o snapshot **no `add_child`**. O `cannon_shooter` setava
  a posição **depois** do `add_child` → o pacote de spawn levava a origem PADRÃO e a bala aparecia
  deslocada no cliente até o 1º sync. **Fix:** montar o transform do cano (`Transform3D(origin).looking_at(
  origin+dir)`, convertido p/ o espaço do `parent`) **ANTES** do `add_child`. `up` não-paralelo à direção
  cobre tiro vertical.
- **Tiro "pro céu" ao mirar-e-atirar rápido:** a raycast da mira (`player_input`) excluía só `[self]`
  (o synchronizer, que nem é corpo físico) → o raio, que parte de trás do ombro, acertava o **próprio
  corpo/cabeça** durante a transição de mira e punha o alvo logo acima do cano = tiro quase vertical.
  **Fix:** `_aim_ray_exclude()` exclui o **corpo + colliders de membro** do atirador e descarta acertos
  colados (`< MIN_AIM_DISTANCE` 3 m, usa o ponto distante na direção da câmera). No servidor, guarda extra:
  alvo degenerado (`< 0.5 m`) cai para `-player_model.basis.z`.

## Relacionado

- [[sistemas/combate-tiro]]
- [[sistemas/sistema-de-vida]]
- [[arquivos-chave/bullet-gd]]
- [[arquivos-chave/player-gd]]

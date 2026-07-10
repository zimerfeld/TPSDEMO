---
tipo: sistema
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-07-04
---

# 🔫 Sistema de Combate e Tiro

---

## Componentes

| Arquivo | Papel |
|---|---|
| `library3D/characters/players/player/player.gd` | Instancia a bala, dispara RPC `shoot()` |
| `library3D/characters/player/bullet/bullet.gd` | Física da bala, detecção de colisão, chama `hit.rpc()` |
| `library3D/characters/player/bullet/bullet.tscn` | Cena da bala: CharacterBody3D + AnimationPlayer + OmniLight |

---

## Ciclo de Tiro

1. `player_input.shooting` (Input capturado no cliente local, replicado ao servidor)
2. Servidor verifica `fire_cooldown.time_left == 0` **e** `_aim_held_time ≥ AIM_WARMUP_TIME` (mira assentada)
3. Servidor instancia `bullet.tscn`, posiciona em `ShootFrom`, aplica direção
4. `shoot.rpc()` → `call_local` → partículas + flash + som + camera shake (trauma 0.35)

> 🐞 **Bug "bala-fantasma presa no cano" no cliente (corrigido 2026-06-24):** `apply_input()` roda
> no servidor **e** na predição do cliente local. O bloco de tiro (e os RPCs `jump`/`land`/`shoot`)
> rodava nos dois → o cliente instanciava uma `bullet.tscn` LOCAL que, por não ser servidor, tinha
> `_physics_process` desligado e **não era replicada nem destruída** → ficava parada no cano "para
> sempre" (efeito que "não some"). **Fix** (`player.gd`): calcula `authoritative = is_server()` no
> topo do `apply_input` e gateia os efeitos autoritativos (spawn da bala + `shoot/jump/land.rpc()`)
> por ele. A predição de **movimento** (velocidade, `move_and_slide`, salto) continua local/responsiva;
> só o que é autoritativo passou a ser exclusivo do servidor. Offline (`OfflineMultiplayerPeer` =
> servidor) atira normalmente.

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

> 🎯 **Aquecimento de mira (`AIM_WARMUP_TIME = 0.45 s`, 2026-06-25):** o disparo agora só ocorre
> depois de o player ficar mirando por ≥ `AIM_WARMUP_TIME` (`_aim_held_time` acumula no branch de
> mira do `apply_input`, zera ao sair da mira/no ar). Assim **a bala sai só após a animação de mira
> assentar e o cano estar alinhado** — corrige o glitch do jogador **cliente**, cujo corpo é
> renderizado ~100 ms no passado e fazia a bala parecer sair antes da mira / fora do cano. Vale p/
> host, cliente e bots; não afeta tiros sustentados (gateados pelo `FireCooldown`), só o 1º após mirar.

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

- `FireCooldown` Timer: **0.7 s**, auto-start (era 0.4 — cadência mais espaçada)
- Verificado em `apply_input()`: `fire_cooldown.time_left == 0`

---

## Aparência da bala (bolinha)

- A **bolinha visível** = `MeshInstance3D` (SphereMesh, escala **0.13**) com material `StandardMaterial3D_ffosa`:
  **unshaded + azul HDR** `Color(0.14902, 0.74902, 1.50196)` (canal azul > 1 → "estoura" no glow). Antes era branco sem cor e dependia 100% do glow do cenário; agora é azul vistoso mesmo **sem** bloom.
- Cor extra vem da `OmniLight3D` azul + rastro de partículas (`BulletBody/MainBody`, `Trail`).
- `CannonShooter.fire(...)` aceita `tint`/`ball_color`/`ball_scale` (alpha 0 = mantém o visual autorado, o tiro azul do player); `bullet.gd._apply_visuals()` aplica em todos os peers.
- ⚠️ O efeito "orbe brilhante" depende de **glow/bloom** do `Environment`. `level_1`/`level_2` têm `glow_enabled` + `glow_hdr_threshold=0.9` + `glow_intensity` inline para a bala florescer. O setting "bloom" (`config.gd`) liga/desliga `glow_enabled` em runtime.

---

## Ponto de Spawn da Bala

- `ShootFrom`: `Marker3D` em `Robot_Skeleton/Skeleton3D/GunBone/ShootFrom`
- Offset: `(0, 0.4, 0)` relativo ao osso do cano

---

## Aniquilação mútua projétil × projétil (2026-06-24)

Quando dois projéteis colidem — bala de player, bala de canhão do red_robot (ambos `bullet.tscn`)
ou bomba da criatura (`bomb.tscn`) — **ambos se destroem** com explosão (dá pra "abater" a bala de
canhão/bomba do inimigo no ar).

- **Colisão:** todos os projéteis ficam na **layer 4** (valor 8) e nada mais usa essa layer. As
  **máscaras** ganharam o bit 4 (bullet `51→59`, bomb `3→11`) → passam a colidir **só entre si**,
  sem mexer na colisão com mundo/personagens.
- **Detecção:** ambos entram no grupo `&"projectiles"` no `_ready`. No `move_and_collide` (server),
  se o `collider` está nesse grupo → chama `annihilate()` em si e no outro e retorna (antes da
  lógica de dano/phase). É **idempotente** (guardas `hit`/`_done`), então não importa qual detecta
  primeiro nem se ambos detectam no mesmo frame.
- **`annihilate()`:** na bala = explode + desativa colisão (mesmo desfecho de um acerto); na bomba =
  `_explode(null)` (detona sem dano a player). As explosões/remoções replicam via os RPCs `call_local`
  + despawn do `MultiplayerSpawner` já existentes → **sem tráfego de rede extra**.
- ⚠️ Best-effort: projéteis muito rápidos e pequenos podem "tunelar" num frame; a bala de canhão
  (maior, `ball_scale 2.5`) e a bomba são alvos fáceis.

---

## Camera Shake

| Evento | Trauma |
|---|---|
| Atirar | `0.35` |
| Ser atingido | `0.75` |

---

## Dano por facção — sem fogo amigo (2026-07-08)

O dano deixou de ser "acerta qualquer um menos o próprio atirador" e passou a respeitar o
[[⚔️ facções|sistema de facções]]:

- **`bullet.gd`** e **`bomb.gd`** checam `Factions.can_damage(shooter/dropper, alvo)` antes de aplicar
  dano. **Mesma facção → sem dano.**
- A **bala ATRAVESSA** um personagem da mesma facção (exceção de colisão, como já faz com o corpo que
  tem colliders de membro) em vez de explodir → **não bloqueia a linha de tiro** de quem está atrás.
- Ao aplicar dano, `Factions.note_damage(...)` **provoca** um alvo neutro (alinha-o contra o atacante).
- Só o servidor aplica dano (server-autoritativo), então a facção só precisa existir no servidor.

---

## Relacionado

- [[🎮 player]]
- [[❤️ sistema-de-vida]]
- [[💥 bullet-gd]]
- [[⚔️ facções]]

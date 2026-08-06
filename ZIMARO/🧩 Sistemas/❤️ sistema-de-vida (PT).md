---
tipo: sistema
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-08-06
---

# ❤️ Sistema de Vida (Health System)

> Implementado em 2026-06-06.
> ⚠️ **Superado como condição de morte em 2026-08-06** — ver [[🦴 hp-por-membro (PT)|🦴 hp-por-membro]].

---

## ⚠️ O que mudou em 2026-08-06

A vida **única** deixou de decidir o abate. Ela continua existindo, mas passa a ser o **espelho da
soma do HP dos membros** (`hp = limbs.total_hp()`); quem decide a morte é o [[🦴 hp-por-membro (PT)|HP
por membro]] — o personagem só cai quando **todos os membros** são destruídos.

| | Antes | Agora |
|---|---|---|
| `MAX_HP` do player | 100 | **150** (15 por membro; ver a calibragem na nota do sistema) |
| `hit()` | `hit(amount)` | `hit(amount, group)` — o membro atingido vai junto |
| Morte | `hp <= 0` | `limbs.is_defeated()` (vida única só como fallback) |
| Respawn | `hp = MAX_HP` | idem **+ `limbs.reset()`** |

O fallback de vida única segue valendo para golpes **sem membro identificado** (explosão de área,
queda) e para modelos que não constroem colliders de membro (ex.: `criatura_alada`).

---

## Arquivos Modificados / Criados

| Arquivo | Ação |
|---|---|
| `library3D/characters/players/player/player.gd` | Adicionado HP, `hit()` com dano, `respawn()` RPC |
| `library3D/characters/players/player/health_bar.gd` | **NOVO** — CanvasLayer com ProgressBar + Label |

---

## Variáveis em `player.gd`

```gdscript
const MAX_HP: int = 100
var hp: int = MAX_HP
var _health_bar = null   # referência ao CanvasLayer
```

---

## Fluxo de Dano

```
bullet._physics_process()
  → collider.hit.rpc()           # chamado pelo servidor
      → hit() executa em TODOS os peers (call_local)
          → hp -= 25
          → _health_bar.update_health(hp, MAX_HP)
          → se hp == 0 e é servidor:
              → respawn.rpc()    # executa em todos
                  → hp = MAX_HP
                  → transform.origin = initial_position
```

---

## Barra de Vida — `library3D/characters/players/player/health_bar.gd`

- Estende `CanvasLayer` (layer = 10)
- Criado programaticamente (sem .tscn)
- Criado em `_setup_health_bar()` (idempotente), disparado por **dois gatilhos** deferidos:
  `_ready()` **e** o setter de `player_id` → **aparece em toda cena de level**, inclusive em clientes multiplayer
- Visível **apenas para o player local** (`$InputSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id()`)
- Guardas: `_health_bar != null` (não duplica) e `is_inside_tree()` (espera entrar na árvore)
- Posicionada no **canto inferior esquerdo** via `PRESET_BOTTOM_LEFT + 16px margin`

### Comportamento de cor por HP

| Faixa | Cor |
|---|---|
| > 50% | Verde |
| 25–50% | Amarelo |
| < 25% | Vermelho |

---

## Parâmetros de Balanceamento

| Parâmetro | Valor | Onde mudar |
|---|---|---|
| HP máximo | `100` | `MAX_HP` em `player.gd` |
| Dano por hit | `25` | `hit()` em `player.gd` |
| Hits para morrer | `4` | derivado |

---

## Relacionado

- [[🎮 player (PT)|🎮 player]]
- [[🔫 combate-tiro (PT)|🔫 combate-tiro]]
- [[🎮 player-gd (PT)|🎮 player-gd]]
- [[💚 health-bar-gd (PT)|💚 health-bar-gd]]

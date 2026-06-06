# Sistema de Vida (Health System)

> Implementado em 2026-06-06.

---

## Arquivos Modificados / Criados

| Arquivo | Ação |
|---|---|
| `player/player.gd` | Adicionado HP, `hit()` com dano, `respawn()` RPC |
| `player/health_bar.gd` | **NOVO** — CanvasLayer com ProgressBar + Label |

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

## Barra de Vida — `player/health_bar.gd`

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

- [[sistemas/player]]
- [[sistemas/combate-tiro]]
- [[arquivos-chave/player-gd]]
- [[arquivos-chave/health-bar-gd]]

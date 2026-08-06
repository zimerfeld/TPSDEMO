---
tipo: arquivo-chave
projeto: ZIMARO
lang: pt-BR
atualizado: 2026-07-04
---

# 🩹 controls2D/enemy_health_bar.gd

**Criado em:** 2026-06-06
**Estende:** `CanvasLayer`

---

## Responsabilidades

- HUD compartilhado estilo **"boss bar"** no topo-centro da tela
- Exibe **nome do inimigo** + **barra de vida** com texto `restante / total`
- Exibe **distância** (m) e, quando o inimigo tem arma, o **alcance da arma** (m)
- Mostra o inimigo atingido mais recentemente; **some sozinho** após 6 s
- Esconde imediatamente quando o inimigo morre

---

## Padrão Singleton — uma instância POR VIEWPORT (2026-08-06)

```gdscript
static var _instances: Dictionary = {}   # id do viewport -> CanvasLayer

static func get_shared(source: Node):    # source = o PRÓPRIO inimigo
    var vp: Viewport = source.get_viewport() ...
    ...
    vp.add_child(inst)                   # nasce DENTRO do viewport da sala
    _instances[vp.get_instance_id()] = inst

static func hide_all() -> void           # esconde em todos os viewports
```

> **Por que mudou:** antes era **uma instância global** pendurada em `get_tree().current_scene`.
> No host, cada sala vive num **SubViewport** próprio, mas o HUD ficava na raiz da
> **HostSession** — resultado: a grade de "Salas em execução" desenhava a barra de vida de um
> inimigo de uma partida que o host **nem estava assistindo** (reportado 2026-08-06). Pendurado no
> viewport do inimigo, ele só aparece quando aquela sala é renderizada (jogando ou observando).
>
> `get_shared` devolve `null` se o nó ainda não está na árvore — os chamadores checam antes de usar.
>
> `hide_all()` é chamado ao **sair da sala**: `host_session._set_observing(-1)` (volta à grade) e
> `client_session._exit_play()` (volta ao navegador) — senão a barra do último inimigo atingido
> ficaria visível por até `AUTO_HIDE_TIME` sobre a tela de salas.

---

## Estrutura de Nós (criados programaticamente)

```
CanvasLayer (layer=9)
  └─ PanelContainer  (âncora: CENTER_TOP, grow horizontal BOTH, margin 16px)
       └─ VBoxContainer (centralizado)
            ├─ HBoxContainer (linha do topo)
            │    ├─ Label (_name_label)  nome do inimigo, fonte 16
            │    └─ Label (_dist_label)  distância "12.3 m", fonte 14
            ├─ ProgressBar (_bar)    260×20
            │    └─ Label (_hp_label) overlay "restante / total" centralizado
            └─ Label (_range_label)  "Alcance/Range: 30 m", fonte 13 (oculto sem arma)
```

---

## API Pública

```gdscript
func show_enemy(enemy_name: String, current: int, maximum: int, distance := -1.0, weapon_range := -1.0) -> void
func hide_now() -> void
```

**Distância:** a linha do topo é um `HBoxContainer` com nome (esq.) + distância (dir., "12.3 m").
`player_input._update_enemy_focus()` calcula `player.distance_to(enemy)` e passa a cada frame.
`distance < 0` mantém a última distância conhecida (ex.: ao ser atingido sem mira).

**Alcance da arma (`weapon_range`):** label dedicado abaixo da barra, exibido só quando o inimigo
tem mecanismo de ataque/tiro (`weapon_range >= 0`); cada inimigo informa o seu (ex.: `red_robot`
passa `effective_range`). Texto **"Alcance: N m"** (PT) ou **"Range: N m"** (EN), escolhido por
`/root/Locale.get_language()`. `weapon_range < 0` mantém o último valor; ao **trocar de inimigo**
(nome diferente) a distância e o alcance anteriores são descartados para não vazar valores.

- `show_enemy` mostra o painel, reinicia o timer de auto-hide (`AUTO_HIDE_TIME = 6.0 s`)
- `_process(delta)` decrementa o timer e esconde o painel ao zerar

---

## Acionado por

1. **Acerto:** `red_robot.gd.hit()` → `show_health_hud()` → `get_shared(...).show_enemy(...)`
2. **Mira do player (entra):** `player_input.gd._update_enemy_focus()` → `collider.show_health_hud()`,
   **só com a mira ATIVADA** (`aiming`) e **só ao acertar um MEMBRO/SUB-MEMBRO** (layer 32) — a
   cápsula de locomoção sozinha não abre o HUD. O sub-membro saliente (ex.: placa de perna) resolve
   o dono por `meta("character")`. Ver [[🕹️ player-input-gd (PT)|🕹️ player-input-gd]].
3. **Mira do player (sai ou desativa):** `_update_enemy_focus()` chama `_clear_enemy_focus()` →
   `_focused_enemy.hide_health_hud()` → `hide_now()`
4. **Morte:** `red_robot.gd` → `hide_health_hud()` → `hide_now()`

Guardas:
- `if DisplayServer.get_name() == "headless": return` (servidor dedicado não monta UI)
- `if dead: return` em `show_health_hud()` (robô morto não exibe HUD ao ser mirado)

## Visibilidade

- **Mira:** aparece ao mirar (**mira ativada**) num **membro/sub-membro** do inimigo e **some
  imediatamente** ao sair dele **ou ao desativar a mira** (rastreamento `_focused_enemy` em
  `player_input.gd`).
- **Acerto sem mirar:** o auto-hide de 6 s (`AUTO_HIDE_TIME`) serve de fallback.

---

## Caminho: `controls2D/enemy_health_bar.gd`

---

## Relacionado

- [[🤖 inimigos (PT)|🤖 inimigos]]
- [[🤖 red-robot-gd (PT)|🤖 red-robot-gd]]
- [[💚 health-bar-gd (PT)|💚 health-bar-gd]]

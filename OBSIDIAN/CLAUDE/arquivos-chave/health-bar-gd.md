# scenes3D/players/player/health_bar.gd

**Criado em:** 2026-06-06
**Estende:** `CanvasLayer`

---

## Responsabilidades

- Exibir barra de vida do player local no canto inferior esquerdo
- Mostrar texto `HP: atual / máximo`
- Mudar cor conforme porcentagem de HP

---

## Estrutura de Nós (criados programaticamente)

```
CanvasLayer (layer=10)
  └─ PanelContainer  (âncora inferior-esquerda, elevada 72px da borda)
       └─ VBoxContainer
            ├─ Label      (_label)  "HP: 100 / 100"
            └─ ProgressBar (_bar)   min=0, max=100, size 200×18
```

> **Posição:** ancorado em baixo-esquerda com `offset_left=24`, `offset_bottom=-72`,
> `grow_horizontal=END`, `grow_vertical=BEGIN`. Os 72px de margem inferior evitam
> que o HUD seja cortado na borda da tela (antes era 16px e cortava).

---

## API Pública

```gdscript
func update_health(current: int, maximum: int) -> void
```

Atualiza barra e label. Muda a cor de fill:

| HP % | Cor |
|---|---|
| > 50% | Verde `(0.1, 0.75, 0.1)` |
| 25–50% | Amarelo `(0.9, 0.7, 0.0)` |
| < 25% | Vermelho `(0.85, 0.1, 0.1)` |

---

## Estilo

- Background do painel: cinza escuro `(0.05, 0.05, 0.05, 0.75)` semi-transparente
- Background da barra: vermelho escuro `(0.25, 0.05, 0.05)`
- Cantos arredondados (radius 6 no painel, 4 na barra)
- Fonte branca, tamanho 13

---

## Instanciação — garantida em toda cena de level

`_setup_health_bar()` é **idempotente** e disparado por **dois gatilhos** (deferidos):
1. `player.gd._ready()` — em todo carregamento de level
2. setter de `player_id` — cobre o caso do **cliente multiplayer**, onde `player_id`
   chega por replicação depois do `_ready` (sem isso, o HUD nunca seria criado nesse level)

```gdscript
func _setup_health_bar() -> void:
    if _health_bar != null:          # idempotente — não duplica
        return
    if not is_inside_tree():         # aguarda o nó entrar na árvore
        return
    # $InputSynchronizer (não o onready) pois o setter pode rodar antes do _ready
    if $InputSynchronizer.get_multiplayer_authority() != multiplayer.get_unique_id():
        return                       # só o player local vê o HUD
    _health_bar = preload("res://scenes3D/players/player/health_bar.gd").new()
    _health_bar.name = "HealthBar"
    add_child(_health_bar)
    _health_bar.update_health(hp, MAX_HP)
```

> **Por que dois gatilhos:** em `level_1` (single-player) a authority já está definida no
> `_ready`. Em `level_base` num **cliente**, o player é criado via `MultiplayerSpawner` e a
> authority só é resolvida quando `player_id` replica — o gatilho no setter garante o HUD nesse caso.

---

## Caminho: `scenes3D/players/player/health_bar.gd`

---

## Relacionado

- [[sistemas/sistema-de-vida]]
- [[arquivos-chave/player-gd]]

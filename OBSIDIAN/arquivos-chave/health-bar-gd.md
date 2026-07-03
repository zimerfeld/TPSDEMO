# library3D/characters/players/player/health_bar.gd

**Criado em:** 2026-06-06
**Estende:** `CanvasLayer`

---

## Responsabilidades

- Exibir barra de vida do player local no canto inferior esquerdo
- **Mostrar o nome do próprio jogador no topo do HUD** (acima do HP) — o rótulo 3D acima da
  cabeça é só para os **outros** jogadores; ver [[arquivos-chave/player-gd]]
- Mostrar texto `HP: atual / máximo`
- Mudar cor conforme porcentagem de HP

---

## Estrutura de Nós (criados programaticamente)

```
CanvasLayer (layer=10)
  └─ PanelContainer  (âncora inferior-esquerda, elevada 72px da borda)
       └─ VBoxContainer
            ├─ Label      (_name_label) nome do jogador (oculto quando vazio)
            ├─ Label      (_label)  "HP: 100 / 100"
            └─ ProgressBar (_bar)   min=0, max=100, size 200×18
```

> **Posição:** ancorado em baixo-esquerda com `offset_left=24`, `offset_bottom=-72`,
> `grow_horizontal=END`, `grow_vertical=BEGIN`. Os 72px de margem inferior evitam
> que o HUD seja cortado na borda da tela (antes era 16px e cortava).

---

## API Pública

```gdscript
func set_player_name(player_name: String) -> void   # nome no topo do HUD (oculto se vazio)
func update_health(current: int, maximum: int) -> void
```

`update_health` atualiza barra e label. Muda a cor de fill:

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
    if not _is_owned_locally():      # só o player local vê o HUD (mesmo critério do nome 3D)
        return
    _health_bar = preload("res://library3D/characters/players/player/health_bar.gd").new()
    _health_bar.name = "HealthBar"
    add_child(_health_bar)
    _health_bar.update_health(hp, MAX_HP)
    _health_bar.set_player_name(player_name)   # nome do dono no topo do HUD
    _apply_name_label()                        # esconde o Label3D acima da própria cabeça
```

> `_is_owned_locally()` resolve "é o meu player" pelo mesmo critério em `player.gd`:
> `$InputSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id()` e não é bot
> (cobre host id 1 e clientes). Usa `$InputSynchronizer` — não o `@onready` — pois pode rodar
> antes do `_ready`.

> **Por que dois gatilhos:** em `level_1` (single-player) a authority já está definida no
> `_ready`. Num nível online num **cliente**, o player é criado via `MultiplayerSpawner` e a
> authority só é resolvida quando `player_id` replica — o gatilho no setter garante o HUD nesse caso.

---

## Caminho: `library3D/characters/players/player/health_bar.gd`

---

## Relacionado

- [[sistemas/sistema-de-vida]]
- [[arquivos-chave/player-gd]]

# enemies/enemy_health_bar.gd

**Criado em:** 2026-06-06  
**Estende:** `CanvasLayer`

---

## Responsabilidades

- HUD compartilhado estilo **"boss bar"** no topo-centro da tela
- Exibe **nome do inimigo** + **barra de vida** com texto `restante / total`
- Mostra o inimigo atingido mais recentemente; **some sozinho** após 6 s
- Esconde imediatamente quando o inimigo morre

---

## Padrão Singleton Compartilhado

Uma única instância por cliente, recriada se o nó for liberado (troca de level):

```gdscript
static var _instance = null

static func get_shared(parent: Node):
    if _instance != null and is_instance_valid(_instance):
        return _instance
    _instance = (preload("res://enemies/enemy_health_bar.gd")).new()
    parent.add_child(_instance)   # parent = get_tree().current_scene
    return _instance
```

> `is_instance_valid()` evita ponteiro pendente após a cena anterior ser liberada.

---

## Estrutura de Nós (criados programaticamente)

```
CanvasLayer (layer=9)
  └─ PanelContainer  (âncora: CENTER_TOP, grow horizontal BOTH, margin 16px)
       └─ VBoxContainer (centralizado)
            ├─ Label  (_name_label)  nome do inimigo, fonte 16
            └─ ProgressBar (_bar)    260×20
                 └─ Label (_hp_label) overlay "restante / total" centralizado
```

---

## API Pública

```gdscript
func show_enemy(enemy_name: String, current: int, maximum: int, distance := -1.0) -> void
func hide_now() -> void
```

**Distância:** a linha do topo é um `HBoxContainer` com nome (esq.) + distância (dir., "12.3 m").
`player_input._update_enemy_focus()` calcula `player.distance_to(enemy)` e passa a cada frame.
`distance < 0` mantém a última distância conhecida (ex.: ao ser atingido sem mira).

- `show_enemy` mostra o painel, reinicia o timer de auto-hide (`AUTO_HIDE_TIME = 6.0 s`)
- `_process(delta)` decrementa o timer e esconde o painel ao zerar

---

## Acionado por

1. **Acerto:** `red_robot.gd.hit()` → `show_health_hud()` → `get_shared(...).show_enemy(...)`
2. **Mira do player (entra):** `player_input.gd._update_enemy_focus()` → `collider.show_health_hud()`
3. **Mira do player (sai):** `_update_enemy_focus()` chama `_focused_enemy.hide_health_hud()` → `hide_now()`
4. **Morte:** `red_robot.gd` → `hide_health_hud()` → `hide_now()`

Guardas:
- `if DisplayServer.get_name() == "headless": return` (servidor dedicado não monta UI)
- `if dead: return` em `show_health_hud()` (robô morto não exibe HUD ao ser mirado)

## Visibilidade

- **Mira:** aparece ao colocar a mira no inimigo, **some imediatamente** ao tirar a mira
  (via rastreamento `_focused_enemy` em `player_input.gd`).
- **Acerto sem mirar:** o auto-hide de 6 s (`AUTO_HIDE_TIME`) serve de fallback.

---

## Caminho: `enemies/enemy_health_bar.gd`

---

## Relacionado

- [[sistemas/inimigos]]
- [[arquivos-chave/red-robot-gd]]
- [[arquivos-chave/health-bar-gd]]

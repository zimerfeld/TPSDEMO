---
tipo: arquivo-chave
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# 💚 library3D/characters/players/player/health_bar.gd

**Created on:** 2026-06-06
**Extends:** `CanvasLayer`

---

## Responsabilidades

- Mostrar la barra de salud del jugador local en la esquina inferior izquierda
- **Mostrar el propio nombre del jugador en la parte superior del HUD** (encima del HP) — la etiqueta 3D sobre la
  cabeza es solo para los **otros** jugadores; ver [[🎮 player-gd (ES)|player.gd]]
- Mostrar el texto `HP: current / maximum`
- Cambiar de color según el porcentaje de HP

---

## Estructura de nodos (creada programáticamente)

```
CanvasLayer (layer=10)
  └─ PanelContainer  (bottom-left anchor, raised 72px from the edge)
       └─ VBoxContainer
            ├─ Label      (_name_label) player name (hidden when empty)
            ├─ Label      (_label)  "HP: 100 / 100"
            └─ ProgressBar (_bar)   min=0, max=100, size 200×18
```

> **Posición:** anclada abajo a la izquierda con `offset_left=24`, `offset_bottom=-72`,
> `grow_horizontal=END`, `grow_vertical=BEGIN`. El margen inferior de 72px evita
> que el HUD quede recortado en el borde de la pantalla (antes era de 16px y se recortaba).

---

## API pública

```gdscript
func set_player_name(player_name: String) -> void   # name at the top of the HUD (hidden if empty)
func update_health(current: int, maximum: int) -> void
```

`update_health` actualiza la barra y la etiqueta. Cambia el color de relleno:

| HP % | Color |
|---|---|
| > 50% | Verde `(0.1, 0.75, 0.1)` |
| 25–50% | Amarillo `(0.9, 0.7, 0.0)` |
| < 25% | Rojo `(0.85, 0.1, 0.1)` |

---

## Estilo

- Fondo del panel: gris oscuro `(0.05, 0.05, 0.05, 0.75)` semitransparente
- Fondo de la barra: rojo oscuro `(0.25, 0.05, 0.05)`
- Esquinas redondeadas (radio 6 en el panel, 4 en la barra)
- Fuente blanca, tamaño 13

---

## Instanciación — garantizada en cada escena de nivel

`_setup_health_bar()` es **idempotente** y disparado por **dos** activadores (deferred):
1. `player.gd._ready()` — en cada carga de nivel
2. el setter de `player_id` — cubre el caso del **cliente multijugador**, donde `player_id`
   llega por replicación después de `_ready` (sin esto, el HUD nunca se crearía en ese nivel)

```gdscript
func _setup_health_bar() -> void:
    if _health_bar != null:          # idempotent — does not duplicate
        return
    if not _is_owned_locally():      # only the local player sees the HUD (same criterion as the 3D name)
        return
    _health_bar = preload("res://library3D/characters/players/player/health_bar.gd").new()
    _health_bar.name = "HealthBar"
    add_child(_health_bar)
    _health_bar.update_health(hp, MAX_HP)
    _health_bar.set_player_name(player_name)   # owner's name at the top of the HUD
    _apply_name_label()                        # hides the Label3D above the player's own head
```

> `_is_owned_locally()` resuelve «es mi jugador» con el mismo criterio de `player.gd`:
> `$InputSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id()` y no es un bot
> (cubre el host id 1 y los clientes). Usa `$InputSynchronizer` — no el `@onready` — ya que puede ejecutarse
> antes de `_ready`.

> **Por qué dos activadores:** en `level_1` (un jugador) la autoridad ya está establecida en
> `_ready`. En un nivel online en un **cliente**, el jugador se crea vía `MultiplayerSpawner` y la
> autoridad solo se resuelve cuando `player_id` se replica — el activador del setter garantiza el HUD en ese caso.

---

## Path: `library3D/characters/players/player/health_bar.gd`

---

## Relacionado

- [[❤️ sistema-de-vida (ES)|Sistema de Vida]]
- [[🎮 player-gd (ES)|player.gd]]

---
tipo: arquivo-chave
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# 🩹 controls2D/enemy_health_bar.gd

**Created on:** 2026-06-06
**Extends:** `CanvasLayer`

---

## Responsabilidades

- Un HUD compartido estilo **«boss bar»** en la parte superior-central de la pantalla
- Muestra el **nombre del enemigo** + una **barra de salud** con el texto `remaining / total`
- Muestra la **distancia** (m) y, cuando el enemigo tiene arma, el **alcance del arma** (m)
- Muestra el enemigo golpeado más recientemente; **se desvanece por sí solo** tras 6 s
- Se oculta inmediatamente cuando el enemigo muere

---

## Patrón Singleton compartido

Una única instancia por cliente, recreada si el nodo se libera (cambio de nivel):

```gdscript
static var _instance = null

static func get_shared(parent: Node):
    if _instance != null and is_instance_valid(_instance):
        return _instance
    _instance = (preload("res://controls2D/enemy_health_bar.gd")).new()
    parent.add_child(_instance)   # parent = get_tree().current_scene
    return _instance
```

> `is_instance_valid()` evita un puntero colgante tras liberarse la escena anterior.

---

## Estructura de nodos (creada programáticamente)

```
CanvasLayer (layer=9)
  └─ PanelContainer  (anchor: CENTER_TOP, grow horizontal BOTH, margin 16px)
       └─ VBoxContainer (centered)
            ├─ HBoxContainer (top row)
            │    ├─ Label (_name_label)  enemy name, font 16
            │    └─ Label (_dist_label)  distance "12.3 m", font 14
            ├─ ProgressBar (_bar)    260×20
            │    └─ Label (_hp_label) overlay "remaining / total" centered
            └─ Label (_range_label)  "Alcance/Range: 30 m", font 13 (hidden without a weapon)
```

---

## API pública

```gdscript
func show_enemy(enemy_name: String, current: int, maximum: int, distance := -1.0, weapon_range := -1.0) -> void
func hide_now() -> void
```

**Distancia:** la fila superior es un `HBoxContainer` con el nombre (izquierda) + la distancia (derecha, "12.3 m").
`player_input._update_enemy_focus()` calcula `player.distance_to(enemy)` y la pasa cada frame.
`distance < 0` mantiene la última distancia conocida (p. ej.: cuando se recibe un impacto sin apuntar).

**Alcance del arma (`weapon_range`):** una etiqueta dedicada debajo de la barra, mostrada solo cuando el enemigo
tiene un mecanismo de ataque/disparo (`weapon_range >= 0`); cada enemigo reporta el suyo (p. ej.: `red_robot`
pasa `effective_range`). Texto **"Range: N m"** (EN) o **"Alcance: N m"** (PT/ES), elegido por
`/root/Locale.get_language()`. `weapon_range < 0` mantiene el último valor; al **cambiar de enemigo**
(nombre distinto) la distancia y el alcance anteriores se descartan para que los valores no se filtren.

- `show_enemy` muestra el panel, reinicia el temporizador de auto-ocultado (`AUTO_HIDE_TIME = 6.0 s`)
- `_process(delta)` decrementa el temporizador y oculta el panel cuando llega a cero

---

## Disparado por

1. **Impacto:** `red_robot.gd.hit()` → `show_health_hud()` → `get_shared(...).show_enemy(...)`
2. **Puntería del jugador (entra):** `player_input.gd._update_enemy_focus()` → `collider.show_health_hud()`.
   El rayo registra tanto el **cuerpo** como los **colisionadores de miembro/SUBMIEMBRO** (layer 32); un
   submiembro sobresaliente (p. ej.: una placa de pierna) resuelve al propietario vía `meta("character")`. Ver
   [[🕹️ player-input-gd (ES)|player_input.gd]].
3. **Puntería del jugador (sale):** `_update_enemy_focus()` llama a `_focused_enemy.hide_health_hud()` → `hide_now()`
4. **Muerte:** `red_robot.gd` → `hide_health_hud()` → `hide_now()`

Guards:
- `if DisplayServer.get_name() == "headless": return` (un servidor dedicado no construye UI)
- `if dead: return` en `show_health_hud()` (un robot muerto no muestra un HUD cuando se le apunta)

## Visibilidad

- **Puntería:** aparece cuando la mira se coloca sobre el enemigo, **desaparece inmediatamente** cuando la puntería se retira
  (vía el rastreo de `_focused_enemy` en `player_input.gd`).
- **Impacto sin apuntar:** el auto-ocultado de 6 s (`AUTO_HIDE_TIME`) sirve como fallback.

---

## Path: `controls2D/enemy_health_bar.gd`

---

## Relacionado

- [[🤖 inimigos (ES)|Enemigos]]
- [[🤖 red-robot-gd (ES)|red_robot.gd]]
- [[💚 health-bar-gd (ES)|health_bar.gd]]

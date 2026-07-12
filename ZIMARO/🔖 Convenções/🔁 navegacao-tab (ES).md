---
tipo: convencao
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# 🔁 Navegación por Tab / foco — helpers `UINav` (y otros helpers del proyecto)

> El autoload **`UINav`** (`autoload/ui_nav.gd`) centraliza la navegación por teclado de las pantallas 2D:
> foco inicial, el anillo de Tab (Tab/Shift+Tab) y la regla ESC. Esta nota documenta cada helper, **en qué
> escenas se usa**, y por qué el **Debug 2D** a veces muestra `TAB: -` (sin número). Relacionado:
> [[🐞 debug-overlay (ES)\|debug-overlay]], [[🎬 fluxo-de-cenas (ES)\|fluxo-de-cenas]], [[⌨️ fluxo-de-input (ES)\|fluxo-de-input]], [[📌 ancoragem-ui (ES)\|ancoragem-ui]].

---

## Orden de Tab EXPLÍCITO — `metadata/tab_order` (2026-06-30)

Regla del proyecto: **incluso con el auto-Tab de Godot aplicado, declara el orden de Tab ESPERADO y
muéstralo en el Debug Overlay**, para la previsibilidad del ciclo. Mecanismo elegido: **metadatos por nodo**.

- Cada control interactivo lleva `metadata/tab_order = N` (basado en 1) en el `.tscn`, en el **orden de
  lectura** (arriba→abajo, izquierda→derecha) — que es el propio orden de árbol/documento. P. ej. (escena
  `menu`): `Play=1, PlayOnline=2, Settings=3, Developer=4, Quit=5, Portuguese=6, English=7`; el
  toggle **Debug 2D** se inyecta en tiempo de ejecución y obtiene `tab_order = el mayor declarado de la pantalla + 1`
  (`DebugOverlay._max_declared_tab_order`), quedándose siempre EL ÚLTIMO (menu `8`, chooseplayer `7`…).
  **Los contenedores de fila (`*Row`)** que envuelven un único control pueden **reflejar** el mismo `tab_order`
  de su control solo para MOSTRARLO (p. ej. `menu` `PlayRow=1`…`QuitRow=5`); como no son focables, no
  entran en el anillo. **Los controles creados en tiempo de ejecución** (p. ej. los botones Template en `levels`) obtienen su propio `name`
  + `tab_order` vía `set_meta` en la creación (de lo contrario aparecerían como `@Button@N` y sin número).
- **`UINav.collect_focusables`** ahora ordena por `tab_order` (ascendente) y, entre los que NO tienen metadatos (o
  empatan), por orden de árbol — de modo que `wire_tab_ring` construye el anillo exactamente en ese orden. Como los
  metadatos replican el orden de árbol que ya se usaba, **no hay cambio de comportamiento** en las pantallas
  que ya conectaban el anillo; solo se volvió explícito.
- **Debug 2D muestra el valor ESPERADO:** la línea de Tab usa `UINav.tab_order_of(ctrl)` — si hay un
  `tab_order`, muestra ese número; de lo contrario recurre al índice CALCULADO de la cadena viva (`_tab_index_map`).
- Aplicado en: `menu`, `chooseplayer`, `controls`, `developer`, `levels`, `playonline`, `settings`
  (numerado **cruzando las pestañas**, ver abajo), `pause_menu` y `models` (3D).

## TabContainer — Tab cruza las pestañas (2026-06-30)

Regla del proyecto para el control `TabContainer` (hoy solo `settings`):

1. La **1ª pestaña** es el foco inicial al entrar con Tab.
2. Dentro de la pestaña, Tab se mueve **izquierda→derecha, arriba→abajo**.
3. En el **último control de una pestaña**, Tab **cambia a la siguiente pestaña** y resalta su **1er control**.
4. Solo **sale** del `TabContainer` (va a Back/Reset/idioma/Debug2D) cuando estás en el **último
   control de la ÚLTIMA pestaña** y se pulsa Tab de nuevo.

Implementación: la escena gestiona Tab/Shift+Tab en `_input` llamando a **`UINav.tab_container_focus_step(self,
tabs, forward)`** (consumiendo el evento). El helper construye el **orden global** con
**`collect_focus_order_with_tabs`** — focables antes del TabContainer → pestaña 0 → … → pestaña N-1 → focables
después — usando **`collect_focusables_ignoring_visibility`** para escanear las pestañas OCULTAS; al cruzar un límite
de pestaña, cambia `current_tab` y enfoca el objetivo (deferred). `settings` dejó de construir un anillo
cerrado (`wire_tab_ring`) y de reconectar en `tab_changed`/idioma — el orden se recalcula en cada paso
(ignora los deshabilitados, así que el idioma activo se cae por sí solo). Con una **ventana flotante abierta**, el Tab es
de la ventana (su propio anillo) — `settings._input` no cruza las pestañas (`_floating_window_open`).

## ¿Por qué Debug 2D muestra `TAB: -` en algunos controles?

La línea blanca **"Tab"** de [[🐞 debug-overlay (ES)\|debug-overlay]] la calcula `DebugOverlay._compute_tab_indices`:
parte del **1er focable** de la pantalla (`UINav.first_focusable`) y sigue **`Control.find_next_valid_focus()`**
control a control hasta que **cierra el ciclo** (vuelve a uno ya numerado). Cada control visitado obtiene
`TAB: 1, 2, 3…`; **quien no es visitado se queda `TAB: -`**. Así que hay **dos motivos** para no tener número:

1. **No es focable** — este es el caso correcto/esperado: `Label`, `ColorRect`, `Panel`, `MarginContainer`,
   `VBox/HBox`, `TextureRect` decorativo, el **título de la escena**, etc. (no tienen `focus_mode = FOCUS_ALL`).
   También el **botón de idioma ACTIVO** (queda `disabled`, fuera del anillo) y los nodos marcados
   `is_queued_for_deletion()`. Estos **deben** mostrar `TAB: -`.
2. **Es focable, pero la cadena automática no lo alcanza** — este es el motivo "sorpresa": **sin**
   `UINav.wire_tab_ring`, `find_next_valid_focus()` sigue los **vecinos que Godot calcula por sí solo**
   (geometría/`focus_next`). Cuando los focables están en **contenedores separados** (varios `HBox`/columnas),
   esos vecinos automáticos **pueden no encadenarlos todos** o **cerrar el ciclo antes** → el recorrido termina
   antes de visitar el resto, que aparece como `TAB: -` **aunque sea focable**.
3. **`SpinBox` NO es `FOCUS_ALL` por defecto (2026-06-30)** — a diferencia de `Button`/`LineEdit`/`OptionButton`,
   el `SpinBox` nace sin `focus_mode = FOCUS_ALL`, así que `collect_focusables` lo IGNORA y Tab lo salta
   (p. ej. `playonline` saltaba de `PlayerName`=1 directamente a `PortHistories`=3, sin parar en `Port`=2).
   **Corrección estableciendo `focus_mode = 2` (FOCUS_ALL)** en el `.tscn`, o `sp.focus_mode = Control.FOCUS_ALL`
   en los `SpinBox` creados por código (el diálogo de templates, las filas Offset/Rotation/Scale de Models).

> **Pantallas con columnas:** el ciclo de Tab es por COLUMNA — recorre todos los controles de una columna (de arriba
> abajo) antes de pasar a la siguiente. Como `collect_focusables` sigue el orden de árbol (y el `tab_order`
> declarado), basta con que cada columna sea su propio contenedor en orden de lectura.

**Conclusión:** si un control **focable** aparece sin número, la pantalla probablemente **aún no conecta el anillo**.
Llamar a **`UINav.wire_tab_ring(self)`** conecta `focus_next`/`focus_previous` en un **anillo cerrado
`1 → 2 → … → N → 1`**, de modo que `find_next_valid_focus()` pasa por **todos** ellos y Debug 2D numera **1..N
incrementando de 1**. (Las labels/contenedores se quedan, correctamente, en `TAB: -`.)

> Para ver los números: pantalla **developer** → activa **Debug 2D** + la línea **Tab**.

---

## Helpers `UINav` (foco/teclado)

| Helper | Firma | Qué hace |
|---|---|---|
| **`wire_tab_ring`** | `wire_tab_ring(root, last=null)` | **(nuevo)** Conecta Tab/Shift+Tab en un **anillo cerrado** en orden de lectura (orden de árbol: arriba→abajo, y dentro de un HBox izquierda→derecha) vía `collect_focusables`. `last` (opcional) va al **FINAL** del anillo (índice más alto) — p. ej. la **×** de las ventanas flotantes. **Idempotente**: vuelve a llamarlo siempre que cambie el conjunto de focables (toggle inyectado, idioma habilitándose/deshabilitándose, listas dinámicas). |
| **`focus_tab_one`** | `focus_tab_one(root, last=null) → Control` | Enfoca la **cabeza del anillo** (Tab = 1). Usado al **abrir** la pantalla para que el foco siempre empiece en el 1º de la secuencia. |
| **`tab_one_control`** | `tab_one_control(root, last=null) → Control` | Devuelve (sin enfocar) el control **Tab = 1** = `collect_focusables(root)` menos `last`, 1er elemento. |
| **`focus_first`** | `focus_first(root) → Control` | Enfoca el **1er focable** en orden de árbol. Equivalente a `focus_tab_one` cuando no hay `last` movido — es el estándar **antiguo** de las pantallas que aún no conectan el anillo. |
| **`first_focusable`** | `first_focusable(node) → Control` | El 1er `Control` focable (FOCUS_ALL, visible, un `BaseButton` no `disabled`) en orden de árbol. La base de `focus_first` y usado por el **DebugOverlay** para hallar el inicio de la cadena de Tab. |
| **`collect_focusables`** | `collect_focusables(root) → Array[Control]` | **Todos** los focables bajo `root` en orden de árbol. La base de `wire_tab_ring`/`tab_one_control`. Ignora `is_queued_for_deletion()`. |
| **`cancel_active_edit`** | `cancel_active_edit(viewport, fallback=null) → bool` | **Regla ESC**: si el foco está en un `LineEdit` (incluye el editor interno de un `SpinBox`), finaliza la edición y devuelve el foco a `fallback`, devolviendo `true` (el llamador consume el ESC y **no** retrocede de pantalla). Solo el **2º ESC** navega hacia atrás. |
| **`tab_order_of`** | `tab_order_of(ctrl) → int` | El valor `metadata/tab_order` declarado (basado en 1) o un centinela grande si está ausente. La base del ordenamiento de `collect_focusables` y de la línea de Tab de Debug 2D (valor ESPERADO). |
| **`collect_focusables_ignoring_visibility`** | `… → Array[Control]` | Escanea una pestaña OCULTA de un `TabContainer`: ignora que la raíz de la pestaña esté oculta, pero RESPETA el flag `.visible` PROPIO del control (los controles ocultos por sí mismos — p. ej. los botones MetalFX en un SO no soportado — quedan FUERA, de lo contrario Tab intentaría enfocar uno oculto y se quedaba atascado al final de la pestaña). |
| **`collect_focus_order_with_tabs`** | `(scene_root, tab_container) → Array[Control]` | El orden GLOBAL de foco con cada pestaña expandida en secuencia (las ocultas incluidas): antes → pestaña 0 → … → pestaña N-1 → después. |
| **`tab_container_focus_step`** | `(scene_root, tab_container, forward) → bool` | Un paso de Tab/Shift+Tab cruzando las pestañas (la regla del TabContainer). Cambia la pestaña visible cuando el objetivo está en otra pestaña. Llamado desde el `_input` de la escena. |

### Patrón de uso en una pantalla (listo para copiar)

```gdscript
func _ready() -> void:
    # ... fill fields, assemble dynamic options BEFORE wiring the ring ...
    UINav.focus_tab_one.call_deferred(self)            # focus on Tab = 1
    _wire_tab_order.call_deferred()                    # wire the ring (deferred)
    ($UI/Actions as HBoxContainer).child_entered_tree.connect(
        func(_n: Node) -> void: _wire_tab_order.call_deferred())  # re-wire when the Debug2D is injected

func _wire_tab_order() -> void:
    UINav.wire_tab_ring(self)

func _update_language_buttons() -> void:
    # ... sets disabled on the active language ...
    if is_node_ready():
        _wire_tab_order.call_deferred()                # the active language leaves the ring → re-wire

func _input(e: InputEvent) -> void:
    if e.is_action_pressed(&"quit"):
        if UINav.cancel_active_edit(get_viewport(), <fallback>):
            get_viewport().set_input_as_handled(); return
        get_viewport().set_input_as_handled()
        # ... go back a screen ...
```

### Matriz: qué escena usa qué helper `UINav`

| Escena / archivo | `wire_tab_ring` | `focus_tab_one` | `focus_first` | `tab_one_control` | `cancel_active_edit` |
|---|:---:|:---:|:---:|:---:|:---:|
| `menu` | ✅ | ✅ | — | — | ✅ |
| `playonline` | ✅ | ✅ | — | — | ✅ |
| `levels` | ✅ | ✅ | — | — | ✅ |
| `host_session` | ✅ (andamiaje estático; `tab_order` por código en `_rewire_tab`) | ✅ | — | — | — |
| `client_session` | ✅ (andamiaje estático; `tab_order` por código en `_rewire_tab`) | ✅ | — | — | — |
| `floating_window` | ✅ (`last=×`) | — | ✅ (en el padre al cerrar) | ✅ (`last=×`) | — |
| `chooseplayer` | ✅ | ✅ | — | — | ✅ |
| `settings` | — (usa `tab_container_focus_step`) | — (enfoca el 1º de la pestaña 0) | — | — | ✅ |
| `developer` | ✅ (+ sub-toggles) | ✅ | — | — | ✅ |
| `controls` | ✅ | ✅ | — | — | ✅ |
| `debug_overlay` (autoload) | — | — | — | — | — (usa `first_focusable`) |

> `collect_focusables` no tiene llamador directo de escena (es interno a `wire_tab_ring`/`tab_one_control`).
> **Casos especiales de reconexión (2026-06-29):** `settings` **ya no** usa el anillo — gestiona Tab en
> `_input` cruzando las pestañas (ver "TabContainer" arriba, 2026-06-30); `developer` reconecta en
> `_update_subrows_enabled` (los sub-toggles de Debug 2D entran/salen del anillo a medida que el maestro se enciende/apaga).

---

## Otros helpers compartidos del proyecto

Helpers reutilizables (estáticos o autoload) usados por varias escenas — no confundir con los
**almacenes de configuración** (`Settings`, `NetConfig`, `RoomManager`…), que guardan estado y no son "helpers".

| Helper | Firma / origen | Escenas que lo usan |
|---|---|---|
| **`FloatingDialog.confirm`** | `confirm(parent, title, text, ok="Sim", cancel="Não") → FloatingWindow` | menu, host_session, client_session, settings, models, crash_handler |
| **`FloatingDialog.alert`** | `alert(parent, title, text, ok="OK") → FloatingWindow` | client_session, crash_handler |
| **`FloatingWindow.style_close_button`** | `static` — da estilo al botón × | models |
| **`FloatingWindow.pointer_over_any_window`** | `static → bool` — cursor sobre alguna ventana flotante | models |
| **`FloatingWindow.wire_focus_ring`** | instance → delega en `UINav.wire_tab_ring(self, _close_button)` | toda ventana flotante (× la última) |
| **`Locale.tr_key`** | `tr_key(key) → String` (autoload [[🗣️ localizacao (ES)\|localizacao]]) | ~84 llamadas (todas las pantallas con texto dinámico/OptionButton) |
| **`Locale.set_language` / `get_language` / `language_changed`** | cambia/lee el idioma + señal | todas las pantallas con una barra de idioma |
| **`CrashHandler.show_error`** | `show_error(msg, retry_callable)` (autoload) | playonline, level_1, level_2, models, player |
| **`DebugOverlay.refresh`** | reconstruye los overlays 2D | developer, settings, debug2d_toggle |

---

## Cobertura y pendientes

**(2026-06-29)** Todas las **pantallas completas** conectan ahora el anillo: `menu`, `playonline`, `levels`,
`host_session`, `client_session`, `chooseplayer`, `settings`, `developer`, `controls` (+ `floating_window`
para las ventanas). Es una **regla del proyecto** (ver `CLAUDE.md`): cada escena 2D conecta `UINav.wire_tab_ring(self)` y
cada control interactivo debe ser focable (sin `TAB: -` en los controles de interacción).

Pendiente conocido: **`pause_menu`** (un overlay `Control`, 3 botones + 3 sliders) — sin barra `Actions` y
sin `grab_focus`. Es un overlay de pausa (no cambia de escenas); aplicar el anillo ahí es opcional/secundario.

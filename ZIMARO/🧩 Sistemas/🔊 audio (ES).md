---
tipo: sistema
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# 🔊 Audio (buses + ajustes)

Sistema de audio del proyecto: layout de buses en `default_bus_layout.tres`
(`uid://vtdn63d3ksc2`, referenciado por `project.godot` en `[audio]
buses/default_bus_layout`) y los controles en la pestaña **Audio** de los ajustes.

## 🎚️ Layout de buses

| # | Bus | Send | Uso |
|---|---|---|---|
| 0 | `Master` | — | mezcla final |
| 1 | `Outside` | `SFX` | zona de reverb (Area3D `SoundOutside`) |
| 2 | `Reactor` | `SFX` | zona de reverb (Area3D `SoundReactorRoom`) |
| 3 | `Music` | `Master` | música de fondo |
| 4 | `SFX` | `Master` | todo sonido que **no** sea música |

`Music` lleva solo la música de fondo, ahora centralizada en el autoload **MusicManager** (ver
la sección de abajo) en un único player con `bus = &"Music"` — los antiguos nodos `Music` incrustados en
`menu`/`chooseplayer` fueron eliminados. `SFX` (creado en 2026-06-16) lleva
**todo lo demás**: cada `AudioStreamPlayer/3D` de gameplay (pasos/disparo/explosión del
jugador, `Shot` de la pistola, `Boom` de la bomba, `sound` de la puerta, `Sound`/`Motor` de los
personajes, `Cannon`/`Explosion`/`Hit`/`Walk` del red_robot, etc.) recibió
`bus = &"SFX"`, y los buses de reverb `Outside`/`Reactor` fueron recableados para enviar
a `SFX` en vez de a `Master`. Así, silenciar `SFX` calla todos los efectos sin tocar la música.

## 🎵 Música por escena/nivel — `MusicManager` (2026-06-25)

Pista de fondo por **nombre de escena**, en **bucle infinito**. El autoload `MusicManager`
(`res://autoload/music_manager.gd`) mantiene un único `AudioStreamPlayer` en el bus `Music`; en cada
cambio de pantalla el router `main.gd` llama a `MusicManager.play_for_scene(node)`:

- **Por defecto = SILENCIO (2026-06-25):** una escena SIN asignación guardada queda en **"Select..." = sin
  música** (no reproduce). Antes, el valor por defecto se resolvía automáticamente por `Audios/<nombre-de-escena>.<ext>` — eso
  es ahora la **opción "Default"** (override `BYNAME`), elegida por escena en el Manager.
- **Resolución por nombre (opción "Default"):** `res://Audios/<nombre-de-escena>.<ext>` (el 1.º de `.ogg`/`.mp3`/`.wav`
  que exista), en `_resolve_by_name`. P. ej.: `menu` → `Audios/menu.ogg`. `ALIASES` hace que `chooseplayer`
  herede la pista de `menu`. Misma pista que la escena anterior → continúa sin reiniciar (transición suave).
- **Bucle forzado en runtime** (`_ensure_loop`): se aplica a cualquier archivo suelto en `Audios/`,
  aunque el import venga con `loop=false`.
- **Online:** en las salas la escena raíz es `host_session`/`client_session`, así que su música proviene de
  `Audios/host_session.ogg`/`client_session.ogg`. Cambiar la pista según el nivel observado dentro de una
  sala (su propio SubViewport) queda fuera del alcance de este autoload.

Para establecer la música de una escena/nivel, basta con colocar el archivo en `res://Audios/` con el nombre de la escena.
Pistas incluidas: `Audios/menu.ogg`. Ver `Audios/README.md` y
[[🎬 fluxo-de-cenas (ES)|fluxo-de-cenas]].

### 🎛️ Music Manager (Ajustes → Music → Enabled)

Al hacer clic en **Music: Enabled** en la pestaña Audio se abre el **Music Manager**
(`scenes2D/music_manager/music_manager_window.gd`). Desde 2026-06-29 es un **controlador** que construye el
formulario DENTRO de la **ventana flotante** reutilizable (`FloatingWindow`), en un `CanvasLayer` arriba —
mismo patrón que la ventana **Template Manager** (plantillas de nivel). Así hereda el tema 2D del proyecto
y el **Debug 2D funciona sobre él** (el `FloatingWindow` se une al grupo `DebugOverlay`),
igual que las demás ventanas flotantes. Permite:

- **Escuchar** cualquier pista en `Audios/` (player de pre-escucha separado; pausa el fondo mientras suena).
  Cada botón **▶ Play** tiene un **⏸ Pause** y un **⏹ Stop** al lado (2026-06-25) — tanto en la
  fila "Listen to track" como en la lista por escena. ▶ reanuda una pausa de la MISMA pista (`preview_or_resume`).
- **Asignar** la pista de cada escena/nivel. **Todo dropdown tiene "Select..." como 1.ª opción = sin
  música (silencio), el VALOR POR DEFECTO** de una escena sin configurar. Otras opciones: **"Default"** (resuelve por
  nombre, override `BYNAME`) o un **archivo** específico.

Las asignaciones se convierten en **overrides** persistidos en `Settings` (sección `[music]`: `scene_key = file`,
`BYNAME` = por nombre, `""` = silencio explícito; **SIN clave = "Select..." = silencio**, el valor por defecto).
`_resolve()` lee esto. Cambiar la
asignación se reaplica **al momento** si es la escena que se está reproduciendo. `MusicManager` expone `list_tracks()`,
`scene_list()`, `assignment_of()`, `set_assignment()`, `effective_track()`, `preview()`,
`preview_or_resume()`/`pause_preview()`/`resume_preview()` (2026-06-25), `stop_preview()`. Se abre vía
el `button_down` del botón Enabled (se abre incluso con la música ya encendida). Los botones de acción están en el
**footer** del `FloatingWindow` (**🎲 Randomize tracks** y **Close**); cerrar (× / ESC / Close) detiene
la pre-escucha. El controlador persiste en la pantalla de Ajustes entre aperturas; la ventana en sí
se auto-libera al cerrarse.

**Randomize + persistencia de estado (2026-06-25):** el footer tiene un botón **"🎲 Randomize tracks"**
(en lugar del 2.º "Stop" — ya hay uno en "Listen to track") que asigna una pista **aleatoria** de
`Audios/` a CADA escena/nivel (`set_assignment`, que persiste) y actualiza la pantalla → las elecciones
se recargan en la siguiente apertura. Cada control de la ventana **persiste al cambiar**: las asignaciones por escena
ya se guardan vía `set_assignment`; la pista elegida en "Listen to track" ahora se guarda en
`[music_ui] listen` y se restaura en `_refresh` (`_restore_listen_choice`).

## 🎧 Sonidos posicionales (3D) del jugador — 2026-06-24

Los efectos del jugador (`SoundEffects/Step`, `Jump`, `Land`, `Shoot`) eran
`AudioStreamPlayer` (no posicionales) → en multijugador oías el disparo de otro jugador
sin saber de dónde venía. Ahora son **`AudioStreamPlayer3D`** y el nodo padre
`SoundEffects` pasó a ser un **`Node3D`** (de lo contrario los hijos 3D sonarían en el origen del mundo, no
en la posición del jugador). Como estos sonidos ya se disparan vía el RPC **`@rpc("call_local")`**
(`jump`/`land`/`shoot`), suenan en todos los peers desde la posición **replicada** del jugador →
espacialización correcta, **sin tráfico de red ni latencia extra**. Para el jugador **local**
(cámara = listener, muy cerca) el sonido es nítido y consistente.

- **Rango/atenuación** (calibrados para no desperdiciar voces de audio en jugadores lejanos):
  `Step` `unit_size 8`/`max_distance 30`;
  `Jump`/`Land` `8`/`35`; `Shoot` `12`/`60` (el disparo llega más lejos; los rangos reflejan
  el `Motor` de la criatura ~35 y el `Explosion` del red_robot ~60). Por encima de `max_distance`,
  Godot descarta la voz → coste de CPU solo para los sonidos audibles.
- El `playera` hereda todo (instancia `player.tscn`), así que lo mismo aplica a la variante.

## ⚙️ Controles de Ajustes

La pestaña **Audio** de `scenes2D/settings/settings.tscn` tiene dos filas independientes,
cada una un par de botones `Disabled`/`Enabled` en un `ButtonGroup` (ver `_make_button_group`):

- **Music** (`MusicRow`) → clave `[audio] music`
- **Sound Effects** (`SFXRow`) → clave `[audio] sfx`

`settings.gd` lee/escribe ambos en `_load_current_settings` / `_on_apply_pressed`.
`Settings` (autoload `scenes2D/settings/config.gd`) los aplica en
`apply_audio_settings()`: silencia/reactiva los buses `Music` y `SFX` vía
`AudioServer.set_bus_mute(get_bus_index(...), not value)`. Valores por defecto en `DEFAULTS.audio`
(`music = true`, `sfx = true`); `apply_audio_settings()` corre en el `_ready` del autoload
y en cada cambio de opción.

### 🎚️ Volumen por bus — VolumeBar (2026-06-25)

A la derecha de cada fila (Music/SFX) hay una **`VolumeBar`** (`controls2D/volume_bar/`,
`class_name VolumeBar`), un control de volumen **reutilizable** dibujado como un **ecualizador** (10
segmentos, gradiente verde→amarillo→rojo) que el usuario **clica/arrastra** para ajustar de
**1 a 100** (emite `value_changed`). `settings.gd` crea los dos por código (`_add_volume_bar`),
los habilita/deshabilita según el toggle (`enabled`, el volumen solo ajustable con el audio encendido) y guarda en
`[audio] music_volume` / `sfx_volume`. `apply_audio_settings()` convierte el % a dB
(`_volume_to_db` → `linear_to_db`; 100% = 0 dB) y lo aplica vía `AudioServer.set_bus_volume_db`.
Valores por defecto `music_volume = 100` / `sfx_volume = 100`. El control también aparece por sí solo en la
pantalla **Controls** (el escáner de `controls2D/` encuentra `volume_bar/volume_bar.tscn`).

> **Botones activos "encendidos" (2026-06-25):** `scenes2D/menu/button_pressed.tres` (el estado pressed/activo
> del tema, usado por los radios de ajustes) pasó de un fondo oscuro (hundido) a un **fondo claro +
> borde blanco + glow** → el botón seleccionado destaca como "encendido".

## 🔍 Vista previa de modelo

Como los emisores de los personajes se movieron al bus `SFX`, el audio de la vista previa en la
[[🗿 biblioteca-de-modelos (ES)|biblioteca-de-modelos]] también respeta el mute global de `SFX` — los toggles
locales **Audio** (todo sonido que no sea habla) y **Voices** (solo voz/gritos,
clasificados por nombre vía `_is_speech_audio`) habilitan/deshabilitan la reproducción, y el bus
global puede silenciarlo por encima.

## 🔗 Relacionado

- [[🗿 biblioteca-de-modelos (ES)|biblioteca-de-modelos]]
- [[🎬 fluxo-de-cenas (ES)|fluxo-de-cenas]]
- [[📄 formatacao (ES)|formatacao]]

---
tipo: sistema
projeto: ZIMARO
lang: es-ES
atualizado: 2026-08-07
---

# 🎛️ Controles, remapeo y gestos

> Pestaña **Controles** de la configuración: cada función del jugador y cada animación del modelo
> asignables a una tecla o botón del ratón — y el camino que hace que la animación suene de verdad en
> partida.
> Hermanas: [[🎛️ controles-e-gestos (PT)|PT]] · [[🎛️ controles-e-gestos (EN)|EN]].
> Ver también [[🧍 humanoide-jogavel (ES)]] y [[🎮 player (ES)]].

## ESC en partida abre la configuración

Antes ESC abría directo la confirmación "¿Abandonar la partida?". Ahora abre la **pantalla de
configuración sobre el juego**, que queda **pausado** — eso es lo que deja al personaje ocioso, sin
responder a los mandos y sin seguir recibiendo daño mientras el jugador toca las opciones. La pantalla
corre en `PROCESS_MODE_ALWAYS` para funcionar con el árbol detenido (el mismo patrón que ya usaba la
confirmación).

- **Volver** reanuda el juego justo donde se detuvo (despausa, recaptura el ratón).
- **Abandonar partida** — botón que solo existe en este modo, montado en código — llama a la **misma**
  confirmación de siempre. "Sí" vuelve a la selección de niveles; "No" devuelve al jugador a la
  configuración, con el juego aún pausado.

**Online quedó como estaba** (ESC vuelve al menú): en una sala el árbol no puede pausarse — congelaría
la replicación — y el ESC de las salas ya lo maneja `host_session`/`client_session`, que ni siquiera
reenvían la tecla al nivel dentro del SubViewport.

## Remapeo de acciones

`scenes2D/settings/input_bindings.gd`. Las acciones y sus eventos **por defecto** viven en
`project.godot`; solo lo que el jugador CAMBIÓ va a `Settings.config_file`, sección `bindings` — quien
nunca remapeó mantiene el archivo limpio.

- 14 acciones en cuatro grupos: **Movimiento**, **Combate**, **Cámara**, **Sistema**.
- Pulsar el atajo entra en captura ("Pulsa una tecla…"); ESC cancela. Acepta **tecla o botón del
  ratón**.
- Teclas guardadas por **posición física** (`physical_keycode`), como el resto del proyecto: AZERTY y
  ABNT2 mantienen el mismo sitio en el teclado.
- Los eventos **de fábrica** se guardan en memoria al arrancar, antes de cualquier override — es a
  ellos a los que vuelve el botón **Predet.**, sin reiniciar.
- Un conflicto con otra acción se **acepta con aviso**: quien remapea suele intercambiar dos acciones,
  y bloquear obligaría a limpiar una antes.
- `Settings.load_settings()` aplica los overrides al arrancar; sin eso solo valdrían en esa sesión.

> **Gotcha:** `ConfigFile.get_value(section, key, null)` cuenta como "sin default" y llena la consola
> de errores. El centinela de "no guardado" es un **diccionario vacío**.

## Atajos de animación

`scenes2D/settings/animation_bindings.gd`. La lista **no está escrita a mano**: sale de las
animaciones del propio modelo humanoide, leídas del `.glb` — añadir un clip en Blender ya lo hace
aparecer en pantalla. Son las 36 del rig de 16 huesos en portugués (`ocioso`, `andar`, `rolar_frente`,
`defender_esq`…), el mismo banco que usa FIGArtStudio.

- Persistencia en `anim_bindings`, solo lo que el jugador cambió.
- **Herencia de valores por defecto:** `andar`/`correr` heredan la tecla de `move_forward`, `saltar`
  la de `jump`, `atirar_*` la de `shoot`. Remapear la acción arrastra la animación — es herencia, no
  copia.
- `defender_*` quedó **fuera** de los valores por defecto a propósito: el botón derecho es la
  **puntería** (activa/desactiva), no la defensa; heredar de ella haría que un botón significara dos
  cosas.

## Gestos: cómo suena la animación en partida

Tres decisiones, cada una evitando una forma de salir mal:

1. **El gesto es CAPA, no estado.** Va en un `AnimationNodeOneShot` por encima de la locomoción. Como
   estado, `animate()` — que corre cada frame de física — lo reescribiría al frame siguiente y el
   gesto simplemente no se vería. Medido: el personaje recorre 2,34 m **mientras** suena el gesto.
2. **El evento NO se consume, y la locomoción nunca se vuelve gesto.**
   `ocioso`/`andar`/`correr`/`saltar` son de la máquina de estados
   (`AnimationBindings.is_locomotion`); dispararlas por encima pelearía con el propio andar. Sumado a
   no consumir el evento, es lo que mantiene **WASD intacto** aunque una animación de locomoción
   herede esa tecla. Solo cuenta el **flanco de subida** — mantener pulsado no redispara.
3. **El servidor media.** El dueño reproduce al instante (respuesta) y pide confirmación; el servidor
   **valida que quien pide es el dueño de ese cuerpo** — si no, cualquier peer animaría el personaje
   ajeno — y retransmite a todos. El eco que vuelve al dueño se ignora durante una ventana, para no
   sonar dos veces.

Un personaje sin la capa (el robot, hoy) es un **no-op silencioso**: `supports_gestures()` devuelve
`false`.

## Dónde vive esto

| archivo | papel |
| --- | --- |
| `scenes2D/settings/input_bindings.gd` | acciones: captura, persistencia, aplicación en el `InputMap`, valores por defecto |
| `scenes2D/settings/animation_bindings.gd` | animaciones: lista leída del `.glb`, herencia, consulta por evento |
| `scenes2D/settings/settings.gd` | la pestaña (filas montadas en código), captura compartida, modo pausa |
| `library3D/characters/player/player.gd` | `request_gesture` / `play_gesture` (RPC mediado por el servidor) |
| `library3D/characters/player/player_input.gd` | interceptación de la tecla en el dueño local |
| `scenes3D/level_exit.gd` | ESC → configuración; confirmación de abandono |

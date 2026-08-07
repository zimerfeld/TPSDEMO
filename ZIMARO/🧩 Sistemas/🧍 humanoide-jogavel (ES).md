---
tipo: sistema
projeto: ZIMARO
lang: es-ES
atualizado: 2026-08-07
---

# 🧍 Humanoide jugable

> Tercer personaje seleccionable, con rig y vocabulario de animación PROPIOS — y las costuras que
> convirtieron la clase `Player` de "el robot" en un chasis de personaje.
> Hermanas: [[🧍 humanoide-jogavel (PT)|PT]] · [[🧍 humanoide-jogavel (EN)|EN]].
> Ver también [[🎮 player (ES)]], [[🎛️ controles-e-gestos (ES)]] y [[🧩 templates-de-level (ES)]].

## El bloqueo que definió el diseño

**La velocidad del player no viene del código: viene de la animación.** `apply_input` lee
`get_root_motion_position()` y divide por delta — el cuerpo avanza exactamente lo que avanzó la
zancada, y por eso los pies no patinan. No existe ninguna constante de velocidad horizontal en
`player.gd`.

Medido en los dos `.glb`:

| modelo | hueso `root` en `andar`/`correr` |
| --- | --- |
| `player.glb` | avanza de verdad (`walking_gun` recorre 2,18 m en 1,25 s) |
| `humanoide3.glb` | desplazamiento horizontal **cero** — las animaciones son **in-place** |

Conectado al motor del player, el humanoide movería las piernas **parado en el sitio**. El retarget lo
resolvería (es el camino del FIGArtStudio), pero quedó fuera de alcance por decisión del dueño. La
salida fue **locomoción por velocidad**: `_apply_horizontal_velocity` pasó a ser **virtual** en la
base, el humanoide la sobrescribe, y la cadencia de la animación se escala
(`AnimationNodeTimeScale`) para que el paso encaje con la velocidad real — la misma técnica que usa
`red_robot` en el movimiento manual.

> El cambio **no** bifurca el netcode: `_reconcile` es posicional y agnóstico a la fuente de la
> velocidad, y servidor y cliente-dueño pasan por el MISMO `apply_input`. Sigue siendo un camino,
> parametrizado.

## Las costuras en la clase `Player`

Cuatro puntos ataban la mecánica al robot. Todos con valores por defecto que dejan `player`/`playera`
idénticos:

| antes | ahora | por qué importa |
| --- | --- | --- |
| `player_model.get_node_or_null("Robot_Skeleton/Skeleton3D")` | `skeleton()`, búsqueda por TIPO | `Robot_Skeleton` es la raíz del glTF **dentro** de `player.glb`, no algo autorado. En otro modelo devolvía `null` **en silencio** → personaje sin daño por miembro y sin puntería procedural |
| `shoot_from` por ruta literal | búsqueda por el nombre `ShootFrom` | cada modelo cuelga el punto de disparo de un hueso distinto |
| `model_key`/`head_shape`/… fijos en el método | `@export` (`limb_model_key`, …) | una subclase no podía sobrescribirlos sin reescribir el método entero |
| velocidad del root motion, directa | `_apply_horizontal_velocity` virtual | ver arriba |

## La escena

`library3D/characters/humanoide_jogavel/humanoide_jogavel.tscn`, generada por
`scripts/build_humanoide_jogavel.gd` (volver a ejecutarlo la regenera).

**Carpeta propia, no dentro de `humanoide/`:** la whitelist de replicación exige
`basename == nombre de la carpeta`; fuera de ella el `MultiplayerSpawner` **rechaza en silencio** y el
jugador queda invisible para los demás peers.

**Copia plana, no escena heredada:** el truco de la `playera` (instanciar `player.tscn` + script) no
sirve — Godot no permite reapuntar el `PackedScene` de un nodo heredado, y el modelo es justo lo que
hay que cambiar.

Dos trampas que solo la prueba detectó, ambas silenciosas:

1. **`PlayerModel` ES la instancia de `player.glb`**, no un nodo vacío. Vaciarlo no sirve: el `pack`
   restaura los hijos y la escena salía con los dos modelos (145 huesos del robot en vez de 16). Solo
   se arregla sustituyendo el nodo entero por un `Node3D` con el mismo nombre.
2. **Los hijos añadidos dentro de una instancia** (el `GunBone`/`ShootFrom` en el esqueleto) solo
   sobreviven al `pack` si se marca con `set_editable_instance` — sin eso el personaje nacía sin desde
   dónde disparar.

## Animaciones

Alcance de esta entrega: **`ocioso`** parado, **`andar`** para cualquier dirección (W/S/A/D) y
**`saltar`**. El árbol expone los **mismos nombres de parámetro** que `Player.animate()` ya escribía
(`parameters/state/transition_request`, `walk`/`strafe` `blend_position`, `aim/add_amount`), así que
no cambió ni una línea de ese código.

Dos trampas de `AnimationTree` registradas: `walk`/`strafe` **tienen** que ser `BlendSpace2D` (el
código escribe `Vector2`; uno 1D lo rechaza cada frame y la salida se congela), y los puntos
**colineales** degeneran la triangulación — de ahí los cuatro puntos cardinales.

## Números a ajustar a ojo

`MAX_SPEED = 5,2 m/s` y la altura de cámara `1,72 m` son **estimaciones**. Una constante cada uno.

## Registro en la selección

`PlayerSelection.VARIANTS` y `chooseplayer.CHARACTERS` deben mantener el **mismo orden** — lo que
viaja por la red es el **índice**. Añadir siempre al final; insertar en medio hace que el jugador
nazca con el cuerpo equivocado en todos los peers, y el clamp lo oculta.

La vista previa de la pantalla dejó de estar fijada a `player.glb`: cada personaje declara `model_glb`
e `idle_anim` (el robot descansa en `Idlecombatrest`; el humanoide, en `ocioso`).

**Bug corregido de paso:** la Label del nombre entraba en el árbol con el texto `"PLAYER"`, que
`Locale` congela como fuente — cambiar de idioma revertía el nombre a "PLAYER". Resuelto poniendo el
nodo en el grupo de traducción manual (un nombre propio es dato, no material de diccionario).

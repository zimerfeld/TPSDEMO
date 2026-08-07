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

## Orientación, velocidad y cadencia (2026-08-07, tras la prueba)

**Giro de 180°.** El glTF del humanoide fue autorado mirando al lado OPUESTO al del player: con el
mismo transform de nodo, su malla caminaba de espaldas. La corrección es `rotation.y = PI` en el nodo
del MODELO (en el generador), no en la lógica — así la dirección de movimiento, la puntería y el punto
de disparo siguen hablando el mismo idioma que el player y el red_robot.

> Medir el ángulo del NODO no delata esto: los transforms de humanoide y player eran iguales. Lo que
> difiere es hacia dónde apunta la MALLA dentro del `.glb`. Es un caso que solo el ojo detecta — lo
> encontró una prueba de juego, no las pruebas automatizadas.

**La animación parecía apresurada** porque la cadencia valía `velocidad / 1,45` con techo **2,6×**: a
5,2 m/s tocaba el techo y reproducía un clip de CAMINATA a casi el triple de velocidad. Dos cambios lo
resolvieron:

1. El estado `walk` pasó a ser una progresión **parado (0) → `andar` (0,45) → `correr` (1,0)**.
2. La cadencia divide por la velocidad que el clip REALMENTE representa, medida por la duración del
   ciclo: `andar` 1,10 s ≈ **1,4 m/s**; `correr` 0,85 s ≈ **4,0 m/s**.

Medido después: caminando 1,70 m/s con cadencia **1,21×**; corriendo 4,50 m/s con **1,12×**. El rango
permitido quedó estrecho (0,75–1,3) a propósito — necesitar 2× indica que suena el clip equivocado.

## Correr, agacharse y el lado de la mira

| tecla | efecto |
| --- | --- |
| **SHIFT** (mantener) | corre: 4,5 m/s y clip `correr`. Al soltar, camina a 1,7 m/s con `andar` |
| **CTRL** (mantener) | se agacha: `ajoelhar_dir` o `ajoelhar_esq` **según el lado de la mira**; al soltar aborta el gesto |
| **C** | alterna el hombro de la mira y RECUERDA la elección (`Settings → reticle_side`) |

Las tres son acciones remapeables en la pestaña Controles. **`running` y `crouching` se REPLICAN**:
sin eso el servidor simularía caminata mientras el cliente corre, y la reconciliación corregiría una
divergencia que es solo de input — el mismo mecanismo que produce el "flickering".

El lado de la mira se aplica **después** de la animación de cámara, espejando la X del `SpringArm3D`:
el clip de mira sigue siendo único, solo cambia de hombro.

## Estado vs. evento: que repite, que mantiene, que ocurre una vez (2026-08-07)

La prueba de juego encontro tres defectos que son, en el fondo, **la misma confusion**: tratar como
evento lo que el cuerpo entiende como estado. Mantener W daba UN paso y paraba; CTRL se arrodillaba
en bucle; y saltar corriendo reproducia el salto parado.

**Causa raiz del primero:** el importador de Godot solo activa el bucle por su cuenta en clips con
sufijo `-cycle` -- convencion del `player.glb`. Los 36 clips del humanoide llegan **todos** como
`LOOP_NONE`, asi que `andar` (1,10 s) sonaba una vez y se congelaba con la tecla aun pulsada.
`_ensure_locomotion_loops()` marca los ciclicos en codigo y no en el `.import`, para que valga en
cualquier maquina sin depender de que alguien recuerde reimportar el `.glb`.

El vocabulario pasa a dividirse en tres naturalezas:

| naturaleza | clips | comportamiento |
| --- | --- | --- |
| **ciclico** | `ocioso`, `andar`, `correr` | repite mientras la tecla este pulsada |
| **postura** | `ajoelhar_dir`/`_esq` | baja una vez y **congela** hasta soltar CTRL |
| **evento** | `levantar_*`, `saltar*`, gestos | suena una vez, termina y devuelve el cuerpo a la locomocion |

### La trampa del OneShot (medida, no deducida)

El primer intento de mantener la pose fue un `AnimationNodeTimeScale` en la rama del gesto, puesto a
cero al final del clip. **No funciono:** `AnimationNodeOneShot` mide su propio progreso por el tiempo
transcurrido desde el disparo, no por el tiempo de la subrama -- congelar el subtiempo no le impide
terminar. Medido: `escala=0.0` pero `capa_activa=false`, es decir, la pose congelada ni siquiera se
estaba mezclando en la salida.

La salida combina ambas piezas: el clip de postura entra en **bucle** (es lo que mantiene viva la capa
de gesto, ya que un clip que termina cierra el OneShot) y el **TimeScale a cero** justo antes del
final impide que empiece el segundo ciclo. El jugador ve el cuerpo bajar y quedarse ahi; nunca ve la
repeticion. El margen (`GESTURE_HOLD_MARGIN`) importa: sin el, un fotograma de retraso rebobinaria la
pose al inicio del movimiento y el cuerpo volveria a ponerse de pie.

**Quien decide mantener es QUIEN DISPARA, no el nombre del clip.** La primera version usaba una lista
de "clips que mantienen" (`hold_gestures`), y la revision encontro el agujero: la pestana Controles
lista los 36 clips e invita al jugador a asignar cualquiera a una tecla -- `ajoelhar_dir` incluido.
Disparado desde ahi, la congelacion no tenia quien la deshiciera y **bloqueaba al personaje para
siempre**, en todas las pantallas. Hoy `hold` es un parametro de `request_gesture()`: CTRL pide
postura, el atajo pide gesto. El mismo clip sirve a ambos, y hasta el `loop_mode` se ajusta en el
disparo segun el uso.

**El reloj de la congelacion tiene que parar junto con la animacion.** `SceneTree.create_timer()`
nace con `process_always = true`: abrir la configuracion (que pausa el arbol) a media agachada dejaba
el clip detenido en la bajada mientras el temporizador seguia corriendo -- al volver, el cuerpo
quedaba atrapado a medio agachar. Corregido pasando `process_always = false`.

Soltar CTRL dejo de **abortar** el gesto y pasa a reproducir `levantar_*` -- abortar hacia que el
cuerpo saltara de vuelta a la locomocion sin levantarse. Y el `levantar` usa el lado en que el cuerpo
SE AGACHO, no el lado de la mira al soltar: cambiar de hombro a media agachada hacia que el modelo
diera un tiron, cambiando de rodilla antes de ponerse de pie. Quien muere agachado tambien se levanta
-- `respawn()` deshace la postura, o el personaje renacia congelado en ella.

### La leccion que sirve para el proximo personaje: `apply_input` NO corre en quien observa

`Player._physics_process` tiene tres ramas. Servidor y cliente-dueno llaman a `apply_input`; **el peer
que solo MIRA cae en el `else`** y ejecuta solo `motion = net_motion`, la interpolacion y
`animate(current_animation, delta)`. Todo lo que se escriba dentro de `apply_input` sencillamente **no
existe** en la pantalla de los demas jugadores.

Fue exactamente lo que le paso al blend de locomocion. El espacio nuevo cambio `{0 = ocioso, 1 =
andar}` por `{0 = ocioso, 0,45 = andar, 1,0 = correr}`, y la eleccion entre 0,45 y 1,0 vivia en el
calculo de velocidad -- dentro de `apply_input`. En el observador quien escribia el blend era la clase
base, con la INTENSIDAD cruda del movimiento; e intensidad plena, en el espacio nuevo, significa
`correr`. Resultado medido: **el personaje caminaba en la pantalla del dueno y corria, con los pies
patinando, en todas las demas** -- lo contrario de lo que prometia la entrega, e invisible en una
prueba de una sola ventana, porque en el host el servidor corre `apply_input` para todos.

La correccion fue mover la escritura a `animate()`, el unico punto por el que pasan las tres ramas. La
regla que queda: **lo que decide que clip se ve tiene que escribirse en `animate()`**; `apply_input`
es solo para lo que mueve el cuerpo. Por eso `running` y `crouching` se replican -- sin ellos el
observador no tendria como decidir igual.

El mismo razonamiento vale para el **salto contextual**: `saltar` (parado), `andar_saltar_*` y
`correr_saltar_*` ya existian en el `.glb`, y la eleccion se hace en el FLANCO de la subida, que llega
al observador por el RPC `jump()` -- por eso paso a ser `reliable`. El **lado es fijo** (`dir`):
`aim_side` es local al dueno y no se replica, asi que cada peer elegiria uno y el mismo salto saldria
con la pierna cambiada en cada pantalla. El agachado si puede usar la mira porque alli lo que viaja
por la red es el **nombre del clip**.

### El lado de la mira: una propiedad que controla la animacion

`_apply_aim_side()` refleja la X del `SpringArm3D` -- pero esa X la escribe una **animacion de
camara** en cada toggle de mira. Aplicar el espejo solo al pulsar fallaba por dos motivos a la vez:
fuera de la mira la X vale 0 (y `0` reflejado sigue siendo `0`, asi que la primera C nunca hacia
nada), y el siguiente toggle regrababa la X, borrando la eleccion. Hoy el espejo se reaplica **cada
fotograma**, al final del `_process`, con `process_priority = 10` para correr despues del
`AnimationPlayer` de la camara.

La preferencia tambien pasa a **leerse**: `reticle_side` se grababa en el archivo de configuracion y
nunca se leia, aunque los READMEs de los tres idiomas prometian que la eleccion se recordaba.

### La postura y quien llega despues

La pose vive en estado local del arbol de animacion, instalada por un RPC. Quien entra en la partida
DESPUES nunca recibio ese RPC y veia de pie a un jugador agachado. Como `crouching` se replica **en el
paquete de spawn**, el `_ready` de `player_input` reconstruye la pose -- y solo localmente
(`play_gesture_here`), porque reanunciarla rebotaria al servidor y el disparo saldria doble.

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

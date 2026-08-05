# ZIMARO — Documentación completa (Español)

> Documentación detallada y extensa en español. Para el resumen bilingüe de alto nivel consulta
> [README.md](README.md); la versión completa en inglés es [README.en-US.md](README.en-US.md) y la
> versión completa en portugués es [README.pt-BR.md](README.pt-BR.md).
> El vault [`ZIMARO/`](ZIMARO) replica este contenido con notas por sistema.

ZIMARO es un sandbox de disparos en tercera persona creado con [Godot Engine](https://godotengine.org).

[![GitHub stars](https://img.shields.io/github/stars/zimerfeld/ZIMARO?style=for-the-badge&logo=github)](https://github.com/zimerfeld/ZIMARO/stargazers) &nbsp; [![GitHub downloads](https://img.shields.io/github/downloads/zimerfeld/ZIMARO/total?style=for-the-badge&logo=github&label=Downloads)](https://github.com/zimerfeld/ZIMARO/releases)

Este juego se desarrolla y mantiene en mi tiempo libre. Si disfrutas de ZIMARO, un patrocinio ayuda a que sigan llegando nuevas funciones y correcciones. 💜

[![GitHub Sponsor](https://img.shields.io/badge/Sponsor-zimerfeld-EA4AAA?style=for-the-badge&logo=githubsponsors&logoColor=white)](https://github.com/sponsors/zimerfeld) &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; [![Ko-fi](https://img.shields.io/badge/Ko--fi-Buy%20me%20a%20coffee-FF5E2B?style=for-the-badge&logo=ko-fi&logoColor=white)](https://ko-fi.com/C0D621FCGD)

## Visión general

Construido sobre [Godot Engine](https://godotengine.org), ZIMARO es un pequeño sandbox de
disparos en tercera persona. A grandes rasgos ofrece:

- **Flujo guiado por menús** — un menú principal conduce a la selección de personaje, un selector
  de niveles, una pantalla de ajustes, una pantalla de desarrollador y el juego en línea.
- **Elementos visuales de pantalla y diálogos** — cada pantalla 2D lleva su propio **fondo de shader
  animado** ligero que evoca su propósito: una **rejilla de escenario** que se aleja (Niveles), una **red
  de nodos conectados** (Jugar en línea), un **ecualizador** (Ajustes) y un **plano técnico de desarrollo** con un barrido de escaneo
  (Desarrollador). La pantalla **Jugar en línea** también enmarca su borde (margen interior) con un **grueso
  cable de metal trenzado** por el que corren lentamente **dos pulsos de intensa energía eléctrica** (núcleo blanco incandescente, bloom pulsante
  y chispas ramificadas), **reflejados sobre el
  eje vertical** (se separan en la parte superior y se reencuentran en la inferior), con **chispas de
  rayo/trueno** crepitando a lo largo. Todas las
  **ventanas de confirmación/alerta se construyen sobre un único control de ventana flotante reutilizable**
  (`FloatingWindow`, una escena de `controls2D`) — texto centrado, botones de igual anchura, un cierre × estándar y un
  fondo modal — creado por el helper `FloatingDialog`; la misma base que otras ventanas flotantes pueden reutilizar.
  La **ventana de error global es recuperable**: cerrarla (× / ESC / **Atrás**) simplemente devuelve el foco a la
  escena que la invocó — un error de puerto/conexión o de validación **nunca cierra el juego** (con una opción **Reintentar**
  cuando tiene sentido).
- **Personajes jugables** — variantes de jugador seleccionables que se mueven, apuntan, saltan y disparan,
  con control de cámara en primera persona y un HUD de salud local. El **salto es más alto** y la **cadencia de
  disparo más espaciada**; el **disparo ahora solo sale después de que la puntería se asiente** (una vez que la animación de puntería
  termina), desde la punta del cañón — corrigiendo el fallo por el cual, en el jugador **cliente**, la bala
  parecía salir antes de la puntería / fuera del cañón.
- **Bots aliados (fuego de cobertura)** — jugadores de la **facción amiga** (generados como `bot_controlled` por
  las plantillas de nivel) dan **cobertura y asistencia** al jugador humano: se enfrentan a las amenazas cercanas al
  bot o al jugador, pero **siguen al jugador** y permanecen dentro de una **correa** — cuando se alejan demasiado,
  reagruparse tiene prioridad sobre perseguir, de modo que **ya no salen corriendo hasta caerse del
  mapa**. Sus comportamientos (seguir al escuadrón, priorizar enemigos, espaciado de combate, presión por el flanco…) viven en
  un script de IA dedicado (`library3D/characters/players/player/IA/player_bot_ai.gd`).
- **Plantillas de nivel (Template Manager)** — cada fila de nivel en la pantalla de Niveles tiene un **botón de
  plantilla** que abre el **Template Manager** (una ventana flotante **desplazable**, también accesible desde
  el gestor de salas del host): plantillas de generación con nombre por nivel, cada una con entradas que definen
  **modelo**, **facción** (amiga/enemiga/neutral), **cantidad** y **colocación**
  (coordenadas explícitas, área aleatoria o formación de combate). **"Guardar y aplicar"** activa
  la plantilla, aplicada cuando el nivel comienza (en solitario o como sala en línea). Funciona igual en el
  editor y en el **.exe exportado**: el escáner de modelos resuelve los nombres `.remap` que produce la exportación
  (mismo patrón que la pantalla Models), guardar una **nueva** plantilla almacena el id generado (de modo que
  activar justo después de guardar funciona y volver a guardar nunca la duplica), y el nombre de la plantilla **sobrevive**
  a los refrescos de añadir/quitar entradas. El modelo de cada entrada se elige mediante **navegación en cascada por carpetas**:
  un desplegable por cada nivel de carpeta de la biblioteca (`characters/` → `enemies/` → `red_robot`,
  por ejemplo), descendiendo solo por las carpetas que contienen modelos — al llegar a una carpeta de modelo se
  rellenan los campos modelo/escena de la entrada. El formulario está **ordenado para facilitar la lectura**: los
  campos específicos de colocación se agrupan en un panel titulado **"Opciones de colocación"** que muestra solo
  los campos del modo elegido (coordenadas / centro + tamaño aleatorios / formación + origen + espaciado),
  los campos numéricos (cantidad, espaciado, rotación) son compactos, y la ventana se ajusta a su contenido para que
  los controles ya no se estiren de borde a borde.
- **Scenery Manager** — hermano del Template Manager con su propio botón junto a cada nivel:
  misma ventana y campos (menos Facción), explorando la biblioteca **`library3D/sceneries`** (accesorios de
  escenario: **caja magenta, esfera esmeralda y píldora ámbar** — geometrías volumétricas básicas con
  materiales emisivos, su propia luz y colisionadores siguiendo el concepto LimbColliders/miembro-BODY,
  configurables en la pantalla Models). Un nivel puede tener una plantilla de personajes **y** un
  escenario activos al mismo tiempo, aplicados en el juego en solitario y en las salas en línea.
- **Entornos de arena (llamativos, baratos por diseño)** — cada nivel trae su propia atmósfera cyberpunk:
  un **cielo procedural con degradado**, **niebla de distancia** exponencial y un **suelo de rejilla de neón**
  emisivo (un único shader compartido, `themes/level_grid_floor.gdshader` — matemática pura por píxel, sin
  texturas, con un desvanecimiento por distancia que elimina el moiré del horizonte), cada uno con una identidad de color por nivel
  (**Nivel 1 = cian**, **Nivel 2 = atardecer ámbar**, el mismo lenguaje de color que las pantallas de sesión
  Host/Cliente). Construido según el objetivo de rendimiento del proyecto — **más de 60 FPS en hardware
  gráfico mínimo** — para que luzca llamativo con un coste de GPU casi nulo; el brillo de la rejilla es pura emisión, así que
  funciona con Bloom desactivado y gana un halo de neón gratis cuando se activa Bloom en Ajustes.
- **Enemigos** — un enemigo terrestre (Red Robot) que se aproxima, apunta y dispara una **bola de cañón**
  negra (una versión recoloreada y con brillo rojo del disparo del jugador), y un bombardero
  volador (Criatura Alada) que orbita al jugador y suelta bombas.
- **IA del Red Robot** — sus comportamientos y decisiones en tiempo de ejecución viven en un script de IA dedicado
  (`library3D/characters/red_robot/IA/red_robot_ai.gd`): **recarga 1,5× más rápida** (primer disparo y
  disparos siguientes); **abre fuego** en cuanto el jugador entra en el alcance del arma y está a más de
  10 m; y si el jugador se acerca a **10 m o menos**, el robot **huye en la dirección opuesta**
  mientras sigue encarando/apuntando y disparando al jugador. Cada robot se mueve
  **individualmente** (su propio signo de desplazamiento lateral, fase y velocidad, sembrados al generarse) de modo que el escuadrón **no
  marche al unísono a cada segundo**, y mantiene una **formación holgada** (ahora aún **menos rígida** — el
  punto de formación "respira" en una deriva lenta en lugar de converger en coordenadas fijas). El **movimiento
  manual** (desplazamiento lateral/retirada/formación) ahora **ajusta la cadencia de la animación a la velocidad real** → los
  enemigos **ya no "patinan"** (sus pies respetan el ritmo de la marcha). Sus **velocidades de movimiento están
  calibradas a estándares humanos reales** (caminar ~1,4 m/s, trotar ~3, correr ~4,5): desplazamiento lateral 2,4 m/s,
  reposicionamiento de presión 3,2 m/s y retirada 3,8 m/s, con **aceleración suave** (la velocidad converge
  en lugar de saltar) para un movimiento con peso y creíble. Cada enemigo apunta al **jugador más
  cercano** dentro de su radio de alerta — **cualquier enemigo puede disparar a cualquier jugador** que entre en el radio
  (multijugador). La **Criatura Alada** varía su **altura de vuelo suavemente**: **desciende** hasta un
  límite para bombardear con más precisión y **asciende** hasta un límite para **escapar** cuando recibe fuego. También hay
  un **marcador de facción** por modelo (hostil / neutral / aliado) — base para futuros personajes **neutrales**
  que solo se defenderían al ser amenazados.
- **HUD de enemigos** — la *barra de jefe* compartida en la parte superior de la pantalla muestra el nombre, la salud y la distancia del enemigo y,
  cuando el enemigo tiene un mecanismo de ataque/disparo, también su **alcance de arma en metros**.
  Aparece cuando **apuntas al enemigo** y se oculta en el momento en que tu puntería lo abandona; el rayo de puntería
  reconoce tanto el cuerpo como los **colisionadores de miembro/submiembro** — de modo que apuntar a un **submiembro
  sobresaliente** (p. ej. las protecciones de las piernas) también revela la salud del enemigo.
- **Cuerpo físico por modelo** — la cápsula de locomoción (bloqueo físico entre personajes) se
  **ajusta automáticamente a cada modelo** a partir de sus colisionadores de miembro (radio a partir de la huella en pie, altura
  a partir de la extensión total), en lugar de un único valor por defecto creado a mano para todos. Sigue siendo una única forma barata e
  independiente de la animación por personaje — física estable y networking determinista.
- **Daño localizado** — colisionadores 3D nativos por miembro dimensionados a la malla de cada personaje, de modo que los impactos en
  distintas partes del cuerpo infligen distinto daño (los disparos a la cabeza infligen extra). Los miembros provienen del
  **plan corporal** del modelo, elegido por un `body_type` (**biped** = cabeza/torso/2 brazos/2 piernas — el
  valor por defecto; **quadruped** = cabeza/torso/4 piernas; **crawler** = solo cabeza/torso), clasificados por la
  jerarquía `BodyParts` a través de la fábrica `BodyPlans` — que reconoce nombres de hueso en **inglés o
  portugués** (`head`/`cabeca`, `chest`/`peito`, `upper_arm.R`/`bracoDireito`…), así que un modelo nuevo
  se clasifica sin renombrar su esqueleto. Los disparos atraviesan el colisionador de cuerpo genérico
  para impactar en los colisionadores de miembro. **Extremidades con daño propio** — antebrazo, mano,
  espinilla y pie pasan a ser **submiembros automáticos** (el miembro grande queda solo con el brazo
  superior / el muslo), cada uno con colisionador y bonificación de daño propios; sin valor definido
  **heredan el del BRAZO/PIERNA** al que pertenecen — se puede acertar "la mano", no solo "el brazo".
  Los personajes ya balanceados (**Player** y **Red Robot**) quedan fuera de esta subdivisión y mantienen
  el hitbox de miembro entero. Los **submiembros** — partes sobresalientes que obtienen su PROPIO colisionador de caja
  (p. ej. las **placas de protección de la pierna trasera** del Red Robot y las **placas de hombro** del jugador, que la
  cápsula de miembro no envolvería) — ahora son **editables en la pantalla Models** (añadir/quitar + un % de bonificación
  cada uno), no codificados a mano; cada parte se agrupa y etiqueta bajo el miembro al que pertenece por su nombre
  (p. ej. "PLACA BRAÇO E", "PLACA PERNA D"), incluso cuando está unida a otro hueso del esqueleto.
  El multiplicador por miembro es **por modelo y editable en la pantalla Models**: cada miembro/submiembro
  se edita en una **ventana flotante arrastrable** (barra de título + **×**, estilo Windows) que contiene un **ÁRBOL**:
  cada miembro es una rama, sus submiembros son hojas debajo de él (p. ej. "↳ PLACA BRAÇO E" bajo
  "BRAÇO E"). Columnas: Nombre | Set (marca) | Bonificación % | Propietario; cada hoja de submiembro lleva un **botón de
  papelera a la derecha de su nombre** para eliminarlo en el sitio (con un diálogo de confirmación; sustituyendo al
  antiguo botón de pie "Quitar submiembro"). **No se requiere ningún valor** — sin su
  propio valor, un submiembro **hereda el del miembro propietario**, y luego el valor por defecto del plan. El **propietario** se
  elige **explícitamente** (solo agrupación lógica — nunca cambia la malla; reasignar pide confirmación). Todo se
  guarda en **un archivo por modelo, en la carpeta propia del modelo**
  (`library3D/<cat>/<model>/limb_config.json` — valores de daño, offsets/escalas + la relación de propietario/herencia de cada
  submiembro; como `res://` es de solo lectura en el `.exe` exportado, las ediciones en el juego van a una
  sobrescritura escribible `user://limb_config/<model>.json` que tiene precedencia de lectura; migra desde el antiguo
  `data/limb_config/<key>.json` / combinado `data/limb_config.json`) y se lee en tiempo de ejecución vía `LimbConfig`; el multiplicador
  por defecto proviene del plan corporal (cabeza +50%, resto ×1). Las formas de los colisionadores son por modelo — p. ej. el
  **red_robot** usa un **torso esférico** y una **cabeza más grande** (`torso_shape`/`head_scale` en
  `LimbColliders`). **Miembro `CORPO` de reserva** — todo modelo sin miembro clasificado (p. ej.
  **Structures** como las estatuas de bronce, o un rig cuyas mallas no coinciden con el plan) obtiene un único
  miembro **CORPO** en la pantalla Models que envuelve todo el modelo (caja por defecto), de modo que
  siempre se pueda definir un colisionador/daño; el desplegable **Miembro** ahora se muestra para **cualquier categoría** en
  "Modelo completo".
- **Disparo reutilizable** — el disparo de bala de cañón y de láser hitscan se aíslan en
  componentes reutilizables (`CannonShooter` / `LaserShooter` en `effects_shared/`) que cualquier modelo
  puede usar; el jugador y el Red Robot disparan ambos mediante `CannonShooter`. La transformación de la boca del cañón de la bala se
  hornea **antes** de que entre en el árbol, de modo que su generación en red aterriza exactamente en el arma en los clientes remotos
  (sin desplazamiento fuera del cañón); y el rayo de puntería ahora **excluye el propio cuerpo/miembros del tirador**
  e ignora los impactos a quemarropa, de modo que apuntar y disparar rápidamente ya no envía un disparo al cielo.
- **Múltiples niveles** — una arena sencilla (Nivel 1) y un encuentro con bombardero (Nivel 2), además del
  **juego en línea basado en salas**: la pantalla **Jugar en línea** tiene dos
  botones que eligen el rol. **Gestionar salas** abre el gestor de salas (`host_session`), donde
  inicias uno o más niveles como salas aisladas y, por sala, **Jugar** (tras el selector de personaje,
  entra en ella como jugador), **Observar** (cámara de vuelo libre sin colisión), **Reiniciar** o **Detener**.
  Ambos envían un **aviso distinto a los clientes de la sala**: **Detener** finaliza la sala y los devuelve
  al navegador con "El nivel fue detenido por el host"; **Reiniciar** recarga el nivel de cero y envía
  "El nivel fue reiniciado por el host" (la sala reconstruida reaparece en la lista para volver a unirse). Tras un
  reinicio, el host permanece en la cuadrícula de gestión con el ratón libre (igual que al iniciar un nivel).
  **Unirse a salas** abre el navegador de salas (`client_session`), que lista las salas en ejecución con un botón **Jugar**
  (mostrado solo mientras la sala existe) que te lanza a la sala elegida tras el selector de personaje.
  La variante/color elegidos de cada jugador se muestran para todos los que están en línea (loadout por par), y el
  **nombre** de cada jugador flota como una etiqueta 3D sobre la cabeza de los **otros** jugadores — nunca sobre la tuya,
  cuyo nombre se sitúa en la parte superior de tu HUD de HP local. Los demás jugadores/enemigos se suavizan con un
  **búfer de interpolación con marca de tiempo** para una vista de cliente sin parpadeos y a alto FPS. La pantalla Jugar en línea también tiene un selector de **Optimización** aplicado antes de hostear/unirse:
  interpolación **Suave / Equilibrada / Reactiva** (retardo de render 100 / 60 / 35 ms — suavidad vs.
  reactividad), **tasa de sincronización 30 / 60 Hz** (actualizaciones servidor→cliente por segundo) y **render del host
  Ventana / Servidor puro** (omitir el renderizado de la sala para liberar la GPU). Todos los modelos dinámicos (jugadores, enemigos,
  balas, bombas) se replican desde el servidor host. La pantalla Jugar en línea persiste cada opción (último
  Puerto/IP, interpolación, tasa de sincronización, render del host) y las restaura la próxima vez; el desplegable **IP/Dominio**
  lista las direcciones recientes **y los dominios completos guardados** (los FQDN se mantienen aparte, no se mezclan con las
  IP recientes) para volver a seleccionarlas más tarde; las pantallas Host/Cliente
  son a pantalla completa, en línea con el resto de la interfaz.
- **Biblioteca + visor de modelos 3D** — recursos 3D reutilizables organizados por tipo bajo `library3D/`,
  explorables en el juego a través de la pantalla Models (categoría → modelo → parte) con interruptores, en
  orden, para rotación, **Animação**, **Efeitos especiais** (todo lo vinculado al modelo
  que ningún otro interruptor cubre — partículas, luces, mallas de láser/boca montadas en huesos),
  **Audio** (todo sonido que el modelo emite — movimiento, motor, disparos, explosiones, voces),
  **Colisores de Membro** / colisionadores de miembro (con el interruptor activado y un miembro/submiembro aislado, muestra el gizmo
  translúcido de ese colisionador — **miembros en azul claro, submiembros en morado claro**), **etiquetas de miembro** (un interruptor propio del navegador para las etiquetas "Membro: …" sobre cada
  colisionador — en **azul oscuro** — independiente de la pantalla Debug 3D — con, justo debajo del interruptor **Membro**, un interruptor **Esqueleto**
  que hace flotar la etiqueta **naranja oscuro** "Esqueleto: \<name\>" del hueso suelto elegido sobre él, además de líneas extra de Type/Name/ID), **Colisores de Esqueleto** (en el modo "All members" → filtro "Skeleton", resalta la
  región del hueso suelto elegido — o todas ellas — con una caja translúcida **naranja claro**), **Submembros** (etiquetas flotantes
  **morado oscuro** "Submembro: \<name\>" — sobre el submiembro elegido en el desplegable, o sobre **todos** los
  submiembros a la vez en el modo "Todos os Sub-membros") y **Colisores de Submembros**
  (muestra el limbcollider del submiembro seleccionado — o todos ellos en "Todos os Sub-membros"). Los selectores son **tres
  desplegables** — **Membro** (miembro), **Sub-membro** justo debajo (con una opción **"Todos os Sub-membros"** para mostrarlos
  todos a la vez) y, solo en el modo **"Todos os membros"**, **Esqueleto** (huesos sueltos), que se sitúa debajo de Sub-membro.
  Elegir un elemento **real** (no "Selecione…"/"Todos") en cualquiera de los tres revela, **a su derecha**, un
  **desplegable de geometría de colisionador** (esfera/caja/cápsula) y abre una **ventana flotante reutilizable** (el `FloatingWindow`
  de controls2D) con **Offset, Rotación (grados) y Escala** X/Y/Z, titulada con el nombre del elemento: cada cambio **persiste al instante**,
  se muestra en el modelo y se **relee cuando un personaje se genera**. Cada desplegable de geometría sigue la misma regla:
  **carga la última elección guardada**; con **ninguna elección guardada autodetecta** la forma a partir de la forma de la parte
  (alargada → cápsula, redonda → esfera, si no caja); y **"Selecione…" significa sin limbcollider**. "Selecione…" en un
  **miembro** elimina su colisionador; en un **submiembro** **suprime** el colisionador pero **mantiene el submiembro**
  en el árbol/desplegable de Daño para que puedas reconfigurarlo (la eliminación total sigue en el icono de papelera). Para un **hueso suelto**
  (Esqueleto), una forma elegida solo **previsualiza** el colisionador mediante el interruptor **"Colisor de Esqueleto"** y
  "Selecione…" lo oculta; el hueso **no** se promueve a submiembro (la promoción se queda en "Añadir submiembro" de la ventana de Daño),
  y los esqueletos no llevan daño, por lo que se **ignoran en las escenas de nivel**. Cuando se selecciona un
  **submiembro** específico, el desplegable de geometría del **miembro** se oculta (el del submiembro toma el relevo). Los
  colisionadores de los miembros se muestran **solo** con **Membro = "Todos os membros"** (en "Modelo completo"/"Selecione…" no se muestra
  ninguno). La **pantalla Dano (Daño)** no está en la lista de interruptores: se abre desde el **botón "Dano"** (a la derecha del botón "Voltar"/Atrás) — una
  **ventana flotante arrastrable** con un fondo negro opaco (barra de título "Dano" + cierre ×) que contiene un **árbol** de
  la bonificación % de cada miembro/submiembro, donde también añades/quitas colisionadores `PART_*` sobresalientes (que **mantienen el
  nombre original del hueso** al añadirse a un miembro propietario) y estableces el **miembro propietario** de cada uno. Cada interruptor es el interruptor maestro de su categoría (no se
  reproduce ningún sonido/animación mientras su interruptor está apagado — incluido el sonido impulsado por pistas de animación) y
  los estados de los interruptores se persisten entre visitas (con la excepción del panel de daño — se abre cerrado, pero la
  **última posición** de la ventana de daño se recuerda y se restaura al reabrir). Una
  animación se reproduce solo cuando **el interruptor está activado Y hay un clip
  elegido** en el desplegable "Animação" (ya no hay autorreproducción de clip por defecto). Los
  desplegables "Animação" y "Efeitos Especiais" aparecen solo para la vista de "Modelo completo"
  ensamblado. "Efeitos Especiais" lista, justo después de "Selecione…", una opción **"Todos"** y muestra todos los
  tipos de efecto que el modelo tiene (luces/luminosidad, humo, partículas, decals, niebla…); elegir uno
  aísla un único efecto. Elegir un
  valor en cualquier selector (Categoria → Modelo → Malha) reinicia todos los desplegables inferiores a
  "Selecione…". **Cada elección de
  selector se persiste** (junto con los interruptores), y reabrir la pantalla restaura la
  cadena exactamente como se dejó — sin autoseleccionar ningún elemento: el primer selector sin elección
  guardada se queda en "Selecione…" listo para continuar, y si una elección guardada ya no existe en la
  biblioteca, ese selector (y los inferiores) se deshabilitan. La navegación se guía puramente por el
  bloqueo secuencial de los desplegables (sin línea de estado). Arrastra con el **botón izquierdo** para rotar a mano el
  modelo hasta 180° en ambos ejes, y con el **botón derecho** para **mover la cámara** (pan) — llevando al
  centro una parte fuera del encuadre (una mano, un pie) sin tener que rotar y alejar. El pan funciona al
  estilo "agarrar la escena" (el punto bajo el cursor sigue el arrastre, con la misma sensación en cualquier
  zoom), está limitado para que el modelo nunca salga de la vista y se recentra al cambiar de modelo; la
  rueda del ratón sigue haciendo zoom. Rotar y mover **se congelan** mientras el puntero está sobre una ventana flotante —
  Daño/IA o cualquier otra — y se reanudan cuando la abandona o la ventana se cierra. Un **gizmo de ejes 3D**
  (estilo editor: X rojo, Y verde, Z azul, con una bola y una letra en cada punta) se sitúa **arriba a la
  derecha** — en su propio SubViewport superpuesto, a la izquierda de los interruptores, sin cubrir el modelo — y
  **rota junto con el modelo**, mostrando su orientación. Activar cualquier opción actúa sobre la previsualización en vivo en el sitio — nunca
  recarga el modelo ni cambia la cámara/rotación. Para Personagens y Armas, una
  **pila de tooltips de miembro** flota sobre el colisionador de cada miembro: cada línea tiene su **propio color**
  (Membro = azul cian, Tipo = naranja, Nome = verde, ID = amarillo), **el mismo color aplicado al
  interruptor** que la activa, y las pilas de distintos miembros **nunca se solapan** — cuando irían a
  colisionar en pantalla, una se empuja a otra posición (cada conjunto se mantiene entero, "uno debajo del otro").
  Impulsado por los interruptores dedicados **propios** de la pantalla Models (interruptores Membro + Tipo/Nome/ID) —
  la escena Models está totalmente desacoplada del overlay global **Debug 3D** (su raíz está en el
  grupo `no_debug_overlay`), de modo que Debug 2D/3D solo afectan a los niveles de juego reales. Al estar exenta del
  overlay global, solo Debug 3D queda limitado a los niveles de juego (Debug 2D ahora se aplica en todas partes). El
  nombre de la escena se muestra mediante la **marca de agua global** en la **esquina superior derecha, junto al título de la escena** (desde
  `debug_overlay.gd`); la antigua etiqueta LOCAL permanece oculta (no se muestra en la ventana de daño). Los personajes con skin
  se enmarcan/centran a partir de sus colisionadores posados de modo que giran en el sitio en lugar de derivar, y los
  modelos se abren **de cara a la cámara** (player y red_robot, exportados con su frente en +Z, empiezan
  mostrando su rostro sin necesidad de rotar).
- **HUD cyberpunk y widgets 2D** — un conjunto de controles de interfaz reutilizables (HUD, minimapa, signos vitales,
  retícula, menú de pausa, scanlines y más).
- **Herramientas de depuración** — consulta [Pantalla de desarrollador y overlay de depuración](#pantalla-de-desarrollador-y-overlay-de-depuración).
- **Localización (EN/PT/ES)** — consulta [Localización](#localización-enptes).
- **Ajustes** — consulta [Ajustes](#ajustes).

## Pantalla de desarrollador y overlay de depuración

Un overlay de depuración global (`autoload/debug_overlay.gd`, autoload **DebugOverlay**) se activa
desde la pantalla de **desarrollador** y la pestaña "Debug" de los ajustes. Todos los interruptores se persisten en los
ajustes guardados (sección `game`) y se aplican de inmediato (`DebugOverlay.refresh()`). Cada
par de interruptores Deshabilitado/Habilitado usa el **mismo estilo de botón coloreado que la pantalla de Ajustes**: la
opción **seleccionada** muestra su color completo diseñado (verde/amarillo) mientras que la **no seleccionada** se
**oscurece** (un subinterruptor deshabilitado — con su maestro Debug 2D apagado — se atenúa en gris en su lugar).

La pantalla de desarrollador dispone los interruptores en **dos columnas**, cuyos tooltips usan colores
claros distintos para poder diferenciarlas:

- **Debug 2D** (etiquetas/tooltips amarillo claro) — maestro `debug_2d` más los interruptores de línea
  dependientes `Type` / `Name` / `Id` / `Path` / `Tab`. Controla el overlay 2D (un borde coloreado + un
  tooltip TYPE/Name/ID/PATH/TAB, una línea por valor, en el mismo orden que los interruptores) sobre los `Control`s. Funciona como un **inspector al pasar el ratón**: el borde y el
  tooltip se muestran **solo para el control bajo el cursor** — el **más específico** (más interno) que el
  ratón cubre — y **todos los demás controles permanecen ocultos**; sin nada bajo el cursor, no se muestra nada.
  El borde del control apuntado **se ilumina** con un realce brillante (más claro, más grueso, pulsante);
  si está **dentro de otro control**, ese **anfitrión** (contenedor) también muestra su overlay — un borde
  con un **brillo mucho más tenue** más su propio tooltip — y los dos tooltips (anfitrión e hijo) se **separan
  para que no se solapen**. Funciona en **todas las escenas sin excepción** — incluidas Models y el editor de Daño (que se excluyen
  del overlay **3D** vía `no_debug_overlay`) — y también sobre la **etiqueta de nombre de escena** (arriba a la derecha,
  junto al título). Cada tooltip elige una de las **cuatro esquinas** del control, probándolas en orden y tomando la
  primera que quepa **completamente en pantalla**: (1) a la derecha de la esquina **superior derecha** → (2) a la izquierda de la
  **superior izquierda** → (3) a la derecha de la **inferior derecha** → (4) a la izquierda de la **inferior izquierda**. El tooltip del control
  apuntado se coloca **primero**; el tooltip del **anfitrión** se coloca **después** y además
  **evita solapar** al del hijo (corrigiendo el caso "el overlay del padre colisiona" cuando pasas el ratón sobre un
  contenedor). Cuando **ninguna de las cuatro esquinas exteriores** cabe sin colisionar, el tooltip se **proyecta
  dentro del propio área del control** (una de sus cuatro esquinas interiores libres) — garantizando que padre e hijo
  **nunca** se solapen. Esto se aplica a **todos** los controles, incluido el **título** de la escena (la etiqueta `Title`). Los controles alojados dentro de un
  **`SubViewport`** (p. ej. la previsualización de Controls 2D) se mapean a su posición real en pantalla de modo que el
  borde/tooltip ya no deriva. En **cualquier escena**, con una
  **ventana flotante abierta** (p. ej. las ventanas de **Daño**/**IA**/offset-escala de Models, o cualquier `FloatingWindow`/
  diálogo de confirmación), Debug 2D **oculta los tooltips de la interfaz que la invocó detrás de ella** — solo los controles
  **dentro** de la ventana flotante mantienen su overlay, para evitar recargar la pantalla; abrir, cerrar o
  cambiar de ventana actualiza esto en vivo. La línea **Tab** (blanca, `show_tab`) reporta el índice de **tab/foco** de
  teclado de cada control en la escena 2D activa (`-` para controles no enfocables). La línea **Path**
  (azul claro, `show_path`) muestra la **ruta del control en el árbol de escena** (p. ej. `UI/Margin/Main`),
  para **diferenciar controles que comparten el mismo Type/Name**. Además de la
  pantalla de desarrollador, cada pantalla 2D con una barra de pie **Actions** lleva un interruptor **Debug 2D**
  (`CheckButton`, inyectado por `DebugOverlay`) para que puedas alternar el maestro sin salir de la escena
  (la pantalla de desarrollador mantiene su propio par). También se añadió una barra Actions de posición estándar al
  **menú**, para que el interruptor la alcance. El interruptor **nunca se muestra en una escena de nivel de juego**
  (`level_1`/`level_2`): es un control de **interfaz 2D**, no parte del juego — `DebugOverlay` omite las escenas
  que enraízan en un `Node3D` (la pantalla **Models**, enraizada en un `Node` simple, mantiene el interruptor).
- **Debug 3D** (etiquetas cian claro) — maestro `debug_3d` más los interruptores dependientes
  `Type` / `Name` / `Id` (que describen el `Skeleton3D` propietario), `Members`, `Skeleton` y
  `Mesh`. Renderiza etiquetas `Label3D` por miembro que siguen la pose en vivo.

Regla de dependencia: que el maestro de una columna esté activado **no es suficiente** — cada línea/función
dependiente surte efecto solo cuando _también_ está seleccionada, en sincronía con su maestro. Cuando el maestro de una
columna está apagado, sus **subfilas completas** (la etiqueta de la fila más los botones) se deshabilitan y atenúan (visualmente en gris). Cuando un
maestro está activado pero no hay ninguna línea dependiente seleccionada, esa columna no muestra nada (el borde 2D
y los tooltips aparecen solo una vez que al menos uno de Type/Name/Id/Tab está seleccionado; las etiquetas 3D
permanecen todas ocultas hasta que sus subinterruptores estén seleccionados).

Los extras de **Debug 3D** son: **Members** (etiquetas por miembro CABEÇA/TRONCO/BRAÇO… vía el mismo
clasificador `BodyParts` usado por los colisionadores de daño localizado), **Skeleton** (líneas de hueso
blancas reconstruidas cada fotograma a partir de la pose en vivo) y **Mesh** (una caja de alambre AABB cian alrededor
de cada MeshInstance3D).

Junto a la columna Debug 3D, una **previsualización del modelo del jugador** (misma altura que las columnas) renderiza el
robot del jugador en su propio `SubViewport` (`World3D`, cámara y luz propios), rotando lentamente con su
animación idle. Como el modelo de previsualización está **fuera** del grupo `no_debug_overlay`, el `DebugOverlay`
global lo escanea como cualquier otro esqueleto, de modo que los interruptores de **Debug 3D** (Skeleton / Mesh /
Members / Type / Name / Id) se le aplican en vivo — activar cualquier botón habilitado/deshabilitado muestra el efecto
en el robot de inmediato.

Encima de las columnas, una sección general contiene **HUD FPS** (`hud_fps`), **Health Monitor**
(`performance_hud`, la etiqueta de la fila de desarrollador para el Performance HUD; ver abajo) y **Malha no Solo** (`show_grid`) — una rejilla
de suelo de alambre de 100 m × 100 m dibujada en el origen en cualquier pantalla que contenga contenido 3D (Modelos 3D, niveles).
Como `main.gd` intercambia pantallas como hijas del nodo `Main` (de modo que `current_scene` siempre
permanece `Main`, un `Node` simple), la rejilla detecta la pantalla activa cargada y busca cualquier
descendiente `Node3D` en lugar de comprobar el tipo de la raíz; está ausente en las pantallas puramente 2D
(menú/ajustes/desarrollador).

## Indicadores de rendimiento (Performance HUD + StabilityGuard)

Dos autoloads complementarios, ambos leyendo solo del singleton `Performance` de Godot (interno del motor,
fiable, multiplataforma). Sustituyeron al antiguo monitor único "System Health".

**StabilityGuard** (`autoload/stability_guard.gd`) es una red de seguridad siempre activa contra caídas/congelaciones (sin
interruptor). Cada 0,5 s clasifica en tres estados y actúa en la transición: `NORMAL` (física a
60 ticks/s), `THROTTLE` (física reducida a 30 ticks/s + una señal de advertencia) y `EMERGENCY`
(`get_tree().paused = true` + un overlay a pantalla completa que se descarta con **ESC**). Vigila cinco
indicadores de riesgo real: **RAM libre del sistema** (`OS.get_memory_info()` — actúa cuando la RAM libre cae por debajo de los
límites; antes usaba `MEMORY_STATIC`, que lee 0 en el `.exe` de release y nunca se disparaba),
**VRAM** (`RENDER_VIDEO_MEM_USED`), **pares de colisión** (`PHYSICS_3D_COLLISION_PAIRS`), **recuento de nodos**
(`OBJECT_NODE_COUNT`) y **FPS** (`TIME_FPS`, detección de bucle atascado). Cada umbral es un `@export`. Emite `state_changed` /
`throttle_activated` / `emergency_activated` / `recovered`, y el overlay corre en
`PROCESS_MODE_ALWAYS` para vivir a través de la pausa.

**Performance HUD** (`autoload/performance_hud.gd` + `scenes2D/overlays/performance_bar.gd`) es un
overlay de barra superior global, activado por la fila **Performance HUD** de la pantalla de desarrollador
(`game/performance_hud`, apagado por defecto). Es de clic pasante (solo el botón del interruptor captura el ratón)
y queda inactivo mientras está oculto. El modo **Basic** muestra `FPS | NET | RAM | CPU% | GPU% | ● insignia StabilityGuard`
(CPU% desde `TIME_PROCESS`, GPU% un proxy de draw-call; **NET** muestra el **ping** de ida y vuelta de ENet —
cliente→servidor, o el promedio del host de sus clientes, codificado por color según la latencia; funciona a través de túneles UDP
como playit.gg, y se degrada a **N/D** solo cuando está offline; **RAM** = memoria del **sistema** como "usada/total GB" vía `OS.get_memory_info()`
— funciona en release, donde `Performance.MEMORY_STATIC` leería 0). El modo **Advanced** (interruptor ▼/▲)
añade columnas por categoría — CPU (proceso/física/carga/nodos/objetos/cuerpos 3D/pares de colisión), GPU
(draw calls/triángulos/VRAM/mem. de textura) y Memoria (RAM del sistema/recursos) — cada valor coloreado por
umbral.

> Nota: sustituir System Health eliminó su muestreo real de CPU por proceso (un hilo en segundo plano de PowerShell `Get-Process`)
> y su pitido de pico crítico; el CPU% del HUD es en su lugar un proxy de tiempo de fotograma.

## Localización (EN/PT/ES)

El idioma de la interfaz cambia entre **Português**, **English** y **Español** mediante el autoload **Locale**
(`autoload/locale.gd`).

- **Diccionarios por escena.** Cada escena trae su propio par de archivos JSON planos dentro de una
  carpeta `Resources/` junto a su `.tscn` — p. ej. `scenes2D/menu/Resources/menu.pt.json` +
  `menu.en.json`. Comparten las **mismas claves** (el texto fuente canónico diseñado de cada
  Button/Label) mapeadas al texto de ese idioma. En el arranque, Locale escanea recursivamente
  `scenes2D/` y `scenes3D/`, encuentra cada `*.pt.json` / `*.en.json`, y los **fusiona**
  en una tabla de búsqueda por idioma — de modo que añadir los diccionarios `Resources/` de una pantalla es todo
  lo que hace falta (sin editar el autoload).
- La elección se persiste en los ajustes guardados (`game/language`, por defecto `pt`) y se aplica
  en el arranque. En `_ready`, Locale se conecta a `node_added`, de modo que cada Button/Label que entra
  en el árbol se traduce automáticamente. `OptionButton`/`MenuButton` se omiten (su texto es
  la selección en vivo), y la primera vez que ve un nodo almacena el texto original en una clave meta,
  de modo que los cambios de idioma traducen desde el original en lugar de desde texto ya traducido.
- **Cada pantalla lleva los botones de idioma.** Una `LangBar` con botones **Português** / **English**
  vive ahora **dentro de la barra de pie `Actions`** (como su último grupo, rutas
  `UI/Actions/LangBar/…`) en lugar de como una barra separada abajo a la derecha — un pie unificado en menu,
  chooseplayer, settings, developer, levels, playonline, controls y models. Pulsar uno llama a
  `Locale.set_language(...)`, que persiste la elección y relocaliza el árbol en vivo en el
  sitio (el botón del idioma activo se atenúa en gris).
- **Texto impulsado por código** (líneas de estado dinámicas, placeholders de desplegables, los títulos de las pestañas de ajustes
  y los diálogos de confirmación, el Performance HUD y el overlay de StabilityGuard) no puede alcanzarlo el localizador automático de
  Button/Label, así que esos nodos se unen al grupo `Locale.SKIP_GROUP` y vuelven a aplicar
  `Locale.tr_key(...)` ellos mismos en la señal `language_changed`.

**Regla de mantenimiento:** siempre que cambies o añadas un texto de interfaz en una escena, actualiza la clave correspondiente
en **ambos** `Resources/<scene>.pt.json` y `.en.json` de esa escena en el mismo cambio (PT recibe
el texto en portugués, EN el inglés) y valida ambos archivos JSON. Como Locale indexa
por el texto fuente, cambiar la escena sin actualizar la clave rompe la traducción.

## Ajustes

La pantalla de ajustes tiene pestañas — en orden **`Resolution`, `Display`**, `Antialiasing`,
`Lighting`, `Effects`, `Audio` — con una **tira de pestañas compacta de media altura** (tamaño de fuente de pestaña 15) y un
ritmo vertical consistente (espaciado de fila/sección de 8).
Los títulos de las pestañas están a su vez localizados (provienen de los nombres de los nodos hijos, así que Locale los traduce
en código). La mayoría de las filas son un conjunto de botones de alternancia que comparten un degradado de color verde → amarillo → naranja → rojo
que se lee como barato → caro (p. ej. rendimiento vs. calidad), siendo el botón verde
la opción segura/baja. El botón **activo** (seleccionado) aparece **encendido** — un relleno brillante
con un borde blanco resplandeciente — mientras que las opciones **no seleccionadas** son ahora **mucho más tenues** (oscurecidas),
haciendo que la elección actual destaque aún más.

- **Resolution** — un desplegable de resolución de vídeo (teñido de cian claro para marcarlo como selector; con una
  **anchura mínima ajustada a su elemento más ancho** para que ningún texto se trunque), escala de resolución, y el filtro
  de escala (Bilinear / FSR / MetalFX…).
- **Display** — Modo de pantalla (Ventana / Pantalla completa / Pantalla completa exclusiva), Sincronización
  vertical, y Límite de FPS (30…144 / Ilimitado). Los botones de modo y de límite de FPS están
  coloreados a lo largo del mismo degradado (tope más alto = más exigente = color más cálido). En modo **Ventana**
  el juego corre como una **ventana normal del SO**: al entrar en él, la ventana se redimensiona a la resolución guardada
  y se centra, de modo que se puede arrastrar por su barra de título (ya no queda atascada al tamaño de pantalla completa).
- **Antialiasing** — TAA, MSAA y FXAA. **TAA se deshabilita automáticamente** cuando el filtro de escalado
  es **FSR 2** o **MetalFX Temporal** (los reescaladores temporales ya hacen antialiasing temporal y son
  incompatibles con TAA — evita la advertencia del motor).
- **Lighting** — Shadow Mapping, Tipo/Calidad de GI, SSAO y SSIL.
- **Effects** — Bloom y Niebla volumétrica.
- **Audio** — controles independientes para la **Música** de fondo (el bus `Music`) y los **Efeitos
  de Som** (el bus `SFX`, hacia el que enrutan los buses de juego `Outside`/`Reactor`), cada uno
  guardado y aplicado globalmente. La **música de fondo es por escena/nivel**, impulsada por el autoload **MusicManager**
  en un **bucle infinito**, cambiando en cada pantalla (ver `Audios/README.md`). Por defecto una
  escena es **"Selecione…" = silenciosa** (sin música) hasta que le asignes una pista. Al hacer clic en **Música → Enabled**
  se abre el **Music Manager**: escucha cualquier pista y **asigna** a cada escena/nivel una pista específica,
  **"Padrão"** (resolver por el nombre de la escena, `Audios/<scene-name>.<ext>`) o **"Selecione…"** (silencio);
  las asignaciones se persisten. Cada botón **▶ Play** tiene una
  **⏸ Pause** y un **⏹ Stop** al lado (ambos en la fila "Listen" y en la lista por escena); un botón **🎲 Shuffle** asigna una
  pista aleatoria a cada escena/nivel y la guarda para la próxima vez. A la derecha de cada fila
  (**Música** y **Efeitos de Som**) se sitúa un **control de volumen estilo ecualizador** (`VolumeBar`, 10
  segmentos coloreados en degradado): con el audio activado, haz clic/arrastra para fijar el volumen de ese bus de **1 a 100**.

**Ajustes en vivo** — no hay botón "Aplicar": cada opción se guarda y aplica en el instante en que
cambia. El desplegable de resolución de vídeo es la excepción: pide confirmación, aplicando
(y bloqueando en modo ventana) con "Sim" o revirtiendo a la elección guardada con "Não". Un botón **Reset**
(junto a "Voltar") restaura los valores por defecto integrados de hardware común — tras la misma
confirmación Sim/Não — guardándolos y aplicándolos de inmediato. Sin configuración almacenada (instalación
nueva) el juego también arranca con esos valores por defecto. El menú principal lee cada ajuste almacenado del
disco y lo aplica (gráficos, resolución y audio) antes de mostrar el menú. Una resolución
elegida se limita a la pantalla visible (de modo que una elección 4K/8K en un monitor más pequeño no pueda empujar la
ventana fuera de pantalla), y la barra de botones inferior y la etiqueta de título superior de cada pantalla se anclan
a todo el ancho de su borde para que permanezcan visibles a cualquier resolución.

## Requisitos

Este proyecto está orientado a **Godot 4.6.2 (stable)** — descárgalo
[desde el sitio web](https://godotengine.org/download/) o
[compílalo desde el código fuente](https://github.com/godotengine/godot). Git LFS no es necesario.

> **Nota:** el repositorio es grande, así que espera un tiempo de espera elevado al abrir el proyecto por
> primera vez.

## Ejecución

Consigue el proyecto desde [zimerfeld/ZIMARO](https://github.com/zimerfeld/ZIMARO) — clónalo o
[descarga un archivo ZIP](https://github.com/zimerfeld/ZIMARO/archive/refs/heads/main.zip) — y luego
ábrelo en Godot 4.6.2.

## Build de Windows (ejecutable + acceso directo en el escritorio)

Para producir un ejecutable de Windows independiente y un acceso directo en el escritorio, ejecuta:

```powershell
pwsh -File build_windows.ps1
```

Exporta `build/windows/ZIMARO.exe` (release, **PCK embebido** → un único archivo autocontenido de ~589 MB)
con la CLI headless de Godot 4.6.2, y (re)crea un acceso directo **ZIMARO** en el Escritorio usando
`build/icon.ico` (rasterizado una vez desde `icon.svg`). Requiere Godot 4.6.2 + sus plantillas de exportación
instaladas; el `.ico` se genera solo en la primera ejecución (necesita Python 3 con Pillow) y se reutiliza
después. La carpeta `build/` y `export_presets.cfg` están en git-ignore.

Antes de exportar, el script **cierra automáticamente** cualquier instancia de `ZIMARO.exe` en ejecución (y limpia un
`.tmp` residual), evitando el error *"Failed to rename temporary file"* cuando el juego está abierto — esto solo
ocurre en una recompilación real (los turnos sin cambios se omiten).

El **splash de arranque** se abre en una **pantalla negra sin logo de Godot** (`application/boot_splash/show_image=false`
+ `bg_color=black` + `minimum_display_time=0` en `project.godot`), de modo que la ventana simplemente aparece oscura hasta
que el menú carga — sin marca de agua del motor.

## Estructura del proyecto

Las pantallas 2D y la UI viven bajo `scenes2D/`, los niveles 3D bajo `scenes3D/`, y la biblioteca reutilizable
de recursos 3D bajo `library3D/`:

- `scenes2D/` — todas las pantallas 2D y la UI:
  - `main` — escena de entrada. `main.gd` es un router que intercambia pantallas como hijas (reaccionando a
    las señales `replace_main_scene` / `quit`) en lugar de llamar a `SceneTree.change_scene`, de modo que
    `current_scene` permanece `main`.
  - `menu`, `chooseplayer`, `levels`, `settings`, `developer`, `playonline` — las pantallas de
    navegación.
  - `controls2D` — widgets de UI reutilizables (HUD cyberpunk, minimapa, signos vitales, barra de habilidades, retícula,
    menú de pausa, scanlines, feed de registro, etc.).
  - `controls` — un visor de controles 2D (el análogo 2D de la pantalla Models) que explora y
    previsualiza los widgets `controls2D` a través de un desplegable.
  - `cyberpunkhud` — pantalla de HUD ensamblada construida a partir de widgets `controls2D`.
- `scenes3D/` — niveles y herramientas 3D: `level_1`, `level_2`, y el visor `models`.
- `library3D/` — biblioteca de recursos 3D, organizada por tipo: `characters`, `propulsores`, `structures`,
  `weapons`, más las carpetas de soporte `geometry` y `textures`. Las nuevas carpetas de modelo que se dejen aquí
  aparecen automáticamente en el visor Models.
- `effects_shared/` — helpers entre personajes: `limb_colliders.gd` (colisionadores nativos por miembro para
  daño localizado), `limb_config.gd` (`LimbConfig` — almacén de multiplicadores de daño + submiembros + propietarios +
  offsets/escalas de colisionador, **un archivo por modelo en la carpeta propia del modelo**
  `library3D/<cat>/<model>/limb_config.json`, con una sobrescritura escribible `user://` para ediciones en el juego), la **jerarquía de plan corporal**
  `body_parts.gd` (base `BodyParts` +
  subclases `body_parts_biped/quadruped/crawler.gd`, clasificación hueso → miembro) y
  `body_plans.gd` (fábrica `BodyPlans`), y recursos compartidos de explosión/sombra.
- `autoload/` — singletons globales: `crash_handler.gd`, `player_selection.gd`, `debug_overlay.gd`,
  `locale.gd`, `stability_guard.gd`, `performance_hud.gd`, `music_manager.gd` (música de fondo por escena/nivel,
  en bucle). `Settings` vive en `scenes2D/settings/config.gd`.
- `<scene>/Resources/*.pt.json` + `*.en.json` — diccionarios de idioma de la UI por escena, escaneados y
  fusionados por el autoload `Locale`.
- `themes/` — recursos de tema compartidos.
- `ZIMARO/` — vault de documentación del proyecto (replica este README).

Flujo de pantallas:

```
menu ─┬─ Play Offline ─► chooseplayer ─► levels ─► level_1 / level_2
      ├─ Play Online ──► playonline (Manage Rooms / Join Rooms)
      │                    ├─ Host ───► host_session   (start rooms; per room: Play / Observe / Restart / Stop)
      │                    └─ Client ─► client_session (browse rooms; per room: Play)
      │                                   └─ Play ─► chooseplayer ─► spawn into the chosen room
      ├─ settings
      ├─ developer ──┬─ models    (3D model viewer for library3D assets)
      │              └─ controls  (2D controls viewer for controls2D widgets)
      └─ quit
```

`main.gd` es el router: cada pantalla emite `replace_main_scene` y `main` la intercambia, de modo que los
botones de atrás (y <kbd>Escape</kbd>) navegan a la pantalla anterior de la misma manera. Cada pantalla 2D
toma un foco inicial al entrar de modo que las **teclas de flecha** navegan entre sus botones (helper compartido
`UINav`, autoload). <kbd>Escape</kbd> sigue una única regla en todas partes: primero **cancela una edición de campo
activa** (un `LineEdit`/`SpinBox` enfocado — p. ej. la IP/puerto en línea) y solo una segunda pulsación
abandona la pantalla; en el `menu` abre una **confirmación "¿Salir de Zimaro?"** (Sí/No) en lugar de
salir directamente. La pantalla `settings`
aplica y persiste cada cambio de inmediato y el `menu` reaplica todos los ajustes almacenados
al entrar. La pantalla `developer` y la pestaña "Debug" de `settings` alternan el `DebugOverlay`, y la
fila "Performance HUD" del desarrollador alterna el overlay `PerformanceHUD` (y `StabilityGuard` corre
siempre activo). El autoload `Locale` cambia
el idioma de la UI (EN/PT/ES) desde los botones Português/English/Español presentes en cada pantalla. La
escena `cyberpunkhud` es una previsualización de HUD ensamblado independiente, no parte de este flujo de navegación.

Disposición de carpetas y subcarpetas:

```
ZIMARO/
├─ scenes2D/             # 2D screens, UI and reusable widgets
│  ├─ main/              # entry scene + router (main.gd swaps screens in)
│  ├─ menu/              # main menu
│  ├─ chooseplayer/      # character picker (3D preview)
│  ├─ levels/            # level selector
│  ├─ settings/          # settings screen + Settings autoload (config.gd)
│  ├─ developer/         # developer tools menu (debug toggles, links to viewers)
│  ├─ playonline/        # online entry: Host/Client role → room manager/browser
│  ├─ host_session/      # server: room manager (start + Play/Observe/Restart/Stop per room)
│  ├─ client_session/    # client: room browser (Play into a running room)
│  ├─ controls/          # 2D widget viewer (analog of the Models screen)
│  └─ controls2D/        # reusable HUD widgets: crosshair, minimap_panel, vitals_panel, volume_bar, …
├─ scenes3D/             # 3D levels and tools
│  ├─ level_1/ level_2/               # playable levels
│  ├─ spectator_camera/  # free-fly no-collision camera to Observe a room (host) — WASD + Space
│  └─ models/            # 3D model viewer/inspector for the library3D assets
├─ library3D/            # reusable 3D asset library, organized by type
│  ├─ characters/        # players + enemies
│  ├─ propulsores/       # propulsion props (forklift)
│  ├─ structures/        # static structures (door, core, lights, props, structure)
│  ├─ weapons/           # weapons (pistola_infantil, bomb)
│  ├─ geometry/          # shared meshes/materials (.tres)
│  └─ textures/          # shared textures
├─ Audios/               # per-scene/level background tracks (infinite loop; see Audios/README.md)
├─ effects_shared/       # cross-character helpers: limb_colliders.gd, body_parts.gd, …
├─ autoload/             # singletons: crash_handler, player_selection, debug_overlay, locale, stability_guard, performance_hud, music_manager
│                        #   (Settings lives in scenes2D/settings/config.gd)
│                        # UI dictionaries live per scene: <scene>/Resources/*.pt.json + *.en.json (read by Locale)
├─ themes/               # shared Theme resources (ui_theme.tres, cyberpunk.tres)
├─ addons/               # Godot editor plugins (godot_ai — the MCP server)
├─ ZIMARO/               # project documentation vault (mirrors this README)
├─ screenshots/          # captured preview images
└─ project.godot · default_bus_layout.tres · file_format.sh   # project config · audio buses · formatter
```

## Bloques de construcción nativos de Godot

Todo en el juego se construye a partir de **nodos y recursos nativos de Godot** — no hay ningún nodo
C++/GDExtension personalizado. Las únicas abstracciones específicas del proyecto son helpers `RefCounted` de lógica pura sin
nodo propio (`BodyParts` y sus subclases de plan corporal + la fábrica `BodyPlans`,
`WeaponParts`, `LimbConfig`, `LaserShooter`, `CannonShooter`), que solo orquestan nodos nativos.
Por subsistema:

- **Física y colisión:** `StaticBody3D`, `CharacterBody3D`, `RigidBody3D`, `Area3D`,
  `CollisionShape3D` (y `BoxShape3D`/`CapsuleShape3D`/`SphereShape3D`/`CylinderShape3D`), `RayCast3D`.
- **Mallas y geometría:** `MeshInstance3D`, `ArrayMesh`, y primitivas (`BoxMesh`, `CylinderMesh`,
  `SphereMesh`, `PrismMesh`…).
- **Esqueleto y animación:** `Skeleton3D`, `BoneAttachment3D`, `Skin`, `AnimationPlayer`,
  `AnimationTree`, `SkeletonModifier3D`.
- **Cámara, luz y entorno:** `Camera3D`, `SpringArm3D`, `Marker3D`, `DirectionalLight3D`/
  `OmniLight3D`/`SpotLight3D`, `WorldEnvironment`, `Sky`.
- **Partículas y materiales:** `CPUParticles3D`, `GPUParticles3D`, `StandardMaterial3D`, `ShaderMaterial`.
- **Audio:** `AudioStreamPlayer3D`, `AudioStreamPlayer`, `AudioStream`/`AudioStreamWAV`,
  `AudioStreamRandomizer`.
- **Networking:** `MultiplayerSynchronizer`, `MultiplayerSpawner`, `SceneReplicationConfig`.
- **UI 2D (árbol `Control`):** `Button`, `Label`, contenedores, `OptionButton`, `ProgressBar`,
  `CanvasLayer`, `Theme`.

El sistema de hitboxes por miembro es el ejemplo canónico: `limb_colliders.gd` es un `Node3D` simple que
**ensambla** `StaticBody3D` + `CollisionShape3D` + `BoneAttachment3D` nativos. La nota de Obsidian
[`recursos-nativos-godot`](<ZIMARO/🧩 Sistemas/🧱 recursos-nativos-godot.md>) tiene el inventario completo.

## Controles

- Ratón o <kbd>Gamepad Right Stick</kbd>: Mirar alrededor
- <kbd>W</kbd>/<kbd>A</kbd>/<kbd>S</kbd>/<kbd>D</kbd>, <kbd>Arrow keys</kbd>, <kbd>Gamepad Left Analog Stick</kbd> o <kbd>Gamepad D-Pad</kbd>: Mover
- <kbd>Space</kbd>, <kbd>Gamepad A/Cross</kbd>: Saltar — **altura variable**: mantén para completar el arco de salto completo
  (altura y distancia máximas, la animación se reproduce hasta el final); suelta a media subida para cortar el salto suavemente
- <kbd>Right Mouse Button</kbd>, <kbd>Gamepad Left Trigger (L2)</kbd> (pulsar para alternar, o mantener y soltar): Apuntar
- <kbd>Left Mouse Button</kbd>, <kbd>Gamepad Right Trigger (R2)</kbd>: Disparar (solo mientras apuntas)
- <kbd>Arrow keys</kbd> / <kbd>Gamepad D-Pad</kbd> (en menús): Mover el foco entre botones
- <kbd>Escape</kbd>, <kbd>Gamepad Start</kbd>: Cancelar una edición de campo activa, si no volver atrás / al menú principal (el menú pide confirmar la salida). **En una partida offline pide confirmar — "¿Abandonar la partida?" (Sí → volver a la selección de nivel, No → reanudar) — pausando el juego mientras decides.**
- <kbd>F11</kbd> o <kbd>Alt + Enter</kbd>: Alternar pantalla completa
- <kbd>F3</kbd>: Alternar la información de depuración (como el contador de FPS)

## Formato de código

Todos los archivos de texto de este proyecto deben seguir un formato consistente, impuesto por
[`file_format.sh`](file_format.sh). Aplícalo siempre antes de confirmar cambios:

- Codificación UTF-8 **sin BOM**
- Finales de línea LF (Unix)
- Sin espacios en blanco al final
- Un salto de línea final al final del archivo

Ejecuta el formateador desde la raíz del repositorio:

```bash
bash file_format.sh
```

En Windows, ejecútalo desde Git Bash. Requiere `dos2unix` y `perl` (`recode` es opcional). Una
causa común de `Parse Error: Expected '['` al cargar un `.tscn`/`.tres` es un BOM UTF-8 residual —
ejecutar el formateador lo elimina.

> **Consejo:** tras mover o renombrar escenas/recursos, reabre también el proyecto en el editor de Godot
> una vez para que reconstruya `.godot/uid_cache.bin` y reimporte los recursos movidos (esto limpia las
> advertencias `invalid UID … using text path instead`).

## Documentación y base de conocimiento

`README.md` es un resumen bilingüe de alto nivel; este archivo (`README.es-ES.md`), junto con
[`README.en-US.md`](README.en-US.md) y [`README.pt-BR.md`](README.pt-BR.md), contienen la documentación
extensa y detallada, y el [`ZIMARO/`](ZIMARO) vault los replica con notas por sistema. **Los tres archivos README se mantienen
al día al final de cada cambio** para que sigan siendo una base de conocimiento fiable para cualquier análisis o
toma de decisiones.

## Enlaces útiles

- [Sitio web principal](https://godotengine.org)
- [Código fuente](https://github.com/godotengine/godot)
- [Documentación](http://docs.godotengine.org)
- [Comunidad](https://godotengine.org/community)
- [Otras demos](https://github.com/godotengine/godot-demo-projects)

## Licencia

© 2026 Renato Zimerfeld. Esta obra está licenciada bajo la **Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License (CC BY-NC-ND 4.0)** — eres libre de compartirla con fines no comerciales con la atribución adecuada, pero **no** puedes usarla comercialmente ni **puedes** distribuir versiones modificadas. Consulta [LICENSE.md](LICENSE.md) para los términos completos.

---
tipo: procedimento
projeto: ZIMARO
lang: es-ES
atualizado: 2026-08-06
---

# 🪟 Dos Ventanas Lado a Lado (Dev)

> **Objetivo:** probar el multijugador en loopback con **un solo comando** — dos instancias de
> ZIMARO abiertas lado a lado (media pantalla cada una), una alojando una sala y la otra entrando
> en ella por su cuenta, sin hacer clic en nada. Sustituye al guion manual de
> [[💻 Rodar no Editor (Dev) (ES)|💻 Ejecutar en el Editor (Dev)]] (paso 3).

## ⚡ TL;DR

```powershell
pwsh -File scripts/dual-window.ps1
```

Ventana **izquierda** = servidor (aloja una sala en el Level 1). Ventana **derecha** = cliente
(espera a que el servidor arranque, entra en la sala y ya nace jugando). `ESC` en la ventana del
cliente sale de la sala y devuelve el ratón.

## ⚙️ Cómo funciona

Dos piezas:

1. **`scripts/dual-window.ps1`** — detecta el **área útil** del monitor (ancho/alto descontando la
   barra de tareas), la divide por la mitad y lanza ambas instancias con los argumentos de cada
   papel. Antes de lanzar, cierra instancias anteriores del mismo ejecutable (si no, el puerto
   queda ocupado). Usa `build/windows/ZIMARO.exe` cuando existe; si no (o con `-Editor`), ejecuta
   el proyecto con el binario de Godot y `--path`.
2. **`autoload/autopilot.gd`** (autoload `Autopilot`) — lee los **argumentos de usuario** de la
   línea de comandos (todo lo que va después de `--`) y conduce el flujo dentro del juego. Sin esos
   argumentos el autoload queda inerte y el juego funciona exactamente como antes.

### Argumentos aceptados (después de `--`)

| Argumento | Efecto |
| --- | --- |
| `autohost` | aloja el servidor de salas y crea la sala inicial |
| `autojoin` | conecta como cliente y entra en la primera sala en ejecución |
| `port=<n>` | puerto del servidor (por defecto `4383`) |
| `address=<host>` | IP/dominio del servidor, solo en `autojoin` (por defecto `127.0.0.1`) |
| `level=<1\|2\|res://…>` | level de la sala creada por `autohost` (por defecto `1`) |
| `template=<id\|nombre>` | plantilla de personajes activada en la sala; casa por el **id exacto** o por un trozo del **nombre** (sin acentos/mayúsculas — `aerea` encuentra "Caça aérea"). `none` la limpia; vacío mantiene la activa |
| `delay=<seg>` | **cliente:** espera antes del 1er intento de conexión (por defecto `6`). **host:** pausa entre rellenar los campos y alojar (por defecto `5`), **solo en builds de depuración** — ver abajo |
| `retries=<n>` | intentos extra, cada 2 s (por defecto `15`) |
| `player=<nombre>` | nombre del jugador de esta instancia (**no** persiste en Settings) |
| `music=<on\|off>` | banda sonora de esta instancia. Sin el argumento, el **host nace mudo** y el cliente suena — dos bandas sonoras a la vez en las dos ventanas estorban el seguimiento. Solo toca el bus vivo, **nunca** Settings (ambas ventanas escriben en el mismo archivo de configuración) |
| `win=<x,y,w,h>` | posiciona/dimensiona la ventana en píxeles de pantalla |

Lo que ejecuta el script:

```
ZIMARO.exe -- autohost port=4383 level=1 win=0,0,960,1032 player=HOST
ZIMARO.exe -- autojoin port=4383 address=127.0.0.1 delay=6 win=960,0,960,1032 player=CLIENTE
```

### Parámetros del script

`-Port` · `-Address` · `-Level` · `-Template` · `-Delay` · `-Retries` · `-Monitor <índice>` (base 0) ·
`-Exe <ruta>` · `-Editor` (fuerza ejecutar con el binario de Godot) · `-NoKill` (no cierra
instancias anteriores) · `-Preview <seg>` (pausa de comprobación antes de lanzar, por defecto `6`;
`0` lanza directo).

### Probar el bot aliado (escolta)

```powershell
pwsh -File scripts/dual-window.ps1 -Level 2 -Template aerea
```

El Level 2 trae la plantilla por defecto **"Level 2 - Caça aérea"** (2 criaturas hostiles + **1 bot
aliado**). Con `-Template`, el autopiloto activa la plantilla **antes** del `start_room` (es lo que
aplica los personajes) — puedes ver la [[🎮 player (ES)|postura de seguridad]] del aliado desde la
rejilla del host (**Observar**) o entrando en la sala. Solo el **host** recibe `template=`: es quien
crea la sala.

### Pausa del host (solo en depuración)

Antes de alojar, la pantalla **Jugar Online** del host se queda **5 s** con los parámetros ya
rellenados — tiempo para comprobar el nombre, el puerto y las opciones de optimización antes de que
cambie a la sesión de salas (`Autopilot.host_preview_delay` → `HOST_PREVIEW_DELAY_SEC`). Pasar
`delay=` sobrescribe el valor.

**No existe en release**: `OS.is_debug_build()` es falso en el `.exe` exportado y la pausa pasa a `0`,
así que un servidor de producción arranca al instante. Es apoyo a la revisión visual, no
comportamiento del juego.

El campo **IP/Dominio** del host va **vacío** a propósito: `create_server` usa solo el puerto, y dejar
ahí la última IP sugeriría que se usa para alojar (no es así — solo el cliente la consume).

### Pausa de comprobación

Antes de lanzar, el script imprime un bloque con **todos los parámetros en uso** — monitor y área
útil, ejecutable, puerto/dirección, level, espera del cliente, la geometría de cada ventana y las
**dos líneas de comando completas** — y hace una cuenta atrás de `-Preview` segundos (`Ctrl+C`
cancela). Es el tiempo para comprobarlo todo antes de que las ventanas tomen la pantalla.

## 🔌 Puntos de enganche en el juego

| Archivo | Qué hace bajo piloto automático |
| --- | --- |
| `scenes2D/main/main.gd` | aplica la geometría `win=` nada más arrancar |
| `scenes2D/menu/menu.gd` | reaplica la geometría y salta directo a **playonline** |
| `scenes2D/playonline/playonline.gd` | rellena puerto/dirección/nombre y aloja **o** conecta (respetando `delay=`); un fallo de conexión **reintenta en silencio** mientras queden intentos |
| `scenes2D/host_session/host_session.gd` | crea la sala inicial (una vez, y solo si no hay salas) |
| `scenes2D/client_session/client_session.gd` | entra en la **primera** sala en cuanto aparece en la lista (una vez) |
| `scenes2D/chooseplayer/chooseplayer.gd` | confirma el personaje por defecto y sigue |
| `scenes3D/level_1/level_1.gd` · `level_2.gd` | reafirman la geometría tras `apply_graphics_settings` (que reimpone el `display_mode` guardado) — sin eso la ventana del **level** volvía a pantalla completa y rompía el lado a lado |

## 🛟 Resolución de problemas

- **Ambas ventanas nacen a pantalla completa y superpuestas:** Settings arranca en **pantalla
  completa exclusiva** y salir de ese modo **no se asienta en el mismo frame** — por eso el
  `Autopilot` reafirma la geometría durante ~30 frames (`REASSERT_FRAMES`) tras cada llamada. Si
  vuelve a pasar, subir ese valor.
- **Ventanas más pequeñas que media pantalla (escalado 125%/150%):** el script llama a
  `SetProcessDPIAware()` antes de leer el área útil. Sin eso Windows devuelve coordenadas
  virtuales.
- **El cliente no entra:** subir `-Delay` (el servidor paga el preload de arranque + la creación de
  la sala antes de aceptar conexiones). El cliente ya reintenta 15× cada 2 s por defecto.
- **"Puerto en uso" en el servidor:** quedó una instancia de una ejecución anterior — ejecutar sin
  `-NoKill` (por defecto) o cerrar `ZIMARO.exe` a mano.
- **Handshake de versión rechazado:** ambas ventanas corren el mismo build, así que esto solo
  aparece apuntando `-Address` a otro PC — ver [[🛰️ hospedagem-online (ES)|🛰️ alojamiento-online]].

## 📏 Reglas que respeta

- **Nunca commitear/publicar** — dejarlo para que el usuario revise (GitFlow).
- Herramienta de **desarrollo**: sin los argumentos de línea de comandos el juego es idéntico al de
  producción (no se ejecuta ningún camino nuevo).

## 🔗 Enlaces
- [[💻 Rodar no Editor (Dev) (ES)|💻 Ejecutar en el Editor (Dev)]] — el guion manual equivalente
- [[🧪 teste-salas-multiplayer (ES)|🧪 prueba-salas-multijugador]] · [[🚪 salas (ES)|🚪 salas]] · [[🌐 multiplayer (ES)|🌐 multijugador]]
- [[🛰️ hospedagem-online (ES)|🛰️ alojamiento-online]] · [[🚀 Build Windows (Prod) (ES)|🚀 Build Windows (Prod)]]
- [[🏠 Home (ES)|🏠 Home]] · [[📌 Backlog (ES)|📌 Backlog]]

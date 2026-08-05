---
tipo: sistema
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# 🛰️ Hospedaje online (jugar con amigos por internet)

> Cómo exponer la máquina host para que otro jugador pueda conectarse por internet.
> Relacionado: [[🌐 multiplayer (ES)|Multiplayer]]

---

## Contexto técnico

- El juego usa **ENetMultiplayerPeer** → `create_server()` / `create_client()` en `scenes2D/playonline/playonline.gd`.
- ENet corre sobre **UDP**. El puerto por defecto es **UDP 4383** (`playonline.tscn`, `Port` SpinBox, `value = 4383`).
- El campo **Address** acepta un hostname (ENet resuelve nombres), así que puedes usar dominios en lugar de una IP.
- El campo **Port** acepta **1–65535**. (Antes, el `max_value` del SpinBox era 49151, que **truncaba** puertos dinámicos como los de playit — p. ej.: teclear 54417 se convertía en 49151 y la conexión fallaba. Corregido a 65535.)
- **Historial de Puerto/IP:** junto a Port y Address hay un `OptionButton` ("Select…") con los **últimos 3 valores** usados. Persistido en `Settings.config_file` bajo la sección **`online`** (claves `ports` / `addresses`), recargado en `_ready` (`_refresh_history`). Seleccionar un elemento rellena el campo y el desplegable vuelve a "Select…".
  - El campo Address almacena el **texto en bruto** — funciona igual para una **IP** (`147.185.221.26`) y un **dominio** (`wharf-pos.gl.at.ply.gg`).
  - Registrado: al pulsar **Host**/**Connect** (`_remember`), al pulsar **Enter** y cuando el campo **pierde el foco** (`_on_address_focus_exited` / `_on_port_focus_exited` — Port guarda vía el `get_line_edit().focus_exited` del SpinBox). Actualiza el desplegable de inmediato. ENet (`create_client`) resuelve hostnames, así que un dominio conecta directamente.
  - **Dominios completos guardados (2026-06-25):** todo **dominio completo** (FQDN — tiene una letra y un punto, p. ej.: `wharf-pos.gl.at.ply.gg`) también entra en su propia lista PERSISTENTE (sección `online`, clave `domains`, tope `DOMAIN_MAX = 12`) que **no rota** junto con las IP recientes. El desplegable Address une las direcciones recientes **+ estos dominios guardados**, deduplicados (`_fill_address_history`, `_remember_address`, `_is_full_domain`) — así un dominio tecleado una vez queda disponible para selección incluso después de usar varias IP.
- **Disposición de la pantalla** (`playonline.tscn`): cada entrada tiene una **Label localizada a la izquierda** — `Port:` (PT "Porta:") y `IP Address/Domain:` (PT "Endereço IP/Domínio:"), vía `Resources/playonline.*.json`. **Debajo** de Port/Address hay dos botones (sin radios; directamente clicables):
  - **ManageRooms** ("Manage Rooms", `_on_manage_rooms_pressed`) = rol **Host**: crea un servidor ENet **persistente** y abre la `host_session` (gestor de salas). Ver [[🚪 salas (ES)|Salas]].
  - **JoinRooms** ("Join Rooms", `_on_join_rooms_pressed`) = rol **Cliente**: se conecta como cliente y, en `connected_to_server`, abre la `client_session` (explorador de salas).
  - Los antiguos botones de nivel único (**Host and Connect / Host Only / Connect**) y la sonda de reconexión ("probe") **fueron eliminados** — el flujo ahora es solo de salas. El **"Back"** de `playonline` vuelve al menú; el Back de las sesiones vuelve a `playonline` (desmontando el peer).
  - **Headless (servidor dedicado):** `playonline` llama a `_on_manage_rooms_pressed` y auto-inicia una sala con `level_1` (`DEFAULT_ROOM_LEVEL`).

> **Unirse a una partida en curso:** en el flujo de salas el cliente simplemente elige una **sala en ejecución**
> en el explorador (`client_session`) y se une — el servidor hace spawn del jugador en ella. Ya no existe
> la sonda de escena ni el `ConfirmationDialog` de reconexión (esos pertenecían al antiguo "Connect" de nivel único).
> Ver [[🚪 salas (ES)|Salas]], [[🌐 multiplayer (ES)|Multiplayer]].

> ⚠️ **ngrok NO funciona** aquí: ngrok solo tuneliza **TCP/HTTP**, no soporta **UDP**. Sin cambiar el juego a WebSocket/TCP, ninguna configuración de ngrok conectará con el host ENet.

---

## Cámara de observación libre ("Observar" una sala)

En la `host_session`, **Observe** sobre una sala muestra el nivel en vivo (robots, jugadores conectados) vía una
cámara libre, **sin colisión y sin jugador controlado**.

- **Flujo:** la cámara la añade `RoomManager.register_room_level` en cada sala del servidor. Al
  pulsar **Observe**, la sala pasa a `UPDATE_ALWAYS` y su textura se muestra a pantalla completa; el ratón se
  **captura** y se empuja al SubViewport (`push_input`) → la cámara mira alrededor. **ESC** sale de la
  observación. (En el **"Play"** del host, esta cámara se **apaga** y cede el paso a la cámara del jugador.)
- **Cámara** (`scenes3D/spectator_camera/spectator_camera.{gd,tscn}`): un `Camera3D` que es **hijo
  directo del nivel** (fuera de `SpawnedNodes` → **no se replica**; solo existe en la instancia del servidor). No consume un
  punto de spawn — todos quedan para los clientes.
- **Controles:** **WASD** vuela en el plano (relativo al yaw de la cámara); el **ratón** mira alrededor (ratón
  capturado); **Espacio+W** sube y **Espacio+S** baja **a la velocidad de salto del jugador**
  (`VERTICAL_SPEED = 5.0 = Player.JUMP_SPEED`); la velocidad se suaviza con `lerp` (arranque/parada sin
  tirones).

---

## Opción 1 — playit.gg (sustituto de ngrok, soporta UDP, gratis)

1. Descarga y ejecuta el agente en https://playit.gg
2. Crea un túnel de tipo **UDP** apuntando a `127.0.0.1:4383`
3. **Proxy Protocol:** ❌ **desactivado** (el ENet de Godot no entiende la cabecera PROXY — rompería la conexión)
4. playit genera una dirección pública, p. ej.: `wharf-pos.gl.at.ply.gg:54417`
5. Host: abre el juego → **Manage Rooms** y **Start Room**. Amigo: **Address** = dominio, **Port** = el puerto del panel → **Join Rooms** → **Play** en la sala

### Por qué conectar al dominio de playit y no a la IP local (`192.168.x.x`)

Son **dos extremos del mismo túnel**, y solo uno es alcanzable por internet:

```
Friend (internet)           playit.gg (cloud)          Your machine (LAN)
────────────────            ─────────────────          ──────────────────
wharf-pos…:54417  ─UDP►   playit relay server    ─►   playit agent   ─►  192.168.0.33:4383
 (PUBLIC address)           (routable IP on the net)   (on your PC)        (game / ENet)
```

- `192.168.0.33:4383` es una **IP privada de LAN** — solo existe dentro de tu red; nadie en internet puede alcanzarla. Es el destino *interno* al que el agente entrega el tráfico.
- `wharf-pos.gl.at.ply.gg:54417` es la **dirección pública** creada en los relays de playit — esa sí es alcanzable desde cualquier lugar.
- El agente en tu PC mantiene el túnel abierto: paquetes a `…:54417` → relay → agente → `192.168.0.33:4383` (juego). Por eso **nunca debes compartir la `192.168…`** (no significa nada fuera de tu red) y el **puerto público** (54417) es distinto del local (4383).

### Valores en la UI de PlayOnline (`playonline.gd`)

| Rol | Address | Port | Cómo |
|---|---|---|---|
| **Host** | *(ignorado — puede dejarse vacío)* | `4383` (el mismo que el túnel) | **Manage Rooms** |
| **Cliente** | `wharf-pos.gl.at.ply.gg` (solo dominio, **sin** `:port`) | `54417` (el puerto **público** del panel) | **Join Rooms** |

- **Host** (`_on_manage_rooms_pressed`): `create_server(port)` usa **solo el puerto**, nunca el Address. Este puerto debe ser el mismo que el túnel de playit redirige (dirección local `4383`).
- **Cliente** (`_on_join_rooms_pressed`): `create_client(address, port)` — dominio en un campo, puerto en el otro. ENet resuelve el hostname, así que **dominio = IP**. No pegues `domain:port` en el Address: el `:port` va en el campo **Port** separado.

### Estabilidad de los valores generados
- **Dominio + puerto** (`xxxxx.gl.at.ply.gg:PORT`): **fijos mientras el túnel exista**. Cambian si el túnel se **elimina y se recrea** (puerto aleatorio en el plan gratuito).
- **IP en bruto** (`147.185.221.26:...`): **compartida/anycast, puede cambiar** — **no la compartas**. Pasa siempre el **dominio**.
- Dirección permanente/personalizada: solo en los planes **de pago**.

### Handshake de versión (host y cliente en la misma build)
Desde el 2026-08-05, al conectar, host y cliente intercambian un **ID de build**: el `RoomManager` envía
su versión en `peer_connected` y el cliente compara en `receive_host_version`. Si las versiones **difieren**,
el cliente **rechaza** con el aviso *"Versiones incompatibles — Host: X, Tú: Y"* (PT/EN/ES) en vez de fallar
a oscuras; si el host es una build antigua que ni responde, un **timeout de 5 s** muestra *"No se pudo
verificar la versión del host"*. El ID se sella en el export con `build_windows.ps1` (`build_id.json` = SHA
corto de git + `-dirty` + timestamp; leído por `RoomManager.game_version`, incrustado en el `.exe`). En el
**editor** todos coinciden (`editor-dev`). Regla práctica: **ambos deben usar el mismo `.exe`** — ahora las
versiones distintas avisan en vez de fallar mudo. Ver [[🌐 multiplayer (ES)]].

### Errores comunes
- **`RequiresVerifiedAccount`**: la cuenta de playit necesita un **e-mail verificado**. Resuélvelo en https://playit.gg/account añadiendo un e-mail + confirmando, **o** iniciando sesión vía **Discord/Google** (ya verificados).
- El **puerto público** puede diferir de 4383 — el amigo debe usar el puerto mostrado en el **panel de playit**.

---

## Opción 2 — Tailscale o ZeroTier (LAN virtual / VPN — más fiable)

Crea una red local entre las máquinas, sin tocar el router ni exponer un puerto en internet.

1. Host y amigo instalan **Tailscale** (https://tailscale.com) e inician sesión en la **misma red** (login de Google/etc.)
2. El host abre el juego → **Manage Rooms** (puerto 4383) e inicia una sala
3. Amigo: **Join Rooms** usando la **IP de Tailscale de la máquina host** (p. ej.: `100.x.x.x`) + puerto **4383**

- **Ventajas:** buena latencia, estable, nada expuesto públicamente, **sin verificación de cuenta**.
- **ZeroTier** es equivalente (red virtual con un ID de red compartido).

---

## Opción 3 — Redirección de puertos en el router (sin programa extra)

1. Redirige **UDP 4383** a la IP local de la máquina host
2. Abre el puerto en el **Firewall de Windows** (UDP 4383, entrante)
3. El amigo se conecta a la **IP pública** del host (https://whatismyip.com) + puerto 4383

- **Inconveniente:** expone el puerto públicamente y depende del NAT del operador (**CGNAT** puede bloquearlo).

---

## Recomendación

- Juego rápido con amigos → **Tailscale** (Opción 2).
- Dirección "pública" estilo ngrok → **playit.gg** (Opción 1).

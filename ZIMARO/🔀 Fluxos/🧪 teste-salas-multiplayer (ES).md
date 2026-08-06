---
tipo: fluxo
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# 🧪 Protocolo de pruebas — Salas multiplayer (P1)

> Un guion **autosuficiente y reutilizable** para validar el servidor multinivel (salas) sobre el terreno.
> Cubre 3 niveles de red, del más fácil al más real. Hazlos en orden: si **la Prueba A (loopback)**
> falla, no tiene sentido pasar a los PC — es un bug de código/lógica, no de red.
> Contexto: [[🚪 salas (ES)|Salas]] · [[🌐 multiplayer (ES)|Multiplayer]] · [[🛰️ hospedagem-online (ES)|Hospedaje online]].
>
> **Estado del code-review (2026-07-01):** el flujo de salas (`RoomManager` + `host_session` +
> `client_session` + el `_ready` de los niveles + template diferido + filtros de visibilidad) fue **revisado y
> es consistente — sin bugs conocidos**. Solo queda la **validación en tiempo de ejecución** de abajo.

---

## Datos del build (del código, para la prueba)

- **Puerto por defecto:** `44000` y **dirección por defecto:** `zimaro.playit.game` (el `Port` SpinBox / `Address` LineEdit de `playonline`; editables y persistidos mediante historial). Para las pruebas locales de este documento, cambia a `127.0.0.1` y el puerto que prefieras.
- **Servidor:** botón **"Manage Rooms"** → `ENetMultiplayerPeer.create_server(port)` → abre `host_session`.
- **Cliente:** botón **"Join Rooms"** → `create_client(address, port)` → abre `client_session`.
- **Sala por defecto (solo servidor headless):** `level_1` (`DEFAULT_ROOM_LEVEL`). En la GUI el host elige el nivel.
- **Protocolo:** ENet sobre **UDP** → los túneles/redes deben reenviar **UDP** (ver Prueba C).

---

## Prueba A — Loopback local (2 instancias en el MISMO PC) · `127.0.0.1`

> ✅ **VALIDADO SOBRE EL TERRENO (2026-07-02).** `playonline` local, el host crea una sala, el cliente entra y aparece en la sala
> (el escenario aparece, no gris), el host muestra "(1 connection)", replicación cliente↔host. **El netcode está
> probado.** Solo quedan las Pruebas B/C (transporte de red real entre 2 PC). Ajustes de UI hechos en la misma
> sesión: ventana de error no destructiva ([[🚪 salas (ES)|Salas]] "ventana de error NO DESTRUCTIVA") y una guarda
> de carrera en el "Play" del cliente (no aparecer en una sala detenida durante `chooseplayer`).
>
> Valida TODA la lógica de salas sin depender de una red real. Es la prueba que yo (Claude) puedo dirigir
> localmente; y la que tú ejecutas en 1 minuto. **Si A pasa, el netcode es correcto** — B/C solo ejercitan
> el transporte de red.

**Setup:** abre **dos** ventanas del juego (el `.exe` en `build/windows/ZIMARO.exe` o dos ejecuciones
desde el editor). Ventana 1 = HOST, Ventana 2 = CLIENTE.

1. **[HOST]** Menú → **Play Online** → (chooseplayer → levels → playonline) → en PlayOnline, Puerto `4383`
   → **"Manage Rooms"**. Aterriza en el `host_session` (grid vacío).
2. **[HOST]** Elige **Level 1** en el desplegable → **"Start Room"**. Aparece **"Room #1 — level_1 (0 connections)"**.
3. **[CLIENTE]** Menú → **Play Online** → en PlayOnline, IP `127.0.0.1`, Puerto `4383` → **"Join Rooms"**.
   Aterriza en el `client_session` y **lista "Room #1 — level_1"** con un botón **Play**.
4. **[CLIENTE]** **Play** → elige un personaje → aparece **dentro de la sala** (se renderiza en la ventana principal).
   - ✅ **Comprobar:** el escenario aparece (NO una pantalla gris/negra), jugador con cámara, la puntería funciona.
   - ✅ **[HOST]** la fila de la sala pasa a **"(1 connection)"**.
5. **[HOST]** En la sala #1, botón **Observe** → ve el escenario en el SubViewport; **el jugador del cliente aparece
     moviéndose** (replicación servidor→host de la posición del cliente). El WASD del host mueve la cámara libre. **ESC** sale.
6. **[HOST]** En la sala #1, botón **Play** → elige un personaje → aparece en la MISMA sala.
   - ✅ **[CLIENTE]** el jugador del HOST aparece en la escena del cliente (replicación servidor→cliente); ambos se ven
     y se mueven. Disparar desde uno debería dañar al otro (combate replicado).
7. **[HOST]** **ESC** mientras juega → diálogo "Disconnect and return to management?" → **Yes** → vuelve al
   grid con el ratón visible; el jugador del host desaparece de la escena del cliente.
8. **[HOST]** botón **Restart** en la sala → ✅ **[CLIENTE]** recibe **"The level was restarted by the host"**,
   vuelve al navegador, y la **sala recreada (nuevo #id)** reaparece en la lista para volver a entrar.
9. **[HOST]** botón **Stop** en la sala (con el cliente dentro) → ✅ **[CLIENTE]** recibe **"The level was stopped
   by the host"** y vuelve al navegador; la sala desaparece del grid del host.
10. **[HOST]** **Start** dos salas (Level 1 y Level 2) a la vez → el cliente entra en una; ✅ **aislamiento:**
    lo que ocurre en una sala **no** aparece en la otra (enemigos/jugadores filtrados por sala).
11. **[CLIENTE]** **ESC** en el navegador (fuera de una sala) → vuelve a PlayOnline (cierra el peer).
    **[HOST]** **Back** → desmonta el servidor, vuelve a PlayOnline.

**Si algún paso falla:** anota el paso + la consola (ejecuta desde el editor para ver `push_error`/RPC).
Sospechosos por síntoma: *pantalla gris en el cliente* → template/cache de escena (ver [[🚪 salas (ES)|Salas]] "las salas
nacen limpias"); *jugador sin cámara* → filtro de visibilidad (`public_visibility`, ver [[🚪 salas (ES)|Salas]]); *nada se replica* →
ruta determinista `/root/RoomManager/Room<id>/Level`.

---

## Prueba B — LAN (2 PC en la MISMA red/Wi-Fi)

Igual que la Prueba A, pero las dos máquinas son físicas.

1. En el HOST-PC, halla la **IP local**: `ipconfig` → "IPv4 Address" (p. ej.: `192.168.0.42`).
2. HOST-PC: hospeda (pasos 1-2 de la Prueba A).
3. CLIENTE-PC: en PlayOnline, IP = **la IP local del host**, Puerto `4383` → **Join Rooms** → continúa desde el paso 3.
4. Si no conecta: el **Firewall de Windows** del HOST-PC puede estar bloqueando UDP `4383` — abre el puerto
   (o permite el `ZIMARO.exe` la primera vez que Windows lo pida). Confirma que ambos están en la misma subred.

---

## Prueba C — Internet (2 PC en redes distintas) · playit.gg (UDP)

El juego es **UDP** → necesita un túnel UDP o port forwarding. **ngrok NO funciona (TCP).** Recomendado: **playit.gg**.

1. HOST-PC: instala el agente **playit.gg**, crea un túnel **UDP** apuntando al puerto local `4383`.
   playit da una dirección pública con el formato `<sub>.playit.gg` + **un puerto** (p. ej.: `147.185.221.x:xxxxx`).
2. HOST-PC: hospeda normalmente en el puerto `4383` (**Manage Rooms**).
3. CLIENTE-PC: en PlayOnline, IP = **la dirección de playit**, Puerto = **el puerto de playit** → **Join Rooms**.
   > ⚠️ El puerto del cliente es el **puerto público del túnel**, que puede ser **distinto** de `4383`.
4. Sigue la matriz de verificación de la Prueba A (pasos 4-10).
5. Alternativas: **Tailscale/ZeroTier** (VPN mesh — el cliente usa la IP `100.x` del host, puerto `4383`) o
   **port forwarding** en el router (reenvía UDP `4383` → la IP local del host). Ver [[🛰️ hospedagem-online (ES)|Hospedaje online]].

---

## Matriz de capacidades (qué prueba cada paso)

| Capacidad | Paso(s) | Prueba |
|---|---|---|
| El servidor arranca + crea una sala | A2 | `create_server` + `start_room` |
| El cliente conecta + lista salas | A3 | `create_client` + `request_room_list`/`receive_room_list` |
| El cliente entra y aparece en la sala | A4 | `client_join_room`/`join_room` + spawn + espejo local |
| Replicación cliente→host | A5 | visibilidad por sala + `MultiplayerSynchronizer` |
| **El host juega en la sala** | A6 | `host_spawn_in_room` (peer 1) + la cámara del jugador en el SubViewport |
| Replicación host→cliente + combate | A6 | spawn del peer 1 replicado + `hit()` RPC |
| Host ESC (saliendo del juego) | A7 | `host_leave_room` |
| Reiniciar sala | A8 | `restart_room` + `notify_room_restarted` |
| Detener sala | A9 | `stop_room` + `notify_room_closed` |
| Aislamiento entre salas | A10 | filtro de visibilidad por `room_id` |
| Red real (LAN/Internet) | B/C | transporte UDP fuera del loopback |

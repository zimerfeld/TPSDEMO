---
tipo: sistema
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# ⚡ Sistema — Indicadores de rendimiento (PerformanceHUD + StabilityGuard)

> Reemplazó al antiguo **SystemHealth** el 2026-06-20. Son DOS autoloads complementarios:
> **StabilityGuard** (protección siempre activa) y **PerformanceHUD** (barra de lectura, opcional).
> Ambos leen únicamente del singleton `Performance` (métricas internas del motor, fiables y
> multiplataforma). Ver [[🧱 recursos-nativos-godot (ES)|Recursos nativos de Godot]].
>
> **Etiqueta en la pantalla de desarrollador (2026-06-23):** la fila que activa la barra (clave `performance_hud`) está
> etiquetada como **"Health Monitor"** / PT "Monitor de Saúde" (antes era "Performance HUD"). La clave de configuración
> y los autoloads NO cambiaron.

## StabilityGuard (`autoload/stability_guard.gd`)

Red de seguridad contra crash/freeze, **siempre activa** (sin toggle). Muestrea cada
`check_interval` (0.5 s) y clasifica en 3 estados, aplicando la acción en la **transición**:

| Estado | Acción |
|---|---|
| `NORMAL` | física a `physics_normal_tps` (60), árbol sin pausar, overlay oculto |
| `THROTTLE` | la física baja a `physics_throttle_tps` (30) + señal `throttle_activated` |
| `EMERGENCY` | `get_tree().paused = true` + overlay de emergencia (pantalla completa, ESC lo descarta) |

**5 indicadores** (umbrales `@export`, en `warn`/`crit`):

| Indicador | Monitor | Riesgo real |
|---|---|---|
| RAM libre del sistema | `OS.get_memory_info()` "free" | poca RAM física libre → swap/OOM/freeze |
| VRAM | `RENDER_VIDEO_MEM_USED` | agotamiento → crash del driver de la GPU |
| Collision Pairs | `PHYSICS_3D_COLLISION_PAIRS` | explosión → freeze del hilo de física |
| Node Count | `OBJECT_NODE_COUNT` | fuga → la RAM crece sin parar |
| FPS | `TIME_FPS` | `≤ fps_crit` durante `fps_crit_frames` → bucle principal bloqueado |

- **RAM movida al sistema (2026-06-21):** la comprobación de RAM usa `OS.get_memory_info()` "free"
  y actúa cuando la RAM física libre cae **POR DEBAJO** de los umbrales (`ram_free_warn_mb` 1024 / `ram_free_crit_mb`
  512) — invertido respecto a los otros indicadores (que actúan POR ENCIMA del umbral). `MEMORY_STATIC` (la RAM del juego)
  era 0 en el `.exe` de release, por lo que la protección de RAM nunca se disparaba en el ejecutable. Sin datos de plataforma
  (`free < 0`) la comprobación de RAM se omite (nunca se dispara por falta de datos).
- Señales: `state_changed(new_state, reason)`, `throttle_activated`, `emergency_activated`,
  `recovered` — el PerformanceHUD las escucha para el badge.
- `state_name()`/`state_color()`/`last_reason`/`dismiss_emergency()`/`force_check()` son la API de lectura/control.
  El overlay corre en `PROCESS_MODE_ALWAYS` (vive durante la pausa).
- Los textos del overlay y el `reason` se localizan vía `Locale.tr_key` (plantillas con `%`
  preservado, formateado después) — diccionario en `res://scenes2D/overlays/Resources`.

## PerformanceHUD (`autoload/performance_hud.gd` + `scenes2D/overlays/performance_bar.gd`)

Overlay GLOBAL: el autoload (Node `PerformanceHUD`) crea un `CanvasLayer` (layer 99) con la
barra `performance_bar.gd`, mostrada/ocultada por la configuración `game/performance_hud` (toggle **Performance
HUD** en la pantalla `developer`). Es **click-through** (el ratón solo sobre la barra de toggle) y
`_process` se omite cuando está oculto (`is_visible_in_tree`).

- **Básico** (32 px): `FPS | NET | RAM | CPU% | GPU% | ● badge de StabilityGuard`.
  - `CPU%` **(2026-06-23)** = `(TIME_PROCESS + TIME_PHYSICS_PROCESS) / real_frame_time ÷ cores`
    (`OS.get_processor_count`) → el % del PROCESO relativo al **total del sistema** (~ Administrador de
    Tareas), en lugar del antiguo fijo `TIME_PROCESS / 16.67` que **se saturaba al 100%** por core.
    Sigue siendo un proxy (solo process+física del hilo principal; no cuenta el hilo de render) — subestima frente a la CPU
    real del proceso, pero ya no se satura. `GPU%` = proxy vía `RENDER_TOTAL_DRAW_CALLS_IN_FRAME`.
  - **NET (2026-06-24)** mide el **RTT/ping de ENet** (`_refresh_net`): en el **cliente**, el ping al
    servidor (`enet.get_peer(1).get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)`); en el **host**, la
    **media** de los pings de los clientes + el recuento (`NET: 42 ms (2)`); sin cliente muestra `NET: host (0)`.
    Coloreado por umbral (<80 ms verde / <160 amarillo / si no rojo). Sin conexión o sin peer de ENet →
    **"N/A"**. Funciona a través de túneles UDP (p. ej.: **playit.gg**): ENet mide el RTT real del paquete,
    incluyendo el relay. (Antes dependía de un `NetworkManager.get_total_bps()` inexistente → atascado en "N/A".)
  - **RAM** (2026-06-21) = memoria del **SISTEMA** vía `OS.get_memory_info()`, formato **"usado/total GB"**
    (usado = `physical - free`, como el "En uso" del Administrador de Tareas; coloreado por % de uso).
    **Por qué:** `Performance.MEMORY_STATIC` solo se registra en **debug** y es **0 en el .exe exportado en release**.
    `OS.get_memory_info()` funciona en release; usa `free` (no `available`, que en Windows
    es memoria virtual/commit y daría `physical - available < 0` → 0).
- **Avanzado** (toggle ▼/▲, 130 px): columnas **CPU** (Process/Physics/Load/Nodes/Objects/3D Bodies/
  Col. Pairs), **GPU** (Draw Calls/Triangles/VRAM/Tex. Mem.) y **Memory** (**System RAM** — el
  mismo usado/total GB que el básico — / Resources), cada valor coloreado por umbral (verde/amarillo/
  rojo), más la fila del Guard.

## Integración

- `project.godot` `[autoload]` (después de `DebugOverlay`): `StabilityGuard` y `PerformanceHUD`.
- `developer.gd`: `_TOGGLES["PerformanceHUDRow"] = "performance_hud"`; `_on_toggle` llama a
  `PerformanceHUD.refresh()`. Fila `PerformanceHUDRow` en `developer.tscn`.
- `config.gd`: por defecto `game/performance_hud = false`. La protección (StabilityGuard) **no** tiene
  configuración — está siempre activa.
- Localización: claves de HUD/Guard en `scenes2D/overlays/Resources/overlays.{pt,en}.json`
  (escaneadas por `Locale`), con todos los nodos en `Locale.SKIP_GROUP` (el script es dueño de los textos).

## Por qué reemplazó a SystemHealth

SystemHealth también pausaba el árbol; mantener ambos crearía una pelea por `get_tree().paused`.
Decisión (2026-06-20): StabilityGuard pasa a ser la ÚNICA protección y PerformanceHUD la lectura. **Pérdidas
aceptadas**: la CPU REAL por proceso (hilo de PowerShell `Get-Process`) y el **beep** de pico crítico de
SystemHealth no se portaron — el CPU% del HUD es un proxy de tiempo de frame.

Relacionado: [[🧱 recursos-nativos-godot (ES)|Recursos nativos de Godot]], [[🗣️ localizacao (ES)|Localización]], [[🐞 debug-overlay (ES)|Debug Overlay]].

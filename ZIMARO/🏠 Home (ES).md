---
tipo: moc
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-06
---

# 🏠 ZIMARO — Bóveda de Neuronas

> 🇧🇷 Leia esta página em português → [[🏠 Home]]

> 🇺🇸 Read this page in English → [[🏠 Home (EN)]]

> [!abstract] 🧠 Qué es esta bóveda
> La memoria persistente de Claude para el proyecto **ZIMARO** — un sandbox de disparos en tercera
> persona construido con **Godot 4**, con multijugador con autoridad de servidor. La bóveda se actualiza al
> final de cada tarea relevante y refleja el estado real del código.
>
> 📁 **Carpeta de la bóveda:** `ZIMARO/` en la raíz del repositorio (`C:\GODOT\ZIMARO\ZIMARO`) — renombrada
> de `OBSIDIAN/` al nombre del proyecto el 2026-07-05.

## ⚡ Resumen ejecutivo

- **Qué es:** un sandbox de disparos en tercera persona (Godot 4.x) con combate, daño localizado por miembro, enemigos con IA y **multijugador online** con salas simultáneas (autoridad de servidor, ENet/UDP).
- **Repositorio:** `C:\GODOT\ZIMARO` · GitHub: [zimerfeld/ZIMARO](https://github.com/zimerfeld/ZIMARO) (código abierto, portafolio).
- **Stack:** Godot 4.6.2 · GDScript · build de Windows vía `build_windows.ps1` (un único .exe con PCK embebido).
- **Diferenciadores:** salas multinivel en el mismo servidor (SubViewport+World3D), daño por hitbox por miembro (headshot), gestores de Plantillas/Escenarios por nivel, i18n EN/PT/ES en cada pantalla.
- **Objetivo de rendimiento:** mínimo **60 FPS** en hardware gráfico mínimo, usando solo técnicas baratas (cielo procedural, shaders emisivos, niebla) — validado en el `.exe`.
- **Estado actual:** varios ítems P0 hechos y a la espera del commit/revisión del usuario; el netcode de salas probado en loopback; validación en red real (2 PC) aún pendiente. Ver [[📌 Backlog (ES)|Backlog]].
- **Ángulo de negocio:** producto de código abierto en el portafolio zimerfeld (prueba social vía estrellas/descargas de GitHub); financiación vía GitHub Sponsors y Ko-fi → [[💜 Financiamento e Patrocínio (ES)|Financiación y Patrocinio]].

## 🧭 Navegación por prioridad

### 1️⃣ 🔑 Impacto — Archivos Clave
> Archivos que, al tocarlos, tienen un gran impacto en el sistema.
- [[🎮 player-gd (ES)|player-gd]] — `library3D/characters/players/player/player.gd`: núcleo del jugador (movimiento/cámara/estado)
- [[🕹️ player-input-gd (ES)|player-input-gd]] — `player_input.gd`: captura y sincronización de input (PlayerInputSynchronizer)
- [[🤖 red-robot-gd (ES)|red-robot-gd]] — `red_robot.gd`: cuerpo/estados del enemigo Red Robot
- [[🧠 red-robot-ai-gd (ES)|red-robot-ai-gd]] — `IA/red_robot_ai.gd`: IA reactiva del Red Robot (objetivo, formación, cadencia de disparo)
- [[💥 bullet-gd (ES)|bullet-gd]] — `bullet.gd`: proyectil y RPC de impacto
- [[🦿 limb-colliders-gd (ES)|limb-colliders-gd]] — `effects_shared/limb_colliders.gd`: hitboxes por miembro + autoajuste de la cápsula de locomoción
- [[🦴 body-parts-gd (ES)|body-parts-gd]] — `effects_shared/body_parts.gd` (+ body plans): partición del cuerpo
- [[💚 health-bar-gd (ES)|health-bar-gd]] — `health_bar.gd`: barra de salud del jugador
- [[🩹 enemy-health-bar-gd (ES)|enemy-health-bar-gd]] — `controls2D/enemy_health_bar.gd`: barra de salud del enemigo (HUD)
- [[🧭 main-gd (ES)|main-gd]] — `scenes2D/main/main.gd`: enrutador de escenas (el punto de entrada del juego)

### 2️⃣ 🧩 Reutilización — Sistemas
> Subsistemas reutilizados por varias partes del proyecto.
- [[🎮 player (ES)|jugador]] — movimiento, física, animación, cámara
- [[🤖 inimigos (ES)|enemigos]] — Red Robot: IA reactiva (recarga 1,5× + retirada ≤10 m), estados, HUD con alcance
- [[🔫 combate-tiro (ES)|combate/disparos]] — bala, RPC de impacto, cooldown
- [[⚔️ facções (ES)|facciones]] — bandos en runtime (hostil/aliado/neutral): sin fuego amigo, targeting por facción, neutrales dinámicos
- [[🌐 multiplayer (ES)|multijugador]] — arquitectura con autoridad de servidor
- [[🚪 salas (ES)|salas]] — servidor multinivel: salas simultáneas (SubViewport+World3D) + rejilla de gestión
- [[🛰️ hospedagem-online (ES)|hospedaje online]] — jugar por internet: playit.gg (UDP) · Tailscale/ZeroTier · redirección de puertos (ngrok NO funciona)
- [[❤️ sistema-de-vida (ES)|sistema de salud]] — HP, barra de salud, respawn
- [[🩸 dano-localizado (ES)|daño localizado]] — daño por arma, hitboxes Area3D por miembro, headshot
- [[🗿 biblioteca-de-modelos (ES)|biblioteca de modelos]] — pantalla Models: navegador/extractor de malla, galería Exported, categoría Estructuras + miembro fallback CORPO
- [[🧩 templates-de-level (ES)|plantillas de nivel]] — gestores de Plantilla (personajes) y Escenario por nivel: navegación en cascada de carpetas, activos independientes
- [[🌌 ambiente-dos-levels (ES)|entorno de los niveles]] — cielo procedural + niebla + shader de suelo con rejilla neón (Nivel 1 cian / Nivel 2 ámbar), 60 FPS en el .exe
- [[🌀 fundos-2D-animados (ES)|fondos 2D animados]] — fondos animados por shader para pantallas 2D (portal/vórtice); la regla de la costura del eje izquierdo con `atan()`
- [[🔊 audio (ES)|audio]] — buses (Master/Outside/Reactor/Music/SFX), música de fondo por escena/nivel (MusicManager) + UI del Music Manager
- [[🐞 debug-overlay (ES)|debug overlay]] — DebugOverlay + pantalla developer a 2 columnas (Debug 2D amarillo / Debug 3D cian), rejilla, etiquetas 3D
- [[⚡ performance-hud (ES)|performance HUD]] — PerformanceHUD (barra FPS/NET/RAM/CPU/GPU) + StabilityGuard (protección contra cuelgues/congelaciones)
- [[🗣️ localizacao (ES)|localización]] — idioma EN/PT/ES: autoload Locale + diccionarios por escena, persistido, botones en TODAS las pantallas
- [[🧱 recursos-nativos-godot (ES)|recursos nativos de Godot]] — qué nodos/recursos NATIVOS usa el juego, por subsistema; helpers RefCounted sin nodo

### 3️⃣ 🔀 Uso — Flujos
> Flujos de uso paso a paso.
- [[🎬 fluxo-de-cenas (ES)|flujo de escenas]] — main (enrutador) → menu → chooseplayer→levels→level_1/level_2 · settings · developer→models
- [[⌨️ fluxo-de-input (ES)|flujo de input]] — captura → sincronización → movimiento
- [[🎯 fluxo-de-tiro (ES)|flujo de disparo]] — apuntar → disparar → bala → impacto → daño
- [[🧪 teste-salas-multiplayer (ES)|pruebas de salas multijugador]] — protocolo de prueba de salas (loopback local → LAN → internet vía playit.gg)

## 🚀 Operaciones
- [[💻 Rodar no Editor (Dev) (ES)|Ejecutar en el Editor (Dev)]] — abrir el proyecto en el editor de Godot 4.6.2 y ejecutar; loopback multijugador con 2 instancias
- [[🚀 Build Windows (Prod) (ES)|Build Windows (Prod)]] — `pwsh -File build_windows.ps1` → un único `.exe` (PCK embebido) + acceso directo en el Escritorio

## 🔖 Convenciones
- [[📄 formatacao (ES)|formato de archivos]] — UTF-8 sin BOM, LF, sin espacios finales, salto de línea final + reconstrucción de la caché de UID
- [[🔽 dropdowns (ES)|desplegables]] — todo OptionButton empieza con "Selecione..." (ítem 0, por defecto); las cascadas reinician los dependientes
- [[📌 ancoragem-ui (ES)|anclaje de UI]] — las barras de botones del pie usan BOTTOM_WIDE; la resolución se limita a la pantalla utilizable
- [[📐 layout-responsivo (ES)|layout responsivo]] — contenedores (no offsets absolutos); esqueleto Margin→VBox→HBox; piloto: developer
- [[🔁 navegacao-tab (ES)|navegación por Tab]] — helpers de `UINav` (foco/Tab): `wire_tab_ring`, `focus_tab_one`, `focus_first`, `cancel_active_edit`

## 💼 Negocio
- [[💜 Financiamento e Patrocínio (ES)|Financiación y Patrocinio]] — GitHub Sponsors + Ko-fi, FUNDING.yml, prueba social en los README

## 🧭 Meta
- [[📌 Fatos-Chave (ES)|Datos Clave]] — organización de carpetas, autoloads, pantallas extra, motor/red/HUD de un vistazo

## 📌 Retomar el trabajo
- [[📌 Backlog (ES)|Backlog]] — **empieza aquí** al retomar el proyecto en otra sesión

## ⚖️ Licencia
- **CC BY-NC-ND 4.0** (Creative Commons Atribución-NoComercial-SinDerivadas 4.0 Internacional) · © 2026 Renato Zimerfeld — compartir no comercial con atribución; **sin uso comercial** y **sin obras derivadas**. Fuente de verdad: `LICENSE.md` en la raíz del repo; nombrada en los README (`README.md`, `README.en-US.md`, `README.pt-BR.md`, `README.es-ES.md`).

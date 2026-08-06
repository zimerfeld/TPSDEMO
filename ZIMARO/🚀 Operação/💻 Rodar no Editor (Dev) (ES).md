---
tipo: procedimento
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# 💻 Ejecutar en el Editor (Dev)

> **Objetivo:** ejecutar y desarrollar ZIMARO localmente a través del editor de Godot — incluyendo la
> prueba multijugador por loopback con 2 instancias en el mismo PC (sin red real).

## ⚡ TL;DR

Abre el proyecto `C:\GODOT\ZIMARO` en **Godot 4.6.2**
(`C:\GODOT\Godot_v4.6.2-stable_win64.exe\…`) y **ejecuta el proyecto** (F5). La escena principal es
`main` ([[🧭 main-gd (ES)|main-gd]], el router), que abre el **menu** — ver
[[🎬 fluxo-de-cenas (ES)|flujo de escenas]].

## ⚙️ Paso a paso

1. **Cierra** cualquier instancia en ejecución del juego **y** el editor de Godot antes de tocar el código
   (regla del proyecto — ver `CLAUDE.md`; hay hooks en `.claude/settings.json` que cierran
   automáticamente `ZIMARO.exe` en cada prompt).
2. Abre el proyecto en el editor de Godot 4.6.2 y ejecuta (F5). Navegación: menu → chooseplayer →
   levels → level_1/level_2 · settings · developer → models ([[🎬 fluxo-de-cenas (ES)|flujo de escenas]]).
3. **Multijugador por loopback (2 instancias en el MISMO PC)** — protocolo completo en
   [[🧪 teste-salas-multiplayer (ES)|teste-salas-multiplayer]] (Prueba A, ✅ validada en campo 2026-07-02):
   - Abre **dos** ventanas del juego (el `.exe` de `build/windows/ZIMARO.exe` o **dos ejecuciones desde el
     editor**). Ventana 1 = HOST, Ventana 2 = CLIENTE.
   - **[HOST]** Menu → **Play Online** → Puerto `4383` → **"Manage Rooms"** → elige un Level →
     **"Start Room"**.
   - **[CLIENTE]** Menu → **Play Online** → IP `127.0.0.1`, Puerto `4383` → **"Join Rooms"** →
     **Play**.
   - Si falla: ejecuta **desde el editor** para ver la consola (`push_error`/RPC).
   - **Atajo automatizado:** `pwsh -File scripts/dual-window.ps1` abre las dos ventanas lado a lado
     (media pantalla cada una) y hace host + join por su cuenta — ver
     [[🪟 Duas Janelas Lado a Lado (Dev) (ES)|🪟 Dos Ventanas Lado a Lado (Dev)]].
4. Validación sin ventana (usada en sesiones): Godot **headless** ejecuta el juego durante ~300 frames para
   cazar errores de script/runtime — los avisos `ObjectDB leaked` / `resources still in use` al cierre
   forzado (`--quit-after`) son benignos.

## 📏 Reglas que respeta

- **Nunca hacer commit/publicar** — dejarlo para que el usuario lo revise (GitFlow; rama activa en
  [[📌 Backlog (ES)|Backlog]]).
- Al final de una tarea con impacto en el usuario: actualizar READMEs + vault y ejecutar el build de producción
  ([[🚀 Build Windows (Prod) (ES)|Build Windows (Prod)]]); cero errores/avisos.

## 🛟 Resolución de problemas

- **Archivo bloqueado / "Failed to rename temporary file":** quedó abierta alguna instancia del juego — cierra
  `ZIMARO.exe` (los hooks del proyecto lo hacen automáticamente).
- **Pantalla gris en el cliente al unirse a una sala:** caché de plantilla/escena — ver
  [[🚪 salas (ES)|salas]] ("las salas nacen limpias"); más síntomas en la tabla de
  [[🧪 teste-salas-multiplayer (ES)|teste-salas-multiplayer]].

## 🔗 Enlaces
- [[🚀 Build Windows (Prod) (ES)|Build Windows (Prod)]] — generar el `.exe` de producción
- [[🧪 teste-salas-multiplayer (ES)|teste-salas-multiplayer]] · [[🚪 salas (ES)|salas]] · [[🌐 multiplayer (ES)|multiplayer]] · [[🎬 fluxo-de-cenas (ES)|flujo de escenas]]
- [[🏠 Home (ES)|Inicio]] · [[📌 Backlog (ES)|Backlog]]

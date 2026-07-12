---
tipo: procedimento
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# 🚀 Build Windows (Prod)

> **Objetivo:** generar el build "de producción" de ZIMARO — un `.exe` de Windows autónomo
> (**PCK embebido**) + un acceso directo en el Escritorio, mediante el script `build_windows.ps1` en la raíz del proyecto.
> Ejecútalo al final de cada tarea que cambie código/assets.

## ⚡ TL;DR — el único comando

```powershell
pwsh -File build_windows.ps1
```

> `-Force` siempre construye (omite el atajo de "sin cambios"): `pwsh -File build_windows.ps1 -Force`.

## ⚙️ Qué hace el script (en orden)

1. **Exporta** `build/windows/ZIMARO.exe` (release, **PCK embebido** → un único archivo de ~589 MB)
   mediante la CLI headless de Godot 4.6.2 (`godot --headless --export-release "Windows Desktop"`), usando
   el preset en `export_presets.cfg` (preset `Windows Desktop`, `binary_format/embed_pck=true`,
   arquitectura `x86_64`).
2. **Icono** `build/icon.ico` — generado solo la 1ª vez: rasteriza `res://icon.svg` mediante un
   tool script headless temporal de Godot (`Texture2D.get_image().save_png`) y lo convierte a un
   `.ico` multitamaño con Python 3 + Pillow. Después se reutiliza (borra el archivo para regenerarlo).
3. **Acceso directo** `ZIMARO.lnk` en el Escritorio (mediante `WScript.Shell`), apuntando al `.exe`, con
   `IconLocation = build/icon.ico`.

## 🛟 Notas, reglas y resolución de problemas

- **Requisitos previos:** Godot 4.6.2 en `C:\GODOT\Godot_v4.6.2-stable_win64.exe\…` + las plantillas de exportación
  4.6.2 instaladas. El `.ico` (1ª generación) necesita Python 3 con Pillow.
- ⚠️ **Caché de exportación con una escena OBSOLETA (2026-07-03):** la exportación reutiliza escenas convertidas de la
  caché `.godot/exported/`, que **no se invalida cuando cambia un `.tscn`** — el exe se envió
  con la escena DESACTUALIZADA incluso con `-Force` (la pantalla `levels` reconstruida mostrando el layout antiguo).
  **Corrección definitiva en el propio script:** `build_windows.ps1` ahora borra `.godot/exported/`
  **antes de cada exportación** (coste: reconvertir las escenas, segundos). Síntoma residual durante
  investigaciones: SIEMPRE validar el cambio visual en el build. Cuidado también con las
  **carreras de reescritura** (hook de formateo/editor externo con el archivo abierto) — si el exe sale
  "una edición por detrás", compara el `LastWriteTime` de las fuentes × el exe antes de sospechar del código.
- El **icono NO está embebido en el .exe** (eso requeriría `rcedit`, un binario externo no
  instalado) — vive solo en el acceso directo. Instalar/configurar `rcedit` en el editor permitiría
  embeberlo en el propio ejecutable.
- **Cierra automáticamente una instancia abierta antes de exportar (2026-06-21):** `Stop-RunningZimaro` mata cualquier
  proceso cuyo **path** == `build/windows/ZIMARO.exe` (no solo por nombre) y borra un `.tmp`
  huérfano, justo antes de la exportación — de lo contrario la ventana abierta bloquea el archivo y Godot falla con
  *"Failed to rename temporary file … ZIMARO.tmp"*. Se ejecuta **solo cuando realmente va a construir**
  (después del salto de "sin cambios"), de modo que no cierra el juego en turnos sin cambios en las fuentes.
- **Boot splash sin el logo de Godot (2026-06-21):** `project.godot` → `[application]`
  `boot_splash/show_image=false` (quita la imagen/logo), `boot_splash/bg_color=Color(0,0,0,1)`
  (fondo negro) y `boot_splash/minimum_display_time=0`. La ventana se abre oscura hasta el
  menu — sin marca de agua del motor. (En la exportación de Windows el splash NO desaparece del todo; esto es
  lo más "enmascarado" posible sin un build personalizado.)
- `build/` y `export_presets.cfg` están **ignorados por git** (ver `.gitignore`); se quedan en local.
- **Saltar si nada cambió:** sin `-Force`, el script compara la fecha del `.exe` con el
  archivo de fuente más reciente (ignorando `.godot/`, `build/`, `.git/`, `ZIMARO/`, `.md`, `.ps1`) y
  **sale inmediatamente** si el `.exe` ya está al día. `pwsh -File build_windows.ps1 -Force`
  siempre construye.
- **Automatizado por hook (2026-06-21):** hay un hook **`Stop`** en `.claude/settings.json`
  (hooks solo del proyecto; `pwsh … build_windows.ps1`, `async`, `timeout 180`) — se ejecuta al final de
  **cada** turno de Claude Code, pero gracias al salto-si-nada-cambió solo exporta realmente
  cuando alguna fuente cambió. Ver/editar: el propio archivo `.claude/settings.json`, o `/hooks` en un
  terminal `claude` interactivo. Ver la memoria `build-exe-at-end-of-tasks`.
- **Hook `UserPromptSubmit` que cierra ZIMARO (2026-06-21):** también en `.claude/settings.json`, se
  ejecuta en **cada prompt del chat** (antes de que Claude procese la petición) el comando de PowerShell
  `Get-Process ZIMARO -ErrorAction SilentlyContinue | Stop-Process -Force …; exit 0` — cierra
  cualquier instancia abierta del juego para liberar bloqueos de archivo antes del trabajo/build. El `exit 0` evita que el
  hook informe de un error cuando no hay nada en ejecución. Redundante (a propósito) con el `Stop-RunningZimaro`
  del build, que cubre el instante de la exportación.

## 🔗 Enlaces
- [[💻 Rodar no Editor (Dev) (ES)|Ejecutar en el Editor (Dev)]] — ejecutar/desarrollar localmente antes de construir
- [[📦 Atualizar Asset da Release (GitHub) (ES)|Actualizar el Asset de la Release (GitHub)]] — publicar el `.exe` construido en la página de releases
- [[🧱 recursos-nativos-godot (ES)|recursos-nativos-godot]] · [[🎬 fluxo-de-cenas (ES)|flujo de escenas]]
- [[🏠 Home (ES)|Inicio]] · [[📌 Backlog (ES)|Backlog]]

---
tipo: procedimento
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-23
---

# 🔌 MCP de Godot (Claude Code)

> **Objetivo:** conectar Claude Code al **editor Godot en vivo** mediante MCP — ejecutar el juego,
> leer la consola e inspeccionar escenas desde el prompt — y registrar los comandos **headless** usados
> para reimportar assets y validar código sin abrir el editor.

## ⚡ TL;DR

El MCP viene del addon de TERCEROS **`addons/godot_ai/`** ([hi-godot/godot-ai](https://github.com/hi-godot/godot-ai)),
que ya está en el repositorio. Activarlo en **Project → Project Settings → Plugins → Godot AI** y, en
el dock **Godot AI**, elegir el cliente y pulsar **Configure**. El plugin levanta el servidor solo
(WebSocket).

## ⚙️ Paso a paso (activar)

1. **Requisitos:** Godot 4.3+ (el proyecto usa **4.6.2**), el instalador de Python
   [`uv`](https://docs.astral.sh/uv/) y un cliente MCP (Claude Code).
   - Instalar `uv` en Windows: `powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"`
2. El addon ya está en `addons/godot_ai/` — si falta, copiarlo a la carpeta `addons/` del proyecto.
3. Activar el plugin: **Project → Project Settings → Plugins → Godot AI**.
4. En el dock **Godot AI**, seleccionar el cliente MCP y pulsar **Configure**. Sin configuración manual.
5. Comprobar: Claude ya expone herramientas `godot` (ejecutar proyecto, parar, leer consola, versión…).

## 🧰 Qué permite el MCP

| Herramienta | Uso |
|---|---|
| `run_project` | ejecuta el juego (opcionalmente una escena concreta) |
| `stop_project` | detiene la ejecución |
| `get_debug_output` | lee la consola y los **errores** de runtime |
| `launch_editor` · `get_godot_version` · `get_project_info` | abrir editor / inspeccionar proyecto |

## 🖥️ Headless (sin editor) — lo que más se usa

Ejecutable en una carpeta homónima: `C:\GODOT\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe`

- **Reimportar assets** (tras cambiar un `.glb`) — es la forma CORRECTA, ver [[🗿 biblioteca-de-modelos (ES)]]:
  `--headless --path C:\GODOT\ZIMARO --import`
- **Validar código / medir rendimiento** con un script temporal `res://_test_x.gd` (`extends SceneTree`):
  `--headless --path C:\GODOT\ZIMARO --script res://_test_x.gd`
  Borrar el script al terminar (regla de limpieza).

## 📏 Reglas que respeta

- **Cerrar el juego en ejecución y el editor Godot** antes de tocar el código (regla del proyecto; hay
  hooks en `.claude/settings.json`). Ver [[💻 Rodar no Editor (Dev) (ES)]].
- **Nunca commitear/publicar** — dejarlo para que el usuario lo revise.

## 🛟 Troubleshooting

- **`No active Godot process`** al parar/leer la consola: no hay nada en ejecución — usar
  `run_project` antes.
- **ESC ya no sale de la pantalla (Models u otra):** la escena se abrió **aislada** (`run_project` con
  `scene:`). El cambio de pantalla usa la señal `replace_main_scene`, y solo **`main.tscn`** la escucha
  ([[🧭 main-gd (ES)]]) — ejecutar el proyecto **sin** indicar escena y navegar por el menú.
- **`.import` inflado / textura desaparecida** tras reimportar: fue el **editor** reimportando. Usar
  siempre `--headless --import` y no matar Godot a mitad de la importación — ver
  [[🗿 biblioteca-de-modelos (ES)]].
- **Falso negativo en pruebas headless:** `set_bone_pose_rotation` **no** cambia
  `get_bone_global_pose` sin un frame real (`Skeleton3D` no recalcula) — validar pose/animación con el
  juego en ejecución, no en headless.

## 🔗 Enlaces
- [[💻 Rodar no Editor (Dev) (ES)]] — ejecutar/desarrollar desde el editor
- [[🚀 Build Windows (Prod) (ES)]] — generar el `.exe` de producción
- [[🏠 Home (ES)]] · [[📌 Backlog (ES)]]

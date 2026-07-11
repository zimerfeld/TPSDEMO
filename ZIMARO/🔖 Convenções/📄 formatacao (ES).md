---
tipo: convencao
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# 📄 Convención — Formateo de archivos

> Aplica siempre el formateo correcto antes de hacer commit y al final de cada tarea.

## Reglas (impuestas por `file_format.sh`)

- Codificación **UTF-8 sin BOM**
- Finales de línea **LF** (Unix)
- **Sin** espacios en blanco al final de las líneas
- **Salto de línea final** al final del archivo

## Cómo aplicar

En la raíz del repositorio (`C:\GODOT\ZIMARO`), mediante **Git Bash** en Windows:

```bash
bash file_format.sh
```

Dependencias: `dos2unix` y `perl` (`recode` es opcional — los archivos ya son UTF-8).

## Por qué importa

- Un **BOM** (`EF BB BF`) al inicio de un `.tscn`/`.tres` hace que el parser de Godot
  falle con `Parse Error: Expected '['`, rompiendo la carga de la escena.
  Eso fue exactamente lo que impedía cargar `level_base` (un nivel luego **eliminado**
  el 2026-07-01) — la corrección fue quitar el BOM de 12 archivos.

## Convención relacionada — cache de UID

Al **mover/renombrar** escenas o recursos:

1. Actualiza todas las referencias `res://...` (incluidas las que están dentro de `.tscn`/`.tres`/`.import`).
2. Reabre el proyecto en el **editor de Godot** una vez para reconstruir el
   `.godot/uid_cache.bin` y reimportar los assets movidos. Esto elimina los
   avisos `invalid UID … using text path instead`.

Los archivos binarios (`.mesh`, `.glb`) pueden contener rutas embebidas que **no** se
corrigen editando texto — en esos casos hay que reimportar/reexportar
desde el `.blend` o reasignar el recurso en el editor.

## Enlaces

- [[🏠 Home (ES)|Home]]

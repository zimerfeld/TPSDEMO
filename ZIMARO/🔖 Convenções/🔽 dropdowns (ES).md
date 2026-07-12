---
tipo: convencao
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# 🔽 Convención — Desplegables (OptionButton)

> Todo desplegable (`OptionButton`) de la UI del juego debe empezar con una
> opción placeholder llamada **"Select..."** como **primer ítem** y **selección
> por defecto**.

## Reglas

1. **Primer ítem = `"Select..."`** en cada desplegable, insertado en el índice `0`
   y seleccionado por defecto (`select(0)`) al construir la pantalla. Los ítems reales
   empiezan en el índice `1` — recuerda el desfase al mapear de vuelta a los datos
   (`data[index - 1]`).
2. **Cascada dependiente.** Al seleccionar `"Select..."` (índice 0) en un
   combo, cada combo que dependa de su valor debe **recargarse también con
   `"Select..."` seleccionado**, y cualquier comportamiento de la pantalla que dependa de la
   selección (vista previa, estado, ventana) debe **reiniciarse/limpiarse**.
3. **La pantalla arranca en blanco.** No se previsualiza/aplica nada hasta que el usuario
   recorre la cadena de selección. No autoselecciones el primer ítem real.
4. **Persistencia de la selección + restauración de la cadena.** Cada elección de desplegable
   se persiste (por un valor **estable** — clave/nombre/centinela, no
   el índice — junto con los toggles). Al reabrir la pantalla, la cadena se reproduce de
   arriba abajo: `select()` no emite `item_selected`, así que cada paso también llama
   al handler explícitamente para poblar el siguiente combo. Regla de parada
   por nivel: un valor **vacío** (el usuario paró ahí) → deja el combo habilitado en el
   placeholder, listo para continuar (con todo vacío = un arranque en blanco normal);
   un valor que **hoy no existe** (una elección guardada que desapareció de la librería, "no hay más
   datos") → **deshabilita ese combo y los de debajo**. Nunca autoselecciona un ítem.

## Nomenclatura de nodos (2026-06-30)

Todo `OptionButton` debe tener su **`Name` en plural** (una regla del proyecto) — el desplegable representa una
**colección** de opciones. Renombrados bajo esta convención:

| Escena | Antes → Después |
|---|---|
| `controls.tscn` | `cboControl` → **`Controls`** (elimina el prefijo `cbo`) |
| `playonline.tscn` | `PortHistory` → **`PortHistories`** · `AddressHistory` → **`AddressHistories`** |
| `settings.tscn` | `VideoResolutionDropdown` → **`VideoResolutions`** (elimina el sufijo de tipo `Dropdown`) |
| `models.tscn` | `Category`→`Categories` · ~~`Prefix`→`Prefixes`~~ (desplegable **eliminado** el 2026-06-30) · `EffectsList`→`EffectsLists` · `MemberGeo`→`MemberGeos` · `SubMemberGeo`→`SubMemberGeos` · `Skeleton`→`Skeletons` · `SkeletonGeo`→`SkeletonGeos` |

Ya en plural (sin cambio): `Models`, `Meshes`, `Animations`, `Members`, `SubMembers`. Los
accesores `%Name` en los `.gd` y el `from=` de los `[connection]` de los `.tscn` siguieron el nombre.

## Casos especiales

- **Filtros "Mostrar todo"** (p. ej.: el antiguo `"All"` del extinto desplegable de prefijo en
  `models.gd` — el propio desplegable de prefijo fue **eliminado** el 2026-06-30):
  sustituido por `"Select..."`, que ahora significa
  "sin filtro" (metadatos vacíos). Sigue listando todos los ítems.
- **Opciones de acción propia** (p. ej.: `"Full model"` en el desplegable de partes en
  `models.gd`): **mantenidas** como ítems seleccionables justo debajo de
  `"Select..."`. P. ej. el orden del desplegable de partes: `Select...`,
  `Full model`, luego cada malla.
- **Desplegables que reflejan estado guardado** (p. ej.: la resolución de vídeo en
  `settings.gd`): `"Select..."` es el valor por defecto solo cuando **no hay valor guardado**;
  si el guardado coincide con un preset, selecciona el preset. Seleccionar `"Select..."`
  no cambia la ventana (un placeholder no-op). El **ancho mínimo** del desplegable se
  ajusta por código (`_fit_dropdown_to_widest_item`) al **texto del ítem más ancho**
  (medido por la fuente resuelta + los márgenes del stylebox + el icono de la flecha), para que ningún
  ítem quede truncado; `size_flags_horizontal` sigue expandiendo por encima de eso.

## Dónde se aplica hoy

- `scenes3D/models/models.gd` — la cadena Category → Model → Part.
- `scenes2D/settings/settings.gd` — el desplegable de resolución de vídeo.
- `scenes2D/controls/controls.gd` — el desplegable de control.

## Enlaces

- [[🏠 Home (ES)|Home]]
- [[🗿 biblioteca-de-modelos (ES)|Librería de modelos]]
- [[📄 formatacao (ES)|Formateo de archivos]]

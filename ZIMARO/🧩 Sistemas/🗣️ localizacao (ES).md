---
tipo: sistema
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# 🗣️ Sistema — Localización (EN/PT/ES)

Cambio de idioma de la UI entre **Português**, **English** y **Español**, mediante el autoload **Locale**
(`autoload/locale.gd`). Los idiomas admitidos están en `Locale.SUPPORTED_LANGS` (`["pt", "en", "es"]`).

## Diccionarios por escena

Cada escena tiene su **propio trío** de JSON planos en una carpeta `Resources/` junto al `.tscn`:
`scenes2D/menu/Resources/menu.pt.json` + `menu.en.json` + `menu.es.json`,
`scenes2D/settings/Resources/settings.pt.json` + `...en.json` + `...es.json`,
`scenes3D/models/Resources/models.pt.json` + `...en.json` + `...es.json`, etc. Cada trío asigna el
texto canónico (de autoría) de cada Button/Label al texto de ese idioma y tiene el **mismo conjunto
de claves** en los tres idiomas.

En el arranque, el Locale **recorre recursivamente** `scenes2D/` y `scenes3D/` (`SCAN_ROOTS`), encuentra
todos los `*.pt.json` / `*.en.json` / `*.es.json` y **fusiona** todo en una tabla por idioma. Para añadir
los diccionarios `Resources/` de una pantalla nueva basta con soltarlos ahí — sin editar el autoload. (Ya
no existe ningún `pt.json`/`en.json`/`es.json` en la raíz del proyecto.)

## Persistencia y aplicación

- La elección se guarda en `Settings` → `game/language` (`"pt"` por defecto / `"en"` / `"es"`; un valor
  fuera de `SUPPORTED_LANGS` recae en el valor por defecto).
- En `_ready`, el Locale lee el idioma persistido, construye la tabla y **se conecta a `node_added`**: todo
  Button/Label que entra en el árbol tiene su `text` traducido automáticamente. `OptionButton`/`MenuButton`
  se **ignoran** (texto = selección viva).
- La primera vez que ve un nodo, guarda el texto original en meta (`_loc_src`); los cambios de idioma
  traducen a partir de ese original (no del texto ya traducido).
- `set_language(lang)` persiste, reconstruye la tabla y **relocaliza el árbol vivo** (emite
  `language_changed`).

## Botones de idioma — en TODAS las pantallas

La `UI/LangBar` (HBox en la esquina inferior derecha con botones "Português" / "English" / "Español", el
mismo patrón que el menú) está en **menu, chooseplayer, settings, developer, levels, playonline, controls y
models**. Cada script llama a `Locale.set_language(...)` y atenúa el botón del idioma activo
(`_update_language_buttons` — cada pantalla tiene `portuguese_button`/`english_button`/`spanish_button`). Como la relocalización es in situ, la pantalla se actualiza al instante.
**Alineación (2026-06-25):** la `LangBar` queda en la **misma franja vertical que el botón "Volver"**
(offsets del pie `−100`/`−50`) en todas esas pantallas.

## Textos que vienen del código (SKIP_GROUP)

Los textos que el localizador automático no alcanza — placeholders/ítems de `OptionButton`, títulos
de las pestañas de settings, diálogos de confirmación, y el **PerformanceHUD**/overlay del **StabilityGuard** —
entran en el grupo `Locale.SKIP_GROUP` y reaplican `Locale.tr_key(...)` por sí solos en la señal
`language_changed`. Las claves del HUD/Guard están en `scenes2D/overlays/Resources/overlays.{pt,en,es}.json`.
(Las pantallas
`models` y `controls` **ya no tienen** `StatusLabel` — retirados el 2026-06-18.)

Los **prefijos de los `Label3D`** de la escena Models (`Membro:`/`Sub-membro:`/`Esqueleto:`/`Tipo:`/`Nome:`)
tampoco los alcanza el autotraductor: van por `Locale.tr_key` y se reconstruyen en
`language_changed` (`_refresh_member_overlays`/`_refresh_aux_labels`) — ver [[🗿 biblioteca-de-modelos (ES)|Biblioteca de Modelos]].

Los **títulos de columna del `Tree`** de la ventana de **Daño** (`Membro`/`Def`/`Bônus %`/`Dono`) son otro
caso: `set_column_title` no es `Label`/`Button`, así que el autotraductor no lo alcanza. Desde 2026-06-27,
`_apply_damage_tree_titles()` los reaplica vía `Locale.tr_key` en la construcción del árbol Y en
`language_changed` (antes quedaban fijos en el idioma de la última construcción) — ver [[🩸 dano-localizado (ES)|Daño Localizado]].

## Regla — cambiaste un texto, actualiza las claves

**Siempre que cambies o añadas un texto de UI en una escena, actualiza la clave correspondiente en
`Resources/<escena>.pt.json`, `Resources/<escena>.en.json` Y `Resources/<escena>.es.json` de la propia
escena, en la misma tarea.** Como el Locale indexa por el texto fuente, cambiar la escena sin actualizar la
clave rompe la traducción. PT recibe la traducción en portugués; EN, en inglés; ES, en español. Validar los
tres JSON al final.

Relacionado: [[🎬 fluxo-de-cenas (ES)|Flujo de Escenas]], [[🐞 debug-overlay (ES)|Debug Overlay]], [[⚡ performance-hud (ES)|Performance HUD]],
[[🧭 main-gd (ES)|main.gd]].

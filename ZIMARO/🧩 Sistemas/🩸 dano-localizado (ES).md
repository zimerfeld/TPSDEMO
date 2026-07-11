---
tipo: sistema
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# 🩸 Sistema de daño de arma + hitboxes localizadas

> Implementado el 2026-06-06; migrado a **colisionadores 3D nativos** el 2026-06-14.
> Daño del **arma** del atacante, con **un `StaticBody3D` por grupo de miembro** y
> **daño localizado** (colisión física, ya no un Area3D "de cristal").

---

## Daño atribuido al arma

| Personaje | `weapon_damage` (export) | Nota |
|---|---|---|
| Player | `50` | Asignado a cada bala disparada (`bullet.weapon_damage = weapon_damage`) |
| Enemy (Red Robot) | `25` | Aplicado al jugador por el láser |

`hit(amount: int)` ahora recibe el valor de daño (antes era fijo).

---

## Grupos de hitbox (miembros)

`effects_shared/limb_colliders.gd` clasifica los huesos en grupos y crea **un `StaticBody3D` por miembro** (ajustado a los vértices skinned, AABB en el espacio del hueso raíz), con metas `group` + `damage_multiplier`. La forma se elige por `make_member_shape()`:

La tabla de abajo es el plan **biped** (el default — ver **Jerarquía de plan corporal**
abajo); los multiplicadores son los **defaults del PLAN** (`BodyParts.default_multiplier`).

| Grupo | Forma | Multiplicador (default del plan) |
|---|---|---|
| **HEAD** (cabeza/cuello) | `SphereShape3D` (cápsula opcional — ver abajo) | `1.5` (+50%) |
| **TORSO** (caderas/columna/pecho/cuerpo) | `BoxShape3D` | `1.0` |
| **ARM R/L** (hombro/brazo/antebrazo/mano/**ala** + lado) | `CapsuleShape3D` (eje largo) | `1.0` |
| **LEG R/L** (muslo/espinilla/rodilla/pie/pierna + lado) | `CapsuleShape3D` (eje largo) | `1.0` |

> Los multiplicadores de arriba son **defaults del plan corporal** (cabeza +50%, todo lo demás 1.0). Desde
> 2026-06-20 cada modelo puede tener su PROPIO multiplicador por miembro, editable en la pantalla Models y
> persistido en la carpeta del modelo (`res://library3D/<cat>/<model_key>/limb_config.json`; override en
> tiempo de ejecución en `user://` — ver **Multiplicadores editables por modelo** abajo).
> Los MIEMBROS en sí dependen del `body_type` del modelo (biped/quadruped/crawler).

Lado detectado por sufijo `.L/.R` (player) o prefijo `L-/R-` (enemigo). `wing` cuenta
como ARM (criaturas aladas: criatura_alada, robot_*_alado).

**Overrides por modelo** (`group_of(..., head_bones, torso_bones, leg_bones)` + exports
`head_bone_names`/`torso_bone_names`/`leg_bone_names` de `LimbColliders`): fuerzan huesos que el
clasificador descartaría de otro modo. red_robot usa: HEAD=`mouth_eyes`+`L-EYE`/`R-EYE` (los ojos van
a la HEAD para que el headshot no sea una esfera diminuta cubriendo solo el panel de la cara — 2026-06-18),
TORSO=`Bone.001`, y **LEG=
`L-RearLegGuard`/`R-RearLegGuard`** (2026-06-18) — las **placas de la pierna**, antes excluidas por la
palabra "guard", van al colisionador de la pierna (lado por el prefijo L-/R-). Los mismos overrides se
aplican en el preview de la pantalla Models (`models.gd` `_MODEL_LEG_BONES`). Huesos de control como
`L-LEGORIENT`/`L-LEGIK` siguen excluidos (no están en la lista).

**Forma de HEAD por modelo** (2026-06-21) — `LimbColliders` tiene un export
`head_shape` (`"sphere"` default o `"capsule"`). El **player** usa `"capsule"`
(`player.gd` fija `lc.head_shape = "capsule"`): la cabeza pasa a ser una **cápsula alineada al
eje más largo de la cabeza** (misma orientación que el hueso), manteniendo el **radio completo**
(`make_member_shape` llama a `make_shape("capsule", aabb, cap_radius=false)`: con
`cap_radius=false` la cabeza salta TANTO el `CROSS_SHRINK` COMO el tope `LIMB_RADIUS_RATIO`
— mantiene el radio completo para **cubrir toda la malla**, en lugar de adelgazar). Otros
modelos mantienen la esfera. El preview de la pantalla Models lo espeja vía la const
`_MODEL_HEAD_SHAPE := {"player":"capsule"}` (`models.gd`), igual que en el juego.

**Ajuste fino de tamaño** (2026-06-16, ancho reducido el 2026-06-20) — para que los
colisionadores se ajusten más al cuerpo: `CROSS_SHRINK = 0.72`
(radio/ancho/profundidad, **solo miembros** — la cabeza con `cap_radius=false` NO
aplica este encogimiento), `LENGTH_SHRINK = 0.95` (eje largo) y
`LIMB_RADIUS_RATIO = 0.32` (tope del radio de la cápsula como fracción de la longitud,
asegurando que un miembro con un AABB casi cúbico — p. ej. el brazo derecho del player, que
sostiene el arma — se lea aún como una **cápsula** y no como una bola).

---

## Jerarquía de plan corporal (2026-06-20)

Los MIEMBROS de cada modelo vienen de su **PLAN CORPORAL**. `effects_shared/body_parts.gd`
(`class_name BodyParts`) ya no es una clase solo estática y pasó a ser una **BASE instanciable
con métodos VIRTUALES** — porque el estático `BodyParts.group_of(...)` **NO es polimórfico** en
GDScript. **Usa siempre una INSTANCIA** (vía `BodyPlans.for_type`/`.default`). Ver
[[🦴 body-parts-gd (ES)\|body-parts-gd]] para la nota dedicada.

- **`BodyParts` (base)** — constantes universales `HEAD`/`TORSO` + `BASE_LABELS` (HEAD/TORSO) +
  `EXCLUDE_KEYWORDS`. **Estáticos universales** (independientes del plan): `side_of(name)` (L/R; detecta
  prefijos/sufijos `L-/R-`, `.l/_l`, `…L/…R` y las palabras `left`/`right`/`esquerd`/`direit`) y
  `front_rear_of(name)` (F/R: front/fore/dianteira vs rear/hind/back/traseira). **Virtuales de
  instancia**: `members()`, `group_of(bone, head_bones, torso_bones, leg_bones)`, `label_of(group)`,
  `default_multiplier(group)` (cabeza 1.5, todo lo demás 1.0) y `default_sub_members()`.
- **`BodyPartsBiped`** (`extends BodyParts`) — añade `ARM_L/ARM_R/LEG_L/LEG_R` (ARM L/R,
  LEG L/R). Es el **DEFAULT**. `wing` cuenta como ARM (criaturas aladas).
- **`BodyPartsQuadruped`** — añade `LEG_FL/LEG_FR/LEG_RL/LEG_RR` (FRONT LEG L/R, REAR LEG
  L/R), **sin brazos**; usa `front_rear_of` + `side_of` para separar las 4 patas.
- **`BodyPartsCrawler`** (serpiente/babosa/gusano) — **solo hereda**: solo HEAD/TORSO (cuerpo alargado =
  TORSO). Punto de extensión futuro.
- **`BodyPlans` (fábrica)** — `effects_shared/body_plans.gd`. `BodyPlans.for_type(body_type) ->
  BodyParts` (match: `quadruped`/`crawler`/`_ => biped`) y `BodyPlans.default()` (biped). `const
  TYPES = ["biped","quadruped","crawler"]`. **Aislado** de las clases para evitar un
  ciclo base↔subclase (la base no referencia las subclases).

**`body_type`** — `LimbColliders` ganó `@export_enum("biped","quadruped","crawler") var
body_type`, que elige el clasificador vía `BodyPlans.for_type` en `build_for`. `player.gd` y
`red_robot.gd` fijan `lc.body_type = "biped"`. La pantalla Models lo espeja en la const
`_MODEL_BODY_TYPE := {"red_robot":"biped","player":"biped"}` (el preview quita scripts, así que el
@export no está disponible) + helpers `_body_type_for_current()`/`_current_classifier()`.

El **overlay de Debug 3D** (`debug_overlay.gd._add_3d_skeleton`) ahora usa `var classifier :=
BodyPlans.default()` (instancia biped) en lugar de los antiguos estáticos, ya que corre sobre
esqueletos de nivel arbitrarios.

> [!note] Miembro "BODY" de fallback (2026-07-01)
> **Todo modelo tiene al menos UN miembro editable.** En la pantalla Models, cuando un modelo **no** tiene
> ningún miembro clasificado, `_add_mesh_member_colliders` (models.gd) sintetiza un único
> miembro **`CORPO`** (BODY) que envuelve **todas las mallas visibles** (AABB), con una forma **box** por defecto —
> para que siempre haya un blanco donde definir un colisionador/daño. Dos situaciones:
> - **Structures/Propulsors** (categorías **sin** plan corporal): el clasificador **no** corre
>   (evita emparejar nombres como `horse_head` a HEAD por substring) → cae directo a `CORPO`.
> - **Characters/Weapons** cuyo rig sin `Skeleton3D` no emparejó ninguna malla → también reciben `CORPO`.
>
> `CORPO` es un miembro normal (meta `group="CORPO"`), así que hereda offset/scale/rotation/shape y el
> multiplicador de daño vía `LimbConfig` (clave `CORPO` en el `limb_config.json` del modelo), y el
> desplegable **Member** ahora aparece para **cualquier categoría** en "Full model" (no solo Characters/Weapons).
> Const `FALLBACK_MEMBER_GROUP`/`FALLBACK_MEMBER_LABEL` en `models.gd`.

---

## Multiplicadores editables por modelo (2026-06-20)

`effects_shared/limb_config.gd` (`class_name LimbConfig`, `RefCounted` con API estática) — el antiguo
`LimbDamage` (renombrado/reemplazado; `limb_damage.gd` + `data/limb_damage.json` fueron **eliminados**)
— almacena el multiplicador de cada miembro/submiembro, la lista de submiembros **y** la relación de propietario
de cada uno. **UN ARCHIVO POR MODELO EN LA CARPETA DEL MODELO (2026-06-22):**
`res://library3D/<category>/<model_key>/limb_config.json` — junto a la malla/escena, versionable y
editable en Godot (`_model_dir` resuelve la carpeta escaneando `library3D`, con caché). **Override
escribible en tiempo de ejecución:** dado que `res://` es **de solo lectura en el .exe exportado** (PCK embebido), las ediciones hechas
MIENTRAS SE EJECUTA el juego (pantalla Models en el .exe) van a `user://limb_config/<model_key>.json`, que tiene
**precedencia de lectura** — así lo que editas en pantalla se relee y aparece. En el editor el guardado va
directo a la carpeta del modelo (fuente canónica) y **borra** el override obsoleto de `user://` de ese modelo.
> ⚠️ **Bug corregido (2026-06-22):** la config solía escribirse en `res://data/limb_config/<key>.json`;
> en el **.exe** `res://` es de solo lectura, así que Add sub-member (p. ej. "mouth"→HEAD) **fallaba al
> escribir** y la reconstrucción releía el disco sin ello → no aparecía en el árbol ni en el desplegable. Con el
> override de `user://` la edición persiste y se refleja en pantalla incluso en el .exe.

**Migración transparente (lectura, en orden):** `user://` (override) → carpeta del modelo → antiguo
`res://data/limb_config/<key>.json` → combinado legado `res://data/limb_config.json`; el primer SAVE
escribe en la nueva ubicación sin perder datos. Esquema de cada archivo:

```json
{
  "damage": { "HEAD": 2.0, "PART_L-RearLegGuard": 1.0 },
  "sub_members": ["L-RearLegGuard", "R-RearLegGuard"],
  "sub_member_owners": { "L-RearLegGuard": "LEG_L", "R-RearLegGuard": "LEG_R" },
  "collider_offsets": { "HEAD": [0.0, 0.1, 0.0] },
  "collider_scales": { "HEAD": [1.2, 1.2, 1.2] },
  "collider_shapes": { "HEAD": "capsule", "TORSO": "none" }
}
```

- **`model_key`** = nombre de la carpeta del modelo (`"red_robot"`, `"player"`), el MISMO valor que
  `player.gd`/`red_robot.gd` pasan en `LimbColliders.model_key`; ahora es el **nombre del archivo**.
  `GROUP` = clave del plan (`HEAD`/`TORSO`/`ARM_L`/…/`LEG_FL`/…) o `PART_<bone>` para un submiembro.
  Valor = **multiplicador** (`1.0` = normal, `1.5` = +50%). `sub_member_owners` = miembro propietario
  EXPLÍCITO de cada submiembro (una agrupación puramente lógica para la herencia; vacío = resolución
  automática). `collider_offsets` (2026-06-22) = **offset** `[x,y,z]` (metros, espacio local del colisionador)
  aplicado al `position` del `StaticBody3D`; `collider_rotations` (2026-06-25) = **rotación** `[x,y,z]`
  (GRADOS) aplicada al `rotation_degrees` del `StaticBody3D`; `collider_scales` (2026-06-22) = **escala**
  `[x,y,z]` aplicada a la forma del colisionador (alrededor del centro). `collider_shapes` (2026-06-25) = **forma**
  elegida en la pantalla Models: `"sphere"`/`"box"`/`"capsule"` sobrescribe la forma automática, `"none"`
  (`SHAPE_NONE`) **suprime el colisionador** del miembro/submiembro (sin hitbox; el preview de la pantalla Models aún
  muestra el submiembro suprimido en el árbol vía `include_suppressed`), ausente = forma automática del plan.
  Todo por miembro/submiembro, editable en la pantalla Models (ver [[🗿 biblioteca-de-modelos (ES)\|biblioteca-de-modelos]]);
  ausente/cero(offset)/[1,1,1](scale) = neutral.
- API estática (2026-06-21): `effective_multiplier(model_key, group, classifier, owner_group="")`
  (CON herencia), `get_multiplier(...)` (wrapper sin owner), `has_multiplier`/`clear_multiplier`
  (estado de la checkbox "Define"), `set_multiplier`, `sub_members`, `sub_member_owner(s)`,
  `set_sub_member_owner`, `add_sub_member(model_key, bone, owner="")`, `remove_sub_member` (también borra
  el `PART_<bone>` de `damage`, el owner, los `collider_offsets`, los `collider_scales`, los
  `collider_rotations` y los `collider_shapes`), `collider_offset`/`set_collider_offset`,
  `collider_scale`/`set_collider_scale` (2026-06-22), `collider_rotation`/`set_collider_rotation`,
  `collider_shape`/`set_collider_shape` + const `SHAPE_NONE` (2026-06-25) y `load_table`.
- **Herencia / "ningún valor es obligatorio" (2026-06-21):** `effective_multiplier` — un valor EXPLÍCITO
  en el grupo mismo tiene precedencia; un `PART_*` SIN valor propio **hereda el del miembro OWNER**
  (el explícito del owner, si no el default del plan del owner); sin nada, cae al
  `default_multiplier` de su propio grupo. `LimbColliders` estampa la meta `damage_multiplier`
  ya RESUELTA (owner = explícito de `LimbConfig`, si no `resolve_sub_member_owner`). El archivo solo almacena ajustes
  del usuario (sin JSON = default del plan, regresión cero).
- **Editor:** la pantalla Models tiene el toggle **"Damage"** (renombrado de "Damage per member" en 2026-06-22) que abre un panel flotante
  (`DamagePanel`, centrado, **720 px de alto** — aumentado desde 500 el 2026-06-20 para caber
  más miembros/submiembros sin scroll) con un `SpinBox` en **bonus %** por miembro (cabeza `+50%` ⇒
  multiplicador `1.5`); cambiarlo guarda vía `LimbConfig.set_multiplier`. Solo aparece para un **personaje
  en "Full model"**. Ver [[🗿 biblioteca-de-modelos (ES)\|biblioteca-de-modelos]]. `res://` es escribible solo al ejecutar
  desde el editor; el juego solo lee.

---

## Submiembros configurables (2026-06-20)

**Submiembros** = huesos auxiliares salientes PROMOVIDOS a su PROPIO colisionador box (grupo único
`PART_<bone>`, para partes que la cápsula del miembro no cubriría — p. ej. las **placas de la pierna** del red_robot).
En `LimbColliders.build_for`, los submiembros efectivos vienen de la UNIÓN de **TRES fuentes**:

1. el `@export standalone_part_bones` del nodo,
2. `LimbConfig.sub_members(model_key)` (los editados en pantalla),
3. `classifier.default_sub_members()` (los del plan corporal).

`red_robot.gd` **ya no hardcodea** `standalone_part_bones`: las placas (`L-RearLegGuard`/
`R-RearLegGuard`) fueron **migradas a `data/limb_config.json`** (seed) y son editables en pantalla. La
pantalla Models eliminó la const `_MODEL_STANDALONE_BONES`.

**A qué MIEMBRO pertenece un submiembro (2026-06-21):** resuelto por
**`LimbColliders.resolve_sub_member_owner(skel, bone, classifier, head, torso, leg)`** (estático,
usado por el `_sub_member_owner_map`/agrupación de herencia de daño de la pantalla Models). Ya no renombra
la etiqueta: desde 2026-06-22 `_part_label` devuelve el **nombre ORIGINAL del hueso** (ver abajo). Capas: (1) **el NOMBRE PROPIO de la parte** vía `owner_hint` (palabras de
miembro + lado, ignorando exclusiones); (2) **sube por la JERARQUÍA** y, en cada ancestro, prueba
`owner_hint` y luego `group_of` (con overrides head/torso/leg). El paso (2) con `owner_hint` es lo que
captura placas colgando de un hueso AUX/IK cuyo NOMBRE dice el miembro:
- **player** — `shoulderpad-adjust.L/.R` (hijos de `chest`): resuelve por (1), nombre "shoulder" → **ARM L/R**.
- **red_robot** — `L-Shield/R-Shield` (escudos de brazo, hijos de `L-ARMIK`/`R-ARMIK`): (1) falla
  ("shield" no es palabra de miembro), pero la subida encuentra al padre **`L-ARMIK`** cuyo `owner_hint` da
  **ARM** → **ARM L/R** (solo para AGRUPAR/heredar daño; la etiqueta se queda con el nombre del hueso).
- **red_robot** — `L-/R-RearLegGuard`: el nombre tiene "leg" → **LEG L/R** por (1).

La **etiqueta MANTIENE el nombre ORIGINAL del hueso (2026-06-22):** `_part_label` fue simplificado a
`return bone_name`. La antigua etiqueta derivada del owner **"PLATE \<MEMBER\>"** (p. ej. "PLATE ARM L",
"PLATE LEG R") fue **descartada por petición** — añadir un submiembro a un miembro solo agrupa el daño,
nunca renombra la parte. Seeds en `data/limb_config.json`: player = `shoulderpad-adjust.L/.R`; red_robot =
`L-/R-RearLegGuard` + `L-/R-Shield`. ⚠️ El hueso idealmente tiene sus **propios vértices skinned** —
`shoulderpad.L/.R` (sin `-adjust`) tienen 0 vértices y la región la deforma `shoulderpad-adjust.L/.R`.
**Fallback para huesos sin vértices (2026-06-22):** un submiembro promovido cuyo hueso NO tiene vértices
dominantes (p. ej. `Mouth`, huesos estructurales/vacíos) **ya no añadía un colisionador** y desaparecía del
árbol/desplegable de la pantalla Models; ahora `_collect_member_boxes` (paso 4, helper `_fallback_part_size`)
genera un **box pequeño centrado en el origen del hueso (rest)** (~20% del mayor miembro medido, consciente de la escala),
para que el submiembro **aparezca y pueda recibir daño**. (El resalte naranja "Skeleton Colliders" y la etiqueta del toggle "Skeleton" (ex-"SubMember"/"Bone"), que usan
`bone_vertex_box`, siguen requiriendo vértices.) Los huesos que ya son un MIEMBRO (`L-Shoulder`/`R-Shoulder` →
ARM) no entran en la lista "Add sub-member" (que solo ofrece auxiliares, `group_of == ""`).

**Editor (panel "Damage"):** lista **todos los miembros del plan** (`_plan_member_entries`,
misma fuente que el combo "Member" desde 2026-06-21) y, **anidados (↳, margen 24px) bajo cada miembro**,
sus submiembros (`PART_*`) — agrupados por el MISMO `_sub_member_owner_map`/`owner_hint` que los combos
(helper `_sub_members_by_owner`), para que panel y desplegable concuerden; un submiembro sin owner en la lista
va a la sección **"Other sub-members"**. El panel es un **Tree**; cada hoja de submiembro
tiene un **botón de papelera a la derecha del nombre** para eliminarlo ahí mismo — con un **diálogo de confirmación**
("Do you really want to remove the association of sub-member: <name> ?") (2026-06-22; reemplazó al antiguo gran
botón "Remove sub-member" del footer — ver [[🗿 biblioteca-de-modelos (ES)\|biblioteca-de-modelos]]). Abajo, la
fila de **añadir** (`_build_damage_footer`): un `OptionButton` con los huesos AUXILIARES del esqueleto del preview
(aquellos cuyo `group_of` da "") + el desplegable de **miembro-owner** + un botón "Add".
**Cabecera fusionada (2026-06-27):** las etiquetas "Add sub-member" y "To Owner Member" están
ahora en un **único `HBoxContainer`** encima de la fila (antes: un título suelto + una etiqueta dentro de un
`VBoxContainer` sobre el desplegable). "Add sub-member" usa `SIZE_EXPAND_FILL` (izquierda, sobre el
selector de hueso) y "To Owner Member" se sitúa a la derecha.
**Títulos de columna retraducidos (2026-06-27):** las cabeceras del árbol (Member/Def/Bonus %/Owner)
**no** son `Label`/`Button`, así que el auto-localizador de `Locale` no las alcanzaba y quedaban atascadas
en el idioma del último build. Ahora `_apply_damage_tree_titles()` las reaplica vía `tr_key` tanto en
`_refresh_damage_panel` como en `_on_language_changed` (ver [[🗣️ localizacao (ES)\|localizacao]]).
Add/remove llama a `LimbConfig.add_sub_member`/`remove_sub_member` y **reconstruye** los colisionadores del
preview (`_rebuild_member_colliders`), restaurando gizmos/labels. La lectura en el juego (`bullet.gd`/
`laser_shooter.gd` leyendo la meta `damage_multiplier`) es **inalterada**.

---

## Capas de colisión

| Bit | Valor | Uso |
|---|---|---|
| bit4 | `8` | Proyectil (bala) — el `collision_layer` de la bala |
| bit5 | `16` | Colisionadores de miembro del **Player** |
| bit6 | `32` | Colisionadores de miembro del **Enemy** |

- Bala: `layer = 8`, `mask = 51` (`3` mundo/cuerpos + `16` + `32`) para colisionar físicamente con los miembros.
- Colisionadores de miembro: `StaticBody3D` en capa 16/32, `mask = 0` (pasivos — son impactados, no detectan).

---

## Flujo de daño (player → enemy)

```
bullet (server) collides physically (move_and_collide) with an enemy member collider
  → bullet._apply_hit(collider)
      → reads damage_multiplier + character metas; ignores if character == shooter
      → enemy.hit.rpc(round(weapon_damage * multiplier))   [server]
      → bullet explodes
Fallback: if the bullet hits a body with hit() and no member metas → TORSO damage (1x)
          in the same _apply_hit (idempotent via _registered)
```

**Pass-through del cuerpo del personaje (2026-06-18):** el cuerpo genérico del personaje (la
cápsula/esfera del `CharacterBody3D`) envuelve toda la figura, así que sería impactado ANTES de los colisionadores de miembro
(que se ajustan a la malla) — siempre 1× de daño, sin headshot. En `bullet._physics_process`, si el
`move_and_collide` impacta un `CharacterBody3D` que tiene el nodo `LimbColliders`, la bala hace
`add_collision_exception_with(body)` y **sigue volando**, atravesando el cuerpo hasta que impacta el
colisionador de MIEMBRO detrás de él. Esto corrigió al red_robot, cuyo cuerpo era un `SphereShape3D` de radio
~1.12 m que envolvía todo e interceptaba cada disparo. El cuerpo aún existe para que el enemigo pueda caminar sobre
el suelo y ser apuntado/detectado (los rayos de puntería del jugador usan `mask 0b11`); solo se aparta del camino del DISPARO.

**Colisionador de cuerpo = cápsula como el player (2026-06-18):** la esfera gigante del cuerpo del red_robot fue
cambiada por una **`CapsuleShape3D` (radio 0.5 / altura 2.0, en y=1)** — la MISMA lógica que el
`CollisionShape3D` del player — así ya no hay una esfera enorme. El nodo se queda como `CollisionShape3D` (dependencia de
`red_robot.gd`).

**Auto-ajuste por modelo de la cápsula de locomoción (2026-07-03):** en lugar de la cápsula por defecto (0.5×2.0)
IGUAL para cada modelo, el bloqueo físico es ahora **proporcional al modelo**, derivado de los MISMOS boxes de miembro
que `LimbColliders` ya mide — manteniendo **1 forma por personaje** (barato, estable y
determinista, para que servidor y predicción-cliente concuerden; independiente de la pose animada). Método
`LimbColliders.fit_locomotion_capsule(shape_node, character)`, llamado justo después de `build_for` en
`player.gd` y `red_robot.gd`:
- **RADIO = huella de pie** (`_is_footprint_group`: **TORSO + LEGS** — `LEG_*` de cualquier plan).
  Los brazos (la envergadura de una T-pose), la cabeza (arriba) y las piezas `PART_*` quedan **fuera** para que no engorden
  el radio. `radius = 0.5 · max(footprint.x, footprint.z)`, con suelo `MIN_BODY_CAPSULE_RADIUS = 0.12`.
- **ALTURA = extensión vertical total** (parte alta de la cabeza → pies), con la **BASE anclada al
  suelo del personaje** (`bottom = min(aabb.min.y, 0)`) para que la cápsula nunca **flote** (mantiene `is_on_floor`).
- **Centro** en el eje del modelo (footprint x/z) y verticalmente en la mitad. **Duplica** la forma para
  que no mute un subrecurso compartido. **No-op** (devuelve `{}`) si no se construyó nada (p. ej. criatura_alada,
  que no construye `LimbColliders` en el juego; un modelo sin miembros clasificados) → **preserva la
  cápsula de origen** como fallback seguro.
- Helpers internos: `member_boxes_in(space)` (AABBs por grupo en el espacio del personaje, leyendo la
  geometría REAL de la forma — post-encogimiento), `_shape_local_aabb` (sphere/box/capsule) y
  `_transform_aabb` (envolvente de las 8 esquinas, correcto para cápsulas de miembro rotadas).
- **Validado** por una sonda headless determinista (biped sintético ~1.8 m): radio **0.250** (footprint,
  NO los brazos a 0.575), altura **1.800**, base **0.000** — los 3 criterios OK.

El tirador excluye sus propios colisionadores de miembro del proyectil (`player._exclude_own_limbs`)
para que el disparo no nazca impactando su propio brazo/arma.

## Flujo de daño (enemy → player)

`red_robot.shoot()` (servidor) **dispara una bola de cañón** (ya no un láser hitscan), vía el
componente `CannonShooter`, en la dirección del jugador (con dispersión si `aim_accuracy < 1`). La bola vuela y,
cuando impacta un colisionador de MIEMBRO del jugador (bit5), aplica `player.hit.rpc(weapon_damage * mult)` —
la misma ruta localizada que el disparo del jugador (`bullet._apply_hit`).

## Componentes de disparo reutilizables (2026-06-18)

Para reutilizar el disparo entre modelos, la lógica fue aislada en `effects_shared/`:

- **`CannonShooter`** (`cannon_shooter.gd`, `class_name`): `static fire(parent, origin, dir, damage,
  shooter, tint, ball_color, ball_scale)` → instancia `bullet.tscn`, lo posiciona/orienta, excluye el
  cuerpo del tirador + colisionadores de miembro y lo lanza. Colores opcionales (alfa 0 = el visual azul por defecto
  del player). Usado por el **player** (azul, default) y por el **red_robot** (bola NEGRA + efecto ROJO,
  `ball_scale 2.5`).
- **`LaserShooter`** (`laser_shooter.gd`, `class_name`): `static fire(muzzle, beam_mesh, blast_scene,
  damage, hitbox_layer, exclude)` → láser hitscan (raycast + daño localizado + recorte del beam + blast).
  Extraído del antiguo láser del red_robot; **disponible para reuso** (el red_robot ahora usa el cañón; ningún
  modelo usa el láser por ahora).
- `bullet.gd` ganó `tint`/`ball_color`/`ball_scale` (centinela alfa 0 = no tocar → player intacto),
  aplicados en `_apply_visuals` (luz + estela CPUParticles + material de la bola).

---

## BulletCache (trampa resuelta)

`player.tscn` tiene un nodo `BulletCache` (bala pre-instanciada, warm-up). Sin tirador,
causaba 50 de daño al inicio. Solución: **una bala sin `shooter` se queda inerte**
(`_ready`: `if shooter == null or not is_server: disable`). También cubre a los clientes
(donde `shooter` no se replica).

**Networking (2026-06-26):** el `BulletCache` arrastraba el `MultiplayerSynchronizer` del `bullet.tscn` a
la escena replicada del player. Al hacer spawn/despawn del player por red, este sync generaba
`Node not found .../BulletCache/MultiplayerSynchronizer`, `Failed to get cached node from peer` y
`on_despawn_receive ERR_UNAUTHORIZED`. Solución: en `player.tscn`, sobrescribir el sync de la caché con
**`public_visibility = false`** (no replica) — afecta solo a la caché; las balas reales (instancias de
`bullet.tscn`) siguen replicando con normalidad.

---

## Precisión y alcance del enemigo

| Export | Default | Función |
|---|---|---|
| `aim_accuracy` | `1.0` | Probabilidad de acertar al disparar (100% = siempre) |
| `effective_range` | `30.0` m | Solo dispara cuando el jugador está dentro de este alcance |

El enemigo espera a acercarse (`shoot_countdown = 0`) mientras el jugador está fuera de alcance.

> **Radio de detección = alcance:** el `PlayerDetectionArea` (`SphereShape3D`) tiene un **radio de 30 m**,
> igual al `effective_range`, para que el robot **detecte y empiece a disparar a 30 m** (antes eran 20 m,
> que impedían abrir fuego al alcance completo del arma).

---

## Ajuste en el inspector (nodo del personaje)

En `limb_colliders.gd` (nodo `LimbColliders`): `enabled`, `padding`, **`body_type`**
(`@export_enum("biped","quadruped","crawler")`, default `biped` — elige el plan corporal vía
`BodyPlans.for_type`; 2026-06-20), `head_bone_names` (`["mouth_eyes", "L-EYE", "R-EYE"]` en el enemigo),
`torso_bone_names` (fuerza un hueso de nombre genérico a TORSO — `["Bone.001"]` en el red_robot, cuyo
cuerpo no era reconocido y **no tenía colisionador de torso**), `standalone_part_bones` (submiembros fijos
en el nodo — UNIDOS con los de `LimbConfig` y los del plan; el red_robot **ya no usa** este export, las
placas de la pierna migraron a `limb_config.json`), `hitbox_layer` (16 player / 32 enemy) y
**`model_key`** (`"player"`/`"red_robot"` — clave de los multiplicadores/submiembros en `LimbConfig`;
2026-06-20). Los exports de color/radio del antiguo sistema de cristal fueron eliminados.

> Verificado vía el MCP de Godot ([[godot-mcp]]): el láser del enemigo aplica 25 (arma),
> lookup de hitbox funcionando, la caché ya no causa daño al inicio, sin errores.

---

## Relacionado

- [[🔫 combate-tiro (ES)\|combate-tiro]]
- [[❤️ sistema-de-vida (ES)\|sistema-de-vida]]
- [[🦿 limb-colliders-gd (ES)\|limb-colliders-gd]]
- [[🦴 body-parts-gd (ES)\|body-parts-gd]]
- [[💥 bullet-gd (ES)\|bullet-gd]]
- [[🤖 red-robot-gd (ES)\|red-robot-gd]]
- [[🩹 enemy-health-bar-gd (ES)\|enemy-health-bar-gd]]

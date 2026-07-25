---
tipo: arquivo-chave
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-23
---

# 🦿 effects_shared/limb_colliders.gd

**Renamed from `glass_hitboxes.gd` on:** 2026-06-14 · **Extends:** `Node3D`

---

## Responsabilidades

- Generar **colisionadores 3D nativos** (`StaticBody3D` + `CollisionShape3D`) por **grupo de miembro** de un `Skeleton3D`
- Cada miembro → `BoneAttachment3D → StaticBody3D (BoxShape3D)`, unido al **hueso raíz** (sigue pose/animación)
- Los proyectiles colisionan **físicamente** con estos cuerpos y el láser del enemigo los golpea por **raycast contra cuerpos** → **daño localizado** al personaje propietario
- Los **MIEMBROS** provienen del **body plan** del modelo, elegido por el `@export body_type` vía la factory **`BodyPlans.for_type`** (una instancia de [[🦴 body-parts-gd (ES)|BodyParts]] — `_classifier`, resuelto en `build_for`). Biped (por defecto), quadruped o crawler.
- El multiplicador de daño por miembro viene de **`LimbConfig`** (leído por `model_key`), con un fallback al valor por defecto del **plan** (`_classifier.default_multiplier`): cabeza = +50% (`1.5`), el resto = `1.0` (2026-06-20). Editable en la pantalla Models (ver [[🩸 dano-localizado (ES)|Daño Localizado]])
- **Submiembros** (huesos sobresalientes con su PROPIO colisionador `PART_<bone>`) = la UNIÓN de 3 fuentes en `_resolve_sub_members`: el `@export standalone_part_bones` + `LimbConfig.sub_members(model_key)` + `_classifier.default_sub_members()`
- **Submiembros DISTALES automáticos (2026-07-23):** con el `@export auto_distal_sub_members` (nuevo, `true` por defecto), **antebrazo/mano** y **espinilla/pie** se convierten en SUBMIEMBROS propios (`PART_<bone>`, con colisionador y daño localizados) en lugar de ser absorbidos en el ARM/LEG. `player.gd` y `red_robot.gd` hacen **opt-out**. Medido: humanoide/monstro = **6 miembros + 8 submiembros**; player = **6 miembros y 0 submiembros**
- **Sin Area3D, sin visual de cristal, sin etiquetas** (reemplazó al antiguo sistema de «glass hitbox»)
- Ver [[🩸 dano-localizado (ES)|Daño Localizado]]

---

## Cómo funciona (posicionamiento por vértices skinned)

1. Clasifica los huesos en grupos vía `_classifier.group_of` — una **INSTANCIA** del body plan (`BodyPlans.for_type(body_type)`), ya que el estático `BodyParts.group_of` NO es polimórfico. Biped da HEAD/TORSO/ARM L-R/LEG L-R; quadruped da 4 piernas; crawler da solo HEAD/TORSO (ver [[🦴 body-parts-gd (ES)|body_parts.gd]])
2. Elige el **hueso raíz** de cada grupo (el menos profundo en la jerarquía)
3. Para cada **vértice skinned** de la malla, toma el hueso de mayor peso y lo convierte al espacio local del hueso raíz usando el **bind pose** del skin (`get_bind_pose`) → acumula un **AABB por miembro** (+ un margen `padding`)
4. Crea `BoneAttachment3D` (en el hueso raíz) → `StaticBody3D` + `CollisionShape3D (BoxShape3D)` del tamaño del AABB
5. Metas en el `StaticBody3D`: `group`, `damage_multiplier` (de `LimbConfig.effective_multiplier(model_key, group, _classifier, owner_group)` — `owner_group` solo entra en los submiembros, para la herencia de daño), `member_label` (etiqueta) y `character` (propietario)
6. **Offset + Scale (2026-06-22):** `body.position = LimbConfig.collider_offset(model_key, group)` desplaza todo el cuerpo (shape/gizmo/etiqueta lo siguen); `shape_node.scale = LimbConfig.collider_scale(model_key, group)` escala el shape alrededor del centro. Ambos en el espacio local del hueso, editables en vivo en la pantalla Models (filas X/Y/Z para Offset y Scale + un botón Save, con el toggle Colliders activado); ver [[🗿 biblioteca-de-modelos (ES)|Biblioteca de Modelos]]. Vacío = offset cero / scale [1,1,1].

- **Fallback para un submiembro sin vértices (2026-06-22):** el paso 3 solo genera un AABB para grupos con **vértices dominantes**. Un submiembro ascendido (`PART_*`) cuyo hueso no tiene vértices propios (p. ej.: `Mouth`, huesos estructurales) acababa **sin colisionador** y desaparecía de la pantalla Models. Ahora el paso 4 de `_collect_member_boxes` (helper `_fallback_part_size`) crea una **caja pequeña centrada en el origen (rest) del hueso** (~20% del mayor miembro medido) para que **aparezca y pueda recibir daño**. Aplica solo a `PART_*` (los miembros sin vértices siguen sin colisionador).

- **Robot sin cabeza:** el rig del RedRobot no tiene un hueso de cabeza estándar; usa `head_bone_names = ["mouth_eyes", "L-EYE", "R-EYE"]` para forzar la HEAD (cara + ojos — los ojos, excluidos por «eye», se añaden para que la esfera no sea diminuta; 2026-06-18). El jugador tiene los 6 grupos; el enemigo también resuelve 6 (con el forzado).

- **Submiembros (piezas sobresalientes):** huesos que reciben su PROPIO colisionador (una caja) ajustada solo a sus vértices, en lugar de ser absorbidos por un miembro. Para piezas SOBRESALIENTES que la cápsula del miembro no cubriría — p. ej.: las **placas de las piernas traseras** del red_robot (`L-/R-RearLegGuard`). Internamente se convierten en un único grupo `PART_<bone>` (reutilizando todo el pipeline), con un shape de **caja**. El conjunto efectivo (`_sub_member_set`) es la UNIÓN de 3 fuentes (`_resolve_sub_members`): `standalone_part_bones` (export) + `LimbConfig.sub_members(model_key)` + `_classifier.default_sub_members()`. `_classify()` intercepta estos huesos ANTES del clasificador normal, para que no contaminen el miembro vecino. El red_robot **ya no usa** el export — las placas migraron a `limb_config.json` y son editables en la pantalla (ver [[🩸 dano-localizado (ES)|Daño Localizado]]).

- **Subdivisión AUTOMÁTICA de las extremidades (2026-07-23):** `_classify()` ahora intercepta en **DOS** casos, siempre ANTES del clasificador de miembro — (a) un submiembro **EXPLÍCITO** (`_sub_member_set`, las 3 fuentes de arriba) y (b) uno **DISTAL automático**, vía `_classifier.is_distal_sub_member(bone)` cuando `auto_distal_sub_members` está activado (antebrazo/mano/espinilla/pie; ver [[🦴 body-parts-gd (ES)|body_parts.gd]]). El miembro **DUEÑO** (solo para la HERENCIA de daño) se resuelve después, en `_build_member_shape`: primero la elección EXPLÍCITA guardada (`LimbConfig.sub_member_owner`) y, a falta de ella, `resolve_sub_member_owner` (`owner_hint` del propio nombre → sube por la jerarquía de huesos). Así la mano hereda el daño del ARM y el pie el del LEG, pero cada extremidad tiene **hitbox y multiplicador propios**. **OPT-OUT:** `player.gd` y `red_robot.gd` ponen `auto_distal_sub_members = false` para mantener el hitbox de ARM/LEG **ENTERO** ya ajustado; `models.gd` refleja el opt-out en la vista previa (`_MODEL_NO_AUTO_DISTAL`), para que la pantalla Models muestre exactamente los mismos miembros que el juego.

---

## Refit en tiempo real (vista previa de la pantalla Models)

`refit(skel, max_groups = 0)` reajusta los colisionadores de miembro/submiembro a la **pose ANIMADA actual** (el `BoneAttachment3D` ya aporta traslación/rotación; el refit reajusta el **VOLUMEN** de la caja a la flexión). La 1ª llamada construye la **caché de skinning** (`_build_refit_cache`, coste único — es ahí donde corre el costoso `surface_get_arrays`); después solo se leen las poses ACTUALES de los huesos.

**Optimizaciones de 2026-07-23** (el refit era lo que hundía los FPS en la pantalla Models):

- **Grupos INVARIANTES omitidos (`_rc_dyn`).** El AABB de un grupo se calcula en el **espacio LOCAL de su hueso raíz**: `p = inv(gpose[raiz]) * gpose[hueso] * bv`. En un grupo de **UN SOLO hueso**, raíz == hueso, los términos se cancelan y queda `p = bv` — el AABB es **CONSTANTE**, independiente de la pose (el colisionador ya sigue al hueso vía `BoneAttachment3D`). Con la subdivisión, **13 de 14 grupos** pasaron a ser de un solo hueso (solo el **TORSO** = cadera + pecho es dinámico), así que reajustarlos todos era recalcular el mismo valor. Ahora `_rc_dyn` lista solo los grupos con **2+ huesos** y el refit recorre únicamente esos.
- **ROTACIÓN por lotes (`max_groups`).** Con `max_groups > 0`, cada llamada procesa solo esa cantidad de grupos, avanzando `_refit_cursor` hasta dar la vuelta. `models.gd` lo llama **cada frame** con `REFIT_GROUPS_PER_FRAME = 3` — sustituye al antiguo **throttle adaptativo**, que rehacía todo de golpe cada ~190 ms y provocaba tirones. `0` (por defecto) = todos de una vez, como antes.
- **Caché ORDENADA por grupo (counting sort).** `_build_refit_cache` ahora ordena los vértices por grupo mediante **counting sort**, guardando el intervalo contiguo de cada uno en `_rc_gstart`/`_rc_gcount` — es lo que permite reajustar un **SUBCONJUNTO** de grupos sin recorrer la caché entera. (El antiguo `_rc_group`, un índice de grupo por vértice, ya no existe.)
	- ⚠️ **Trampa de GDScript** que motivó el counting sort: un `Packed*Array` guardado **DENTRO** de un `Array` se devuelve **COPIADO** al leerlo — acumular en «cubos» por grupo no funciona, los `append` se pierden **en silencio**.
- **Gizmo bajo demanda.** `shape.get_debug_mesh()` **GENERA** geometría en cada llamada; en el refit solo se invoca cuando el gizmo está `is_visible_in_tree()`. Un gizmo oculto se actualiza en el primer refit tras reaparecer (desfase máximo = un intervalo de refit).

**Ganancia medida (humanoide):** 6,45 ms → 1,89 ms (tras la caché de `LimbConfig`) → **0,318 ms por frame** (~1,9% de un frame de 60 FPS). El player, con opt-out de la subdivisión, se queda en **0,612 ms** con 6 grupos dinámicos.

---

## Detección (física, nativa)

- **Bala → miembro:** `bullet.gd` usa `move_and_collide`; al golpear un colisionador de miembro, `_apply_hit` lee `damage_multiplier`/`character` y aplica `character.hit.rpc(round(weapon_damage * mult))`. Fallback de cuerpo (cápsula) = `1×`. Quien dispara excluye sus propios colisionadores (`player._exclude_own_limbs`).
- **Láser del enemigo → miembro del jugador:** `red_robot._damage_player` hace raycast con `collide_with_bodies = true` en la layer 16.
- `bullet.tscn collision_mask = 51` (mundo/cuerpos `3` + miembros `16` + `32`).

---

## Exports

| Export | Jugador / Enemigo | Descripción |
|---|---|---|
| `enabled` | `true` | Activa/desactiva la generación |
| `body_type` | `"biped"` | Body plan (`@export_enum` biped/quadruped/crawler) → clasificador vía `BodyPlans.for_type` (ver [[🦴 body-parts-gd (ES)|body_parts.gd]]) |
| `padding` | `0.03` | Margen (m) añadido a cada lado de la caja |
| `head_bone_names` | `[] / ["mouth_eyes", "L-EYE", "R-EYE"]` | Huesos forzados a la HEAD |
| `head_shape` | `"capsule" (player) / "sphere"` | Shape del colisionador de HEAD (`@export_enum` sphere/capsule) |
| `head_scale` | `1.0 / 1.3` | Factor de escala para el VOLUMEN de la cabeza (red_robot = 1.3, headshot mayor) — escala el AABB alrededor del centro (2026-06-21) |
| `torso_shape` | `"box" / "sphere"` | Shape del colisionador de TORSO (`@export_enum` box/sphere; red_robot = sphere) (2026-06-21) |
| `torso_bone_names` | `[] / ["Bone.001"]` | Huesos forzados al TORSO (el hueso genérico del enemigo) |
| `leg_bone_names` | `[]` | Huesos forzados a la L/R LEG |
| `standalone_part_bones` | `[] / []` | Submiembros FIJOS en el nodo (su PROPIO colisionador) — UNIDOS con los de `LimbConfig` + el plan. El red_robot **ya no lo usa** (las placas migraron a `limb_config.json`) |
| `hitbox_layer` | `16 / 32` | Layer de los colisionadores (jugador bit5, enemigo bit6) |
| `model_key` | `"player" / "red_robot"` | Clave (nombre de carpeta) para buscar multiplicadores + submiembros en [[🩸 dano-localizado (ES)\|LimbConfig]]; vacío = valores por defecto del plan |
| `include_suppressed` | `false` (`true` solo en la vista previa de la pantalla Models) | True: los SUBMIEMBROS con `SHAPE_NONE` («Select...») se construyen igualmente (shape automático, meta `suppressed`, sin gizmo) para que permanezcan en el árbol/dropdown y puedan reconfigurarse. False (gameplay): omitidos, sin hitbox (2026-06-25) |
| `auto_distal_sub_members` | `false / false` (opt-out; **por defecto `true`**) | Subdivisión AUTOMÁTICA de las extremidades: antebrazo/mano y espinilla/pie se convierten en SUBMIEMBROS propios (`PART_<bone>`, colisionador + daño localizados, heredando el ARM/LEG cuando no tienen valor propio) en lugar de ser absorbidos en el miembro grande. Activado por defecto (modelos nuevos); player/red_robot hacen opt-out para mantener el hitbox ENTERO ya ajustado (2026-07-23) |

---

## Instanciación (por código)

`player.gd._setup_limb_colliders()` y `red_robot.gd._setup_limb_colliders()`:
```gdscript
var skel = <model>.get_node_or_null(^".../Skeleton3D") as Skeleton3D
var lc = preload("res://effects_shared/limb_colliders.gd").new()
lc.name = "LimbColliders"
lc.body_type = "biped"   # body plan → clasificador (BodyPlans.for_type)
lc.model_key = "player"   # "red_robot" en el enemigo — clave de los multiplicadores/submiembros en LimbConfig
lc.hitbox_layer = 16   # 32 en el enemigo
lc.auto_distal_sub_members = false   # opt-out: ARM/LEG ENTEROS (hitbox ya ajustado)
add_child(lc)
lc.build_for(skel)   # resolves _classifier (body_type) + _sub_member_set (3 sources)
```
Construido en todos los peers (solo el servidor simula los disparos). `get_limb_bodies()` lista los `StaticBody3D` creados (usado para excluir los propios de quien dispara de la colisión del proyectil disparado).

> [!note] SHAPE override + supresión por grupo (2026-06-25)
> `make_member_shape(group, aabb, head_kind, torso_kind, head_scale, shape_override="")` ganó el
> parámetro **`shape_override`**: `"sphere"/"box"/"capsule"` FUERZA el shape de ese grupo sobre el automático
> (una HEAD de cápsula mantiene el radio completo). `build_for`/`_build_member_shape`/`refit` leen
> `LimbConfig.collider_shape(model_key, group)` y pasan el override; y `build_for` **omite** los grupos
> cuyo `collider_shape == LimbConfig.SHAPE_NONE` (`"none"`) → el miembro/submiembro acaba **sin colisionador**
> (excepto los SUBMIEMBROS en la vista previa de la pantalla Models, vía `include_suppressed` — ver la tabla). Todo se
> elige en la pantalla Models (el dropdown de geometría a la derecha de Member/Sub-member/Skeleton) y se relee
> aquí al spawn. La ruta sin esqueleto (`models.gd._add_mesh_member_colliders`) respeta las mismas
> dos. Ver [[🗿 biblioteca-de-modelos (ES)|Biblioteca de Modelos]] y [[🩸 dano-localizado (ES)|Daño Localizado]].

- Esqueleto del jugador: `PlayerModel/Robot_Skeleton/Skeleton3D` (el jugador hereda de Player)
- Esqueleto del enemigo: `RedRobotModel/Armature/Skeleton3D`

---

## Path: `effects_shared/limb_colliders.gd`

---

## Relacionado

- [[🩸 dano-localizado (ES)|Daño Localizado]]
- [[🦴 body-parts-gd (ES)|body_parts.gd]]
- [[🗿 biblioteca-de-modelos (ES)|Biblioteca de Modelos]]
- [[🎮 player (ES)|Jugador]]
- [[🤖 inimigos (ES)|Enemigos]]
- [[🎮 player-gd (ES)|player.gd]]
- [[🤖 red-robot-gd (ES)|red_robot.gd]]
- [[💥 bullet-gd (ES)|bullet.gd]]

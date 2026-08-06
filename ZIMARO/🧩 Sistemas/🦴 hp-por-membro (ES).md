---
tipo: sistema
projeto: ZIMARO
lang: es-ES
atualizado: 2026-08-06
---

# 🦴 HP por Miembro (condición de abatimiento)

> Implementado el 2026-08-06. Sustituye a la **barra única de vida** como condición de muerte:
> el personaje solo cae cuando **todos los miembros y sub-miembros** han sido destruidos.
> Archivo nuevo: `effects_shared/limb_health.gd` (`class_name LimbHealth`).

---

## La idea

Cada miembro/sub-miembro con collider de gameplay tiene **su propio HP**. El daño va al miembro
alcanzado, no a una barra global. La vida total del personaje sigue existiendo — se **reparte** entre
los miembros y pasa a ser el espejo de su suma (`health = limbs.total_hp()`), para que las barras que
muestran el cuerpo entero sigan funcionando.

El **porcentaje configurado en la pantalla Models sigue siendo multiplicador de DAÑO**, como siempre
(ver [[🩸 dano-localizado (ES)|🩸 dano-localizado]]). Un miembro al 200% cae con la mitad de los
disparos. No hubo que reconfigurar nada modelo por modelo.

---

## Reparto del HP

| Miembro | Peso |
|---|---|
| CABEZA | `HEAD_HP_WEIGHT` = **2,0** |
| Todos los demás | 1,0 |

`HP del miembro = vida_total × peso / suma_de_pesos`

Engrosar la cabeza **adelgaza a los demás en la misma medida** — el total sigue siendo la vida del
personaje; nadie gana vida gratis.

---

## Quién cuenta para el abatimiento

**Todo miembro/sub-miembro que el modelo construye de verdad** (tiene collider de gameplay). El que no
tiene porcentaje propio en `LimbConfig` usa el daño por defecto 1×.

> ⚠️ La alternativa — contar solo los que tienen porcentaje configurado — fue **medida** y descartada:
> en el red_robot daba 5 miembros (los dos escudos, el tanque y las dos placas traseras), porque su
> `limb_config.json` solo define `PART_FuelTank`. Cabeza, torso, brazos y piernas quedaban fuera, es
> decir, **acertar en la cabeza no ayudaba a derribar al enemigo**. Contar por collider cierra ese
> agujero sin exigir reconfigurar modelo por modelo.

---

## Propagación (quién cae junto)

```
miembro-padre destruido  →  caen todos sus sub-miembros
sub-miembro del ROSTRO   →  derriba la CABEZA (y con ella sus hermanos)
sub-miembro común        →  NO derriba al miembro-padre
```

El criterio de "rostro" es que el **miembro-dueño sea la CABEZA** (`BodyParts.HEAD`), no una lista de
nombres de hueso — así vale para cualquier modelo y en cualquier idioma. Es lo que devuelve valor a la
puntería precisa: por la vía bruta la cabeza cuesta varios impactos; por el ojo o la boca, **uno solo**.

---

## Calibración (medida el 2026-08-06)

| Personaje | Vida total | Cabeza | Miembro común | Abatimiento |
|---|---|---|---|---|
| **Red Robot** | `max_health` = **550** | 92 | 46 | **7 disparos** de 50 |
| **Player** | `MAX_HP` = **150** | 27 | 14 | **13 impactos** de 10 · **11** apuntando al rostro |

Por qué estos números:

- **Red Robot** — con los 200 antiguos cada miembro tenía 18 HP y el disparo del player (50) arrancaba
  cualquier pieza de una vez, mientras el cañón de 10 del propio robot quitaba más de medio miembro por
  impacto. 550 mantiene una granularidad sana. Entre 200 y 550 el **número de disparos no cambia** (el
  coste es la cantidad de miembros, no la vida); por encima de ~560 cada miembro exigiría 2 disparos y
  el abatimiento saltaría a 12.
- **Player** — con los 100 antiguos cada miembro tenía exactamente 10 HP y caía con **un** impacto: el
  player moría en 6 impactos, o sea, el cambio lo había dejado **más frágil** que antes. 150 da 15 por
  miembro (2 impactos cada uno) y devuelve el equilibrio de los ~10 impactos del modelo de vida única.

---

## Overlay

Al apuntar a un miembro, la *boss bar* compartida muestra **el nombre del miembro y su HP** —
`Red Robot — CABEÇA`, con `92` de máximo —, no la vida del cuerpo. Es el miembro el que debe caer, así
que es el número que importa. Ver [[🤖 inimigos (ES)|🤖 inimigos]].

---

## Red

`hit()` es `@rpc("call_local")`: **todos los pares aplican el mismo daño** y llegan al mismo estado. No
se replica ningún diccionario. Quien dispara pasa el miembro alcanzado junto con el daño:

```gdscript
character.hit.rpc(int(round(weapon_damage * mult)), String(collider.get_meta("group", "")))
```

---

## Facciones

Vale para **enemigos, aliados y neutrales** — el `player` usa el mismo sistema (con `limbs.reset()` en
el respawn). La `criatura_alada` **no** construye colliders de miembro, así que sigue con vida única y
solo acepta el argumento nuevo. Ver [[⚔️ facções (ES)|⚔️ facções]].

---

## 💥 Efecto visual del desmontaje (2026-08-06)

`LimbHealth` emite **`limb_destroyed(group)`** por cada miembro que cae — incluidos los arrastrados por
la propagación. El personaje conecta esa señal a **`LimbColliders.collapse_limb(group)`**, que:

1. **apaga el collider** de ese miembro (una pieza caída ya no recibe disparos);
2. **colapsa el hueso** vía [[limb-debris]] → la pieza **desaparece de la malla**, y lo que viene
   después en la cadena se va con ella (el brazo se lleva antebrazo, mano y el escudo sujeto a él);
3. suelta una **nube de chispas** (`CPUParticles3D` de un disparo, material *unshaded*, autoliberada) en
   la posición del hueso — barata, dentro del techo de 60 FPS del proyecto.

El **TORSO no colapsa**: es la raíz del rig, y ocultarlo se llevaría al personaje entero, miembros en
pie incluidos. Solo recibe las chispas. En el **respawn** del player, `restore_limbs()` devuelve las
piezas y reactiva los colliders.

> ⚠️ **TRAMPA de la virtual (medida el 2026-08-06).** `LimbDebris` es un `SkeletonModifier3D` porque la
> AnimationTree reescribe la pose de todos los huesos en cada fotograma — poner la escala a cero en
> cualquier otro punto se desharía al siguiente. **Godot 4.6 llama a
> `_process_modification_with_delta(delta)`**; la `_process_modification()` sin argumentos sigue en la
> `ClassDB` pero quedó **obsoleta**. Implementar solo la versión sin delta hace que el modificador **no
> se ejecute nunca, sin error alguno** — los colliders se apagan, salen las chispas y la pieza sigue ahí
> (medido: 0 llamadas frente a 22). Implementamos ambas.
>
> 🔍 **Cómo VERIFICAR:** leer `get_bone_pose_scale()` **desde fuera** devuelve `1.0` aunque el miembro
> haya desaparecido — la lectura toma la pose de ENTRADA que la animación acaba de reescribir. La escala
> solo es observable **dentro** del pipeline de poses: usa un **segundo `SkeletonModifier3D` como
> sonda**, añadido DESPUÉS del `LimbDebris`, y lee `get_bone_global_pose()` allí. Medido así: miembro
> destruido `(0.001, 0.001, 0.001)`, miembro intacto `(1.0, 1.0, 1.0)`.

---

## Limitaciones conocidas
- El daño **sin miembro identificado** (explosión de área, caída) sigue descontándose de la vida
  global; de lo contrario esos golpes quedarían inertes.

---

## Archivos

| Archivo | Papel |
|---|---|
| `effects_shared/limb_health.gd` | **NUEVO** — `LimbHealth`: reparto, daño, propagación, abatimiento |
| `effects_shared/limb_debris.gd` | **NUEVO** — `LimbDebris`: colapsa el hueso (la pieza desaparece) + chispas |
| `effects_shared/limb_colliders.gd` | Marca la meta `owner_group` (miembro-dueño del sub-miembro) |
| `library3D/characters/red_robot/red_robot.gd` | `limbs`, `hit(amount, group)`, overlay por miembro |
| `library3D/characters/player/player.gd` | `limbs`, `hit(amount, group)`, `reset()` en el respawn |
| `library3D/characters/player/bullet/bullet.gd` | Pasa el miembro alcanzado |
| `effects_shared/laser_shooter.gd` | Pasa el miembro alcanzado |
| `library3D/characters/player/player_input.gd` | Miembro bajo la mira → overlay |

Relacionadas: [[❤️ sistema-de-vida (ES)|❤️ sistema-de-vida]] · [[🩸 dano-localizado (ES)|🩸 dano-localizado]] · [[🗿 biblioteca-de-modelos (ES)|🗿 biblioteca-de-modelos]]

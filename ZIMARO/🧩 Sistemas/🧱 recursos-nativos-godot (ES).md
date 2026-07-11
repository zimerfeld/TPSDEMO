---
tipo: sistema
projeto: ZIMARO
lang: es-ES
atualizado: 2026-07-04
---

# 🧱 Recursos nativos de Godot usados en el proyecto

> Documentado el 2026-06-20. Un recuento de **qué nodos y recursos NATIVOS de Godot**
> usa el juego directamente (p. ej.: `StaticBody3D`, `CollisionShape3D`,
> `MeshInstance3D`). Recopilado a partir del `extends` de los archivos `.gd` y del `type=` de los `.tscn`,
> **excluyendo** el addon `godot_ai` (plugin MCP de terceros) — la porción de abajo es la del **juego**.

El proyecto **no tiene ningún nodo C++/GDExtension personalizado**: cada clase es nativa de Godot.
Las únicas abstracciones propias son scripts `RefCounted` de **lógica pura sin nodo**
(`BodyParts` + las subclases de plan corporal `BodyPartsBiped`/`Quadruped`/`Crawler` + la
fábrica `BodyPlans`, `WeaponParts`, `LimbConfig`, `LaserShooter`, `CannonShooter`), que
solo orquestan los nodos nativos. Ver [[🩸 dano-localizado (ES)|Daño localizado]] y
[[🦿 limb-colliders-gd (ES)|limb_colliders.gd]] para el ejemplo canónico: un `Node3D` que
**ensambla** `StaticBody3D` + `CollisionShape3D` + `BoneAttachment3D` nativos.

> Los conteos entre paréntesis = número de ocurrencias en `type=` a lo largo de las escenas del juego
> (snapshot 2026-06-20), útil solo como noción de frecuencia.

---

## Física y colisión

El grupo más usado del proyecto (un reflejo del disparo + daño localizado por miembro).

| Nodo/Recurso | Uso |
|---|---|
| `CollisionShape3D` (658×) | forma de toda colisión — con diferencia el más frecuente |
| `StaticBody3D` (13×) | hitboxes de miembros (`limb_colliders.gd`) y escenario |
| `CharacterBody3D` | `player`, `red_robot`, `bullet`, `bomb`, `criatura_alada` |
| `RigidBody3D` | `part.gd` (escombros del red_robot) |
| `Area3D` | `door.gd`, triggers, `PlayerDetectionArea` |
| `BoxShape3D` (118×) · `CylinderShape3D` · `SphereShape3D` · `CapsuleShape3D` | formas generadas por `make_shape()` y por el escenario |
| `CollisionPolygon3D` · `SeparationRayShape3D` · `RayCast3D` · `PhysicsMaterial` | casos ocasionales (raycast del láser, fricción) |

## Mallas y geometría visual

| Nodo/Recurso | Uso |
|---|---|
| `MeshInstance3D` (244×) | cada pieza visible |
| `BoxMesh` (101) · `CylinderMesh` (88) · `PrismMesh` (31) · `SphereMesh` (21) · `CapsuleMesh` · `QuadMesh` · `PlaneMesh` | modelos ensamblados a partir de primitivas |
| `ArrayMesh` (14) | mallas generadas/importadas |

## Esqueleto y animación

| Nodo/Recurso | Uso |
|---|---|
| `Skeleton3D` · `BoneAttachment3D` (25×) · `Skin` | rig; `BoneAttachment3D` une la hitbox al hueso |
| `AnimationPlayer` (12×) · `AnimationTree` · `AnimationLibrary` · `Animation` (44×) | clips y máquina de estados |
| `AnimationNode*` (`Animation`, `OneShot`, `BlendSpace2D`, `BlendTree`, `Blend2`, `TimeScale`, `Transition`, `Add3`) | grafos del AnimationTree |
| `SkeletonModifier3D` | `procedural_aim.gd` (puntería procedural) |
| `RootMotionView` | depuración de root motion |

## Cámara, luz y entorno

| Nodo/Recurso | Uso |
|---|---|
| `Camera3D` (4×) · `SpringArm3D` · `Marker3D` (11×) | `camera_noise_shake_effect.gd` hereda de `Camera3D` |
| `DirectionalLight3D` · `OmniLight3D` · `SpotLight3D` | iluminación |
| `WorldEnvironment` · `Environment` · `Sky` · `ProceduralSkyMaterial` · `PanoramaSkyMaterial` | entorno/cielo |
| `ReflectionProbe` · `VoxelGI`/`VoxelGIData` · `LightmapProbe` (32×) · `Decal` · `OccluderInstance3D`/`ArrayOccluder3D` | GI, oclusión, decals |

## Partículas y efectos

| Nodo/Recurso | Uso |
|---|---|
| `CPUParticles3D` (29×) · `GPUParticles3D` · `ParticleProcessMaterial` · `GPUParticlesCollisionSDF3D` | `part_disappear.gd` hereda de `CPUParticles3D` |

## Materiales, shaders y texturas

| Nodo/Recurso | Uso |
|---|---|
| `StandardMaterial3D` (47×) · `ShaderMaterial` · `Shader` · `Material` | materiales y shaders |
| `Texture2D` · `ImageTexture` · `Image` · `CurveTexture` · `Curve` (27×) · `Gradient`/`GradientTexture2D`/`1D` · `NoiseTexture2D` · `FastNoiseLite` | texturas y curvas |

## Audio

| Nodo/Recurso | Uso |
|---|---|
| `AudioStreamPlayer3D` (13×) · `AudioStreamPlayer` · `AudioStream`/`AudioStreamWAV` · `AudioStreamRandomizer` | emisores y streams. Ver [[🔊 audio (ES)|Audio]] |

## Red / multiplayer

| Nodo/Recurso | Uso |
|---|---|
| `MultiplayerSynchronizer` (7×) · `MultiplayerSpawner` · `SceneReplicationConfig` | `player_input.gd` hereda de `MultiplayerSynchronizer`. Ver [[🌐 multiplayer (ES)|Multiplayer]] |

## UI 2D (árbol `Control`)

`Control` · `Button` (126×) · `Label` (102×) · `HBoxContainer`/`VBoxContainer` ·
`PanelContainer` · `OptionButton` · `CheckButton`/`CheckBox` · `ProgressBar` ·
`ColorRect`/`TextureRect` · `HSlider` · `SpinBox` · `LineEdit` · `TabContainer` ·
`Center`/`Margin`/`SubViewportContainer` · `SubViewport` · `CanvasLayer` (HUDs:
`health_bar.gd`, `cyberpunk_hud.gd`) · `Timer` · `Theme` · `PackedScene`

---

## Clases base de los scripts (`extends` de un nodo nativo)

La porción más directa: scripts del juego que **heredan** de un nodo nativo.

| Clase nativa | Scripts |
|---|---|
| `CharacterBody3D` | `player.gd`, `red_robot.gd`, `bullet.gd`, `bomb.gd`, `criatura_alada.gd` |
| `RigidBody3D` | `part.gd` |
| `Area3D` | `door.gd` |
| `Camera3D` | `camera_noise_shake_effect.gd` |
| `MultiplayerSynchronizer` | `player_input.gd` |
| `SkeletonModifier3D` | `procedural_aim.gd` |
| `CPUParticles3D` | `part_disappear.gd` |
| `CanvasLayer` | `health_bar.gd`, `enemy_health_bar.gd` |
| `Node3D` | `level_*.gd`, `blast.gd`, `limb_colliders.gd`, `flying_forklift.gd` |
| `Node` | autoloads (`locale`, `debug_overlay`, `stability_guard`, `performance_hud`, `crash_handler`, `player_selection`) + escenas 2D de menú/ajustes |
| `RefCounted` | lógica pura **sin nodo**: `body_parts.gd` (+ `body_parts_biped/quadruped/crawler.gd`, `body_plans.gd`), `weapon_parts.gd`, `limb_config.gd`, `laser_shooter.gd`, `cannon_shooter.gd` |
| subclases de `Control` | widgets de HUD en `controls2D/` |

---

## Relacionado

- [[🩸 dano-localizado (ES)|Daño localizado]]
- [[🗿 biblioteca-de-modelos (ES)|Biblioteca de modelos]]
- [[🦿 limb-colliders-gd (ES)|limb_colliders.gd]]
- [[🌐 multiplayer (ES)|Multiplayer]]
- [[🔊 audio (ES)|Audio]]

# Recursos Nativos do Godot Usados no Projeto

> Documentado em 2026-06-20. Levantamento de **quais nós e recursos NATIVOS do
> Godot** o jogo usa diretamente (ex.: `StaticBody3D`, `CollisionShape3D`,
> `MeshInstance3D`). Apurado dos `extends` dos `.gd` e dos `type=` dos `.tscn`,
> **excluindo** o addon `godot_ai` (plugin MCP de terceiros) e a pasta `_gen/`
> (ferramentas de geração) — o recorte abaixo é o do **jogo**.

O projeto **não tem nó custom em C++/GDExtension**: toda classe é nativa do Godot.
As únicas abstrações próprias são scripts `RefCounted` de **lógica pura sem nó**
(`BodyParts` + as subclasses de plano corporal `BodyPartsBiped`/`Quadruped`/`Crawler` + a
factory `BodyPlans`, `WeaponParts`, `LimbConfig`, `LaserShooter`, `CannonShooter`), que
apenas orquestram os nós nativos. Ver [[sistemas/dano-localizado]] e
[[arquivos-chave/limb-colliders-gd]] para o exemplo canônico: um `Node3D` que
**monta** `StaticBody3D` + `CollisionShape3D` + `BoneAttachment3D` nativos.

> Contagens entre parênteses = nº de ocorrências em `type=` nas cenas do jogo
> (snapshot 2026-06-20), úteis só como noção de frequência.

---

## Física e colisão

O grupo mais usado do projeto (reflexo do tiro + dano localizado por membro).

| Nó/Recurso | Uso |
|---|---|
| `CollisionShape3D` (658×) | forma de toda colisão — de longe o mais frequente |
| `StaticBody3D` (13×) | hitboxes de membro (`limb_colliders.gd`) e cenário |
| `CharacterBody3D` | `player`, `red_robot`, `bullet`, `bomb`, `criatura_alada` |
| `RigidBody3D` | `part.gd` (destroços do red_robot) |
| `Area3D` | `door.gd`, gatilhos, `PlayerDetectionArea` |
| `BoxShape3D` (118×) · `CylinderShape3D` · `SphereShape3D` · `CapsuleShape3D` | shapes geradas por `make_shape()` e por cenário |
| `CollisionPolygon3D` · `SeparationRayShape3D` · `RayCast3D` · `PhysicsMaterial` | casos pontuais (raycast do laser, atrito) |

## Malhas e geometria visual

| Nó/Recurso | Uso |
|---|---|
| `MeshInstance3D` (244×) | toda peça visível |
| `BoxMesh` (101) · `CylinderMesh` (88) · `PrismMesh` (31) · `SphereMesh` (21) · `CapsuleMesh` · `QuadMesh` · `PlaneMesh` | modelos montados por primitivas |
| `ArrayMesh` (14) | malhas geradas/importadas |

## Esqueleto e animação

| Nó/Recurso | Uso |
|---|---|
| `Skeleton3D` · `BoneAttachment3D` (25×) · `Skin` | rig; `BoneAttachment3D` prende o hitbox ao osso |
| `AnimationPlayer` (12×) · `AnimationTree` · `AnimationLibrary` · `Animation` (44×) | clipes e máquina de estados |
| `AnimationNode*` (`Animation`, `OneShot`, `BlendSpace2D`, `BlendTree`, `Blend2`, `TimeScale`, `Transition`, `Add3`) | grafos do AnimationTree |
| `SkeletonModifier3D` | `procedural_aim.gd` (mira procedural) |
| `RootMotionView` | depuração de root motion |

## Câmera, luz e ambiente

| Nó/Recurso | Uso |
|---|---|
| `Camera3D` (4×) · `SpringArm3D` · `Marker3D` (11×) | `camera_noise_shake_effect.gd` herda `Camera3D` |
| `DirectionalLight3D` · `OmniLight3D` · `SpotLight3D` | iluminação |
| `WorldEnvironment` · `Environment` · `Sky` · `ProceduralSkyMaterial` · `PanoramaSkyMaterial` | ambiente/céu |
| `ReflectionProbe` · `VoxelGI`/`VoxelGIData` · `LightmapProbe` (32×) · `Decal` · `OccluderInstance3D`/`ArrayOccluder3D` | GI, oclusão, decals |

## Partículas e efeitos

| Nó/Recurso | Uso |
|---|---|
| `CPUParticles3D` (29×) · `GPUParticles3D` · `ParticleProcessMaterial` · `GPUParticlesCollisionSDF3D` | `part_disappear.gd` herda `CPUParticles3D` |

## Materiais, shaders e texturas

| Nó/Recurso | Uso |
|---|---|
| `StandardMaterial3D` (47×) · `ShaderMaterial` · `Shader` · `Material` | materiais e shaders |
| `Texture2D` · `ImageTexture` · `Image` · `CurveTexture` · `Curve` (27×) · `Gradient`/`GradientTexture2D`/`1D` · `NoiseTexture2D` · `FastNoiseLite` | texturas e curvas |

## Áudio

| Nó/Recurso | Uso |
|---|---|
| `AudioStreamPlayer3D` (13×) · `AudioStreamPlayer` · `AudioStream`/`AudioStreamWAV` · `AudioStreamRandomizer` | emissores e streams. Ver [[sistemas/audio]] |

## Rede / multiplayer

| Nó/Recurso | Uso |
|---|---|
| `MultiplayerSynchronizer` (7×) · `MultiplayerSpawner` · `SceneReplicationConfig` | `player_input.gd` herda `MultiplayerSynchronizer`. Ver [[sistemas/multiplayer]] |

## UI 2D (árvore `Control`)

`Control` · `Button` (126×) · `Label` (102×) · `HBoxContainer`/`VBoxContainer` ·
`PanelContainer` · `OptionButton` · `CheckButton`/`CheckBox` · `ProgressBar` ·
`ColorRect`/`TextureRect` · `HSlider` · `SpinBox` · `LineEdit` · `TabContainer` ·
`Center`/`Margin`/`SubViewportContainer` · `SubViewport` · `CanvasLayer` (HUDs:
`health_bar.gd`, `cyberpunk_hud.gd`) · `Timer` · `Theme` · `PackedScene`

---

## Classes-base dos scripts (`extends` de nó nativo)

Recorte mais direto: scripts do jogo que **herdam** um nó nativo.

| Classe nativa | Scripts |
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
| `Node` | autoloads (`locale`, `debug_overlay`, `stability_guard`, `performance_hud`, `crash_handler`, `player_selection`) + cenas 2D de menu/settings |
| `RefCounted` | lógica pura **sem nó**: `body_parts.gd` (+ `body_parts_biped/quadruped/crawler.gd`, `body_plans.gd`), `weapon_parts.gd`, `limb_config.gd`, `laser_shooter.gd`, `cannon_shooter.gd` |
| Subclasses de `Control` | widgets de HUD em `scenes2D/controls2D/` |

---

## Relacionado

- [[sistemas/dano-localizado]]
- [[sistemas/biblioteca-de-modelos]]
- [[arquivos-chave/limb-colliders-gd]]
- [[sistemas/multiplayer]]
- [[sistemas/audio]]

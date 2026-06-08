# scenes3D/players/player/player.gd

**Classe:** `Player extends CharacterBody3D`

---

## Responsabilidades

- Física e movimento (root motion, servidor)
- Gerenciamento de animações (enum `Animations`)
- Instanciação e disparo de balas
- **Sistema de HP e respawn**
- Sons: jump, land, shoot
- Camera shake via trauma

---

## Estrutura

```
_ready()
  ├─ inicializa orientation
  ├─ desativa process em clientes (servidor faz física)
  └─ _setup_health_bar.call_deferred()  (também disparado pelo setter de player_id)

player_id (setter)
  ├─ set_multiplayer_authority(InputSynchronizer)
  └─ _setup_health_bar.call_deferred()  (garante HUD em cliente multiplayer)

_physics_process(delta)
  ├─ servidor → apply_input(delta)
  └─ cliente  → animate(current_animation, delta)

apply_input(delta)
  ├─ interpola motion
  ├─ lógica de pulo / airborne
  ├─ aiming → STRAFE → instancia bala
  ├─ walk → orienta pelo movimento
  ├─ root motion → move_and_slide()
  └─ respawn se y < -40

animate(anim, delta)
  └─ controla parâmetros do AnimationTree
```

---

## Constantes e Variáveis Importantes

```gdscript
const MOTION_INTERPOLATE_SPEED: float = 10.0
const ROTATION_INTERPOLATE_SPEED: float = 10.0
const MIN_AIRBORNE_TIME: float = 0.1
const JUMP_SPEED: float = 5.0
const MAX_HP: int = 100

var hp: int = MAX_HP
var airborne_time: float = 100.0
var orientation := Transform3D()
var root_motion := Transform3D()
var motion := Vector2()
```

---

## Dependências (`@onready`)

```
$InputSynchronizer      → PlayerInputSynchronizer
$AnimationTree          → AnimationTree
$PlayerModel            → Node3D (modelo 3D)
$FireCooldown           → Timer (0.4s)
$SoundEffects/Jump      → AudioStreamPlayer
$SoundEffects/Land      → AudioStreamPlayer
$SoundEffects/Shoot     → AudioStreamPlayer
PlayerModel/.../GunBone/ShootFrom → Marker3D
```

---

## Caminho: `scenes3D/players/player/player.gd`

---

## Relacionado

- [[sistemas/player]]
- [[sistemas/sistema-de-vida]]
- [[arquivos-chave/player-input-gd]]
- [[arquivos-chave/health-bar-gd]]

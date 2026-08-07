class_name HumanoideJogavel
extends Player
## Personagem jogável com o modelo **humanoide** — o rig de 16 ossos com 36 animações em português.
##
## Reaproveita a classe `Player` inteira (input, câmera, rede, dano por membro, HUD). Duas coisas
## precisam ser diferentes:
##
## 1. **A velocidade não pode vir do root motion.** No player, o corpo anda exatamente o que a passada
##    da animação andou — por isso os pés não patinam. As animações do humanoide, porém, são
##    IN-PLACE: medido no `.glb`, `ocioso`/`andar`/`correr` não deslocam o osso `root` em X/Z.
##    Plugadas naquele motor, o personagem mexeria as pernas parado no lugar. Aqui a velocidade é
##    calculada por código e a animação vira visual, com a cadência escalada para o passo casar com a
##    velocidade real (mesma técnica que o red_robot usa no movimento manual).
## 2. **O vocabulário de animação é outro** — `ocioso`/`andar`/`saltar` em vez de `Idle`/`walking_gun`/
##    `jump_*`. Isso vive na árvore de animação da cena, que expõe os MESMOS nomes de parâmetro que o
##    `Player.animate()` escreve, então nem uma linha daquele código precisou mudar.
##
## Retarget (usar os clipes do player neste rig, ou o contrário) fica fora daqui de propósito — é
## trabalho de asset, do FIGArtStudio.

## Velocidade máxima de deslocamento (m/s). Calibrada para ficar perto do que o player alcança com
## root motion, para os dois personagens jogarem parecido na mesma sala.
const MAX_SPEED: float = 5.2
## Velocidade que a animação `andar` percorreria se o clipe tivesse deslocamento (m/s). É o divisor da
## cadência: acima disso o passo acelera, abaixo desacelera — é o que evita o pé deslizando.
const WALK_NATURAL_SPEED: float = 1.45
## Limites da escala de cadência. Fora dessa faixa a animação começa a parecer câmera rápida/lenta.
const CADENCE_MIN: float = 0.6
const CADENCE_MAX: float = 2.6
const CADENCE_PARAM := "parameters/locomotion_scale/scale"


func _ready() -> void:
	# Perfil de rig: reaproveita o `limb_config` da pasta `humanoide/` (a mesma que a tela Models já
	# edita), em vez de exigir uma configuração nova só porque a cena jogável mora noutra pasta.
	limb_model_key = "humanoide"
	limb_head_shape = "sphere"
	limb_auto_distal = true
	super._ready()


## Velocidade horizontal por CÓDIGO (ver o cabeçalho): a direção vem da câmera + input, a rapidez de
## MAX_SPEED, e a cadência da animação é escalada para o passo acompanhar.
func _apply_horizontal_velocity(_delta: float, camera_x: Vector3, camera_z: Vector3) -> void:
	var wish: Vector3 = camera_x * motion.x + camera_z * motion.y
	wish.y = 0.0
	var intensity: float = clampf(motion.length(), 0.0, 1.0)
	var speed: float = MAX_SPEED * intensity
	if wish.length() > 0.001:
		wish = wish.normalized()
	else:
		wish = Vector3.ZERO
	velocity.x = wish.x * speed
	velocity.z = wish.z * speed
	if animation_tree != null:
		animation_tree[CADENCE_PARAM] = clampf(
				speed / WALK_NATURAL_SPEED, CADENCE_MIN, CADENCE_MAX)

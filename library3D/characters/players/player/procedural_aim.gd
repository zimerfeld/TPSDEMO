extends SkeletonModifier3D
## Mira vertical PROCEDURAL do player.
##
## A animação additive do rig (AIM-Up/AIM-Down) não consegue ABAIXAR o braço — ela só
## levanta/segura, então a metade de baixo da mira ficava invertida (ver player_input.gd).
## Este modifier roda, DEPOIS do AnimationTree, o osso do TORSO (chest) em torno do eixo
## horizontal do esqueleto conforme o pitch da câmera. Como os ombros/braços/pescoço/arma
## são filhos do chest, o conjunto inteiro acompanha a mira para cima E para baixo.

## Pitch alvo em radianos (vem da câmera; + = cima, - = baixo). O player atualiza todo frame.
var aim_pitch: float = 0.0

## Osso do torso a girar. Seus descendentes (ombros, braços, arma, cabeça) acompanham.
@export var aim_bone: String = "chest"
## Fração do pitch da câmera que o torso acompanha (1.0 = total). Ajuste para o visual.
@export var strength: float = 0.7
## Eixo de pitch no espaço do esqueleto (direita do player). Inverta o sinal se a mira
## ficar trocada (cima vira baixo).
@export var pitch_axis: Vector3 = Vector3.RIGHT

var _bone: int = -2


func _process_modification() -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	if _bone == -2:
		_bone = skel.find_bone(aim_bone)
	if _bone < 0:
		return
	var angle := aim_pitch * strength * get_influence()
	if is_zero_approx(angle):
		return
	# Gira a pose GLOBAL do osso em torno do eixo de pitch e reconverte para pose local
	# (independe dos eixos locais do osso — a direção fica correta em qualquer rig).
	var g := skel.get_bone_global_pose(_bone)
	g.basis = Basis(pitch_axis.normalized(), angle) * g.basis
	var parent := skel.get_bone_parent(_bone)
	var local := g
	if parent >= 0:
		local = skel.get_bone_global_pose(parent).affine_inverse() * g
	skel.set_bone_pose_rotation(_bone, local.basis.get_rotation_quaternion())

class_name LimbDebris
extends SkeletonModifier3D

## EFEITO VISUAL do membro destruído: a peça **some da malha** e uma nuvem de faíscas marca o lugar.
##
## POR QUE UM SkeletonModifier3D: a AnimationTree reescreve a pose de todos os ossos a cada quadro, então
## zerar a escala do osso em qualquer outro ponto seria desfeito no quadro seguinte. Um modificador roda
## DEPOIS da animação, no ponto da engine feito para isto — a peça continua sumida enquanto o robô anda.
##
## Como a escala do osso propaga pela cadeia, colapsar um membro **leva junto o que vem depois dele**
## (o braço leva antebraço e mão) — o mesmo desenho da propagação de dano do [[limb-health]].
##
## ⚠️ O TRONCO é a raiz da maioria dos rigs: colapsá-lo sumiria com o personagem inteiro, inclusive os
## membros ainda de pé. Por isso ele recebe só as faíscas — ver `collapse_bone`.

# Escala aplicada ao osso colapsado. Não é zero: escala exatamente 0 degenera a base do transform
# (determinante nulo) e o Godot reclama; 0,001 já é invisível na prática.
const COLLAPSED_SCALE := Vector3(0.001, 0.001, 0.001)

# Faíscas: partículas CPU (baratas, sem custo de GPU compute) num disparo só, liberadas ao terminar.
const SPARK_COUNT := 18
const SPARK_LIFETIME := 0.55
const SPARK_VELOCITY := 3.2
const SPARK_COLOR := Color(1.0, 0.72, 0.25)

# bone_idx -> true. Reaplicado a cada quadro (ver _process_modification).
var _collapsed: Dictionary = {}


func _ready() -> void:
	# Roda no fim do pipeline de poses, depois da AnimationTree.
	influence = 1.0


# ⚠️ É ESTA a virtual que o Godot 4.6 chama (medido: 22 chamadas contra 0 da versão sem delta). A
# `_process_modification()` sem argumentos ainda existe na ClassDB, mas ficou legada — implementá-la
# sozinha faz o modificador nunca rodar, sem erro nenhum: o membro simplesmente não some.
func _process_modification_with_delta(_delta: float) -> void:
	_apply()


# Compatibilidade com versões que ainda chamem a virtual sem delta.
func _process_modification() -> void:
	_apply()


# Reaplica o colapso a cada quadro: a AnimationTree reescreve a pose de ENTRADA de todos os ossos
# antes de nós, então o valor precisa ser re-imposto aqui — por isso ler `get_bone_pose_scale` de fora
# devolve 1.0 mesmo com o membro sumido; a escala só vale dentro do pipeline de poses.
func _apply() -> void:
	if _collapsed.is_empty():
		return
	var skel := get_skeleton()
	if skel == null:
		return
	for idx in _collapsed:
		skel.set_bone_pose_scale(int(idx), COLLAPSED_SCALE)


# Colapsa o osso `bone_idx` (a peça e tudo que vem depois dela na cadeia somem) e solta faíscas na
# posição dele. `structural` = osso-raiz (tronco): não colapsa, só solta as faíscas, senão o
# personagem inteiro desapareceria de uma vez.
func collapse_bone(bone_idx: int, structural: bool = false) -> void:
	var skel := get_skeleton()
	if skel == null or bone_idx < 0 or bone_idx >= skel.get_bone_count():
		return
	_spark_at(skel, bone_idx)
	if structural or _collapsed.has(bone_idx):
		return
	_collapsed[bone_idx] = true


# Devolve todos os membros colapsados (respawn).
func restore_all() -> void:
	_collapsed.clear()


func _spark_at(skel: Skeleton3D, bone_idx: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var sparks := CPUParticles3D.new()
	sparks.name = "LimbSparks"
	sparks.emitting = true
	sparks.one_shot = true
	sparks.amount = SPARK_COUNT
	sparks.lifetime = SPARK_LIFETIME
	sparks.explosiveness = 1.0
	sparks.direction = Vector3.UP
	sparks.spread = 180.0
	sparks.initial_velocity_min = SPARK_VELOCITY * 0.4
	sparks.initial_velocity_max = SPARK_VELOCITY
	sparks.gravity = Vector3(0, -9.0, 0)
	sparks.scale_amount_min = 0.03
	sparks.scale_amount_max = 0.07
	sparks.color = SPARK_COLOR
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED   # emissivo barato, sem luz dinâmica
	mat.albedo_color = SPARK_COLOR
	mat.vertex_color_use_as_albedo = true
	sparks.material_override = mat
	skel.add_child(sparks)
	sparks.global_position = skel.to_global(skel.get_bone_global_pose(bone_idx).origin)
	# Some sozinho quando a última partícula morre — nada fica pendurado na cena.
	sparks.finished.connect(sparks.queue_free)

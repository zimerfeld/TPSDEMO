extends SceneTree
## Gera `library3D/characters/humanoide_jogavel/humanoide_jogavel.tscn` a partir do `player.tscn`.
##
## Por que por SCRIPT e nao a mao: a cena do player tem ~700 linhas de .tscn, com sub-recursos de
## AnimationTree e overrides de pose por indice de osso (do rig de 145) que NAO servem ao humanoide.
## Instanciar e re-empacotar produz uma copia PLANA correta por construcao, e a arvore de animacao
## nova e montada pela API — sem risco de erro de sintaxe num arquivo de recurso.
##
## Nao da para herdar `player.tscn` (o truque da `playera`): o Godot nao permite repontar o
## PackedScene de um no herdado instanciado, e e exatamente isso que precisamos fazer com o modelo.
##
## Uso: godot --headless --path . --script scripts/build_humanoide_jogavel.gd
## Rodar de novo REGENERA a cena (idempotente).

const PLAYER_SCENE := "res://library3D/characters/player/player.tscn"
const MODEL_GLB := "res://library3D/characters/humanoide/humanoide3.glb"
const OUT_DIR := "res://library3D/characters/humanoide_jogavel"
const OUT_SCENE := OUT_DIR + "/humanoide_jogavel.tscn"
const SCRIPT_PATH := OUT_DIR + "/humanoide_jogavel.gd"

# Altura (m) da plataforma da camera. O humanoide tem ~1,89 m de caixa; o player usa 1,6.
const CAMERA_HEIGHT := 1.72
# Nome do no que segura o modelo — o Player o acessa como `$PlayerModel`.
const MODEL_HOLDER := "PlayerModel"


func _initialize() -> void:
	_build()


func _build() -> void:
	var packed: PackedScene = load(PLAYER_SCENE)
	if packed == null:
		printerr("Nao consegui carregar %s" % PLAYER_SCENE)
		quit(1)
		return
	var root := packed.instantiate()
	root.name = "HumanoideJogavel"

	# 1) MODELO — fora o robo, dentro o humanoide. O no que o segura mantem o nome `PlayerModel`
	#    porque o Player o acessa por esse caminho.
	# O `PlayerModel` do player.tscn NAO e um no vazio: ele E a instancia do player.glb. Esvazia-lo nao
	# resolve — no `pack` o Godot restaura os filhos da instancia e a cena sairia com os DOIS modelos
	# (o teste pegou isso: 145 ossos do robo em vez dos 16 do humanoide). Trocamos o no inteiro por um
	# Node3D vazio de mesmo nome, na mesma posicao da arvore.
	var old_holder: Node3D = root.get_node_or_null(NodePath(MODEL_HOLDER))
	if old_holder == null:
		printerr("player.tscn sem %s" % MODEL_HOLDER)
		quit(1)
		return
	var holder_index := old_holder.get_index()
	var holder_transform := old_holder.transform
	root.remove_child(old_holder)
	old_holder.free()
	var holder := Node3D.new()
	holder.name = MODEL_HOLDER
	holder.transform = holder_transform
	root.add_child(holder)
	root.move_child(holder, holder_index)
	holder.owner = root
	var model_scene: PackedScene = load(MODEL_GLB)
	var model := model_scene.instantiate()
	model.name = "Humanoide"
	# GIRO DE 180°: o glTF do humanoide foi autorado encarando +Z, e todo o resto do jogo assume que a
	# frente de um personagem e o -Z (e o que `orientation`/`looking_at` e o root motion do player
	# usam). Sem isto ele anda de costas — o corpo aponta para o lado oposto ao do deslocamento.
	# Corrigido aqui, no no do MODELO, e nao na logica: assim a direcao de movimento, a mira e o ponto
	# de tiro continuam falando a mesma lingua do player e do red_robot.
	model.rotation.y = PI
	holder.add_child(model)
	model.owner = root

	var skeleton := _find(model, "Skeleton3D") as Skeleton3D
	var anim_player := _find(model, "AnimationPlayer") as AnimationPlayer
	if skeleton == null or anim_player == null:
		printerr("Modelo sem Skeleton3D/AnimationPlayer")
		quit(1)
		return
	print("Ossos: %d | animacoes: %d" % [
		skeleton.get_bone_count(), anim_player.get_animation_list().size()])

	# 2) PONTO DE SAIDA DO TIRO — o humanoide nao tem cano; usamos a mao direita do rig. O Player
	#    acha o `ShootFrom` por NOME, entao a hierarquia pode ser esta.
	var gun_bone := BoneAttachment3D.new()
	gun_bone.name = "GunBone"
	gun_bone.bone_name = _pick_bone(skeleton, ["hand.R", "hand_r", "mao.R", "hand.L"])
	skeleton.add_child(gun_bone)
	gun_bone.owner = root
	var shoot_from := Marker3D.new()
	shoot_from.name = "ShootFrom"
	skeleton.get_node(NodePath("GunBone")).add_child(shoot_from)
	shoot_from.owner = root

	# 3) ARVORE DE ANIMACAO — os MESMOS nomes de parametro que Player.animate() escreve
	#    (state/strafe/walk/aim), tocando os clipes do humanoide. Escopo atual: ocioso, andar em
	#    qualquer direcao, saltar.
	var tree: AnimationTree = root.get_node_or_null(^"AnimationTree")
	if tree == null:
		printerr("player.tscn sem AnimationTree")
		quit(1)
		return
	tree.tree_root = _build_tree()
	tree.anim_player = tree.get_path_to(anim_player)
	tree.root_node = tree.get_path_to(holder)
	# A track de root motion e EXTRAIDA da pose (senao o deslocamento vertical do `saltar` moveria a
	# malha inteira); a velocidade horizontal, essa sim, vem do codigo — ver humanoide_jogavel.gd.
	tree.root_motion_track = NodePath("%s/Skeleton3D:root" % model.name)
	tree.set("parameters/state/current_state", "walk")
	tree.set("parameters/aim/add_amount", 0.0)
	tree.set("parameters/locomotion_scale/scale", 1.0)
	tree.set("parameters/gesture_scale/scale", 1.0)

	# 4) CAMERA na altura do humanoide.
	var camera_base: Node3D = root.get_node_or_null(^"CameraBase")
	if camera_base != null:
		camera_base.position.y = CAMERA_HEIGHT

	# 5) SCRIPT do personagem.
	root.set_script(load(SCRIPT_PATH))

	# O GunBone/ShootFrom sao filhos ADICIONADOS dentro da instancia do .glb. Sem marcar a instancia
	# como editavel, o `pack` os descarta em silencio (foi o que o teste pegou: shoot_from == null) —
	# e o personagem nasceria sem de onde atirar.
	root.set_editable_instance(model, true)

	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var out := PackedScene.new()
	if out.pack(root) != OK:
		printerr("Falha ao empacotar")
		quit(1)
		return
	var err := ResourceSaver.save(out, OUT_SCENE)
	print("%s -> %s" % [OUT_SCENE, "OK" if err == OK else error_string(err)])
	root.free()
	quit(0 if err == OK else 1)


# BlendTree com a topologia que o Player.animate() espera:
#   output <- aim(Add3) <- locomotion_scale(TimeScale) <- state(Transition: strafe|walk|jump_up|jump_down)
func _build_tree() -> AnimationNodeBlendTree:
	var tree := AnimationNodeBlendTree.new()
	tree.resource_local_to_scene = true

	# `walk` e `strafe` sao BlendSpace2D porque o codigo escreve Vector2 neles; um BlendSpace1D
	# rejeitaria o valor a cada frame e a saida congelaria no primeiro clipe.
	# Escopo atual: MESMA animacao de andar para qualquer direcao (W/S/A/D), parado = ocioso.
	tree.add_node(&"walk", _walk_space())
	tree.add_node(&"strafe", _locomotion_space())
	var state := AnimationNodeTransition.new()
	state.resource_local_to_scene = true
	state.xfade_time = 0.2
	state.set("input_count", 4)
	var inputs := ["strafe", "walk", "jump_up", "jump_down"]
	for i in inputs.size():
		state.set("input_%d/name" % i, inputs[i])
		state.set("input_%d/auto_advance" % i, false)
		state.set("input_%d/reset" % i, true)
	tree.add_node(&"state", state)
	tree.add_node(&"jump_up", _clip("saltar"))
	tree.add_node(&"jump_down", _clip("saltar"))
	# Escala da cadencia: o script do personagem escreve aqui para o passo casar com a velocidade.
	tree.add_node(&"locomotion_scale", AnimationNodeTimeScale.new())
	# `aim` existe porque Player.animate() escreve parameters/aim/add_amount; com add_amount 0 ele e
	# transparente. Mantido para o codigo da base rodar sem alteracao.
	var aim := AnimationNodeAdd3.new()
	aim.resource_local_to_scene = true
	tree.add_node(&"aim", aim)
	# Duas instancias: o Godot nao aceita o MESMO no alimentando duas entradas do mesmo destino.
	tree.add_node(&"aim_minus", _clip("ocioso"))
	tree.add_node(&"aim_plus", _clip("ocioso"))

	# GESTO: as animacoes avulsas (rolar, defender, bater...) entram como CAMADA por cima da
	# locomocao, num OneShot. Nao podem ser um estado do `state`: o Player.animate() reescreve o
	# estado a cada frame de fisica e engoliria o gesto no frame seguinte. O clipe e trocado em
	# runtime (o BlendTree e local a cena, entao cada personagem tem o seu).
	var gesture := AnimationNodeOneShot.new()
	gesture.resource_local_to_scene = true
	gesture.fadein_time = 0.15
	gesture.fadeout_time = 0.2
	tree.add_node(&"gesture", gesture)
	# Escala de tempo do gesto. Existe para os gestos de POSTURA (agachar): zerando a escala quando o
	# clipe chega ao fim, o tempo do ramo para e a pose CONGELA no ultimo frame — o personagem fica
	# abaixado sem repetir a animacao de abaixar. Repetir em loop resolveria "ficar la", mas o corpo
	# ficaria se ajoelhando de novo e de novo. Ver Player.hold_gestures.
	tree.add_node(&"gesture_scale", AnimationNodeTimeScale.new())
	tree.add_node(&"gesture_clip", _clip("ocioso"))

	tree.connect_node(&"state", 0, &"strafe")
	tree.connect_node(&"state", 1, &"walk")
	tree.connect_node(&"state", 2, &"jump_up")
	tree.connect_node(&"state", 3, &"jump_down")
	tree.connect_node(&"locomotion_scale", 0, &"state")
	tree.connect_node(&"gesture", 0, &"locomotion_scale")
	tree.connect_node(&"gesture", 1, &"gesture_scale")
	tree.connect_node(&"gesture_scale", 0, &"gesture_clip")
	tree.connect_node(&"aim", 0, &"aim_minus")
	tree.connect_node(&"aim", 1, &"gesture")
	tree.connect_node(&"aim", 2, &"aim_plus")
	tree.connect_node(&"output", 0, &"aim")
	return tree


# Espaco do estado WALK (movimento livre). O `Player.animate()` escreve aqui
# `Vector2(motion.length(), 0)` — ou seja, o eixo X e a INTENSIDADE do movimento, de 0 a 1. Entao a
# progressao natural e parado -> andar -> correr, e nao "andar acelerado ate virar borrao": o clipe de
# CAMINHADA tocado a 2,6x era o que fazia a animacao parecer rapida demais.
func _walk_space() -> AnimationNodeBlendSpace2D:
	var space := AnimationNodeBlendSpace2D.new()
	space.resource_local_to_scene = true
	space.add_blend_point(_clip("ocioso"), Vector2(0, 0))
	space.add_blend_point(_clip("andar"), Vector2(0.45, 0))
	space.add_blend_point(_clip("correr"), Vector2(1, 0))
	# Ponto fora da linha: tres pontos colineares degeneram a triangulacao (0 triangulos = saida
	# congelada). O codigo nunca escreve y != 0, entao ele so existe para a malha fechar.
	space.add_blend_point(_clip("ocioso"), Vector2(0, 1))
	space.min_space = Vector2(0, 0)
	space.x_label = "velocidade"
	return space


# Espaco do estado STRAFE (movimento com a mira ativa): `andar` em todas as direcoes, porque mirando
# o personagem se desloca devagar. Os quatro pontos cardeais evitam a triangulacao degenerada.
func _locomotion_space() -> AnimationNodeBlendSpace2D:
	var space := AnimationNodeBlendSpace2D.new()
	space.resource_local_to_scene = true
	space.add_blend_point(_clip("ocioso"), Vector2(0, 0))
	space.add_blend_point(_clip("andar"), Vector2(0, 1))
	space.add_blend_point(_clip("andar"), Vector2(0, -1))
	space.add_blend_point(_clip("andar"), Vector2(1, 0))
	space.add_blend_point(_clip("andar"), Vector2(-1, 0))
	return space


func _clip(animation: String) -> AnimationNodeAnimation:
	var node := AnimationNodeAnimation.new()
	node.resource_local_to_scene = true
	node.animation = StringName(animation)
	return node


func _pick_bone(skeleton: Skeleton3D, candidates: Array) -> String:
	for name in candidates:
		if skeleton.find_bone(String(name)) != -1:
			return String(name)
	# Sem nenhum candidato: fica no primeiro osso, para a cena continuar valida (o tiro sai do lugar
	# errado, mas isso aparece em teste em vez de quebrar a montagem).
	push_warning("Nenhum osso de mao encontrado; usando '%s'" % skeleton.get_bone_name(0))
	return skeleton.get_bone_name(0)


func _find(node: Node, type_name: String) -> Node:
	var found := node.find_children("*", type_name, true, false)
	return found[0] if not found.is_empty() else null

class_name PlayerInputSynchronizer
extends MultiplayerSynchronizer

const CAMERA_CONTROLLER_ROTATION_SPEED: float = 3.0
const CAMERA_MOUSE_ROTATION_SPEED: float = 0.001
# A minimum angle lower than or equal to -90 breaks movement if the player is looking upward.
const CAMERA_X_ROT_MIN: float = deg_to_rad(-89.9)
const CAMERA_X_ROT_MAX: float = deg_to_rad(70.0)

# Release aiming if the mouse/gamepad button was held for longer than 0.4 seconds.
# This works well for trackpads and is more accessible by not making long presses a requirement.
# If the aiming button was held for less than 0.4 seconds, keep aiming until the aiming button is pressed again.
const AIM_HOLD_THRESHOLD: float = 0.4

# Distância mínima (m) de um acerto da mira para valer como alvo. Acertos colados na câmera
# (o próprio corpo durante a transição de mira, uma parede encostada) jogariam o alvo logo
# ACIMA do cano → o tiro saía quase vertical ("pro céu"). Abaixo disto usamos o ponto distante
# na direção da câmera, mantendo o tiro alinhado com a mira.
const MIN_AIM_DISTANCE: float = 3.0

# If `true`, the aim button was toggled checked by a short press (instead of being held down).
var toggled_aim: bool = false

# The duration the aiming button was held for (in seconds).
var aiming_timer: float = 0.0

# Inimigo atualmente sob a mira (para esconder o HUD quando a mira sai dele).
var _focused_enemy: Node = null

# Synchronized controls
@export var aiming: bool = false
@export var shoot_target := Vector3()
@export var motion := Vector2()
@export var shooting: bool = false
# This is handled via RPC for now
@export var jumping: bool = false
# Espaço ainda pressionado (sincronizado a cada tick, como shooting/aiming). Segurar até o
# fim = arco completo do pulo; soltar no meio da subida corta o pulo suavemente (player.gd).
@export var jump_held: bool = false

# Camera and effects
@export var camera_animation: AnimationPlayer
@export var crosshair: TextureRect
@export var camera_base: Node3D
@export var camera_rot: Node3D
@export var camera_camera: Camera3D
@export var color_rect: ColorRect
@export var ai_controlled: bool = false:
	set(value):
		ai_controlled = value
		if is_inside_tree():
			apply_authority()


func _ready() -> void:
	apply_authority()


# (Re)aplica o setup que depende da autoridade (câmera local + leitura de input).
# Precisa ser reentrante porque o MultiplayerSpawner só atribui o player_id (e,
# portanto, a autoridade deste nó) DEPOIS que este _ready já rodou no cliente que
# entra. Sem reaplicar, o cliente fica sem câmera ativa (view preso no centro do
# mundo) e com o input desligado (player não se move). Chamado de novo pelo setter
# de player_id em player.gd.
func apply_authority() -> void:
	if not is_inside_tree():
		return
	var parent := get_parent()
	var parent_bot_flag: Variant = parent.get("bot_controlled") if parent != null else false
	if ai_controlled or (parent_bot_flag is bool and bool(parent_bot_flag)):
		set_process(false)
		set_process_input(false)
		if crosshair != null:
			crosshair.hide()
		if color_rect != null:
			color_rect.hide()
		return
	if get_multiplayer_authority() == multiplayer.get_unique_id():
		camera_camera.make_current()
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		set_process(true)
		set_process_input(true)
		# Taxa de envio do INPUT deste peer (o dono) = a "Taxa de sincronização" que ELE escolheu no
		# NetConfig. O servidor já controla a taxa do ESTADO das entidades (ServerSynchronizer) pelo
		# RoomManager; aqui o dono controla a taxa do PRÓPRIO input → o controle vale dos dois lados
		# (host = broadcast das entidades; cliente = upload do seu input). Sem isto a escolha do
		# cliente ficaria inerte (só a do host valia).
		replication_interval = NetConfig.sync_interval()
	else:
		set_process(false)
		set_process_input(false)
		color_rect.hide()


func _process(delta: float) -> void:
	motion = Vector2(
			Input.get_action_strength(&"move_right") - Input.get_action_strength(&"move_left"),
			Input.get_action_strength(&"move_back") - Input.get_action_strength(&"move_forward"))
	var camera_move := Vector2(
			Input.get_action_strength(&"view_right") - Input.get_action_strength(&"view_left"),
			Input.get_action_strength(&"view_up") - Input.get_action_strength(&"view_down"))
	var camera_speed_this_frame: float = delta * CAMERA_CONTROLLER_ROTATION_SPEED
	if aiming:
		camera_speed_this_frame *= 0.5
	rotate_camera(camera_move * camera_speed_this_frame)
	var current_aim: bool = false

	# Keep aiming if the mouse wasn't held for long enough.
	if Input.is_action_just_released(&"aim") and aiming_timer <= AIM_HOLD_THRESHOLD:
		current_aim = true
		toggled_aim = true
	else:
		current_aim = toggled_aim or Input.is_action_pressed("aim")
		if Input.is_action_just_pressed("aim"):
			toggled_aim = false

	if current_aim:
		aiming_timer += delta
	else:
		aiming_timer = 0.0

	if aiming != current_aim:
		aiming = current_aim
		if aiming:
			camera_animation.play("shoot")
		else:
			camera_animation.play("far")

	if Input.is_action_just_pressed("jump"):
		jump.rpc()
	jump_held = Input.is_action_pressed(&"jump")

	shooting = Input.is_action_pressed("shoot")
	if shooting:
		var ch_pos = crosshair.position + crosshair.size * 0.5
		var ray_from = camera_camera.project_ray_origin(ch_pos)
		var ray_dir = camera_camera.project_ray_normal(ch_pos)

		var query := PhysicsRayQueryParameters3D.create(ray_from, ray_from + ray_dir * 1000.0, 0b11, _aim_ray_exclude())
		var col = get_parent().get_world_3d().direct_space_state.intersect_ray(query)
		# Descarta acertos colados na câmera (corpo próprio/parede durante a transição de mira):
		# eles jogariam o alvo logo acima do cano → tiro vertical. Nesses casos mira no ponto
		# distante ao longo da câmera, alinhando o tiro com a mira.
		if col.is_empty() or ray_from.distance_to(col.position) < MIN_AIM_DISTANCE:
			shoot_target = ray_from + ray_dir * 1000.0
		else:
			shoot_target = col.position

	# Exibe o HUD do inimigo quando a mira está sobre ele.
	_update_enemy_focus()

	# Fade out to black if falling out of the map. -17 is lower than
	# the lowest valid position checked the map (which is a bit under -16).
	# At 15 units below -17 (so -32), the screen turns fully black.
	var player_transform: Transform3D = get_parent().global_transform
	if player_transform.origin.y < -17.0:
		color_rect.modulate.a = minf((-17.0 - player_transform.origin.y) / 15.0, 1.0)
	else:
		# Fade out the black ColorRect progressively after being teleported back.
		color_rect.modulate.a *= 1.0 - delta * 4.0


func _input(input_event: InputEvent) -> void:
	if input_event is InputEventMouseMotion:
		var camera_speed_this_frame = CAMERA_MOUSE_ROTATION_SPEED
		if aiming:
			camera_speed_this_frame *= 0.75
		rotate_camera(input_event.screen_relative * camera_speed_this_frame)


# Lança um raio a partir da mira: mostra o HUD do inimigo sob a mira e o
# esconde assim que a mira sai dele. Só funciona com a MIRA ATIVADA (aiming) e
# quando o raio acerta um MEMBRO/SUB-MEMBRO do inimigo — andar de olho no inimigo
# sem mirar não abre mais o overlay. A máscara inclui a layer dos colliders de
# membro do inimigo (bit6=32) além do corpo (0b11), para que mirar num SUB-MEMBRO
# saliente (ex.: as placas das pernas, que escapam da silhueta do corpo) também
# acuse o inimigo. O dono é resolvido pela meta "character" do collider de membro.
func _update_enemy_focus() -> void:
	# Mira desativada: nenhum overlay: solta o foco atual e sai.
	if not aiming:
		_clear_enemy_focus()
		return

	var ch_pos: Vector2 = crosshair.position + crosshair.size * 0.5
	var ray_from: Vector3 = camera_camera.project_ray_origin(ch_pos)
	var ray_dir: Vector3 = camera_camera.project_ray_normal(ch_pos)

	var col: Dictionary = get_parent().get_world_3d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters3D.create(ray_from, ray_from + ray_dir * 1000, 0b100011, _aim_ray_exclude()))

	var enemy: Node = null
	if not col.is_empty():
		enemy = _resolve_focus_enemy(col.collider)

	if enemy:
		var dist: float = get_parent().global_position.distance_to(enemy.global_position)
		enemy.show_health_hud(dist)
		_focused_enemy = enemy
	else:
		# A mira saiu do inimigo → esconde o HUD imediatamente.
		_clear_enemy_focus()


# Esconde o HUD do inimigo em foco (mira saiu dele ou mira foi desativada).
func _clear_enemy_focus() -> void:
	if _focused_enemy == null:
		return
	if is_instance_valid(_focused_enemy) and _focused_enemy.has_method(&"hide_health_hud"):
		_focused_enemy.hide_health_hud()
	_focused_enemy = null


# Resolve o inimigo sob a mira a partir do collider atingido. O alvo válido é um collider
# de MEMBRO/SUB-MEMBRO (StaticBody3D passivo), que guarda o dono na meta "character" —
# acertar só a cápsula de locomoção do inimigo não conta. Exceção: inimigo que ainda não
# construiu colliders de membro cai no corpo, senão nunca mostraria a vida.
func _resolve_focus_enemy(collider) -> Node:
	if collider == null:
		return null
	if collider.has_meta(&"character"):
		var ch = collider.get_meta(&"character")
		if is_instance_valid(ch) and ch.has_method(&"show_health_hud"):
			return ch
		return null
	if collider.has_method(&"show_health_hud") and not _has_limb_colliders(collider):
		return collider
	return null


# `true` se o personagem já tem colliders de membro construídos (então o corpo não vale
# como alvo do overlay — o acerto precisa ser num membro/sub-membro).
func _has_limb_colliders(character: Node) -> bool:
	var lc := character.get_node_or_null(^"LimbColliders")
	if lc == null or not lc.has_method(&"get_limb_bodies"):
		return false
	return not lc.get_limb_bodies().is_empty()


# RIDs a excluir das raycasts de mira/foco: o CORPO do próprio atirador e seus colliders de
# MEMBRO. Sem isto o raio (que parte de trás do ombro) acertava o próprio jogador — pondo o
# alvo logo acima do cano (tiro pro céu) e fazendo a mira "focar" o próprio corpo. O `[self]`
# antigo era o synchronizer (nem é corpo físico), então não excluía nada.
func _aim_ray_exclude() -> Array[RID]:
	var ex: Array[RID] = []
	var body := get_parent()
	if body is CollisionObject3D:
		ex.append((body as CollisionObject3D).get_rid())
	var lc := body.get_node_or_null(^"LimbColliders")
	if lc != null and lc.has_method(&"get_limb_bodies"):
		for limb in lc.get_limb_bodies():
			if limb is CollisionObject3D:
				ex.append((limb as CollisionObject3D).get_rid())
	return ex


func rotate_camera(move: Vector2) -> void:
	camera_base.rotate_y(-move.x)
	# After relative transforms, camera needs to be renormalized.
	camera_base.orthonormalize()
	camera_rot.rotation.x = clampf(camera_rot.rotation.x + move.y, CAMERA_X_ROT_MIN, CAMERA_X_ROT_MAX)


# Pitch da câmera (rad) que alimenta a mira vertical PROCEDURAL (procedural_aim.gd).
# A antiga get_aim_rotation alimentava o blend additive AIM-Up/AIM-Down do AnimationTree,
# mas esse blend não abaixa o braço (só levanta/segura), então a metade de baixo ficava
# invertida. Agora o torso é girado por código conforme este pitch (+ = cima, - = baixo).
func get_aim_pitch() -> float:
	return clampf(camera_rot.rotation.x, CAMERA_X_ROT_MIN, CAMERA_X_ROT_MAX)


func get_camera_base_quaternion() -> Quaternion:
	return camera_base.global_transform.basis.get_rotation_quaternion()


func get_camera_rotation_basis() -> Basis:
	return camera_rot.global_transform.basis


@rpc("call_local")
func jump() -> void:
	jumping = true
	# Semeia o hold junto do pulo: a property sincronizada pode chegar ao servidor um tick
	# depois do RPC — sem isto o primeiro frame do pulo poderia ser cortado por engano.
	jump_held = true

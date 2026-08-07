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
## SHIFT segurado: corre (mais rápido, animação de corrida). Solto: caminha. Replicado como os
## demais — o servidor precisa saber, senão ele simula uma velocidade e o cliente outra, e a
## reconciliação passaria a corrigir uma divergência que é só de input.
@export var running: bool = false
## CTRL segurado: abaixa. A perna que se ajoelha segue o LADO DA MIRA (ver aim_side).
## Replicado também no pacote de SPAWN — é o que permite a quem entra atrasado reconstruir a pose
## de alguém que já estava agachado (ver `_ready`).
@export var crouching: bool = false
## Lado da mira sobre o ombro: +1 direita (padrão), -1 esquerda. Alterna com C e é lembrado entre
## sessões (Settings → `reticle_side`). Espelha a posição da câmera de mira.
var aim_side: int = 1
# Estado anterior do agachar, para disparar/abortar a animação só na mudança.
var _was_crouching: bool = false
## Lado em que o corpo agachou. O levantar tem de usar ESTE, não o lado da mira no momento de soltar.
var _crouch_side: int = 1

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
	_load_aim_side()
	# Roda DEPOIS do AnimationPlayer da câmera (prioridade 0): é o que permite ao `_apply_aim_side`
	# do fim do `_process` corrigir o ombro sem ser sobrescrito no mesmo frame.
	process_priority = 10
	apply_authority()
	# LATE JOIN: a postura mora em estado local da árvore de animação, instalado por um RPC que quem
	# chega depois nunca recebeu — o recém-chegado via de pé alguém que estava agachado. `crouching`
	# vem no pacote de spawn, então basta reconstruir a pose aqui. Só localmente: o gesto já foi
	# anunciado à rede por quem agachou, e reanunciá-lo daqui ecoaria de volta ao servidor.
	if crouching:
		_was_crouching = true
		_play_posture.call_deferred(true, true)


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
		# Idem spectator_camera: durante o pré-pagamento do startup não há partida, e capturar o mouse
		# ali custa o cursor da UI 2D que vem depois. Ver [[loading_screen]].
		if not LoadingScreen.preloading:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		set_process(true)
		set_process_input(true)
		# Taxa de envio do INPUT deste peer. NÃO é a "Taxa de sincronização" do NetConfig: aquela
		# dimensiona o BROADCAST DE ESTADO (dezenas de entidades × todos os peers), enquanto isto aqui
		# é um único pacote de ~40 B com as teclas de UM jogador. Amarrar os dois punha até 33 ms de
		# espera na frente de TODA ação do cliente — inclusive a borda de subida do tiro — para
		# economizar uns 2 KB/s de upload, troca claramente ruim.
		#
		# Só do lado do CLIENTE: no host este mesmo InputSynchronizer é autoritativo e transmite para
		# todos os peers, e `apply_authority` é deferido — sem o guard, ele sobrescreveria o intervalo
		# que o RoomManager aplicou ao broadcast da sala.
		if not multiplayer.is_server():
			replication_interval = NetConfig.input_interval()
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
	running = Input.is_action_pressed(&"run")
	if Input.is_action_just_pressed(&"toggle_aim_side"):
		_flip_aim_side()
	_update_crouch()
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

	# POR ÚLTIMO: reimpõe o ombro escolhido sobre o que a animação de câmera acabou de escrever.
	_apply_aim_side()

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
		return
	_try_gesture(input_event)


# Atalhos de ANIMAÇÃO (aba Controles): a tecla pressionada vira um gesto no personagem. Só a BORDA de
# subida conta — segurar a tecla não fica redisparando —, e o evento NÃO é consumido: a mesma tecla
# continua andando/atirando normalmente. É por isso que o WSAD segue intacto mesmo quando uma animação
# de locomoção herda a tecla dele.
func _try_gesture(input_event: InputEvent) -> void:
	if not input_event.is_pressed() or input_event.is_echo():
		return
	if not InputBindings.is_supported(input_event):
		return
	var character := get_parent()
	if character == null or not character.has_method(&"request_gesture"):
		return
	if not character.call(&"supports_gestures"):
		return
	var animation := AnimationBindings.animation_for_event(input_event)
	if animation == "" or AnimationBindings.is_locomotion(animation):
		return   # locomoção é da máquina de estados; tocá-la como gesto brigaria com ela
	character.call(&"request_gesture", animation)


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
		# Membro sob a mira: o overlay mostra o HP e o NOME dele (é esse membro que precisa cair).
		# Personagens sem HP por membro ignoram o grupo e mostram a vida do corpo. Ver [[limb-health]].
		var group: String = String(col.collider.get_meta(&"group", "")) if col.collider != null else ""
		enemy.show_health_hud(dist, group)
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


# ───────────────────────── lado da mira e agachar ─────────────────────────

## Alterna o ombro sobre o qual a câmera de mira se apoia (C) e lembra a escolha.
func _flip_aim_side() -> void:
	aim_side = -aim_side
	Settings.config_file.set_value("runtime", "reticle_side", "right" if aim_side > 0 else "left")
	Settings.save_settings()


## Lê o ombro escolhido na sessão anterior. Sem isto a chave era gravada e nunca lida — a preferência
## voltava para a direita a cada partida, embora a documentação prometesse o contrário.
func _load_aim_side() -> void:
	var salvo := String(Settings.config_file.get_value("runtime", "reticle_side", "right"))
	aim_side = -1 if salvo == "left" else 1


# A posição de mira é escrita por uma ANIMAÇÃO da câmera (o clipe de mira desloca o SpringArm para o
# ombro). Espelhar o X preserva a distância autorada e só troca de lado, em vez de duplicar o clipe
# inteiro para a esquerda.
#
# Precisa rodar TODO FRAME, e não só no clique: a animação regrava o X a cada toggle de mira, o que
# apagava a escolha. E no clique isolado não adiantava nada — fora da mira o X vale 0, e 0 espelhado
# continua 0. Por isso este nó também roda com prioridade tardia (ver _ready): o AnimationPlayer da
# câmera escreve primeiro, nós corrigimos o lado depois.
func _apply_aim_side() -> void:
	var arm := camera_rot.get_node_or_null(^"SpringArm3D") as Node3D if camera_rot != null else null
	if arm == null:
		return
	arm.position.x = absf(arm.position.x) * float(aim_side)


## CTRL abaixa. A animação é a do lado da mira — mira à direita ajoelha com a perna direita, à
## esquerda com a esquerda. São dois movimentos distintos e cada um toca UMA vez: ao apertar, abaixa e
## FICA abaixado (a pose congela — ver o parâmetro `hold` de Player.request_gesture); ao soltar, roda
## o levantar. Abortar o
## gesto, como se fazia antes, fazia o corpo saltar de volta à locomoção sem levantar.
## Quais clipes usar é o personagem quem diz: este nó não conhece o vocabulário de nenhum modelo.
func _update_crouch() -> void:
	crouching = Input.is_action_pressed(&"crouch")
	if crouching == _was_crouching:
		return
	_was_crouching = crouching
	_play_posture(crouching)


## Toca o abaixar (ou o levantar) no personagem. Separado de `_update_crouch` porque o late join
## chega aqui sem passar pelo teclado (ver `_ready`).
##
## `local_only` toca sem anunciar à rede — é o modo do late join, onde a postura já é conhecida de
## todos e o que falta é só reconstruí-la nesta tela.
func _play_posture(down: bool, local_only: bool = false) -> void:
	var character := get_parent()
	var asker: StringName = &"crouch_gesture" if down else &"stand_gesture"
	# Nem todo corpo que aceita este nó é um `Player` — o red_robot é um CharacterBody3D próprio.
	if character == null or not character.has_method(asker) \
			or not character.has_method(&"request_gesture"):
		return
	# O levantar usa o lado em que o corpo AGACHOU, não o lado da mira agora: trocar de ombro com C
	# no meio do agachamento fazia o modelo estalar, trocando de joelho antes de ficar de pé.
	if down:
		_crouch_side = aim_side
	var clip: String = character.call(asker, _crouch_side)
	if clip == "":
		return
	# `hold` só no abaixar: o levantar precisa terminar e devolver o corpo à locomoção.
	if local_only:
		character.call(&"play_gesture_here", clip, down)
	else:
		character.call(&"request_gesture", clip, down)

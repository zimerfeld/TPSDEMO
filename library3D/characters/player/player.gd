class_name Player
extends CharacterBody3D


enum Animations {
	JUMP_UP,
	JUMP_DOWN,
	STRAFE,
	WALK,
}

const MOTION_INTERPOLATE_SPEED: float = 10.0
const ROTATION_INTERPOLATE_SPEED: float = 10.0
const PlayerBotAILib := preload("res://library3D/characters/player/IA/player_bot_ai.gd")

const MIN_AIRBORNE_TIME: float = 0.1
const JUMP_SPEED: float = 6.5
# Amortecimento (1/s) da velocidade vertical quando o espaço é SOLTO no meio da subida do
# pulo: a subida morre suavemente (sem trancos) e a animação transiciona para jump_down.
# Segurar o espaço até o fim mantém o arco completo (altura e distância máximas).
const JUMP_CUT_DAMPING: float = 14.0
# Tempo (s) mirando antes do PRIMEIRO tiro — espera a animação de mira assentar. Sem isto, num
# aim→tiro instantâneo a bala saía antes de o corpo entrar na pose de mira; no cliente (corpo
# renderizado ~100 ms no passado) isso parecia a bala saindo fora da extremidade do cano.
const AIM_WARMUP_TIME: float = 0.45

var airborne_time: float = 100.0
# True do início do pulo até o ápice (ou o pouso). Restringe o corte de pulo (JUMP_CUT_DAMPING)
# a pulos REAIS — cair de uma borda não pode ser amortecido só porque o espaço não está pressionado.
var _jump_active: bool = false
# Tempo acumulado mirando (zera ao sair da mira); o tiro só é liberado após AIM_WARMUP_TIME.
var _aim_held_time: float = 0.0

var orientation := Transform3D()
var root_motion := Transform3D()
var motion := Vector2()

var _is_local_player: bool = false
var _has_prediction: bool = false
var _predicted_origin: Vector3
var _predicted_velocity: Vector3
const SERVER_SNAP_THRESHOLD: float = 2.0

# --- Interpolação de rede (suavização das entidades remotas) ---
## Proxies replicados pelo ServerSynchronizer NO LUGAR de transform/PlayerModel:transform.
## O servidor os espelha do estado real a cada frame; o cliente remoto os bufferiza (NetInterp)
## e renderiza ~100 ms no passado, eliminando o stutter de aplicar o transform cru ~30x/s. O
## cliente DONO usa net_transform como "verdade do servidor" para reconciliar a predição.
@export var net_transform: Transform3D = Transform3D.IDENTITY:
	set(value):
		net_transform = value
		_net_received = true
@export var net_model_transform: Transform3D = Transform3D.IDENTITY
var _net_received: bool = false
var _interp_body := NetInterp.new()
var _interp_model := NetInterp.new()
var _interp_seeded: bool = false
# Estado da mira no frame anterior — para detectar o "aim-enter" e alinhar o corpo na hora.
var _was_aiming: bool = false

var initial_position: Vector3 = Vector3.ZERO

@onready var player_input: PlayerInputSynchronizer = $InputSynchronizer
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var player_model: Node3D = $PlayerModel
@onready var shoot_from: Marker3D = player_model.get_node(^"Robot_Skeleton/Skeleton3D/GunBone/ShootFrom")
@onready var crosshair: TextureRect = $Crosshair
@onready var fire_cooldown: Timer = $FireCooldown

@onready var sound_effects: Node = $SoundEffects
@onready var sound_effect_jump: AudioStreamPlayer3D = sound_effects.get_node(^"Jump")
@onready var sound_effect_land: AudioStreamPlayer3D = sound_effects.get_node(^"Land")
@onready var sound_effect_shoot: AudioStreamPlayer3D = sound_effects.get_node(^"Shoot")

@export var player_id: int = 1:
	set(value):
		player_id = value
		$InputSynchronizer.set_multiplayer_authority(value)
		# O MultiplayerSpawner atribui player_id (logo, a autoridade do input) só
		# DEPOIS que $InputSynchronizer._ready() rodou no cliente que entra. Por isso
		# o setup de câmera/input precisa ser reaplicado aqui — senão o cliente fica
		# com a view presa no centro do mundo e o player não se move.
		if is_inside_tree():
			$InputSynchronizer.apply_authority.call_deferred()
		# Garante o HUD do player local em toda cena de level, inclusive quando
		# player_id chega via replicação depois do _ready (cliente multiplayer).
		_setup_health_bar.call_deferred()
		# A autoridade do input (definida agora) decide se o nome vai no Label3D acima da
		# cabeça (outros) ou no HUD (player local) — reavalia após a autoridade assentar.
		_apply_name_label.call_deferred()
		# Guard: multiplayer is only available when inside the scene tree.
		# _ready() will re-evaluate _is_local_player after add_child().
		if is_inside_tree():
			_is_local_player = _safe_is_server_call(false) == false and value == multiplayer.get_unique_id()

@export var current_animation := Animations.WALK

## Posição de spawn definida pelo servidor; replicada como spawn property (ver
## ServerSynchronizer em player.tscn). O spawn do transform via MultiplayerSpawner NÃO
## chega a tempo no cliente que entra — ele nasceria em (0,0,0) e cairia do mapa. Esta
## property (entregue no pacote de spawn, como player_id) reposiciona o cliente.
@export var spawn_position: Vector3 = Vector3.ZERO:
	set(value):
		spawn_position = value
		_apply_spawn_position()

## Nome do jogador (spawn property, definida pelo servidor a partir do que o peer escolheu na
## playonline). Replicada a TODOS os peers no pacote de spawn → cada um mostra o Label3D acima
## da cabeça. O setter pode rodar antes do _ready (como player_id), por isso é idempotente.
@export var player_name: String = "":
	set(value):
		player_name = value
		_apply_name_label()

const MAX_HP: int = 100
var hp: int = MAX_HP

## Dano da arma que o player porta (atribuído a cada bullet disparado).
@export var weapon_damage: int = 50

var _health_bar = null

# SkeletonModifier3D que faz a mira vertical procedural (gira o torso pelo pitch da câmera).
var _aim_modifier = null
var ai: Node = null

@export var bot_controlled: bool = false:
	set(value):
		bot_controlled = value
		if is_inside_tree():
			_apply_bot_controlled()


func _ready() -> void:
	# Facção runtime deste nó (aliado por padrão; template "enemy" tem precedência). Usada para o
	# targeting da IA e para cortar o fogo amigo (ver [[factions]] / effects_shared/factions.gd).
	Factions.seed_node(self, &"player")
	# Pre-initialize orientation transform.
	orientation = player_model.global_transform
	orientation.origin = Vector3()
	initial_position = transform.origin
	# Posiciona no spawn replicado (cobre o caso de a property já ter chegado antes do _ready).
	_apply_spawn_position()
	# Mostra o nome acima da cabeça (cobre o caso de player_name já ter chegado antes do _ready).
	_apply_name_label()
	# Semeia os proxies de rede com a pose inicial APENAS no servidor (assim o spawn property
	# já carrega o valor certo). No cliente NÃO semeamos: o valor correto chega pela replicação
	# de spawn; semear aqui marcaria _net_received cedo e a entidade interpolaria a partir da
	# origem (flicker). Até chegar, o remoto fica na spawn_position.
	if _safe_is_server_call(false):
		net_transform = transform
		net_model_transform = player_model.transform
	# Re-evaluate here: player_id setter may have run before add_child() (no tree = no multiplayer).
	_is_local_player = not _safe_is_server_call(false) and player_id == multiplayer.get_unique_id()
	if not _safe_is_server_call(false):
		set_process(false)
	# Cria o HUD de vida do player local sempre que um level carrega.
	# Deferido para garantir que player_id/authority já foi replicado em multiplayer.
	_setup_health_bar.call_deferred()
	# Colliders 3D de membro (dano localizado). O projétil colide fisicamente
	# com eles; construídos em todos os peers (só o servidor simula os tiros).
	_setup_limb_colliders.call_deferred()
	# Mira vertical procedural (gira o torso conforme o pitch da câmera). Substitui o
	# blend additive AIM-Up/AIM-Down, que não conseguia abaixar o braço.
	_setup_aim_modifier.call_deferred()
	_apply_bot_controlled.call_deferred()


func _apply_bot_controlled() -> void:
	if player_input == null:
		return
	player_input.ai_controlled = bot_controlled
	if bot_controlled:
		_is_local_player = false
		if ai == null:
			ai = PlayerBotAILib.new()
			ai.name = "IA"
			add_child(ai)
	else:
		if ai != null:
			ai.queue_free()
			ai = null
		if is_inside_tree() and not _safe_is_server_call(false):
			_is_local_player = player_id == multiplayer.get_unique_id()
	# Bot vs. controlado muda quem é "dono local": reavalia o nome 3D / HUD.
	_apply_name_label()


# Coloca o player na posição de spawn enviada pelo servidor e zera a queda/predição local.
# Reentrante: chamado pelo setter de spawn_position (quando a property replicada chega) e
# pelo _ready. Idempotente — só age quando já está na árvore e há um spawn válido.
func _apply_spawn_position() -> void:
	if not is_inside_tree() or spawn_position == Vector3.ZERO:
		return
	global_position = spawn_position
	initial_position = spawn_position
	velocity = Vector3.ZERO
	_has_prediction = false
	# Salto de posição: zera a interpolação física para não "rasgar" (flicker) do ponto
	# antigo (ex.: 0,0,0) até o spawn. Roda em todos os peers (a property é replicada).
	reset_physics_interpolation()


# Atualiza o Label3D do nome acima da cabeça. Idempotente (chamado pelo setter de player_name e
# pelo _ready). O nome 3D acima da cabeça aparece só para os OUTROS jogadores conectados; no
# próprio player local o nome vai para o HUD (health_bar), então o Label3D dele fica escondido.
# Também esconde quando o nome está vazio para não mostrar uma etiqueta em branco.
func _apply_name_label() -> void:
	if not is_inside_tree():
		return
	var lbl := get_node_or_null(^"NameLabel") as Label3D
	if lbl == null:
		return
	lbl.text = player_name
	lbl.visible = player_name.strip_edges() != "" and not _is_owned_locally()
	# Mantém o HUD do dono em sincronia com o nome (quando o HUD já existe).
	if _health_bar != null and _health_bar.has_method(&"set_player_name"):
		_health_bar.set_player_name(player_name)


# True apenas na instância que CONTROLA localmente este player (o "meu" player), pelo mesmo
# critério do HUD de vida: a autoridade do InputSynchronizer é este peer e não é um bot. Cobre o
# host (id 1, que joga na sala) e os clientes. Usa $InputSynchronizer (não o onready) porque pode
# ser chamado antes do _ready, quando o setter de player_id já configurou a autoridade.
func _is_owned_locally() -> bool:
	if not is_inside_tree() or multiplayer == null:
		return false
	if bot_controlled:
		return false
	return $InputSynchronizer.get_multiplayer_authority() == multiplayer.get_unique_id()


func _setup_health_bar() -> void:
	# Idempotente: pode ser chamado pelo _ready e pelo setter de player_id.
	if _health_bar != null:
		return
	# Mostra o HUD apenas para o player controlado localmente (mesmo critério do nome 3D).
	if not _is_owned_locally():
		return
	_health_bar = preload("res://controls2D/health_bar.gd").new()
	_health_bar.name = "HealthBar"
	add_child(_health_bar)
	_health_bar.update_health(hp, MAX_HP)
	# O nome do player local vai no HUD (acima do HP); o Label3D acima da cabeça fica escondido.
	_health_bar.set_player_name(player_name)
	_apply_name_label()


func _setup_limb_colliders() -> void:
	if has_node(^"LimbColliders"):
		return
	var skel := player_model.get_node_or_null(^"Robot_Skeleton/Skeleton3D") as Skeleton3D
	if skel == null:
		return
	var lc = preload("res://effects_shared/limb_colliders.gd").new()
	lc.name = "LimbColliders"
	lc.body_type = "biped"      # plano corporal → classificador de membros
	lc.model_key = "player"     # busca os multiplicadores de dano por membro em LimbConfig
	lc.head_shape = "capsule"   # cabeça do player = cápsula (mesma orientação), não esfera
	lc.hitbox_layer = 16        # bit5 = colliders de membro do player
	add_child(lc)
	lc.build_for(skel)
	# Ajusta a cápsula de LOCOMOÇÃO (bloqueio físico) ao modelo, derivando raio/altura dos boxes
	# de membro recém-construídos — corpo proporcional ao player em vez da cápsula default. Mantém
	# 1 shape/personagem (barato, estável, netcode-friendly). Ver [[sistemas/player]].
	var body_shape := get_node_or_null(^"CapsuleShape3D") as CollisionShape3D
	if body_shape != null:
		lc.fit_locomotion_capsule(body_shape, self)


# Cria o SkeletonModifier3D da mira vertical procedural sob o Skeleton3D do player.
func _setup_aim_modifier() -> void:
	if _aim_modifier != null:
		return
	var skel := player_model.get_node_or_null(^"Robot_Skeleton/Skeleton3D") as Skeleton3D
	if skel == null:
		return
	_aim_modifier = preload("res://library3D/characters/player/procedural_aim.gd").new()
	_aim_modifier.name = "ProceduralAim"
	skel.add_child(_aim_modifier)


func _safe_is_server_call(default: bool = false) -> bool:
	if not is_inside_tree():
		return default
	if multiplayer == null:
		CrashHandler.show_error(
			"MultiplayerAPI indisponível no player %d.\nVerifique a conexão de rede." % player_id
		)
		return default
	return multiplayer.is_server()


func _physics_process(delta: float) -> void:
	if _safe_is_server_call(false):
		if bot_controlled and ai != null and ai.has_method(&"update_input"):
			ai.update_input(self, player_input, delta)
		apply_input(delta)
		# Espelha o estado real nos proxies replicados (os clientes interpolam estes valores).
		net_transform = transform
		net_model_transform = player_model.transform
	elif _is_local_player:
		_reconcile()
		apply_input(delta)
		_predicted_origin = global_position
		_predicted_velocity = velocity
		_has_prediction = true
	else:
		# Player remoto: renderiza ~100 ms no passado interpolando os snapshots recebidos.
		_interpolate_remote()
		animate(current_animation, delta)


# Aplica o transform interpolado (buffer de snapshots datados) no player remoto e no seu modelo.
func _interpolate_remote() -> void:
	if not _net_received:
		return  # nada recebido ainda: fica na posição de spawn
	var now: float = float(Time.get_ticks_msec())
	_interp_body.push(now, net_transform)
	_interp_model.push(now, net_model_transform)
	if _interp_body.has_data():
		transform = _interp_body.sample(now)
	if _interp_model.has_data():
		player_model.transform = _interp_model.sample(now)
	if not _interp_seeded:
		# 1ª aplicação: zera a interpolação física p/ não "rasgar" do spawn até a 1ª amostra.
		_interp_seeded = true
		reset_physics_interpolation()


func _reconcile() -> void:
	if not _has_prediction:
		return
	if not _net_received:
		# Sem verdade do servidor ainda: confia 100% na predição local.
		global_position = _predicted_origin
		velocity = _predicted_velocity
		return
	var drift: float = net_transform.origin.distance_to(_predicted_origin)
	if drift < SERVER_SNAP_THRESHOLD:
		# Servidor concorda o suficiente: mantém a predição local (sem solavanco).
		global_position = _predicted_origin
		velocity = _predicted_velocity
	else:
		# Divergiu demais: ressincroniza com a posição autoritativa do servidor.
		global_position = net_transform.origin
		_has_prediction = false


func animate(anim: int, _delta: float) -> void:
	current_animation = anim as Animations

	if anim == Animations.JUMP_UP:
		animation_tree["parameters/state/transition_request"] = "jump_up"

	elif anim == Animations.JUMP_DOWN:
		animation_tree["parameters/state/transition_request"] = "jump_down"

	elif anim == Animations.STRAFE:
		animation_tree["parameters/state/transition_request"] = "strafe"
		# Vertical aim is now PROCEDURAL (see procedural_aim.gd): the additive AIM-Up/AIM-Down
		# blend can't lower the arm, so it stays disabled (add_amount 0) and the torso is
		# rotated by the camera pitch instead.
		animation_tree["parameters/aim/add_amount"] = 0
		if _aim_modifier != null:
			_aim_modifier.aim_pitch = player_input.get_aim_pitch()
		# The animation's forward/backward axis is reversed.
		animation_tree["parameters/strafe/blend_position"] = Vector2(motion.x, -motion.y)

	elif anim == Animations.WALK:
		# Not aiming while walking: zero the additive blend and the procedural pitch.
		animation_tree["parameters/aim/add_amount"] = 0
		if _aim_modifier != null:
			_aim_modifier.aim_pitch = 0.0
		# Change state to walk.
		animation_tree["parameters/state/transition_request"] = "walk"
		# Blend position for walk speed based checked motion.
		animation_tree["parameters/walk/blend_position"] = Vector2(motion.length(), 0)


func apply_input(delta: float) -> void:
	# apply_input roda no SERVIDOR (autoritativo) e também na PREDIÇÃO do cliente local. O
	# movimento é previsto nos dois; mas os EFEITOS AUTORITATIVOS (spawnar a bala replicada,
	# disparar os RPCs call_local de tiro/pulo/aterrissagem) só podem rodar no servidor — senão
	# o cliente cria uma bala-fantasma local que nunca se move nem é destruída (fica presa no cano).
	var authoritative: bool = _safe_is_server_call(false)
	motion = motion.lerp(player_input.motion, MOTION_INTERPOLATE_SPEED * delta)

	var camera_basis: Basis = player_input.get_camera_rotation_basis()
	var camera_z: Vector3 = camera_basis.z
	var camera_x: Vector3 = camera_basis.x

	camera_z.y = 0
	camera_z = camera_z.normalized()
	camera_x.y = 0
	camera_x = camera_x.normalized()

	# Jump/in-air logic.
	airborne_time += delta
	if is_on_floor():
		if airborne_time > 0.5 and authoritative:
			land.rpc()
		airborne_time = 0
		_jump_active = false

	var on_air: bool = airborne_time > MIN_AIRBORNE_TIME

	if not on_air and player_input.jumping:
		velocity.y = JUMP_SPEED  # salto previsto localmente (movimento responsivo)
		on_air = true
		_jump_active = true
		# Increase airborne time so next frame on_air is still true
		airborne_time = MIN_AIRBORNE_TIME
		if authoritative:
			jump.rpc()

	player_input.jumping = false

	if on_air:
		_aim_held_time = 0.0  # no ar não há mira: zera o aquecimento de mira
		if velocity.y > 0:
			# Pulo variável: espaço SEGURO até o fim = arco completo (animação e distância
			# máximas). Espaço SOLTO na subida = corta o pulo suavemente, amortecendo a
			# velocidade vertical; a gravidade assume e a animação vira jump_down no ápice.
			if _jump_active and not player_input.jump_held:
				velocity.y *= exp(-JUMP_CUT_DAMPING * delta)
			animate(Animations.JUMP_UP, delta)
		else:
			_jump_active = false  # subida acabou (ápice/queda): nada mais a cortar
			animate(Animations.JUMP_DOWN, delta)
	elif player_input.aiming:
		_aim_held_time += delta  # acumula tempo de mira; o disparo aguarda AIM_WARMUP_TIME
		var q_to: Quaternion = player_input.get_camera_base_quaternion()
		if not _was_aiming:
			# Aim-enter: alinha o corpo À CÂMERA IMEDIATAMENTE (sem slerp). Sem isto, num
			# aim→tiro muito rápido o cano (shoot_from) ainda aponta para a direção antiga e a
			# bala sai torta. Atualiza já o player_model para o shoot_from refletir a mira agora.
			orientation.basis = Basis(q_to)
			player_model.global_transform.basis = orientation.basis
		else:
			# Convert orientation to quaternions for interpolating rotation.
			var q_from: Quaternion = orientation.basis.get_rotation_quaternion()
			# Interpolate current rotation with desired one.
			orientation.basis = Basis(q_from.slerp(q_to, delta * ROTATION_INTERPOLATE_SPEED))

		# Change state to strafe.
		animate(Animations.STRAFE, delta)

		root_motion = Transform3D(animation_tree.get_root_motion_rotation(), animation_tree.get_root_motion_position())

		# Disparo é SERVER-AUTORITATIVO: só o servidor spawna a bala (replicada a todos via
		# MultiplayerSpawner) e dispara o RPC do efeito de tiro. No cliente isso é pulado — senão
		# nasceria uma bala local sem física nem replicação, presa no cano (efeito que "não some").
		# Aguarda o aquecimento de mira (AIM_WARMUP_TIME): o tiro sai só DEPOIS de a animação
		# de mira assentar e o cano estar alinhado — corrige o glitch do cliente (bala antes
		# da mira / fora do cano). Vale p/ host, cliente e bots (todos passam por aqui).
		if authoritative and player_input.shooting and fire_cooldown.time_left == 0 \
				and _aim_held_time >= AIM_WARMUP_TIME:
			var shoot_origin: Vector3 = shoot_from.global_transform.origin
			var to_target: Vector3 = player_input.shoot_target - shoot_origin
			# Guarda contra alvo degenerado (perto/atrás do cano, ex.: shoot_target ainda em
			# 0,0,0 ou um acerto colado): em vez de uma direção absurda (tiro vertical), usa a
			# direção que o modelo encara. A correção principal está na mira (player_input).
			var shoot_dir: Vector3 = -player_model.global_transform.basis.z
			if to_target.length() > 0.5:
				shoot_dir = to_target.normalized()

			# Reusable cannon shooter spawns + configures the bullet (default blue look)
			# and excludes the shooter's own body/limb colliders.
			CannonShooter.fire(get_parent(), shoot_origin, shoot_dir, weapon_damage, self)
			if bot_controlled and ai != null and ai.has_method(&"note_shot_fired"):
				var target_speed := 0.0
				if ai.has_method(&"current_target_speed"):
					target_speed = float(ai.current_target_speed())
				ai.note_shot_fired(shoot_origin.distance_to(player_input.shoot_target),
					target_speed)
			shoot.rpc()

	else: # Not in air or aiming, idle.
		_aim_held_time = 0.0  # saiu da mira: zera o aquecimento
		# Convert orientation to quaternions for interpolating rotation.
		var target: Vector3 = camera_x * motion.x + camera_z * motion.y
		if target.length() > 0.001:
			var q_from: Quaternion = orientation.basis.get_rotation_quaternion()
			var q_to: Quaternion = Basis.looking_at(target).get_rotation_quaternion()
			# Interpolate current rotation with desired one.
			orientation.basis = Basis(q_from.slerp(q_to, delta * ROTATION_INTERPOLATE_SPEED))

		animate(Animations.WALK, delta)

		root_motion = Transform3D(animation_tree.get_root_motion_rotation(), animation_tree.get_root_motion_position())

	# Apply root motion to orientation.
	orientation *= root_motion

	var h_velocity: Vector3 = orientation.origin / delta
	velocity.x = h_velocity.x
	velocity.z = h_velocity.z
	velocity += get_gravity() * delta
	set_velocity(velocity)
	set_up_direction(Vector3.UP)
	move_and_slide()

	orientation.origin = Vector3() # Clear accumulated root motion displacement (was applied to speed).
	orientation = orientation.orthonormalized() # Orthonormalize orientation.

	player_model.global_transform.basis = orientation.basis

	# If we're below -40, respawn (teleport to the initial position).
	if transform.origin.y < -40.0:
		transform.origin = initial_position
		reset_physics_interpolation()  # teleporte: evita o rasgo de interpolação até o respawn

	# Estado da mira p/ o próximo frame (detecção do aim-enter, ver branch de mira acima).
	_was_aiming = player_input.aiming


@rpc("call_local")
func jump() -> void:
	animate(Animations.JUMP_UP, 0.0)
	sound_effect_jump.play()


@rpc("call_local")
func land() -> void:
	animate(Animations.JUMP_DOWN, 0.0)
	sound_effect_land.play()


@rpc("call_local")
func shoot() -> void:
	var shoot_particle = $PlayerModel/Robot_Skeleton/Skeleton3D/GunBone/ShootFrom/ShootParticle
	shoot_particle.restart()
	shoot_particle.emitting = true
	var muzzle_particle = $PlayerModel/Robot_Skeleton/Skeleton3D/GunBone/ShootFrom/MuzzleFlash
	muzzle_particle.restart()
	muzzle_particle.emitting = true
	fire_cooldown.start()
	sound_effect_shoot.play()
	if not bot_controlled:
		add_camera_shake_trauma(0.35)


@rpc("call_local")
func hit(amount: int = 25) -> void:
	hp = maxi(hp - amount, 0)
	if _health_bar:
		_health_bar.update_health(hp, MAX_HP)
	if hp <= 0 and _safe_is_server_call(false):
		respawn.rpc()
	if not bot_controlled:
		add_camera_shake_trauma(0.75)


@rpc("call_local")
func respawn() -> void:
	hp = MAX_HP
	if _health_bar:
		_health_bar.update_health(hp, MAX_HP)
	transform.origin = initial_position
	reset_physics_interpolation()  # teleporte de respawn: evita o rasgo de interpolação


@rpc("call_local")
func add_camera_shake_trauma(amount: float) -> void:
	player_input.camera_camera.add_trauma(amount)


func notify_projectile_feedback(hit_target: Node) -> void:
	if not bot_controlled or ai == null or not ai.has_method(&"report_shot_result"):
		return
	ai.report_shot_result(hit_target != null and hit_target.has_method(&"show_health_hud"))

extends CharacterBody3D


signal exploded()

enum State {
	APPROACH = 0,
	AIM = 1,
	SHOOTING = 2,
}

const PLAYER_AIM_TOLERANCE_DEGREES = deg_to_rad(15.0)

const SHOOT_WAIT: float = 6.0
const AIM_TIME: float = 1.0

const AIM_PREPARE_TIME: float = 0.5
const BLEND_AIM_SPEED: float = 0.05

# Aparência da bala de canhão do red_robot (CannonShooter): bola PRETA grande (calibre) com
# rastro/flash VERMELHO — o mesmo bullet do player, recolorido.
const BULLET_TINT := Color(1.0, 0.12, 0.12)            # cor do efeito (luz + rastro)
const BULLET_BALL_COLOR := Color(0.03, 0.03, 0.03, 1)  # bola preta
const BULLET_BALL_SCALE := 2.5                         # tamanho do calibre

@export var test_shoot: bool = false

# Camada das hitboxes do player (bit5 = 16) — alvo do laser do enemy.
const PLAYER_HITBOX_LAYER: int = 16

@export var enemy_name: String = "Red Robot"
@export var max_health: int = 200

## Dano-base do laser do enemy por acerto em MEMBRO do player (cabeça aplica
## +50% via multiplicador 1.5 da hitbox). Só há dano se acertar um membro.
@export var weapon_damage: int = 10
## Precisão de mira: 1.0 = 100% (acerta sempre que dispara).
@export_range(0.0, 1.0) var aim_accuracy: float = 1.0
## Só dispara quando o player estiver dentro deste alcance (mira precisa).
@export var effective_range: float = 30.0

@export var target_position := Vector3()
@export var health: int = 200
@export var state: State = State.APPROACH
@export var dead: bool = false
@export var aim_preparing: float = AIM_PREPARE_TIME

var shoot_countdown: float = SHOOT_WAIT
var aim_countdown: float = AIM_TIME

var player: Node3D = null
var orientation := Transform3D()

# Controlador de IA (comportamentos/decisões), instanciado em _ready a partir de IA/.
var ai: RedRobotAI = null
# Recarga efetiva entre tiros, já acelerada pela IA (SHOOT_WAIT / fire_rate_multiplier).
var shoot_reload: float = SHOOT_WAIT

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var shoot_animation: AnimationPlayer = $ShootAnimation

@onready var model: Node3D = $RedRobotModel
# Muzzle of the cannon (the bullet is fired from here, along its -Z).
@onready var ray_from: BoneAttachment3D = model.get_node(^"Armature/Skeleton3D/RayFrom")
@onready var ray_mesh: MeshInstance3D = ray_from.get_node(^"RayMesh")
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

@onready var explosion_sound: AudioStreamPlayer3D = $SoundEffects/Explosion
@onready var hit_sound: AudioStreamPlayer3D = $SoundEffects/Hit

@onready var death: Node3D = $Death
@onready var death_shield1: RigidBody3D = death.get_node(^"PartShield1")
@onready var death_shield2: RigidBody3D = death.get_node(^"PartShield2")
@onready var death_head: RigidBody3D = death.get_node(^"PartHead")
@onready var death_detach_spark1: CPUParticles3D = death.get_node(^"DetachSpark1")
@onready var death_detach_spark2: CPUParticles3D = death.get_node(^"DetachSpark2")


func _ready() -> void:
	orientation = global_transform
	orientation.origin = Vector3()
	$AnimationTree.active = true

	# IA do red_robot: instancia o controlador de comportamento/decisões (pasta IA/) e
	# aplica a recarga acelerada (1.5x mais rápida no 1º e nos próximos tiros).
	ai = preload("res://library3D/characters/red_robot/IA/red_robot_ai.gd").new()
	ai.name = "IA"
	add_child(ai)
	shoot_reload = ai.reload_time(SHOOT_WAIT)
	shoot_countdown = shoot_reload

	if test_shoot:
		shoot_countdown = 0.0

	# Sem mais laser: o tiro agora é uma bala de canhão. Esconde o feixe do laser e suas
	# faíscas para que nada do antigo raio apareça.
	ray_mesh.visible = false
	var laser_ember := ray_from.get_node_or_null(^"LaserEmber")
	if laser_ember is CPUParticles3D:
		(laser_ember as CPUParticles3D).emitting = false

	if dead:
		model.visible = false
		collision_shape.disabled = true
		animation_tree.active = false

	animate(0.0)

	# Colliders 3D de membro (dano localizado); o projétil colide fisicamente.
	if not dead:
		_setup_limb_colliders.call_deferred()


func _setup_limb_colliders() -> void:
	if has_node(^"LimbColliders"):
		return
	var skel := model.get_node_or_null(^"Armature/Skeleton3D") as Skeleton3D
	if skel == null:
		return
	var lc = preload("res://effects_shared/limb_colliders.gd").new()
	lc.name = "LimbColliders"
	lc.body_type = "biped"      # plano corporal → classificador de membros
	lc.model_key = "red_robot"  # busca os multiplicadores de dano e os sub-membros em LimbConfig
	lc.hitbox_layer = 32        # bit6 = colliders de membro do enemy
	# A CABEÇA cobre o painel do rosto ("mouth_eyes") + os olhos ("L-EYE"/"R-EYE"). Sem os
	# olhos (excluídos pela palavra "eye") a cabeça ficaria minúscula (~42 vértices só do
	# painel) — esta hitbox vale para o headshot em jogo e para o gizmo do model browser.
	lc.head_bone_names = (["mouth_eyes", "L-EYE", "R-EYE"] as Array[String])
	# O corpo do red_robot é o osso genérico "Bone.001", que o classificador não
	# reconhece — sem isto ele ficaria sem collider de TRONCO (só a cabeça).
	lc.torso_bone_names = (["Bone.001"] as Array[String])
	# Os sub-membros (placas traseiras das pernas "L-/R-RearLegGuard") agora vêm de
	# LimbConfig (res://data/limb_config.json) — editáveis na tela Models. Ver build_for.
	add_child(lc)
	lc.build_for(skel)


func resume_approach() -> void:
	state = State.APPROACH
	aim_preparing = AIM_PREPARE_TIME
	shoot_countdown = shoot_reload


@rpc("call_local")
func hit(amount: int = 50) -> void:
	if dead:
		return
	var param = "parameters/hit" + str(randi() % 3 + 1) + "/request"
	animation_tree[param] = 1
	hit_sound.play()
	health = maxi(health - amount, 0)
	show_health_hud()
	if health <= 0:
		dead = true
		animation_tree.active = false
		model.visible = false
		death.visible = true
		collision_shape.disabled = true

		death_detach_spark1.emitting = true
		death_detach_spark2.emitting = true

		death_shield1.explode()
		death_shield2.explode()
		death_head.explode()

		explosion_sound.play()
		exploded.emit()
		hide_health_hud()

		if multiplayer.is_server():
			await get_tree().create_timer(10.0).timeout
			queue_free()


# Atualiza o HUD compartilhado de vida do inimigo (apenas em clientes com tela).
# Público: chamado por hit() e pela mira do player (player_input.gd).
# `distance` (m) é exibida ao lado do nome; -1 oculta a distância.
func show_health_hud(distance: float = -1.0) -> void:
	if dead:
		return
	if DisplayServer.get_name() == "headless":
		return
	var hud = preload("res://library3D/characters/enemies/enemy_health_bar.gd").get_shared(get_tree().current_scene)
	# red_robot possui arma de tiro: informa o alcance efetivo (m) para o HUD exibi-lo.
	hud.show_enemy(enemy_name, maxi(health, 0), max_health, distance, effective_range)


# Público: chamado na morte e quando a mira do player sai do inimigo.
func hide_health_hud() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var hud = preload("res://library3D/characters/enemies/enemy_health_bar.gd").get_shared(get_tree().current_scene)
	hud.hide_now()


# Dispara uma BALA DE CANHÃO (preta, com rastro/flash vermelho) pelo cano, via o
# componente reutilizável CannonShooter (mesmo bullet do player, recolorido). A bala voa
# e aplica DANO LOCALIZADO ao acertar os colliders de membro do player (LimbColliders);
# não há mais raio hitscan. O servidor dispara; clientes recebem a bala replicada.
func shoot() -> void:
	if not multiplayer.is_server():
		return
	var origin: Vector3 = ray_from.global_transform.origin
	var dir: Vector3 = -ray_from.global_transform.basis.z
	if is_instance_valid(player):
		dir = ((player.global_transform.origin + Vector3.UP) - origin).normalized()
		# Precisão de mira: com accuracy < 1, adiciona dispersão (pode errar).
		if aim_accuracy < 1.0:
			var spread := (1.0 - aim_accuracy) * 0.15
			dir = (dir + Vector3(randf_range(-spread, spread), randf_range(-spread, spread),
				randf_range(-spread, spread))).normalized()
	CannonShooter.fire(get_parent(), origin, dir, weapon_damage, self,
		BULLET_TINT, BULLET_BALL_COLOR, BULLET_BALL_SCALE)


func animate(delta: float) -> void:
	if state == State.APPROACH:
		var to_player_local: Vector3 = target_position * global_transform
		# The front of the robot is +Z, and atan2 is zero at +X, so we need to use the Z for the X parameter (second one).
		var angle_to_player: float = atan2(to_player_local.x, to_player_local.z)
		if angle_to_player > PLAYER_AIM_TOLERANCE_DEGREES:
			animation_tree["parameters/state/transition_request"] = "turn_left"
		elif angle_to_player < -PLAYER_AIM_TOLERANCE_DEGREES:
			animation_tree["parameters/state/transition_request"] = "turn_right"
		elif target_position == Vector3.ZERO:
			animation_tree["parameters/state/transition_request"] = "idle"
		else:
			animation_tree["parameters/state/transition_request"] = "walk"
	else:
		animation_tree["parameters/state/transition_request"] = "idle"

	# Aiming or shooting
	if target_position != Vector3.ZERO:
		animation_tree["parameters/aiming/blend_amount"] = clamp(aim_preparing / AIM_PREPARE_TIME, 0, 1)

		var to_cannon_local: Vector3 = (target_position + Vector3.UP) * ray_mesh.global_transform
		var h_angle: float = rad_to_deg(atan2( to_cannon_local.x, -to_cannon_local.z))
		var v_angle: float = rad_to_deg(atan2( to_cannon_local.y, -to_cannon_local.z))
		var blend_pos: Vector2 = animation_tree.get("parameters/aim/blend_position")
		var h_motion: float = BLEND_AIM_SPEED * delta * -h_angle
		blend_pos.x += h_motion
		blend_pos.x = clampf(blend_pos.x, -1.0, 1.0)

		var v_motion: float = BLEND_AIM_SPEED * delta * v_angle
		blend_pos.y += v_motion
		blend_pos.y = clampf(blend_pos.y, -1.0, 1.0)

		animation_tree["parameters/aim/blend_position"] = blend_pos


func _physics_process(delta: float) -> void:
	if dead:
		return

	if not multiplayer.is_server():
		animate(delta)
		return

	if test_shoot:
		shoot()
		test_shoot = false

	if not player:
		target_position = Vector3()
		animate(delta)
		set_velocity(get_gravity() * delta)
		set_up_direction(Vector3.UP)
		move_and_slide()
		return

	target_position = player.global_transform.origin

	# Decisão da IA neste quadro a partir da distância ao player e do alcance da arma.
	# FLEE: player perto demais (<= flee_distance) → corre no sentido oposto, olhando p/ ele.
	# O tiro continua acontecendo via a lógica abaixo (player está dentro do alcance).
	var dist_to_player: float = global_transform.origin.distance_to(player.global_transform.origin)
	var fleeing: bool = ai.decide(dist_to_player, effective_range) == RedRobotAI.Action.FLEE

	if state == State.APPROACH:
		if aim_preparing > 0:
			aim_preparing -= delta
			if aim_preparing < 0:
				aim_preparing = 0

		var to_player_local: Vector3 = target_position * global_transform
		# The front of the robot is +Z, and atan2 is zero at +X, so we need to use the Z for the X parameter (second one).
		var angle_to_player: float = atan2(to_player_local.x, to_player_local.z)
		if angle_to_player > -PLAYER_AIM_TOLERANCE_DEGREES and angle_to_player < PLAYER_AIM_TOLERANCE_DEGREES:
			# Facing player, try to shoot.
			shoot_countdown -= delta
			if shoot_countdown < 0.0:
				var ray_origin = ray_from.global_transform.origin
				# Só dispara quando a mira é precisa (player dentro do alcance efetivo).
				if ray_origin.distance_to(player.global_transform.origin) > effective_range:
					# Muito longe — aguarda aproximar antes de mirar.
					shoot_countdown = 0.0
				else:
					# See if player can be killed because in they're sight.
					var ray_to = player.global_transform.origin + Vector3.UP # Above middle of player.
					var col = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(ray_origin, ray_to, 0xFFFFFFFF, [self]))

					if not col.is_empty() and col.collider == player:
						state = State.AIM
						aim_countdown = AIM_TIME
						aim_preparing = 0.0
					else:
						# Player not in sight, do nothing.
						shoot_countdown = shoot_reload

	elif state == State.AIM or state == State.SHOOTING:
		if aim_preparing < AIM_PREPARE_TIME:
			aim_preparing += delta
			if aim_preparing > AIM_PREPARE_TIME:
				aim_preparing = AIM_PREPARE_TIME

		aim_countdown -= delta
		if aim_countdown < 0.0 and state == State.AIM:
			var ray_origin: Vector3 = ray_from.global_transform.origin
			var ray_to: Vector3 = target_position + Vector3.UP
			var col: Dictionary = get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(ray_origin, ray_to, 0xFFFFFFFF, [self]))
			if not col.is_empty() and col.collider == player:
				state = State.SHOOTING
				shoot_countdown = shoot_reload
				play_shoot.rpc()
			else:
				resume_approach()

	animate(delta)
	if fleeing:
		# Recuo: pernas correndo (walk) enquanto o corpo encara o player e desliza para
		# longe. Sobrepõe o root motion deste quadro com a velocidade de fuga.
		animation_tree["parameters/state/transition_request"] = "walk"
		_flee_movement()
	else:
		# Apply root motion to orientation.
		orientation *= Transform3D(animation_tree.get_root_motion_rotation(), animation_tree.get_root_motion_position())
		var h_velocity: Vector3 = orientation.origin / delta
		velocity.x = h_velocity.x
		velocity.z = h_velocity.z

	velocity += get_gravity() * delta
	set_velocity(velocity)
	set_up_direction(Vector3.UP)
	move_and_slide()

	orientation.origin = Vector3() # Clear accumulated root motion displacement (was applied to speed).
	orientation = orientation.orthonormalized() # orthonormalize orientation.

	global_transform.basis = orientation.basis


# Recuo (IA → Action.FLEE): orienta o corpo para ENCARAR o player (frente do robô é +Z) e
# define a velocidade horizontal no sentido OPOSTO, fazendo-o correr para longe sem deixar
# de olhar/mirar no player. O canhão segue mirando via o blend de "aim" em animate().
func _flee_movement() -> void:
	var to_player: Vector3 = player.global_transform.origin - global_transform.origin
	to_player.y = 0.0
	if to_player.length() < 0.001:
		return
	var fwd: Vector3 = to_player.normalized()             # frente (+Z) aponta para o player
	var x_axis: Vector3 = Vector3.UP.cross(fwd).normalized()
	var y_axis: Vector3 = fwd.cross(x_axis).normalized()
	orientation.basis = Basis(x_axis, y_axis, fwd)
	var away: Vector3 = -fwd                              # corre no sentido oposto ao player
	velocity.x = away.x * ai.flee_speed
	velocity.z = away.z * ai.flee_speed


@rpc("call_local")
func play_shoot() -> void:
	shoot_animation.play(&"shoot")


func shoot_check() -> void:
	test_shoot = true


func _on_area_body_entered(body: Node3D) -> void:
	if body is Player or body.name == "Target":
		player = body


func _on_area_body_exited(body: Node3D) -> void:
	if body is Player:
		player = null

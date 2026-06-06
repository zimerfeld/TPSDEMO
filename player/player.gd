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

const MIN_AIRBORNE_TIME: float = 0.1
const JUMP_SPEED: float = 5.0

var airborne_time: float = 100.0

var orientation := Transform3D()
var root_motion := Transform3D()
var motion := Vector2()

@onready var initial_position: Vector3 = transform.origin

@onready var player_input: PlayerInputSynchronizer = $InputSynchronizer
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var player_model: Node3D = $PlayerModel
@onready var shoot_from: Marker3D = player_model.get_node(^"Robot_Skeleton/Skeleton3D/GunBone/ShootFrom")
@onready var crosshair: TextureRect = $Crosshair
@onready var fire_cooldown: Timer = $FireCooldown

@onready var sound_effects: Node = $SoundEffects
@onready var sound_effect_jump: AudioStreamPlayer = sound_effects.get_node(^"Jump")
@onready var sound_effect_land: AudioStreamPlayer = sound_effects.get_node(^"Land")
@onready var sound_effect_shoot: AudioStreamPlayer = sound_effects.get_node(^"Shoot")

@export var player_id: int = 1:
	set(value):
		player_id = value
		$InputSynchronizer.set_multiplayer_authority(value)
		# Garante o HUD do player local em toda cena de level, inclusive quando
		# player_id chega via replicação depois do _ready (cliente multiplayer).
		_setup_health_bar.call_deferred()

@export var current_animation := Animations.WALK

const MAX_HP: int = 100
var hp: int = MAX_HP

## Dano da arma que o player porta (atribuído a cada bullet disparado).
@export var weapon_damage: int = 50

@export_group("Glass Hitboxes")
@export var hitbox_color: Color = Color(0.45, 0.8, 1.0, 0.22)
@export var hitbox_radius: float = 0.1
@export var hitbox_radius_factor: float = 0.4
@export var hitbox_max_radius: float = 0.22
@export var hitbox_head_radius: float = 0.16

var _health_bar = null


func _ready() -> void:
	# Pre-initialize orientation transform.
	orientation = player_model.global_transform
	orientation.origin = Vector3()
	if not multiplayer.is_server():
		set_process(false)
	# Cria o HUD de vida do player local sempre que um level carrega.
	# Deferido para garantir que player_id/authority já foi replicado em multiplayer.
	_setup_health_bar.call_deferred()
	# Hitboxes de vidro por membro (visual + dano localizado).
	# Construídas também no servidor (as áreas detectam tiros); o mesh é pulado em headless.
	_setup_glass_hitboxes.call_deferred()


func _setup_health_bar() -> void:
	# Idempotente: pode ser chamado pelo _ready e pelo setter de player_id.
	if _health_bar != null:
		return
	if not is_inside_tree():
		return
	# Mostra o HUD apenas para o player controlado localmente.
	# Usa $InputSynchronizer (não o onready) pois o setter pode rodar antes do _ready.
	if $InputSynchronizer.get_multiplayer_authority() != multiplayer.get_unique_id():
		return
	_health_bar = preload("res://player/health_bar.gd").new()
	_health_bar.name = "HealthBar"
	add_child(_health_bar)
	_health_bar.update_health(hp, MAX_HP)


func _setup_glass_hitboxes() -> void:
	if has_node(^"GlassHitboxes"):
		return
	var skel := player_model.get_node_or_null(^"Robot_Skeleton/Skeleton3D") as Skeleton3D
	if skel == null:
		return
	var gh = preload("res://effects_shared/glass_hitboxes.gd").new()
	gh.name = "GlassHitboxes"
	gh.hitbox_layer = 16        # bit5 = hitboxes do player
	gh.detect_layer = 8         # bit4 = projétil (bullet)
	gh.glass_color = hitbox_color
	gh.radius = hitbox_radius
	gh.radius_factor = hitbox_radius_factor
	gh.max_radius = hitbox_max_radius
	gh.head_radius = hitbox_head_radius
	add_child(gh)
	gh.build_for(skel)


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		apply_input(delta)
	else:
		animate(current_animation, delta)


func animate(anim: int, _delta: float) -> void:
	current_animation = anim as Animations

	if anim == Animations.JUMP_UP:
		animation_tree["parameters/state/transition_request"] = "jump_up"

	elif anim == Animations.JUMP_DOWN:
		animation_tree["parameters/state/transition_request"] = "jump_down"

	elif anim == Animations.STRAFE:
		animation_tree["parameters/state/transition_request"] = "strafe"
		# Change aim according to camera rotation.
		animation_tree["parameters/aim/add_amount"] = player_input.get_aim_rotation()
		# The animation's forward/backward axis is reversed.
		animation_tree["parameters/strafe/blend_position"] = Vector2(motion.x, -motion.y)

	elif anim == Animations.WALK:
		# Aim to zero (no aiming while walking).
		animation_tree["parameters/aim/add_amount"] = 0
		# Change state to walk.
		animation_tree["parameters/state/transition_request"] = "walk"
		# Blend position for walk speed based checked motion.
		animation_tree["parameters/walk/blend_position"] = Vector2(motion.length(), 0)


func apply_input(delta: float) -> void:
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
		if airborne_time > 0.5:
			land.rpc()
		airborne_time = 0

	var on_air: bool = airborne_time > MIN_AIRBORNE_TIME

	if not on_air and player_input.jumping:
		velocity.y = JUMP_SPEED
		on_air = true
		# Increase airborne time so next frame on_air is still true
		airborne_time = MIN_AIRBORNE_TIME
		jump.rpc()

	player_input.jumping = false

	if on_air:
		if velocity.y > 0:
			animate(Animations.JUMP_UP, delta)
		else:
			animate(Animations.JUMP_DOWN, delta)
	elif player_input.aiming:
		# Convert orientation to quaternions for interpolating rotation.
		var q_from: Quaternion = orientation.basis.get_rotation_quaternion()
		var q_to: Quaternion = player_input.get_camera_base_quaternion()
		# Interpolate current rotation with desired one.
		orientation.basis = Basis(q_from.slerp(q_to, delta * ROTATION_INTERPOLATE_SPEED))

		# Change state to strafe.
		animate(Animations.STRAFE, delta)

		root_motion = Transform3D(animation_tree.get_root_motion_rotation(), animation_tree.get_root_motion_position())

		if player_input.shooting and fire_cooldown.time_left == 0:
			var shoot_origin: Vector3 = shoot_from.global_transform.origin
			var shoot_dir: Vector3 = (player_input.shoot_target - shoot_origin).normalized()

			var bullet: CharacterBody3D = preload("res://player/bullet/bullet.tscn").instantiate()
			bullet.weapon_damage = weapon_damage
			bullet.shooter = self
			get_parent().add_child(bullet, true)
			bullet.global_transform.origin = shoot_origin
			# If we don't rotate the bullets there is no useful way to control the particles ..
			bullet.look_at(shoot_origin + shoot_dir)
			bullet.add_collision_exception_with(self)
			shoot.rpc()

	else: # Not in air or aiming, idle.
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
	add_camera_shake_trauma(0.35)


@rpc("call_local")
func hit(amount: int = 25) -> void:
	hp = maxi(hp - amount, 0)
	if _health_bar:
		_health_bar.update_health(hp, MAX_HP)
	if hp <= 0 and multiplayer.is_server():
		respawn.rpc()
	add_camera_shake_trauma(0.75)


@rpc("call_local")
func respawn() -> void:
	hp = MAX_HP
	if _health_bar:
		_health_bar.update_health(hp, MAX_HP)
	transform.origin = initial_position


@rpc("call_local")
func add_camera_shake_trauma(amount: float) -> void:
	player_input.camera_camera.add_trauma(amount)

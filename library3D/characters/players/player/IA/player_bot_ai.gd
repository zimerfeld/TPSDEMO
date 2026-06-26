class_name PlayerBotAI
extends Node

const AIConfigLib := preload("res://effects_shared/ai_config.gd")

const MODEL_KEY := "player"
const BEHAVIOR_ALLY_FOLLOW := "ally_follow"
const BEHAVIOR_ENEMY_PRIORITIZATION := "enemy_prioritization"
const BEHAVIOR_PREDICTIVE_ASSIST_AIM := "predictive_assist_aim"
const BEHAVIOR_COMBAT_SPACING := "combat_spacing"
const BEHAVIOR_FRIENDLY_FIRE_GUARD := "friendly_fire_guard"
const BEHAVIOR_PRESSURE_FLANK := "pressure_flank"

@export var follow_distance := 5.5
@export var preferred_combat_distance := 18.0
@export var combat_band := 4.5
@export var weapon_range := 52.0
@export var bullet_speed := 20.0
@export var lead_strength := 0.82
@export var flank_duration := 1.1
@export var scan_interval := 0.35
## Só engaja inimigos a até esta distância (m) do próprio bot — evita perseguir ameaças do
## outro lado do mapa e abandonar a cobertura do player.
@export var engage_range := 32.0
## Também engaja inimigos a até esta distância (m) do player humano (para defendê-lo).
@export var player_threat_radius := 24.0
## Coleira de cobertura: a partir desta distância (m) do player o bot já é puxado de volta
## durante o combate, para lutar ao lado do player em vez de derivar atrás do inimigo.
@export var soft_leash := 14.0
## Distância (m) máxima do player: além disto, reagrupar tem prioridade sobre perseguir.
## É o que impede o aliado de "correr sem parar até cair do mapa".
@export var max_leash := 20.0

var _behaviors: Dictionary = {}
var _target: Node3D = null
var _anchor: Node3D = null
var _scan_cd := 0.0
var _flank_sign := 1.0
var _flank_time := 0.0
var _pending_shots: Array[Dictionary] = []
var _bucket_stats: Dictionary = {}
var _miss_streak := 0


func _ready() -> void:
	reload_config()


func reload_config() -> void:
	_behaviors = AIConfigLib.behaviors(MODEL_KEY)


func behavior_enabled(key: String) -> bool:
	if _behaviors.is_empty():
		reload_config()
	return bool(_behaviors.get(key, false))


func update_input(bot: CharacterBody3D, input: PlayerInputSynchronizer, delta: float) -> void:
	if bot == null or input == null or not bot.is_inside_tree():
		return
	_scan_cd -= delta
	_flank_time = maxf(0.0, _flank_time - delta)
	if _scan_cd <= 0.0:
		_scan_cd = scan_interval
		var scope: Node = bot.get_parent()
		if scope == null:
			scope = bot.get_tree().current_scene
		_target = _find_enemy(scope, bot.global_position)
		_anchor = _find_human_ally(scope, bot)
	var bot_pos := bot.global_position
	var has_anchor := behavior_enabled(BEHAVIOR_ALLY_FOLLOW) and _is_valid_anchor(_anchor)
	var anchor_pos := _anchor.global_position if has_anchor else bot_pos
	var move_dir := Vector3.ZERO
	var aim_point := Vector3.ZERO
	var should_aim := false
	var should_shoot := false
	# Cobertura: se o bot se afastou demais do player, reagrupar tem prioridade sobre perseguir.
	# É isto que impede o aliado de correr atrás de um inimigo até cair do mapa.
	var must_regroup := has_anchor and bot_pos.distance_to(anchor_pos) > max_leash
	# Só engaja ameaças perto do bot OU perto do player (defendê-lo) — nunca do outro lado do mapa.
	var engage := false
	if behavior_enabled(BEHAVIOR_ENEMY_PRIORITIZATION) and _is_valid_enemy(_target) and not must_regroup:
		var enemy_pos: Vector3 = _target.global_position
		var near_bot := bot_pos.distance_to(enemy_pos) <= engage_range
		var threatens_anchor := has_anchor and anchor_pos.distance_to(enemy_pos) <= player_threat_radius
		engage = near_bot or threatens_anchor
	if engage:
		var target_pos := _target.global_position + Vector3.UP
		var target_velocity := _velocity_of(_target)
		aim_point = _compute_aim_point(bot_pos + Vector3.UP, target_pos, target_velocity)
		move_dir = _combat_move(bot_pos, _target.global_position, anchor_pos, has_anchor)
		should_aim = true
		should_shoot = bot_pos.distance_to(_target.global_position) <= weapon_range \
			and _has_line_of_fire(bot, aim_point)
	elif has_anchor:
		# Sem ameaça engajável: dá cobertura ao player (segue e mantém-se por perto).
		move_dir = _follow_move(bot_pos, anchor_pos)
		# Guarda virada para o inimigo mais próximo, se houver; senão, para onde anda.
		if _is_valid_enemy(_target):
			aim_point = _target.global_position + Vector3.UP
		else:
			aim_point = bot_pos + _flat_or_forward(move_dir, -bot.global_transform.basis.z) * 20.0 + Vector3.UP
	input.motion = _world_dir_to_motion(input, move_dir)
	input.aiming = should_aim
	input.shooting = should_shoot
	input.shoot_target = aim_point
	input.jumping = false
	if should_aim:
		_face_point(input, bot_pos + Vector3.UP, aim_point)
	elif move_dir.length() > 0.01:
		_face_point(input, bot_pos + Vector3.UP, bot_pos + move_dir + Vector3.UP)


func note_shot_fired(distance: float, target_speed: float) -> void:
	_pending_shots.append({
		"bucket": _bucket_key(distance, target_speed),
	})


func current_target_speed() -> float:
	return _velocity_of(_target).length() if _is_valid_enemy(_target) else 0.0


func report_shot_result(hit_target: bool) -> void:
	if not _pending_shots.is_empty():
		var shot: Dictionary = _pending_shots.pop_front()
		var bucket := str(shot.get("bucket", "mid:moving"))
		var stats := _stats_for_bucket(bucket)
		stats["samples"] = int(stats.get("samples", 0)) + 1
		if hit_target:
			stats["hits"] = int(stats.get("hits", 0)) + 1
		_bucket_stats[bucket] = stats
	if hit_target:
		_miss_streak = 0
		return
	_miss_streak += 1
	if behavior_enabled(BEHAVIOR_PRESSURE_FLANK) and _miss_streak >= 2:
		_flank_time = flank_duration
		_flank_sign *= -1.0


func _combat_move(origin: Vector3, target_position: Vector3, anchor_position: Vector3, has_anchor: bool) -> Vector3:
	var to_target := target_position - origin
	to_target.y = 0.0
	var distance := to_target.length()
	if distance < 0.01:
		return Vector3.ZERO
	var forward := to_target.normalized()
	var move := Vector3.ZERO
	if behavior_enabled(BEHAVIOR_COMBAT_SPACING):
		if distance > preferred_combat_distance + combat_band:
			move += forward
		elif distance < preferred_combat_distance - combat_band:
			move -= forward
	if behavior_enabled(BEHAVIOR_PRESSURE_FLANK):
		var right := Vector3.UP.cross(forward).normalized()
		var flank_weight := 0.55 if _flank_time > 0.0 else 0.25
		move += right * _flank_sign * flank_weight
	# Coleira de cobertura: ao começar a se afastar do player, o bot é puxado de volta — assim
	# combate ao lado dele em vez de derivar pelo mapa atrás do inimigo (e nunca cai do mapa).
	if has_anchor:
		var to_anchor := anchor_position - origin
		to_anchor.y = 0.0
		var leash := to_anchor.length()
		if leash > soft_leash:
			var pull := clampf((leash - soft_leash) / maxf(max_leash - soft_leash, 0.1), 0.0, 1.0)
			move += to_anchor.normalized() * (0.6 + pull)
	return move.normalized() if move.length() > 0.01 else Vector3.ZERO


func _follow_move(origin: Vector3, anchor_position: Vector3) -> Vector3:
	var to_anchor := anchor_position - origin
	to_anchor.y = 0.0
	if to_anchor.length() <= follow_distance:
		return Vector3.ZERO
	return to_anchor.normalized()


func _compute_aim_point(origin: Vector3, target_position: Vector3, target_velocity: Vector3) -> Vector3:
	if not behavior_enabled(BEHAVIOR_PREDICTIVE_ASSIST_AIM):
		return target_position
	var distance := origin.distance_to(target_position)
	var travel := clampf(distance / maxf(bullet_speed, 0.1), 0.0, 1.6) * lead_strength
	var learned := _learned_lead_adjustment(distance, target_velocity.length())
	return target_position + target_velocity * travel * (1.0 + learned)


func _has_line_of_fire(bot: CharacterBody3D, aim_point: Vector3) -> bool:
	var from := bot.global_position + Vector3.UP
	var exclude: Array[RID] = []
	exclude.append(bot.get_rid())
	var limb_colliders := bot.get_node_or_null(^"LimbColliders")
	if limb_colliders != null and limb_colliders.has_method(&"get_limb_bodies"):
		for limb in limb_colliders.get_limb_bodies():
			if limb is CollisionObject3D:
				exclude.append((limb as CollisionObject3D).get_rid())
	var query := PhysicsRayQueryParameters3D.create(from, aim_point, 0xFFFFFFFF, exclude)
	var hit := bot.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider := hit.get("collider") as Node
	var resolved := _resolve_character(collider)
	if resolved == _target:
		return true
	if behavior_enabled(BEHAVIOR_FRIENDLY_FIRE_GUARD) and _is_ally(resolved):
		return false
	return not behavior_enabled(BEHAVIOR_FRIENDLY_FIRE_GUARD)


func _face_point(input: PlayerInputSynchronizer, from: Vector3, point: Vector3) -> void:
	var to := point - from
	if to.length() < 0.01:
		return
	var flat := Vector3(to.x, 0.0, to.z)
	if flat.length() > 0.01:
		input.camera_base.look_at(input.camera_base.global_position + flat.normalized(), Vector3.UP)
	var flat_len := maxf(flat.length(), 0.01)
	input.camera_rot.rotation.x = clampf(atan2(to.y, flat_len), deg_to_rad(-55.0), deg_to_rad(45.0))


func _world_dir_to_motion(input: PlayerInputSynchronizer, world_dir: Vector3) -> Vector2:
	if world_dir.length() < 0.01:
		return Vector2.ZERO
	var dir := world_dir.normalized()
	var camera_basis := input.get_camera_rotation_basis()
	var camera_z := camera_basis.z
	var camera_x := camera_basis.x
	camera_z.y = 0.0
	camera_x.y = 0.0
	camera_z = camera_z.normalized()
	camera_x = camera_x.normalized()
	return Vector2(clampf(dir.dot(camera_x), -1.0, 1.0), clampf(dir.dot(camera_z), -1.0, 1.0))


func _find_enemy(scope: Node, origin: Vector3) -> Node3D:
	if not behavior_enabled(BEHAVIOR_ENEMY_PRIORITIZATION):
		return null
	var best: Node3D = null
	var best_dist := INF
	for candidate in _collect_nodes(scope):
		if not _is_valid_enemy(candidate):
			continue
		var d := origin.distance_to((candidate as Node3D).global_position)
		if d < best_dist:
			best_dist = d
			best = candidate as Node3D
	return best


func _find_human_ally(scope: Node, bot: Node) -> Node3D:
	for candidate in _collect_nodes(scope):
		if candidate == bot or not _is_ally(candidate):
			continue
		var bot_flag: Variant = candidate.get("bot_controlled")
		if bot_flag is bool and bool(bot_flag):
			continue
		return candidate as Node3D
	return null


func _collect_nodes(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	if root == null:
		return out
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		out.append(node)
		for child in node.get_children():
			stack.append(child)
	return out


func _is_valid_enemy(node: Node) -> bool:
	return node is Node3D and is_instance_valid(node) and node.has_method(&"hit") \
		and node.has_method(&"show_health_hud") and not _is_ally(node)


func _is_valid_anchor(node: Node) -> bool:
	return node is Node3D and is_instance_valid(node) and _is_ally(node)


func _is_ally(node: Node) -> bool:
	return node is Node3D and node.has_method(&"add_camera_shake_trauma") and node.has_method(&"hit")


func _resolve_character(collider: Node) -> Node:
	if collider == null:
		return null
	if collider.has_meta(&"character"):
		return collider.get_meta(&"character") as Node
	return collider


func _velocity_of(node: Node) -> Vector3:
	if node is CharacterBody3D:
		return (node as CharacterBody3D).velocity
	var raw: Variant = node.get("velocity") if node != null else null
	return raw if raw is Vector3 else Vector3.ZERO


func _flat_or_forward(move_dir: Vector3, fallback: Vector3) -> Vector3:
	var dir := move_dir
	dir.y = 0.0
	if dir.length() > 0.01:
		return dir.normalized()
	var fwd := fallback
	fwd.y = 0.0
	return fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD


func _learned_lead_adjustment(distance: float, target_speed: float) -> float:
	var stats := _stats_for_bucket(_bucket_key(distance, target_speed))
	var samples := float(int(stats.get("samples", 0)))
	var hits := float(int(stats.get("hits", 0)))
	var familiarity := clampf(samples / 7.0, 0.0, 1.0)
	var hit_rate := hits / maxf(samples, 1.0)
	return 0.28 * familiarity * clampf(0.55 - hit_rate, 0.0, 0.55)


func _bucket_key(distance: float, target_speed: float) -> String:
	var dist_bucket := "near"
	if distance > 32.0:
		dist_bucket = "far"
	elif distance > 16.0:
		dist_bucket = "mid"
	var speed_bucket := "steady"
	if target_speed > 7.0:
		speed_bucket = "fast"
	elif target_speed > 2.0:
		speed_bucket = "moving"
	return "%s:%s" % [dist_bucket, speed_bucket]


func _stats_for_bucket(bucket: String) -> Dictionary:
	if not _bucket_stats.has(bucket):
		_bucket_stats[bucket] = {"samples": 0, "hits": 0}
	return _bucket_stats[bucket]

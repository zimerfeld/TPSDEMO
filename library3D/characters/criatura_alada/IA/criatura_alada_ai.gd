class_name CriaturaAladaAI
extends Node

const AIConfigLib := preload("res://effects_shared/ai_config.gd")

const MODEL_KEY := "criatura_alada"
const BEHAVIOR_AERIAL_PREDICTIVE_BOMBING := "aerial_predictive_bombing"
const BEHAVIOR_ADAPTIVE_ALTITUDE := "adaptive_altitude"
const BEHAVIOR_REACTIVE_ORBIT := "reactive_orbit"
const BEHAVIOR_VERTICAL_EVASION := "vertical_evasion"
const BEHAVIOR_AIRSPACE_PROBE := "airspace_probe"
const BEHAVIOR_PRESSURE_BOMB_RUN := "pressure_bomb_run"

@export var preferred_altitude_above_target := 14.0
@export var minimum_altitude_above_target := 7.0
@export var altitude_band := 4.0
@export var orbit_radius_min := 7.0
@export var orbit_radius_max := 14.0
@export var airspace_probe_length := 7.0
@export var lead_strength := 0.78
@export var learned_lead_bonus := 0.22
@export var pressure_run_duration := 1.7
@export var vertical_evasion_amplitude := 2.3

var _behaviors: Dictionary = {}
var _orbit_sign := 1.0
var _orbit_switch_cd := 0.0
var _blocked_time := 0.0
var _pressure_time := 0.0
var _miss_streak := 0
var _pending_bombs: Array[Dictionary] = []
var _bucket_stats: Dictionary = {}


func _ready() -> void:
	reload_config()


func reload_config() -> void:
	_behaviors = AIConfigLib.behaviors(MODEL_KEY)


func behavior_enabled(key: String) -> bool:
	if _behaviors.is_empty():
		reload_config()
	return bool(_behaviors.get(key, false))


func tick(delta: float) -> void:
	_orbit_switch_cd = maxf(0.0, _orbit_switch_cd - delta)
	_pressure_time = maxf(0.0, _pressure_time - delta)


func movement_plan(origin: Vector3, target_position: Vector3, base_radius: float,
		base_speed: float, base_altitude: float, bob_time: float,
		space_state: PhysicsDirectSpaceState3D, exclude: Array, delta: float) -> Dictionary:
	tick(delta)
	var to_self := origin - target_position
	to_self.y = 0.0
	var dist := to_self.length()
	var radial := to_self.normalized() if dist > 0.01 else Vector3.BACK
	var desired_radius := _desired_orbit_radius(base_radius, dist)
	_choose_orbit_sign(space_state, origin, radial, exclude, dist)
	var tangent := Vector3(-radial.z, 0.0, radial.x) * _orbit_sign
	var radial_err := dist - desired_radius
	var speed_mult := 1.0 + (0.22 if _pressure_time > 0.0 else 0.0)
	var horiz := tangent * base_speed * speed_mult - radial * clampf(radial_err, -base_speed, base_speed)
	if behavior_enabled(BEHAVIOR_PRESSURE_BOMB_RUN) and _pressure_time > 0.0:
		horiz += -radial * base_speed * 0.28
	var altitude := _desired_altitude(target_position.y, base_altitude, bob_time)
	var vertical_bias := _vertical_space_bias(space_state, origin, exclude)
	return {
		"horiz": horiz,
		"altitude": altitude + vertical_bias,
		"bank_boost": 1.18 if _pressure_time > 0.0 else 1.0,
	}


func compute_bomb_velocity(origin: Vector3, target_position: Vector3, target_velocity: Vector3,
		gravity: float, lead_max: float) -> Vector3:
	var height := maxf(origin.y - target_position.y, 1.0)
	var fall_time := sqrt(2.0 * height / maxf(gravity, 0.1))
	var lead_scale := 0.0
	if behavior_enabled(BEHAVIOR_AERIAL_PREDICTIVE_BOMBING):
		lead_scale = lead_strength + _learned_lead_adjustment(origin.distance_to(target_position), target_velocity.length())
	var aim := target_position + target_velocity * fall_time * lead_scale
	if behavior_enabled(BEHAVIOR_PRESSURE_BOMB_RUN) and _pressure_time > 0.0:
		aim += target_velocity.normalized() * minf(target_velocity.length() * 0.18, 1.4)
	var disp := aim - origin
	disp.y = 0.0
	return (disp / fall_time).limit_length(lead_max)


func note_bomb_dropped(distance: float, target_speed: float) -> void:
	_pending_bombs.append({
		"bucket": _bucket_key(distance, target_speed),
	})


func report_bomb_result(hit_player: bool) -> void:
	if not _pending_bombs.is_empty():
		var bomb: Dictionary = _pending_bombs.pop_front()
		var bucket := str(bomb.get("bucket", "mid:moving"))
		var stats := _stats_for_bucket(bucket)
		stats["samples"] = int(stats.get("samples", 0)) + 1
		if hit_player:
			stats["hits"] = int(stats.get("hits", 0)) + 1
		_bucket_stats[bucket] = stats
	if hit_player:
		_miss_streak = 0
		return
	_miss_streak += 1
	if behavior_enabled(BEHAVIOR_PRESSURE_BOMB_RUN) and _miss_streak >= 2:
		_trigger_pressure_run()


func _desired_orbit_radius(base_radius: float, current_distance: float) -> float:
	if not behavior_enabled(BEHAVIOR_REACTIVE_ORBIT):
		return base_radius
	var radius := clampf(base_radius, orbit_radius_min, orbit_radius_max)
	if _pressure_time > 0.0:
		radius = maxf(orbit_radius_min, radius - 1.2)
	elif current_distance < base_radius * 0.75:
		radius = minf(orbit_radius_max, radius + 2.0)
	return radius


func _desired_altitude(target_y: float, base_altitude: float, bob_time: float) -> float:
	var altitude := base_altitude
	if behavior_enabled(BEHAVIOR_ADAPTIVE_ALTITUDE):
		altitude = maxf(base_altitude, target_y + preferred_altitude_above_target)
	if behavior_enabled(BEHAVIOR_VERTICAL_EVASION):
		var evasion := sin(bob_time * 1.7 + float(_miss_streak)) * vertical_evasion_amplitude
		if _pressure_time > 0.0:
			evasion -= 1.4
		altitude += evasion
	return maxf(altitude, target_y + minimum_altitude_above_target)


func _choose_orbit_sign(space_state: PhysicsDirectSpaceState3D, origin: Vector3,
		radial: Vector3, exclude: Array, distance: float) -> void:
	if not behavior_enabled(BEHAVIOR_REACTIVE_ORBIT):
		return
	if _orbit_switch_cd > 0.0:
		return
	var right_tangent := Vector3(-radial.z, 0.0, radial.x)
	if not behavior_enabled(BEHAVIOR_AIRSPACE_PROBE):
		_orbit_sign *= -1.0
		_orbit_switch_cd = 2.2
		return
	var right_score := _probe_score(space_state, origin, right_tangent, airspace_probe_length, exclude)
	right_score += 0.55 * _probe_score(space_state, origin, (right_tangent - radial * 0.45).normalized(), airspace_probe_length, exclude)
	var left_tangent := -right_tangent
	var left_score := _probe_score(space_state, origin, left_tangent, airspace_probe_length, exclude)
	left_score += 0.55 * _probe_score(space_state, origin, (left_tangent - radial * 0.45).normalized(), airspace_probe_length, exclude)
	if absf(right_score - left_score) > 0.1:
		_orbit_sign = 1.0 if right_score >= left_score else -1.0
		_orbit_switch_cd = 1.25
	elif distance < orbit_radius_min and _orbit_switch_cd <= 0.0:
		_orbit_sign *= -1.0
		_orbit_switch_cd = 1.8


func _vertical_space_bias(space_state: PhysicsDirectSpaceState3D, origin: Vector3, exclude: Array) -> float:
	if not behavior_enabled(BEHAVIOR_AIRSPACE_PROBE):
		return 0.0
	var up_score := _probe_score(space_state, origin, Vector3.UP, altitude_band, exclude)
	var down_score := _probe_score(space_state, origin, Vector3.DOWN, altitude_band, exclude)
	if up_score < 0.35 and down_score > up_score:
		_note_blocked(0.2)
		return -altitude_band * 0.5
	if down_score < 0.35 and up_score > down_score:
		_note_blocked(0.2)
		return altitude_band * 0.5
	return 0.0


func _note_blocked(amount: float) -> void:
	if not behavior_enabled(BEHAVIOR_PRESSURE_BOMB_RUN):
		return
	_blocked_time += amount
	if _blocked_time >= 0.6:
		_blocked_time = 0.0
		_trigger_pressure_run()


func _trigger_pressure_run() -> void:
	_pressure_time = maxf(_pressure_time, pressure_run_duration)
	_orbit_sign *= -1.0
	_orbit_switch_cd = 0.65


func _probe_score(space_state: PhysicsDirectSpaceState3D, from: Vector3, dir: Vector3,
		length: float, exclude: Array) -> float:
	if dir.length() < 0.001:
		return 0.0
	var to := from + dir.normalized() * maxf(length, 0.1)
	var query := PhysicsRayQueryParameters3D.create(from, to, 0xFFFFFFFF, exclude)
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return 1.0
	_note_blocked(0.08)
	return clampf(from.distance_to(hit.position) / maxf(length, 0.1), 0.0, 1.0)


func _learned_lead_adjustment(distance: float, target_speed: float) -> float:
	var stats := _stats_for_bucket(_bucket_key(distance, target_speed))
	var samples := float(int(stats.get("samples", 0)))
	var hits := float(int(stats.get("hits", 0)))
	var familiarity := clampf(samples / 6.0, 0.0, 1.0)
	var hit_rate := hits / maxf(samples, 1.0)
	return learned_lead_bonus * familiarity * clampf(0.55 - hit_rate, 0.0, 0.55)


func _bucket_key(distance: float, target_speed: float) -> String:
	var dist_bucket := "near"
	if distance > 28.0:
		dist_bucket = "far"
	elif distance > 15.0:
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

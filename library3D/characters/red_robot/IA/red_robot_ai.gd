class_name RedRobotAI
extends Node

const AIConfigLib := preload("res://effects_shared/ai_config.gd")

## Inteligência artificial do Red Robot.
##
## Centraliza os COMPORTAMENTOS e as DECISÕES de ação do red_robot em tempo de execução.
## O "corpo" (red_robot.gd) é responsável por animação, física e disparo; ele instancia esta
## IA como filha e consulta as decisões aqui definidas a cada quadro:
##
##   1. Cadência de tiro: a recarga (do 1º e dos próximos tiros) fica `fire_rate_multiplier`
##      vezes mais rápida — ver `reload_time()`.
##   2. Engajamento: começa a atirar no player quando a distância é menor que o alcance da
##      arma e maior que `flee_distance` — ver `decide()` (Action.ENGAGE).
##   3. Recuo: se o player chegar a `flee_distance` metros ou menos, o robô corre no sentido
##      oposto OLHANDO para o player e continua atirando — ver `decide()` (Action.FLEE).

## Ações táticas de alto nível que o corpo pode executar.
enum Action {
	APPROACH,  ## Fora da faixa ideal: precisa ganhar distância/ângulo.
	ENGAGE,    ## Dentro da faixa ideal: pode manter pressão lateral e preparar o tiro.
	FLEE,      ## Perto demais: abre espaço antes de continuar o duelo.
}

const MODEL_KEY := "red_robot"
const BEHAVIOR_PREDICTIVE_AIM := "predictive_aim"
const BEHAVIOR_ADAPTIVE_ACCURACY := "adaptive_accuracy"
const BEHAVIOR_REACTIVE_STRAFE := "reactive_strafe"
const BEHAVIOR_ADAPTIVE_SPACING := "adaptive_spacing"
const BEHAVIOR_GEOMETRY_PROBE := "geometry_probe"
const BEHAVIOR_PRESSURE_REPOSITION := "pressure_reposition"
const QUICK_RETRY_DELAY := 0.35

## Recarga 1.5x mais rápida (1º e próximos tiros): reload = recarga_base / multiplicador.
@export var fire_rate_multiplier: float = 1.5
## Se o player chegar a esta distância (m) ou menos, o robô precisa abrir espaço.
@export var flee_distance: float = 10.0
## Velocidade (m/s) com que o robô recua quando o alvo invade sua zona curta.
@export var flee_speed: float = 6.0
## Velocidade lateral padrão durante o combate reativo.
@export var strafe_speed: float = 4.25
## Velocidade lateral mais agressiva em reposicionamentos de pressão.
@export var pressure_speed: float = 5.2
## Distância preferida como razão do alcance efetivo da arma.
@export_range(0.2, 0.95) var preferred_range_ratio: float = 0.68
## Largura da faixa "confortável" em torno da distância preferida.
@export_range(0.05, 0.5) var preferred_range_band: float = 0.16
## Comprimento (m) das sondas laterais/diagonais de geometria.
@export var probe_length: float = 4.5
## Velocidade do projétil usada para prever o alvo.
@export var bullet_speed: float = 20.0
## Força do lead preditivo (1.0 = previsao cheia).
@export_range(0.0, 1.5) var lead_strength: float = 0.92
## Bônus máximo de precisão acumulado por familiaridade com o duelo.
@export_range(0.0, 0.4) var learned_accuracy_bonus: float = 0.18
## Duração (s) de um burst de reposicionamento quando a IA sente pressão.
@export var reposition_duration: float = 0.9
## Coesão de formação: o quanto o robô tende a voltar ao seu slot designado (0 = livre, 1 = rígido).
@export_range(0.0, 1.5) var formation_cohesion: float = 0.55
## Tolerância (m) antes de o robô ser puxado de volta ao slot — abaixo disto ele circula livre.
@export var formation_band: float = 5.0
## Variação de velocidade por-indivíduo (±fração) — quebra o "todos andam igual a cada segundo".
@export_range(0.0, 0.4) var speed_variation: float = 0.18

var _behaviors: Dictionary = {}
var _pending_shots: Array[Dictionary] = []
var _bucket_stats: Dictionary = {}
var _strafe_sign: float = 1.0
var _strafe_cooldown: float = 0.0
var _blocked_time: float = 0.0
var _reposition_time: float = 0.0
var _miss_streak: int = 0
# Individualização (semeada no _ready): cada robô tem slot/fase/velocidade próprios, para que o
# pelotão não se mova em lockstep e cada um mantenha seu lugar na formação designada.
var _slot_bearing: float = 0.0
var _slot_seeded: bool = false
var _phase: float = 0.0
var _speed_mult: float = 1.0


func _ready() -> void:
	reload_config()
	# Cada robô começa com sinal de strafe, fase e velocidade próprios — assim o pelotão NÃO
	# anda "exatamente igual a cada segundo". RNG do servidor (movimento é server-autoritativo;
	# clientes só interpolam), portanto não há dessincronia de rede.
	_strafe_sign = 1.0 if randf() < 0.5 else -1.0
	_phase = randf() * TAU
	_speed_mult = 1.0 + randf_range(-speed_variation, speed_variation)


## Recarrega os toggles persistidos da IA deste modelo.
func reload_config() -> void:
	_behaviors = AIConfigLib.behaviors(MODEL_KEY)


func behavior_enabled(key: String) -> bool:
	if _behaviors.is_empty():
		reload_config()
	return bool(_behaviors.get(key, false))


## Recarga efetiva: `base_wait` acelerada por `fire_rate_multiplier`.
func reload_time(base_wait: float) -> float:
	return base_wait / maxf(fire_rate_multiplier, 0.01)


## Pequeno atraso de nova tentativa ao perder a linha de visão: não vale a pena resetar
## a recarga inteira, ou o inimigo fica "duro" demais para reposicionar.
func retry_delay() -> float:
	return QUICK_RETRY_DELAY


## Distância preferida do duelo para este robô.
func preferred_distance(effective_range: float) -> float:
	return clampf(effective_range * preferred_range_ratio, flee_distance + 1.5, maxf(flee_distance + 1.5, effective_range - 1.0))


## Decide a ação do quadro a partir da distância ao player e do alcance da arma.
func decide(distance: float, effective_range: float) -> Action:
	if not behavior_enabled(BEHAVIOR_ADAPTIVE_SPACING):
		if distance <= flee_distance:
			return Action.FLEE
		if distance <= effective_range:
			return Action.ENGAGE
		return Action.APPROACH
	var preferred := preferred_distance(effective_range)
	var band := maxf(1.0, effective_range * preferred_range_band)
	if distance <= maxf(flee_distance, preferred - band):
		return Action.FLEE
	if distance >= preferred + band:
		return Action.APPROACH
	return Action.ENGAGE


## Atualiza timers internos da sessão de combate.
func tick(delta: float) -> void:
	_strafe_cooldown = maxf(0.0, _strafe_cooldown - delta)
	_reposition_time = maxf(0.0, _reposition_time - delta)


## Guarda o contexto do disparo para a memória adaptativa.
func note_shot_fired(distance: float, target_speed: float) -> void:
	_pending_shots.append({
		"bucket": _bucket_key(distance, target_speed),
	})


## Resultado do projétil mais antigo ainda "em voo". Hitar o player alimenta a memória;
## errar demais força reposicionamento para mudar o ângulo do duelo.
func report_shot_result(hit_player: bool) -> void:
	if not _pending_shots.is_empty():
		var shot: Dictionary = _pending_shots.pop_front()
		var bucket := str(shot.get("bucket", "mid:steady"))
		var stats := _stats_for_bucket(bucket)
		stats["samples"] = int(stats.get("samples", 0)) + 1
		if hit_player:
			stats["hits"] = int(stats.get("hits", 0)) + 1
		_bucket_stats[bucket] = stats
	if hit_player:
		_miss_streak = 0
		return
	_miss_streak += 1
	if behavior_enabled(BEHAVIOR_PRESSURE_REPOSITION) and _miss_streak >= 2:
		_trigger_reposition()


## Observa a linha de visão atual para detectar becos/ângulos ruins e reagir mais cedo.
func note_line_of_sight(has_los: bool, delta: float) -> void:
	if has_los:
		_blocked_time = 0.0
		return
	if not behavior_enabled(BEHAVIOR_PRESSURE_REPOSITION):
		_blocked_time = 0.0
		return
	_blocked_time += delta
	if _blocked_time >= 0.45:
		_blocked_time = 0.0
		_trigger_reposition()


## Ponto de mira dinâmico. Sem a feature, mira direto no centro do player.
func compute_aim_point(origin: Vector3, target_position: Vector3, target_velocity: Vector3) -> Vector3:
	var aim := target_position + Vector3.UP
	if not behavior_enabled(BEHAVIOR_PREDICTIVE_AIM):
		return aim
	var distance := origin.distance_to(aim)
	var travel := clampf(distance / maxf(bullet_speed, 0.1), 0.0, 1.25) * lead_strength
	return aim + target_velocity * travel


## Precisão dinâmica. O robô começa bom, mas "aprende" melhor as mesmas situações de
## distância/velocidade conforme acumula amostras de combate naquela sessão.
func dynamic_accuracy(base_accuracy: float, distance: float, target_speed: float) -> float:
	if not behavior_enabled(BEHAVIOR_ADAPTIVE_ACCURACY):
		return clampf(base_accuracy, 0.05, 1.0)
	var stats := _stats_for_bucket(_bucket_key(distance, target_speed))
	var samples := float(int(stats.get("samples", 0)))
	var hits := float(int(stats.get("hits", 0)))
	var familiarity := clampf(samples / 6.0, 0.0, 1.0)
	var hit_rate := hits / maxf(samples, 1.0)
	var motion_penalty := clampf(target_speed / 12.0, 0.0, 0.16)
	var learned := learned_accuracy_bonus * familiarity + 0.08 * maxf(0.0, hit_rate - 0.45)
	return clampf(base_accuracy + learned - motion_penalty, 0.45, 1.0)


## Plano de movimento manual para o quadro atual. Quando `manual = false`, o corpo pode
## cair no root motion tradicional; quando `manual = true`, a IA quer sobrepor o movimento.
func movement_plan(origin: Vector3, target_position: Vector3, effective_range: float,
		space_state: PhysicsDirectSpaceState3D, exclude: Array, delta: float,
		has_los: bool) -> Dictionary:
	tick(delta)
	var plan := {
		"manual": false,
		"direction": Vector3.ZERO,
		"speed": 0.0,
		"action": Action.APPROACH,
	}
	var to_target := target_position - origin
	to_target.y = 0.0
	if to_target.length() < 0.001:
		return plan
	var distance := to_target.length()
	var forward := to_target.normalized()
	var action := decide(distance, effective_range)
	plan["action"] = action
	if action == Action.FLEE:
		plan["manual"] = true
		plan["direction"] = -forward
		plan["speed"] = flee_speed * _speed_mult
		return plan
	var should_strafe := action == Action.ENGAGE and behavior_enabled(BEHAVIOR_REACTIVE_STRAFE)
	var geometry_recover := behavior_enabled(BEHAVIOR_GEOMETRY_PROBE) and not has_los and distance <= effective_range * 1.1
	var pressure := behavior_enabled(BEHAVIOR_PRESSURE_REPOSITION) and _reposition_time > 0.0
	if not should_strafe and not geometry_recover and not pressure:
		return plan
	var side_sign := _choose_strafe_sign(space_state, origin, forward, exclude)
	var lateral := Vector3.UP.cross(forward).normalized() * side_sign
	var preferred := preferred_distance(effective_range)
	var band := maxf(1.0, effective_range * preferred_range_band)
	var radial_factor := clampf((distance - preferred) / band, -1.0, 1.0)
	var move := lateral
	if radial_factor > 0.18:
		move += forward * minf(radial_factor, 0.8) * 0.65
	elif radial_factor < -0.18:
		move += -forward * minf(-radial_factor, 1.0) * 0.55
	if geometry_recover:
		move += forward * 0.45
	if pressure:
		move += lateral * 0.45 + forward * 0.2
	# Formação designada: cada robô guarda um slot (a direção a partir do player capturada na
	# 1ª vez, derivada do ponto de spawn) e tende a voltar a ele. Continua circulando/strafe
	# livremente, mas o pelotão mantém uma formação frouxa em vez de amontoar e marchar igual.
	if not _slot_seeded:
		_slot_seeded = true
		var spawn_off := origin - target_position
		spawn_off.y = 0.0
		_slot_bearing = atan2(spawn_off.x, spawn_off.z) if spawn_off.length() > 0.5 else _phase
	var slot_dir := Vector3(sin(_slot_bearing), 0.0, cos(_slot_bearing))
	var to_slot := (target_position + slot_dir * preferred) - origin
	to_slot.y = 0.0
	if to_slot.length() > formation_band:
		move += to_slot.normalized() * formation_cohesion * clampf(to_slot.length() / maxf(preferred, 1.0), 0.0, 1.0)
	plan["manual"] = true
	plan["direction"] = move.normalized()
	plan["speed"] = (pressure_speed if pressure else strafe_speed) * _speed_mult
	return plan


func _trigger_reposition() -> void:
	_reposition_time = maxf(_reposition_time, reposition_duration)
	_strafe_sign *= -1.0
	_strafe_cooldown = 0.4


func _choose_strafe_sign(space_state: PhysicsDirectSpaceState3D, origin: Vector3,
		forward: Vector3, exclude: Array) -> float:
	if not behavior_enabled(BEHAVIOR_GEOMETRY_PROBE):
		if _strafe_cooldown <= 0.0:
			_strafe_sign *= -1.0
			_strafe_cooldown = randf_range(0.7, 1.6)  # período individual: evita flips sincronizados
		return _strafe_sign
	var from := origin + Vector3.UP
	var right := Vector3.UP.cross(forward).normalized()
	var left := -right
	var right_score := _probe_score(space_state, from, right, probe_length, exclude)
	right_score += 0.35 * _probe_score(space_state, from, (right + forward).normalized(), probe_length * 0.75, exclude)
	var left_score := _probe_score(space_state, from, left, probe_length, exclude)
	left_score += 0.35 * _probe_score(space_state, from, (left + forward).normalized(), probe_length * 0.75, exclude)
	if absf(right_score - left_score) > 0.08:
		_strafe_sign = 1.0 if right_score >= left_score else -1.0
		_strafe_cooldown = randf_range(0.45, 0.7)
	elif _strafe_cooldown <= 0.0:
		_strafe_sign *= -1.0
		_strafe_cooldown = randf_range(0.6, 1.3)  # período individual: quebra o lockstep
	return _strafe_sign


func _probe_score(space_state: PhysicsDirectSpaceState3D, from: Vector3, dir: Vector3,
		length: float, exclude: Array) -> float:
	var to := from + dir.normalized() * maxf(length, 0.1)
	var query := PhysicsRayQueryParameters3D.create(from, to, 0xFFFFFFFF, exclude)
	var hit := space_state.intersect_ray(query)
	if hit.is_empty():
		return 1.0
	return clampf(from.distance_to(hit.position) / maxf(length, 0.1), 0.0, 1.0)


func _bucket_key(distance: float, target_speed: float) -> String:
	var dist_bucket := "near"
	if distance > 22.0:
		dist_bucket = "far"
	elif distance > 13.0:
		dist_bucket = "mid"
	var speed_bucket := "steady"
	if target_speed > 6.5:
		speed_bucket = "fast"
	elif target_speed > 2.0:
		speed_bucket = "moving"
	return "%s:%s" % [dist_bucket, speed_bucket]


func _stats_for_bucket(bucket: String) -> Dictionary:
	if not _bucket_stats.has(bucket):
		_bucket_stats[bucket] = {"samples": 0, "hits": 0}
	return _bucket_stats[bucket]

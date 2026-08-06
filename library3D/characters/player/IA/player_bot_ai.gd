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
const BEHAVIOR_GUARD_STANCE := "guard_stance"

## Distância (m) em que o aliado acompanha o player. Na postura de segurança é o raio do POSTO
## (atrás e ao lado do protegido), não o raio de uma órbita.
@export var follow_distance := 2.5
## Folga (m) em torno de `follow_distance` antes de o aliado corrigir o raio da órbita.
## Só vale fora da postura de segurança (esta usa `station_tolerance`).
@export var orbit_band := 0.9
## Peso do componente tangencial da órbita (0 = só mantém distância; maior = circula mais).
## Fora da postura de segurança. Baixo de propósito: circular demais lê como "correr sem direção".
@export var orbit_strength := 0.15
## ─── Postura de segurança (guard_stance) ───
## Quanto do `follow_distance` fica ATRÁS do protegido (o resto vai para o lado). 0.8 atrás + 0.6 ao
## lado = posto na diagonal traseira, a `follow_distance` do player, sem tapar a linha de tiro dele.
@export_range(0.0, 1.0) var guard_back_ratio := 0.8
@export_range(0.0, 1.0) var guard_side_ratio := 0.6
## Com uma ameaça perto do protegido, o posto vai para a FRENTE dele, na direção da ameaça (o
## segurança se INTERPÕE). Fração do `follow_distance` — a distância ao protegido não muda.
@export_range(0.0, 1.0) var guard_screen_ratio := 0.8
## Raio (m) da BOLHA de liberdade em torno do protegido: dentro dela o aliado anda para onde quiser
## (orbitar, flanquear, recuar, avançar). Ao ultrapassá-la, a volta passa a dominar o movimento —
## proporcionalmente, até virar obrigatória em `max_leash`. É o que dá "liberdade sem se afastar".
@export var roam_radius := 4.0
## Zona morta (m) do posto: dentro dela o aliado PARA. Pequena para ele reagir a cada passo do
## protegido; o vaivém é evitado pela histerese abaixo, não por uma zona morta larga.
@export var station_tolerance := 0.6
## Histerese: já parado, só volta a andar quando o posto se afasta `station_tolerance` × este fator.
## Separar "chegar" (0,45 m) de "sair" (≈1,0 m) dá reação rápida SEM tremer parado.
@export_range(1.0, 5.0) var settle_release := 2.2
## Peso da preferência por se interpor (ficar entre o protegido e a ameaça). Enviesa o movimento
## livre; não o substitui.
@export_range(0.0, 2.0) var guard_screen_weight := 0.7
## Suavização (1/s) do RUMO: a direção decidida entra GRADUALMENTE, em vez de trocar de golpe a cada
## varredura. Menor = mais pesado/suave. É o que tira o "tremido" e os movimentos repetitivos rápidos
## (mesmo remédio do `move_dir_response` do red_robot).
@export var move_dir_response := 4.0
## Distância (m) mínima do protegido: se o player andar para cima do bot, o único movimento dele é
## recuar. Garante o "acompanha sem colidir" mesmo com a exceção de colisão física ativa.
## Tem de ficar CONFORTAVELMENTE abaixo de `follow_distance` (posto a 2,5 m → recuo a 1,8 m dá 0,7 m
## de margem); colado no raio do posto, ele oscilaria entre "ir ao posto" e "recuar".
@export var min_standoff := 1.8
## Raio (m) em que um aliado começa a se afastar de OUTRO aliado (separação/anti-empilhamento).
@export var separation_radius := 3.0
## Peso do empurrão de separação em relação ao movimento normal (0 = desligado).
@export var separation_strength := 1.0
@export var preferred_combat_distance := 12.0
@export var combat_band := 4.5
@export var weapon_range := 52.0
@export var bullet_speed := 20.0
@export var lead_strength := 0.82
@export var flank_duration := 1.1
## Intervalo (s) entre varreduras de alvo/âncora/aliados. Curto = o segurança percebe a ameaça
## mudar de lado mais rápido (é o que dá a sensação de "reação" sem aumentar a agressividade).
@export var scan_interval := 0.2
## Só engaja inimigos a até esta distância (m) do próprio bot — evita perseguir ameaças do
## outro lado do mapa e abandonar a cobertura do player. Curto: o aliado é escolta, não caçador.
@export var engage_range := 16.0
## Também engaja inimigos a até esta distância (m) do player humano (para defendê-lo). É o raio que
## de fato importa numa escolta: reage ao que ameaça o protegido, não ao que passa longe.
@export var player_threat_radius := 18.0
## Coleira de cobertura: a partir desta distância (m) do player o bot já é puxado de volta
## durante o combate, para lutar ao lado do player em vez de derivar atrás do inimigo.
@export var soft_leash := 6.0
## Distância (m) máxima do player: além disto, reagrupar tem prioridade sobre perseguir.
## É o que impede o aliado de "correr sem parar até cair do mapa".
@export var max_leash := 9.0

var _behaviors: Dictionary = {}
var _target: Node3D = null
var _anchor: Node3D = null
# Corpo do bot (setado a cada update_input) — referência de facção nas checagens de alvo/aliado.
var _bot: CharacterBody3D = null
# Última âncora com exceção de colisão aplicada, para não colidir com o player que orbita.
var _prev_anchor: Node3D = null
# Outros aliados por perto (exceto a âncora) — recalculado no scan; usado na separação anti-empilhamento.
var _allies: Array[Node3D] = []
var _orbit_sign := 1.0
# Posto de origem: onde o bot foi spawnado. É o que ele guarda quando NÃO há ninguém para escoltar
# (host observando, sala antes de o jogador entrar, jogador que saiu). Sem isto ele caía no combate
# livre e avançava no inimigo — "correndo em direção à morte".
var _home := Vector3.ZERO
var _home_set := false
# Rumo suavizado entre quadros (ver _smooth_dir): tira o tremido/vaivém rápido do movimento.
var _move_dir_smooth := Vector3.ZERO
# True enquanto o aliado está ASSENTADO no posto (ver settle_release): a histerese que separa o
# limiar de chegar do de sair, evitando o tremor de quem corrige a posição a cada quadro.
var _settled := false
var _scan_cd := 0.0
var _flank_sign := 1.0
var _flank_time := 0.0
var _pending_shots: Array[Dictionary] = []
var _bucket_stats: Dictionary = {}
var _miss_streak := 0


func _ready() -> void:
	reload_config()
	_orbit_sign = 1.0 if randf() < 0.5 else -1.0  # sentido de órbita individual (quebra o lockstep)


func reload_config() -> void:
	_behaviors = AIConfigLib.behaviors(MODEL_KEY)


func behavior_enabled(key: String) -> bool:
	if _behaviors.is_empty():
		reload_config()
	return bool(_behaviors.get(key, false))


func update_input(bot: CharacterBody3D, input: PlayerInputSynchronizer, delta: float) -> void:
	if bot == null or input == null or not bot.is_inside_tree():
		return
	_bot = bot
	if not _home_set:
		_home = bot.global_position
		_home_set = true
	_scan_cd -= delta
	_flank_time = maxf(0.0, _flank_time - delta)
	if _scan_cd <= 0.0:
		_scan_cd = scan_interval
		var scope: Node = bot.get_parent()
		if scope == null:
			scope = bot.get_tree().current_scene
		_target = _find_enemy(scope, bot.global_position)
		_anchor = _find_nearest_human_ally(scope, bot)
		_allies = _collect_allies(scope, bot)
		_sync_anchor_collision(bot)
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
	elif not has_anchor and behavior_enabled(BEHAVIOR_GUARD_STANCE):
		# Sem ninguém para escoltar: guarda o posto de origem (volta se derivou) em vez de vagar.
		move_dir = _hold_move(bot_pos)
		if _is_valid_enemy(_target):
			aim_point = _target.global_position + Vector3.UP
		else:
			aim_point = bot_pos + _flat_or_forward(move_dir, -bot.global_transform.basis.z) * 20.0 + Vector3.UP
	elif has_anchor:
		# Sem ameaça engajável: dá cobertura ao player (segue e mantém-se por perto).
		move_dir = _follow_move(bot_pos, anchor_pos)
		# Guarda virada para o inimigo mais próximo, se houver; senão, para onde anda.
		if _is_valid_enemy(_target):
			aim_point = _target.global_position + Vector3.UP
		else:
			aim_point = bot_pos + _flat_or_forward(move_dir, -bot.global_transform.basis.z) * 20.0 + Vector3.UP
	# Separação: afasta-se dos outros aliados por perto → não empilham na órbita nem no combate.
	move_dir += _separation(bot_pos) * separation_strength
	# Liberdade COM coleira: dentro da bolha ele anda para onde quiser; passando dela, a volta domina.
	move_dir = _leash(move_dir, bot_pos, has_anchor)
	# Rumo suavizado: a direção entra gradualmente → sem trocas bruscas nem vaivém rápido.
	move_dir = _smooth_dir(move_dir, delta)
	input.aiming = should_aim
	input.shooting = should_shoot
	input.shoot_target = aim_point
	input.jumping = false
	# ORDEM IMPORTA: virar ANTES de projetar o movimento.
	# O `input.motion` é um vetor no frame da CÂMERA (é o que o teclado produz para um humano) e o
	# `player.apply_input` o reconstrói em coordenadas de mundo com a base da câmera DAQUELE quadro.
	# Enquanto projetávamos antes do `_face_point`, a base usada na ida era a do quadro anterior e a
	# da volta já vinha girada para a nova direção: a cada tick o vetor era reinterpretado girado, o
	# erro se realimentava e o bot saía em LINHA RETA, ignorando posto e alvo. Virando primeiro, ida
	# e volta usam a mesma base e o deslocamento sai exatamente na direção decidida.
	if should_aim:
		_face_point(input, bot_pos + Vector3.UP, aim_point)
	elif move_dir.length() > 0.01:
		_face_point(input, bot_pos + Vector3.UP, bot_pos + move_dir + Vector3.UP)
	input.motion = _world_dir_to_motion(input, move_dir)


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
	# Postura de segurança: o aliado NÃO avança para cima do inimigo — segura o posto e atira dali.
	# Só recua se o inimigo colar (`combat_spacing`). Sem investida e sem flanco, é o que separa uma
	# escolta de um caçador. O posto é ao lado do protegido; SEM protegido (host observando, sala
	# vazia, jogador que saiu), é o lugar onde ele nasceu — e não uma corrida atrás do inimigo.
	# Sem ninguém para escoltar (host observando, sala antes de o jogador entrar): guarda o posto de
	# origem em vez de sair caçando.
	if behavior_enabled(BEHAVIOR_GUARD_STANCE) and not (has_anchor and _is_valid_anchor(_anchor)):
		move = _hold_move(origin)
		if behavior_enabled(BEHAVIOR_COMBAT_SPACING) and distance < preferred_combat_distance - combat_band:
			move -= forward
		return move.normalized() if move.length() > 0.01 else Vector3.ZERO
	if behavior_enabled(BEHAVIOR_COMBAT_SPACING):
		if distance > preferred_combat_distance + combat_band:
			move += forward
		elif distance < preferred_combat_distance - combat_band:
			move -= forward
	if behavior_enabled(BEHAVIOR_PRESSURE_FLANK):
		var right := Vector3.UP.cross(forward).normalized()
		var flank_weight := 0.55 if _flank_time > 0.0 else 0.25
		move += right * _flank_sign * flank_weight
	# Postura de segurança: PREFERÊNCIA (não posto rígido) por ficar entre o protegido e a ameaça.
	# Peso moderado — o aliado continua livre para orbitar, flanquear e recuar; isto só enviesa a
	# escolha. Quem impede o afastamento é a coleira (_leash), não uma âncora fixa.
	if behavior_enabled(BEHAVIOR_GUARD_STANCE) and has_anchor and _is_valid_anchor(_anchor):
		var to_station := _guard_station(_anchor) - origin
		to_station.y = 0.0
		if to_station.length() > station_tolerance:
			move += to_station.normalized() * guard_screen_weight
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


# Sem ameaça: acompanha o player. Na POSTURA DE SEGURANÇA vai para um posto fixo (atrás e ao lado)
# e para lá; fora dela, cai na órbita clássica (mantém o raio e circula devagar). Em ambos os casos
# o raio > corpo e há exceção de colisão bot↔âncora, então ele fica no entorno SEM colidir.
func _follow_move(origin: Vector3, anchor_position: Vector3) -> Vector3:
	if behavior_enabled(BEHAVIOR_GUARD_STANCE) and _is_valid_anchor(_anchor):
		return _guard_move(origin, _anchor)
	var to_anchor := anchor_position - origin
	to_anchor.y = 0.0
	var dist := to_anchor.length()
	if dist < 0.01:
		return Vector3.ZERO
	var radial := to_anchor.normalized()
	var move := Vector3.ZERO
	var radial_err := dist - follow_distance
	if absf(radial_err) > orbit_band:
		# aproxima (err>0) ou afasta (err<0), proporcional ao quanto saiu da folga.
		move += radial * signf(radial_err) * clampf(absf(radial_err) / (orbit_band * 2.0), 0.25, 1.0)
	# componente tangencial → circula o player em vez de só ficar parado ao lado.
	move += Vector3.UP.cross(radial).normalized() * _orbit_sign * orbit_strength
	return move.normalized() if move.length() > 0.01 else Vector3.ZERO


# Postura de segurança: caminha até o POSTO ao lado do protegido e PARA ao chegar. Três regras, nesta
# ordem: (1) colou demais → só recua (nunca esbarra no player); (2) já está no posto (dentro de
# `station_tolerance`) → fica parado; (3) senão, vai em linha reta até o posto. Sem componente
# tangencial: é o que elimina o "correr sem direção" da órbita.
func _guard_move(origin: Vector3, anchor: Node3D) -> Vector3:
	var to_anchor := anchor.global_position - origin
	to_anchor.y = 0.0
	var dist := to_anchor.length()
	if dist < min_standoff:
		_settled = false
		return -to_anchor.normalized() if dist > 0.01 else Vector3.ZERO
	var to_station := _guard_station(anchor) - origin
	to_station.y = 0.0
	var gap := to_station.length()
	# Histerese: chega no posto com `station_tolerance` e só sai dele com `× settle_release`. Dá
	# reação rápida (zona morta pequena) sem o tremor de corrigir a posição a cada quadro.
	if _settled:
		if gap <= station_tolerance * settle_release:
			return Vector3.ZERO
		_settled = false
	elif gap <= station_tolerance:
		_settled = true
		return Vector3.ZERO
	return to_station.normalized()


# Coleira da bolha: DENTRO de `roam_radius` do protegido o movimento passa intacto (liberdade total
# de direção); FORA dela, a volta entra proporcionalmente ao excesso e vira dominante em `max_leash`.
# É isto — e não um posto fixo — que garante "anda para qualquer lado sem se afastar do player".
# Sem protegido, o centro é o posto de origem (`_home`).
func _leash(move: Vector3, origin: Vector3, has_anchor: bool) -> Vector3:
	var center := _anchor.global_position if (has_anchor and _is_valid_anchor(_anchor)) else _home
	if not has_anchor and not _home_set:
		return move
	var to_center := center - origin
	to_center.y = 0.0
	var dist := to_center.length()
	if dist <= roam_radius or dist < 0.01:
		return move
	var back := to_center.normalized()
	var pull: float = clampf((dist - roam_radius) / maxf(max_leash - roam_radius, 0.1), 0.0, 1.0)
	var blended := move.lerp(back, pull)
	return blended if blended.length() > 0.01 else back


# Interpolação exponencial (independente de framerate) do rumo. Guarda o vetor entre quadros, então a
# IA pode mudar de ideia à vontade que o CORPO muda de direção de forma gradual.
func _smooth_dir(target: Vector3, delta: float) -> Vector3:
	var weight: float = 1.0 - exp(-maxf(move_dir_response, 0.01) * delta)
	_move_dir_smooth = _move_dir_smooth.lerp(target, weight)
	if _move_dir_smooth.length() < 0.05:
		return Vector3.ZERO   # rumo praticamente nulo → parado (não fica cutucando)
	return _move_dir_smooth


# Sem protegido: guarda o LUGAR onde nasceu. Volta ao posto se derivou (o empurrão de separação e o
# recuo de combate deslocam um pouco) e para ao chegar, com a mesma histerese do posto de escolta.
# É esta função que impede o aliado de sair caçando quando não há quem escoltar.
func _hold_move(origin: Vector3) -> Vector3:
	if not _home_set:
		return Vector3.ZERO
	var to_home := _home - origin
	to_home.y = 0.0
	if to_home.length() <= station_tolerance * settle_release:
		return Vector3.ZERO
	return to_home.normalized()


# O posto, sempre a `follow_distance` do protegido — o que muda é o LADO:
#   • em paz: diagonal TRASEIRA (atrás + ao lado), fora da linha de tiro do player, seguindo-o quando
#     ele vira;
#   • com ameaça perto dele: à FRENTE, na direção da ameaça — o segurança se INTERPÕE entre os dois.
#     O deslocamento lateral continua, para não tapar o tiro do protegido.
# O lado sai do `_orbit_sign` sorteado no _ready, então dois aliados cobrem lados opostos.
func _guard_station(anchor: Node3D) -> Vector3:
	var anchor_pos := anchor.global_position
	var forward := -anchor.global_transform.basis.z
	var along := -guard_back_ratio          # negativo = atrás do protegido
	if _is_valid_enemy(_target) and anchor_pos.distance_to(_target.global_position) <= player_threat_radius:
		var to_threat := _target.global_position - anchor_pos
		to_threat.y = 0.0
		if to_threat.length() > 0.01:
			forward = to_threat
			along = guard_screen_ratio      # positivo = entre o protegido e a ameaça
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var right := Vector3.UP.cross(forward).normalized()
	return anchor_pos \
		+ forward * follow_distance * along \
		+ right * _orbit_sign * follow_distance * guard_side_ratio


# Âncora = player HUMANO (não-bot) mais PRÓXIMO e do mesmo lado (aliado). Antes pegava o primeiro.
func _find_nearest_human_ally(scope: Node, bot: Node) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	var here: Vector3 = (bot as Node3D).global_position
	for candidate in _collect_nodes(scope):
		if candidate == bot or not _is_ally(candidate):
			continue
		var bot_flag: Variant = candidate.get("bot_controlled")
		if bot_flag is bool and bool(bot_flag):
			continue  # ancora num HUMANO, não noutro bot
		var d := here.distance_to((candidate as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = candidate as Node3D
	return best


# Outros aliados no escopo (mesmo lado), EXCETO a âncora (essa é tratada pela órbita + exceção de
# colisão). É a lista contra a qual a separação empurra, para os aliados não se empilharem.
func _collect_allies(scope: Node, bot: Node) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for candidate in _collect_nodes(scope):
		if candidate == bot or candidate == _anchor or not _is_ally(candidate):
			continue
		out.append(candidate as Node3D)
	return out


# Vetor de separação (steering estilo boids): soma dos empurrões para LONGE de cada aliado dentro de
# `separation_radius`, com peso proporcional à proximidade (mais perto → empurra mais). Zero se ninguém
# perto → não atrapalha o movimento normal. Horizontal (y = 0).
func _separation(pos: Vector3) -> Vector3:
	if separation_radius <= 0.01:
		return Vector3.ZERO
	var push := Vector3.ZERO
	for ally in _allies:
		if not is_instance_valid(ally):
			continue
		var away := pos - ally.global_position
		away.y = 0.0
		var d := away.length()
		if d < 0.01 or d >= separation_radius:
			continue
		push += away.normalized() * (1.0 - d / separation_radius)
	return push


# Mantém a exceção de colisão física com a âncora atual (e a remove da anterior) → o aliado orbita
# "sem colidir com ele". Reaplicada quando a âncora (player mais próximo) muda.
func _sync_anchor_collision(bot: CharacterBody3D) -> void:
	if _anchor == _prev_anchor:
		return
	if is_instance_valid(_prev_anchor) and _prev_anchor is CollisionObject3D:
		bot.remove_collision_exception_with(_prev_anchor)
	if is_instance_valid(_anchor) and _anchor is CollisionObject3D:
		bot.add_collision_exception_with(_anchor)
	_prev_anchor = _anchor


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
		# Mesma convenção invertida de _world_dir_to_motion: a "frente" efetiva do corpo é o +Z da
		# base da câmera, então apontamos o -Z do camera_base para o lado OPOSTO ao alvo. Assim o
		# corpo encara o alvo de fato (e não de costas), tanto ao andar quanto ao mirar.
		input.camera_base.look_at(input.camera_base.global_position - flat.normalized(), Vector3.UP)
	var flat_len := maxf(flat.length(), 0.01)
	# O yaw espelhado inverte também o sentido do pitch.
	input.camera_rot.rotation.x = clampf(-atan2(to.y, flat_len), deg_to_rad(-55.0), deg_to_rad(45.0))


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
	# SINAL INVERTIDO — a convenção do projeto é essa, não um ajuste arbitrário.
	# O `apply_input` monta `target = camera_x*motion.x + camera_z*motion.y` e usa esse vetor só para
	# ORIENTAR o corpo (`Basis.looking_at`); o deslocamento vem do ROOT MOTION da animação, que corre
	# no +Z local ("The animation's forward/backward axis is reversed", player.gd) — ou seja, o corpo
	# VIAJA no sentido OPOSTO ao `target`. O PlayerModel carrega o giro de 180° que faz isso parecer
	# certo em tela, e para o humano tudo fecha porque a tecla W já manda motion.y = -1.
	# Medido no harness: um player sem IA com motion=(0,-1) desloca-se para -camFwd (alinhamento
	# -1.00). Logo, para andar na direção `dir` do mundo, projetamos `-dir`.
	return Vector2(clampf(-dir.dot(camera_x), -1.0, 1.0), clampf(-dir.dot(camera_z), -1.0, 1.0))


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


# Parâmetro SEM tipo de propósito: _target pode apontar para um inimigo JÁ LIBERADO (morreu/
# despawnou). Com o parâmetro tipado (Node), o GDScript valida o tipo do argumento na ENTRADA da
# função e estoura ("previously freed ... not a subclass") antes de o is_instance_valid() rodar.
# Sem tipo, o objeto liberado entra e o is_instance_valid (1º, por curto-circuito) o rejeita.
func _is_valid_enemy(node) -> bool:
	return is_instance_valid(node) and node is Node3D and node.has_method(&"hit") \
		and Factions.are_enemies(_bot, node)


func _is_valid_anchor(node) -> bool:
	# Sem tipo: o anchor (player seguido) pode ter sido liberado — o parâmetro tipado estouraria
	# na entrada antes do is_instance_valid (mesmo motivo de _is_valid_enemy).
	return is_instance_valid(node) and node is Node3D and _is_ally(node)


# Aliado = do mesmo lado que ESTE bot (ambos "ally"). Facção runtime, não mais duck-typing.
func _is_ally(node) -> bool:
	return is_instance_valid(node) and node is Node3D and Factions.same_side(_bot, node)


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

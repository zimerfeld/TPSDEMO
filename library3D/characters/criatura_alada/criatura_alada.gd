extends CharacterBody3D
## Criatura alada motorizada — inimigo voador.
## Quando há um player na cena, alça voo até a altitude de cruzeiro (~20 m),
## orbita o player com voo suave (subidas e descidas suaves, mais lento que o
## real) e libera bombas miradas pelo compartimento frontal. Cada bomba tira
## 50 HP ao acertar o player (que tem tempo de desviar durante a queda).
## Pode ser abatida a tiros (tem vida própria). Lógica server-autoritária.

const Bomb: PackedScene = preload("res://library3D/weapons/bomb/bomb.tscn")
const CriaturaAladaAILib := preload("res://library3D/characters/criatura_alada/IA/criatura_alada_ai.gd")
const BOMB_GRAVITY := 18.0   # deve casar com bomb.gd (fall_gravity)

@export var auto_fly := true

@export_group("Voo")
@export var cruise_altitude := 20.0    ## altura de cruzeiro (Y do mundo, em metros)
@export var climb_speed := 4.0         ## m/s de subida (lento)
@export var cruise_speed := 2.6        ## m/s horizontal (abaixo do real)
@export var orbit_radius := 8.0        ## raio da órbita em torno do player (m)
@export var bob_amplitude := 0.6       ## m de subida/descida suave em cruzeiro
@export var bob_freq := 0.6
@export var bank_max := 0.45
## Suavização (1/s) do RUMO horizontal: a direção decidida pela IA entra gradualmente, em vez de
## virar de golpe a cada varredura. Menor = voo mais pesado/suave. Ver _physics_process.
@export var move_dir_response := 3.5

@export_group("Bombas")
@export var bomb_damage := 50          ## HP tirado do player por bomba
@export var bomb_interval := 4.0       ## s entre lançamentos
@export var bomb_lead_max := 9.0       ## m/s máx. da velocidade horizontal da bomba (deixa o player desviar)

@export_group("Vida")
@export var enemy_name := "Criatura Alada"
@export var max_health := 120
@export var health := 120

enum Phase { CLIMB, PATROL }

var _t := 0.0
var _bob_phase := 0.0  # fase inicial individual do bob (criaturas não oscilam em sincronia)
var _yaw := 0.0
# Rumo horizontal suavizado entre quadros (ver move_dir_response).
var _horiz_smooth := Vector3.ZERO
var _phase := Phase.CLIMB
var _bomb_cd := 0.0
var _scan_cd := 0.0
# Janela (s) em que a criatura se considera AMEAÇADA após levar um tiro → sobe p/ escapar (IA aérea).
var _recent_hit_t := 0.0
var _player: Node3D = null
var _dead := false
var ai: Node = null

## Proxy replicado NO LUGAR de global_transform: o servidor o espelha a cada frame; o cliente
## o bufferiza (NetInterp) e renderiza ~100 ms no passado, suavizando o voo (anti-flicker).
## Mesmo padrão de player.gd / red_robot.gd — sem isto a criatura ficava PARADA nos clientes,
## pois ela só simula no servidor.
@export var net_transform: Transform3D = Transform3D.IDENTITY:
	set(value):
		net_transform = value
		_net_received = true
var _net_received := false
var _interp := NetInterp.new()
var _interp_seeded := false

@onready var _rig: Node3D = $Rig
@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _bay: Node3D = $BombBay


func _ready() -> void:
	# Facção runtime (hostil por padrão; template tem precedência) → targeting e sem fogo amigo.
	Factions.seed_node(self, &"criatura_alada")
	_yaw = rotation.y
	_bomb_cd = bomb_interval
	_bob_phase = randf() * TAU  # desincroniza o bob/oscilação entre criaturas
	_t = _bob_phase
	ai = CriaturaAladaAILib.new()
	ai.name = "IA"
	add_child(ai)
	if _anim and _anim.has_animation("voar"):
		_anim.play("voar")
	# Semeia o proxy de rede com a pose inicial APENAS no servidor (assim o spawn property já
	# carrega o valor certo). No cliente o valor chega pela replicação de spawn.
	if _is_server():
		net_transform = global_transform


func _is_server() -> bool:
	if not is_inside_tree():
		return false
	if multiplayer == null:
		return true
	return multiplayer.is_server()


func _physics_process(delta: float) -> void:
	if not auto_fly:
		return
	# Clientes não simulam: o servidor é autoritativo. O cliente interpola o transform
	# recebido (~100 ms no passado) para um voo suave; sem isto a criatura ficava parada.
	if not _is_server():
		_interpolate_remote()
		return

	if _dead:
		velocity.y -= BOMB_GRAVITY * delta
		move_and_slide()
		net_transform = global_transform  # espelha p/ replicação (clientes interpolam)
		return

	_t += delta
	_recent_hit_t = maxf(0.0, _recent_hit_t - delta)  # decai a sensação de ameaça

	# procura o player periodicamente
	_scan_cd -= delta
	if _scan_cd <= 0.0:
		_scan_cd = 1.0
		# Procura o player só na PRÓPRIA sala (irmãos no SpawnedNodes) — não no current_scene
		# global, que no servidor multi-level acharia o player de OUTRA sala. Vale tb p/ single-level.
		var scope: Node = get_parent()
		if scope == null:
			scope = get_tree().current_scene
		_player = _find_nearest_player(scope)

	# sem player → repouso: paira no lugar (bom para preview/navegador de modelos)
	if _player == null:
		_phase = Phase.CLIMB
		velocity = Vector3.UP * (bob_amplitude * bob_freq * cos(_t * bob_freq))
		move_and_slide()
		net_transform = global_transform  # espelha p/ replicação (clientes interpolam)
		return

	# ---- direção/altitude: a IA aérea escolhe órbita, raio e camada vertical.
	# Contexto p/ a camada de voo: AMEAÇADA (levou tiro há pouco) → sobe p/ escapar; prestes a
	# bombardear (cd ≤ 1.2 s) → desce p/ precisão. A IA interpola a troca de camada (sem degrau).
	var threatened := _recent_hit_t > 0.0
	var bomb_imminent := _phase == Phase.PATROL and _bomb_cd <= 1.2
	var move_plan: Dictionary = ai.movement_plan(global_position, _player.global_position, orbit_radius,
		cruise_speed, cruise_altitude, _t, get_world_3d().direct_space_state, [self, _player], delta,
		threatened, bomb_imminent)
	var horiz: Vector3 = move_plan.get("horiz", Vector3.ZERO)
	var desired_altitude := float(move_plan.get("altitude", cruise_altitude))

	# ---- vertical: subir até a altitude de cruzeiro, depois oscilar suave
	var vy := 0.0
	if _phase == Phase.CLIMB:
		var dy := desired_altitude - global_position.y
		if dy <= 0.4:
			_phase = Phase.PATROL
			_t = _bob_phase
		vy = clampf(dy * 2.0, -climb_speed, climb_speed)
		horiz *= 0.6   # sobe mais reto
	else:
		vy = bob_amplitude * bob_freq * cos(_t * bob_freq) + (desired_altitude - global_position.y) * 0.6
		# Teto de taxa vertical → a troca de camada (descer p/ mirar / subir p/ escapar) fica suave.
		vy = clampf(vy, -climb_speed * 1.6, climb_speed * 1.6)

	# ---- rumo horizontal SUAVIZADO (mesmo remédio do `move_dir_response` do red_robot)
	# A IA troca de plano a qualquer momento (raio/sentido da órbita, evasão, corrida de pressão).
	# Aplicado cru, isso vira de GOLPE a cada varredura e o voo fica tremido e repetitivo. Aqui a
	# direção entra gradualmente; a VELOCIDADE decidida pela IA é preservada.
	var speed := horiz.length()
	if speed > 0.05:
		var w: float = 1.0 - exp(-maxf(move_dir_response, 0.01) * delta)
		_horiz_smooth = _horiz_smooth.lerp(horiz.normalized(), w)
		if _horiz_smooth.length() > 0.01:
			horiz = _horiz_smooth.normalized() * speed

	# ---- orientação (frente -Z aponta para onde voa) + banking ao curvar
	if horiz.length() > 0.05:
		look_at(global_position + Vector3(horiz.x, 0.0, horiz.z), Vector3.UP)
	var heading := atan2(horiz.x, horiz.z)
	var dyaw := wrapf(heading - _yaw, -PI, PI)
	_yaw = heading
	if _rig:
		var bank_boost := float(move_plan.get("bank_boost", 1.0))
		var tb := clampf(-dyaw / maxf(delta, 0.0001) / 2.0, -1.0, 1.0) * bank_max * bank_boost
		_rig.rotation.z = lerpf(_rig.rotation.z, tb, delta * 2.5)

	velocity = horiz + Vector3.UP * vy
	move_and_slide()

	# ---- bombardeio (apenas em cruzeiro)
	if _phase == Phase.PATROL:
		_bomb_cd -= delta
		if _bomb_cd <= 0.0:
			_bomb_cd = bomb_interval
			_drop_bomb()

	net_transform = global_transform  # espelha p/ replicação (clientes interpolam)


# Aplica o transform interpolado (buffer de snapshots datados) na criatura remota.
func _interpolate_remote() -> void:
	if not _net_received:
		return  # nada recebido ainda: fica na posição de spawn
	var now: float = float(Time.get_ticks_msec())
	_interp.push(now, net_transform)
	if _interp.has_data():
		global_transform = _interp.sample(now)
	if not _interp_seeded:
		# 1ª aplicação: zera a interpolação física p/ não "rasgar" do spawn até a 1ª amostra.
		_interp_seeded = true
		reset_physics_interpolation()


func _drop_bomb() -> void:
	if not _is_server() or _bay == null:
		return
	var origin: Vector3 = _bay.global_position
	var bomb := Bomb.instantiate()
	bomb.damage = bomb_damage
	bomb.dropper = self
	get_parent().add_child(bomb, true)
	bomb.global_position = origin
	bomb.add_collision_exception_with(self)

	# Mira balística: velocidade horizontal para a bomba cair sobre o player
	# (limitada para o player conseguir desviar durante a queda).
	var horiz := Vector3.ZERO
	if _player != null:
		var target_velocity := _player_velocity()
		horiz = ai.compute_bomb_velocity(origin, _player.global_position, target_velocity,
			BOMB_GRAVITY, bomb_lead_max)
		ai.note_bomb_dropped(origin.distance_to(_player.global_position), target_velocity.length())
	if bomb.has_method("set_initial_velocity"):
		bomb.set_initial_velocity(horiz + Vector3.DOWN * 1.0)


func notify_projectile_feedback(hit_target: Node) -> void:
	if ai != null and ai.has_method(&"report_bomb_result"):
		ai.report_bomb_result(hit_target != null and hit_target == _player)


@rpc("call_local")
func hit(amount: int = 50) -> void:
	if _dead:
		return
	health = maxi(health - amount, 0)
	_recent_hit_t = 3.0  # levou tiro → ameaçada: sobe p/ escapar (janela decai no _physics_process)
	show_health_hud()
	if health <= 0:
		_dead = true
		hide_health_hud()
		if _is_server():
			await get_tree().create_timer(4.0).timeout
			queue_free()


func show_health_hud(distance: float = -1.0) -> void:
	if _dead or DisplayServer.get_name() == "headless":
		return
	# `self` (e não a cena atual): o HUD nasce no viewport DESTA sala — ver enemy_health_bar.gd.
	var hud = preload("res://controls2D/enemy_health_bar.gd").get_shared(self)
	if hud == null:
		return
	hud.show_enemy(enemy_name, maxi(health, 0), max_health, distance)


func hide_health_hud() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var hud = preload("res://controls2D/enemy_health_bar.gd").get_shared(self)
	if hud != null:
		hud.hide_now()


# Player VIVO mais próximo dentro do escopo (a própria sala) — qualquer inimigo mira o mais perto DELE.
func _find_nearest_player(scope: Node) -> Node3D:
	var candidates: Array[Node3D] = []
	_collect_players(scope, candidates)
	var best: Node3D = null
	var best_d := INF
	var here := global_position
	for p in candidates:
		# Facção: só mira o lado OPOSTO (inimigo). Dinâmico → reage a neutros provocados.
		if not Factions.are_enemies(self, p):
			continue
		var d := here.distance_to(p.global_position)
		if d < best_d:
			best_d = d
			best = p
	return best


func _collect_players(n: Node, out: Array[Node3D]) -> void:
	if n == null:
		return
	if n is Node3D and _is_player_candidate(n as Node3D):
		out.append(n as Node3D)
	for c in n.get_children():
		_collect_players(c, out)


func _is_player_candidate(body: Node3D) -> bool:
	return body != null and (body.name == "Target" \
		or (body.has_method(&"add_camera_shake_trauma") and body.has_method(&"hit")))


func _player_velocity() -> Vector3:
	if _player == null:
		return Vector3.ZERO
	if _player is CharacterBody3D:
		return (_player as CharacterBody3D).velocity
	var raw: Variant = _player.get("velocity")
	return raw if raw is Vector3 else Vector3.ZERO

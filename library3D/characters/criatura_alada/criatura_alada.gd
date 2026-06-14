extends CharacterBody3D
## Criatura alada motorizada — inimigo voador.
## Quando há um player na cena, alça voo até a altitude de cruzeiro (~20 m),
## orbita o player com voo suave (subidas e descidas suaves, mais lento que o
## real) e libera bombas miradas pelo compartimento frontal. Cada bomba tira
## 50 HP ao acertar o player (que tem tempo de desviar durante a queda).
## Pode ser abatida a tiros (tem vida própria). Lógica server-autoritária.

const Bomb: PackedScene = preload("res://library3D/weapons/bomb/bomb.tscn")
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
var _yaw := 0.0
var _phase := Phase.CLIMB
var _bomb_cd := 0.0
var _scan_cd := 0.0
var _player: Node3D = null
var _dead := false

@onready var _rig: Node3D = $Rig
@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _bay: Node3D = $BombBay


func _ready() -> void:
	_yaw = rotation.y
	_bomb_cd = bomb_interval
	if _anim and _anim.has_animation("voar"):
		_anim.play("voar")


func _is_server() -> bool:
	if not is_inside_tree():
		return false
	if multiplayer == null:
		return true
	return multiplayer.is_server()


func _physics_process(delta: float) -> void:
	if not auto_fly:
		return
	# Clientes não simulam: o servidor é autoritativo (a posição é replicada).
	if not _is_server():
		return

	if _dead:
		velocity.y -= BOMB_GRAVITY * delta
		move_and_slide()
		return

	_t += delta

	# procura o player periodicamente
	_scan_cd -= delta
	if _scan_cd <= 0.0:
		_scan_cd = 1.0
		var scene: Node = get_tree().current_scene
		if scene == null:
			scene = get_tree().root
		_player = _find_player(scene)

	# sem player → repouso: paira no lugar (bom para preview/navegador de modelos)
	if _player == null:
		_phase = Phase.CLIMB
		velocity = Vector3.UP * (bob_amplitude * bob_freq * cos(_t * bob_freq))
		move_and_slide()
		return

	# ---- direção horizontal: orbitar o player no raio desejado
	var to_self := global_position - _player.global_position
	to_self.y = 0.0
	var dist := to_self.length()
	var radial := to_self.normalized() if dist > 0.01 else Vector3.BACK
	var tangent := Vector3(-radial.z, 0.0, radial.x)             # perpendicular (sentido da órbita)
	var radial_err := dist - orbit_radius
	var horiz := tangent * cruise_speed - radial * clampf(radial_err, -cruise_speed, cruise_speed)

	# ---- vertical: subir até a altitude de cruzeiro, depois oscilar suave
	var vy := 0.0
	if _phase == Phase.CLIMB:
		var dy := cruise_altitude - global_position.y
		if dy <= 0.4:
			_phase = Phase.PATROL
			_t = 0.0
		vy = clampf(dy * 2.0, -climb_speed, climb_speed)
		horiz *= 0.6   # sobe mais reto
	else:
		vy = bob_amplitude * bob_freq * cos(_t * bob_freq) + (cruise_altitude - global_position.y) * 0.6

	# ---- orientação (frente -Z aponta para onde voa) + banking ao curvar
	if horiz.length() > 0.05:
		look_at(global_position + Vector3(horiz.x, 0.0, horiz.z), Vector3.UP)
	var heading := atan2(horiz.x, horiz.z)
	var dyaw := wrapf(heading - _yaw, -PI, PI)
	_yaw = heading
	if _rig:
		var tb := clampf(-dyaw / maxf(delta, 0.0001) / 2.0, -1.0, 1.0) * bank_max
		_rig.rotation.z = lerpf(_rig.rotation.z, tb, delta * 2.5)

	velocity = horiz + Vector3.UP * vy
	move_and_slide()

	# ---- bombardeio (apenas em cruzeiro)
	if _phase == Phase.PATROL:
		_bomb_cd -= delta
		if _bomb_cd <= 0.0:
			_bomb_cd = bomb_interval
			_drop_bomb()


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
		var h: float = maxf(origin.y - _player.global_position.y, 1.0)
		var t: float = sqrt(2.0 * h / BOMB_GRAVITY)
		var disp: Vector3 = _player.global_position - origin
		disp.y = 0.0
		horiz = (disp / t).limit_length(bomb_lead_max)
	if bomb.has_method("set_initial_velocity"):
		bomb.set_initial_velocity(horiz + Vector3.DOWN * 1.0)


@rpc("call_local")
func hit(amount: int = 50) -> void:
	if _dead:
		return
	health = maxi(health - amount, 0)
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
	var hud = preload("res://library3D/characters/enemies/enemy_health_bar.gd").get_shared(get_tree().current_scene)
	hud.show_enemy(enemy_name, maxi(health, 0), max_health, distance)


func hide_health_hud() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var hud = preload("res://library3D/characters/enemies/enemy_health_bar.gd").get_shared(get_tree().current_scene)
	hud.hide_now()


func _find_player(n: Node) -> Node3D:
	if n == null:
		return null
	if n is Player:
		return n
	for c in n.get_children():
		var r := _find_player(c)
		if r != null:
			return r
	return null

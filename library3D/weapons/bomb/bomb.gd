extends CharacterBody3D
## Bomba lançada pela criatura alada pelo compartimento frontal.
## Cai por gravidade; ao acertar o player causa `damage` de HP; explode ao
## tocar qualquer coisa (player ou cenário) ou ao fim do tempo de vida.
## Server-autoritária (espelha o padrão do bullet do projeto).

@export var damage: int = 50
@export var fall_gravity: float = 18.0   ## queda com peso (um pouco acima do real)
@export var life_time: float = 8.0

var dropper: Node = null
var _done := false

@onready var _mesh: Node3D = $Mesh
@onready var _col: CollisionShape3D = $CollisionShape3D
@onready var _explosion: CPUParticles3D = $Explosion
@onready var _boom: AudioStreamPlayer3D = $Boom


func _ready() -> void:
	# Projétil → grupo usado para a aniquilação mútua projétil×projétil (ver _physics_process).
	add_to_group(&"projectiles")
	# Clientes não simulam — a posição é replicada pelo servidor.
	if not _is_server():
		set_physics_process(false)


func set_initial_velocity(v: Vector3) -> void:
	velocity = v


# Aniquilação mútua projétil×projétil: detona a bomba (sem dano a player). Idempotente (_done).
func annihilate() -> void:
	_explode(null)


func _physics_process(delta: float) -> void:
	if _done:
		return
	life_time -= delta
	if life_time <= 0.0:
		_explode(null)
		return
	velocity.y -= fall_gravity * delta
	if _mesh:
		_mesh.rotate_x(2.0 * delta)
	var col := move_and_collide(velocity * delta)
	if col:
		var collided := col.get_collider() as Node
		# Projétil × projétil → explosão anulativa (ambos se destroem). Idempotente.
		if collided != null and collided.is_in_group(&"projectiles"):
			annihilate()
			if collided.has_method(&"annihilate"):
				collided.annihilate()
			return
		_explode(collided)


func _explode(collider: Node) -> void:
	if _done:
		return
	_done = true
	# Dano ao player (o servidor decide).
	if _is_server() and collider != null and collider is Player and collider.has_method(&"hit"):
		collider.hit.rpc(damage)
	_detonate.rpc()


@rpc("call_local")
func _detonate() -> void:
	velocity = Vector3.ZERO
	if _mesh:
		_mesh.visible = false
	if _col:
		_col.set_deferred(&"disabled", true)
	if _explosion:
		_explosion.emitting = true
	if _boom:
		_boom.play()
	if _is_server():
		await get_tree().create_timer(1.5).timeout
		queue_free()


func _is_server() -> bool:
	if not is_inside_tree():
		return false
	if multiplayer == null:
		return true
	return multiplayer.is_server()

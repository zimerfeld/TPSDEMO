extends CharacterBody3D


const BULLET_VELOCITY: float = 20.0

var time_alive: float = 5.0
var hit: bool = false

# Dano da arma que disparou (atribuído pelo atirador ao instanciar).
var weapon_damage: int = 50
# Quem disparou — evita dano ao próprio atirador (o bullet nasce dentro dele).
var shooter: Node = null
# Garante que o dano seja aplicado uma única vez (área ou fallback).
var _registered: bool = false

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var omni_light: OmniLight3D = $OmniLight3D


func _ready() -> void:
	# Sem atirador = bullet inerte: o "BulletCache" pré-instanciado na cena do
	# player (warm-up) e os bullets replicados em clientes (shooter não replica).
	if shooter == null or not multiplayer.is_server():
		set_physics_process(false)
		collision_shape.disabled = true


func _physics_process(delta: float) -> void:
	if hit:
		return
	time_alive -= delta
	if time_alive < 0.0:
		hit = true
		explode.rpc()
		return
	var displacement: Vector3 = -delta * BULLET_VELOCITY * transform.basis.z
	var col: KinematicCollision3D = move_and_collide(displacement)
	if col:
		var collider: Node3D = col.get_collider() as Node3D
		# Acertou o corpo de um personagem sem uma hitbox de membro específica
		# ter registrado: aplica dano de TRONCO (1x) como fallback (deferido para
		# dar chance às Area3D de membro registrarem no mesmo frame).
		if collider and collider.has_method(&"hit") and collider != shooter:
			_fallback_body_damage.call_deferred(collider)
		hit = true
		explode.rpc()
		# set_deferred: mantém a shape ativa neste frame para as áreas detectarem.
		collision_shape.set_deferred(&"disabled", true)


# Chamado por uma Area3D de hitbox de membro (dano localizado).
func register_hit(target: Node, multiplier: float) -> void:
	if _registered:
		return
	_registered = true
	if multiplayer.is_server() and target and target.has_method(&"hit"):
		target.hit.rpc(int(round(weapon_damage * multiplier)))
	if not hit:
		hit = true
		explode.rpc()
		collision_shape.set_deferred(&"disabled", true)


# Fallback de dano de corpo (tronco, 1x) se nenhuma hitbox de membro registrou.
func _fallback_body_damage(target: Node) -> void:
	if _registered:
		return
	_registered = true
	if multiplayer.is_server() and target and target.has_method(&"hit"):
		target.hit.rpc(weapon_damage)


@rpc("call_local")
func explode() -> void:
	animation_player.play(&"explode")

	# Only enable shadows for the explosion, as the moving light
	# is very small and doesn't noticeably benefit from shadow mapping.
	if Settings.config_file.get_value("rendering", "shadow_mapping"):
		omni_light.shadow_enabled = true


func destroy() -> void:
	if not multiplayer.is_server():
		return
	queue_free()

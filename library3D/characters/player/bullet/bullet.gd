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
		_apply_hit(col.get_collider() as Node)
		hit = true
		explode.rpc()
		collision_shape.set_deferred(&"disabled", true)


# Aplica o dano do acerto físico (servidor). Se o collider for um collider de
# MEMBRO (StaticBody3D com metas "damage_multiplier"/"character"), usa o
# multiplicador localizado e atinge o personagem dono (cabeça = +50%); senão, se
# for o próprio corpo do personagem, aplica dano de TRONCO (1x) como fallback.
func _apply_hit(collider: Node) -> void:
	if _registered or not multiplayer.is_server() or collider == null:
		return
	if collider.has_meta("damage_multiplier") and collider.has_meta("character"):
		var character: Node = collider.get_meta("character")
		if character == shooter or character == null or not character.has_method(&"hit"):
			return
		_registered = true
		var mult: float = collider.get_meta("damage_multiplier")
		character.hit.rpc(int(round(weapon_damage * mult)))
	elif collider.has_method(&"hit") and collider != shooter:
		_registered = true
		collider.hit.rpc(weapon_damage)


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

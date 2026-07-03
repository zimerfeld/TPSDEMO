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
var _feedback_reported: bool = false

# Aparência configurável (CannonShooter passa estes ao disparar), para o MESMO bullet
# servir vários modelos. Alpha <= 0 = sentinela "não mexer" (mantém o visual da cena, o
# tiro azul do player). tint = cor do EFEITO (luz + rastro); ball_color = cor da BALA;
# ball_scale = multiplicador de tamanho da bala (calibre).
var tint: Color = Color(0, 0, 0, 0)
var ball_color: Color = Color(0, 0, 0, 0)
var ball_scale: float = 1.0

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var omni_light: OmniLight3D = $OmniLight3D


func _ready() -> void:
	# Projétil → grupo usado para detectar colisão projétil×projétil (aniquilação mútua).
	add_to_group(&"projectiles")
	# Recolore/redimensiona em TODOS os peers (o visual aparece em todo mundo).
	_apply_visuals()
	# Sem atirador = bullet inerte: o "BulletCache" pré-instanciado na cena do
	# player (warm-up) e os bullets replicados em clientes (shooter não replica).
	if shooter == null or not multiplayer.is_server():
		set_physics_process(false)
		collision_shape.disabled = true


# Aplica tint/cor/escala configurados. Sentinela (alpha 0) mantém o visual autorado.
func _apply_visuals() -> void:
	if tint.a > 0.0:
		omni_light.light_color = tint
		for p in [$BulletBody/MainBody, $BulletBody/Trail]:
			(p as CPUParticles3D).color = tint
	if ball_color.a > 0.0:
		var mi: MeshInstance3D = $MeshInstance3D
		var mat := mi.material_override
		if mat is StandardMaterial3D:
			mat = mat.duplicate()
			(mat as StandardMaterial3D).albedo_color = ball_color
			mi.material_override = mat
	if not is_equal_approx(ball_scale, 1.0):
		$MeshInstance3D.scale *= ball_scale


func _physics_process(delta: float) -> void:
	if hit:
		return
	time_alive -= delta
	if time_alive < 0.0:
		_report_feedback(null)
		hit = true
		explode.rpc()
		return
	var displacement: Vector3 = -delta * BULLET_VELOCITY * transform.basis.z
	var col: KinematicCollision3D = move_and_collide(displacement)
	if col:
		var collided := col.get_collider() as Node
		# Projétil × projétil (bala, bala de canhão ou bomba) → explosão ANULATIVA: ambos se
		# destroem. Checado antes de tudo; idempotente nos dois lados (guardas hit/_done).
		if collided != null and collided.is_in_group(&"projectiles"):
			_report_feedback(null)
			annihilate()
			if collided.has_method(&"annihilate"):
				collided.annihilate()
			return
		# A character's generic BODY collider (e.g. the enemy's body capsule/sphere) wraps
		# the whole figure, so it would be struck before the per-limb colliders that hug the
		# mesh — dealing flat 1× damage and defeating localized damage (no headshots). When the
		# hit body owns localized limb colliders, phase the bullet through it (collision
		# exception) and keep flying, so the shot lands on the actual limb collider behind it.
		# Bodies without limb colliders keep the normal hit-and-explode behavior.
		if collided is CharacterBody3D and collided.has_node(^"LimbColliders"):
			add_collision_exception_with(collided)
			return
		_apply_hit(collided)
		_report_feedback(_resolve_feedback_target(collided))
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


# Aniquilação mútua: explode e desativa a colisão (mesmo desfecho de um acerto). Idempotente.
# Chamado pelo servidor quando dois projéteis colidem (ver _physics_process / bomb.gd).
func annihilate() -> void:
	if hit:
		return
	_report_feedback(null)
	hit = true
	explode.rpc()
	collision_shape.set_deferred(&"disabled", true)


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


func _resolve_feedback_target(collider: Node) -> Node:
	if collider == null:
		return null
	if collider.has_meta("character"):
		return collider.get_meta("character") as Node
	return collider


func _report_feedback(target: Node) -> void:
	if _feedback_reported or not multiplayer.is_server() or shooter == null:
		return
	_feedback_reported = true
	if shooter.has_method(&"notify_projectile_feedback"):
		shooter.notify_projectile_feedback(target)

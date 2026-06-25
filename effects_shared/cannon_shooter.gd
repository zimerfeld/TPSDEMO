class_name CannonShooter
extends RefCounted

## Reusable cannon-bullet shooter — isolates the "spawn a flying bullet" behavior so any
## 3D model (player, enemies, …) can fire the shared bullet (bullet.tscn) without copying
## the spawn/positioning/collision-exclusion code. The bullet itself does the localized
## damage on impact (see bullet.gd / LimbColliders); this helper only launches it.
##
## Usage (server, or local prediction):
##   CannonShooter.fire(get_parent(), origin, dir, weapon_damage, self)                # default blue
##   CannonShooter.fire(get_parent(), origin, dir, dmg, self, Color(1,0.1,0.1), Color(0.02,0.02,0.02,1), 2.5)
##
## Color params are optional — alpha 0 keeps the bullet's authored look (the blue player
## shot). tint recolors the EFFECT (light + trail); ball_color recolors the BALL; ball_scale
## sizes it (a bigger black sphere reads as a cannon ball).

const BULLET_SCENE: PackedScene = preload("res://library3D/characters/player/bullet/bullet.tscn")


# Spawn and launch a bullet from `origin` along `dir`, owned by `shooter`, added under
# `parent`. Returns the bullet (or null if it couldn't be created). Excludes the shooter's
# own body and per-limb colliders so the shot never hits the one who fired it.
static func fire(parent: Node, origin: Vector3, dir: Vector3, damage: int, shooter: Node,
		tint: Color = Color(0, 0, 0, 0), ball_color: Color = Color(0, 0, 0, 0), ball_scale: float = 1.0) -> Node:
	if parent == null or dir.length_squared() < 0.0001:
		return null
	var bullet: CharacterBody3D = BULLET_SCENE.instantiate()
	bullet.weapon_damage = damage
	bullet.shooter = shooter
	bullet.tint = tint
	bullet.ball_color = ball_color
	bullet.ball_scale = ball_scale
	# Posição+orientação do cano DEFINIDAS ANTES do add_child. O `global_transform` da bala é uma
	# spawn property (ver bullet.tscn); o MultiplayerSpawner tira o snapshot de spawn NO add_child.
	# Setar o transform DEPOIS (como era) fazia o pacote de spawn carregar a origem PADRÃO da cena
	# → no cliente a bala nascia fora do cano (deslocada) até o 1º sync corrigir. Montamos o
	# transform no mundo e convertemos para o espaço do `parent` (SpawnedNodes), cobrindo o caso
	# de o pai não estar na origem.
	var n_dir: Vector3 = dir.normalized()
	# `up` não-paralelo à direção (tiro vertical pro alto/baixo quebraria o looking_at com Y).
	var up: Vector3 = Vector3.UP if absf(n_dir.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	var world: Transform3D = Transform3D(Basis(), origin).looking_at(origin + n_dir, up)
	bullet.transform = parent.global_transform.affine_inverse() * world
	# add_child(..., true) gives a stable name for the MultiplayerSynchronizer.
	parent.add_child(bullet, true)
	# Never collide with the shooter or its own limb hitboxes (the bullet is born inside it).
	if shooter is PhysicsBody3D:
		bullet.add_collision_exception_with(shooter)
	if shooter != null:
		var lc: Node = shooter.get_node_or_null(^"LimbColliders")
		if lc != null and lc.has_method(&"get_limb_bodies"):
			for body in lc.get_limb_bodies():
				bullet.add_collision_exception_with(body)
	return bullet

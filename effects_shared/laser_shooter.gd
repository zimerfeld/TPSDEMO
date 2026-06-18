class_name LaserShooter
extends RefCounted

## Reusable hitscan LASER shooter — isolates the instant-hit laser fire (raycast + localized
## damage + beam clip + impact blast) so any 3D model can reuse it. Extracted from
## red_robot's original laser (red_robot now fires a cannon ball via CannonShooter, but this
## stays available for other models that want a hitscan beam).
##
## Usage (server decides damage):
##   LaserShooter.fire(muzzle_node, beam_mesh, blast_scene, damage, hitbox_layer, [self])


# Fire a hitscan laser from `muzzle` (its -Z is the beam direction):
#  - clips `beam_mesh`'s "clip" shader param to the hit distance (so the beam stops on impact),
#  - spawns `blast_scene` at the impact point,
#  - applies LOCALIZED damage to a character whose member collider (on `hitbox_layer`) is hit
#    (head = +50% via the collider's "damage_multiplier" meta).
# `exclude` are bodies the rays ignore (e.g. the shooter itself). Returns the hit distance.
static func fire(muzzle: Node3D, beam_mesh: MeshInstance3D, blast_scene: PackedScene,
		damage: int, hitbox_layer: int, exclude: Array = []) -> float:
	if muzzle == null or not muzzle.is_inside_tree():
		return 0.0
	var gt := muzzle.global_transform
	var origin := gt.origin
	var dir := -gt.basis.z
	var max_dist := 1000.0
	var space := muzzle.get_world_3d().direct_space_state

	# General hit (walls/bodies, any layer) to clip the beam and place the blast.
	var col := space.intersect_ray(
		PhysicsRayQueryParameters3D.create(origin, origin + dir * max_dist, 0xFFFFFFFF, exclude))
	if not col.is_empty():
		max_dist = origin.distance_to(col.position)

	# Localized damage: a second ray against the member-collider layer only. Only deals
	# damage if it actually hits a member (the collider carries the damage multiplier + owner).
	var hq := PhysicsRayQueryParameters3D.create(origin, origin + dir * (max_dist + 0.5), hitbox_layer, exclude)
	hq.collide_with_bodies = true
	hq.collide_with_areas = false
	var hb := space.intersect_ray(hq)
	if not hb.is_empty() and hb.collider != null and hb.collider.has_meta("damage_multiplier") \
			and hb.collider.has_meta("character"):
		var character = hb.collider.get_meta("character")
		if character != null and character.has_method("hit"):
			var mult: float = hb.collider.get_meta("damage_multiplier")
			character.hit.rpc(int(round(damage * mult)))

	# Clip the beam mesh to the hit distance via its shader's "clip" parameter.
	if beam_mesh != null:
		var mesh_offset: float = beam_mesh.position.z
		var mat := beam_mesh.get_surface_override_material(0)
		if mat != null:
			mat.set_shader_parameter("clip", max_dist + mesh_offset)

	# Impact blast at the hit point.
	if blast_scene != null and not col.is_empty():
		var blast := blast_scene.instantiate()
		muzzle.get_tree().get_root().add_child(blast)
		(blast as Node3D).global_transform.origin = col.position

	return max_dist

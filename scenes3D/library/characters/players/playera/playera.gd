class_name Playera
extends Player


func _ready() -> void:
	super._ready()
	_apply_playera_skin.call_deferred()


func _apply_playera_skin() -> void:
	if player_model == null:
		return
	for mi in player_model.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := mi as MeshInstance3D
		for i in mesh_inst.get_surface_override_material_count():
			var orig: Material = mesh_inst.mesh.surface_get_material(i)
			if orig is BaseMaterial3D:
				var mat := orig.duplicate() as BaseMaterial3D
				mat.albedo_color = Color(
					mat.albedo_color.r,
					mat.albedo_color.g * 0.55,
					mat.albedo_color.b * 0.65,
					mat.albedo_color.a
				)
				mesh_inst.set_surface_override_material(i, mat)

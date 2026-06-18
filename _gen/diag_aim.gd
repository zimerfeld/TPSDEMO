extends SceneTree


func _init() -> void:
	var scene: PackedScene = load("res://library3D/characters/player/player.glb")
	var inst := scene.instantiate()
	get_root().add_child(inst)
	var aps: Array = inst.find_children("*", "AnimationPlayer", true, false)
	if aps.is_empty():
		print("NO ANIMATIONPLAYER")
		quit()
		return
	var ap := aps[0] as AnimationPlayer
	print("animations: ", ap.get_animation_list())

	for clip_name in ["AIM-Up", "AIM-Down"]:
		if not ap.has_animation(clip_name):
			print(clip_name, " : MISSING")
			continue
		var anim := ap.get_animation(clip_name)
		print("=== ", clip_name, " (len=", anim.length, ") ===")
		for t in anim.get_track_count():
			var path := str(anim.track_get_path(t))
			if not (path.contains("upper_arm.R") or path.contains("neck.001")):
				continue
			if anim.track_get_type(t) != Animation.TYPE_ROTATION_3D:
				print("  ", path, " type=", anim.track_get_type(t))
				continue
			var n := anim.track_get_key_count(t)
			for ki in n:
				var q: Quaternion = anim.rotation_track_interpolate(t, anim.track_get_key_time(t, ki))
				var e := Vector3(q.get_euler() * 180.0 / PI)
				print("  ", path, " key", ki, " t=", anim.track_get_key_time(t, ki),
					" euler=(", "%.1f" % e.x, ",", "%.1f" % e.y, ",", "%.1f" % e.z, ")")
	quit()

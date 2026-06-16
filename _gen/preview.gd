extends Node3D
## Previewer headless-ish: instancia PREVIEW_PATH com luz + câmera (vista 3/4
## frontal), toca a 1ª animação, espera alguns frames e SALVA um PNG do viewport
## em res://_gen/shot.png (lido depois com a ferramenta Read). SHOW_MEMBERS desenha
## colliders+labels por membro (skeleton ou mesh).

const PREVIEW_PATH := "res://library3D/characters/demonio_rig2/demonio_rig2.tscn"
const SHOW_MEMBERS := false
const SHOT_PATH := "res://_gen/shot.png"
const LimbCollidersScript = preload("res://effects_shared/limb_colliders.gd")
const BodyPartsScript = preload("res://effects_shared/body_parts.gd")


func _ready() -> void:
	get_window().size = Vector2i(900, 900)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.45, 0.48, 0.54)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.72, 0.78)
	e.ambient_light_energy = 1.3
	e.glow_enabled = true
	e.glow_intensity = 0.8
	e.glow_bloom = 0.2
	env.environment = e
	add_child(env)

	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-32.0), deg_to_rad(200.0), 0.0)
	key.light_energy = 1.6
	add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-10.0), deg_to_rad(20.0), 0.0)
	fill.light_energy = 0.4
	add_child(fill)

	_inst = load(PREVIEW_PATH).instantiate()
	add_child(_inst)
	if not SHOW_MEMBERS:
		_inst.add_to_group("no_debug_overlay")   # captura limpa (sem labels de debug)
	for ap in _inst.find_children("*", "AnimationPlayer", true, false):
		_player = ap as AnimationPlayer

	if SHOW_MEMBERS:
		_build_members(_inst)

	var aabb := _aabb(_inst)
	var cam := Camera3D.new()
	cam.fov = 38.0
	var c := aabb.get_center()
	var r: float = maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	# Vista 3/4 frontal (frente do modelo = -Z, então câmera no lado -Z).
	cam.position = c + Vector3(r * 0.75, r * 0.12, -r * 1.7)
	cam.current = true
	add_child(cam)
	cam.look_at(c, Vector3.UP)

	_capture()


var _inst: Node
var _player: AnimationPlayer


func _capture() -> void:
	# Uma captura por animação (pose representativa de cada uma).
	var poses := {"walk": 0.28, "run": 0.18, "jump": 0.45}
	if _player != null:
		for anim in _player.get_animation_list():
			var dur: float = _player.get_animation(anim).length
			var t: float = poses.get(anim, dur * 0.3)
			_player.play(anim)
			_player.seek(t, true)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.save_png("res://_gen/shot_%s.png" % anim)
			print("SHOT_SAVED %s" % anim)
	# Também salva o arquivo padrão (sinaliza fim).
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(SHOT_PATH)
	print("SHOT_DONE")
	get_tree().quit()


func _build_members(inst: Node) -> void:
	var skels: Array = inst.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		var lc = LimbCollidersScript.new()
		lc.hitbox_layer = 64
		lc.padding = 0.04
		add_child(lc)
		lc.build_for(skels[0] as Skeleton3D)
	var giz := StandardMaterial3D.new()
	giz.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	giz.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	giz.cull_mode = BaseMaterial3D.CULL_DISABLED
	giz.albedo_color = Color(0.2, 1.0, 0.4, 0.30)
	for node in inst.find_children("*", "CollisionShape3D", true, false):
		var cs := node as CollisionShape3D
		if cs.shape == null:
			continue
		var gizmo := MeshInstance3D.new()
		gizmo.mesh = cs.shape.get_debug_mesh()
		gizmo.material_override = giz
		cs.add_child(gizmo)
	for node in inst.find_children("*", "StaticBody3D", true, false):
		var body := node as StaticBody3D
		if not body.has_meta("member_label"):
			continue
		var lbl := Label3D.new()
		lbl.text = str(body.get_meta("member_label"))
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.no_depth_test = true
		lbl.fixed_size = true
		lbl.pixel_size = 0.0007
		lbl.modulate = Color(1.0, 0.85, 0.2)
		lbl.outline_size = 10
		body.add_child(lbl)


func _aabb(node: Node) -> AABB:
	var out := AABB()
	var first := true
	for n in node.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var b := mi.global_transform * mi.get_aabb()
		if first:
			out = b
			first = false
		else:
			out = out.merge(b)
	if first:
		return AABB(Vector3.ZERO, Vector3.ONE)
	return out

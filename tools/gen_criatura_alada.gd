extends SceneTree
# Gerador headless: criatura alada motorizada (<= 2 m), animada, com som e textura.
# Raiz CharacterBody3D + colisão + script de voo (inimigo voador).
# Uso: Godot --headless --path <projeto> --script res://tools/gen_criatura_alada.gd

const OUT_DIR := "res://library3D/characters/criatura_alada"
const REL_DIR := "library3D/characters/criatura_alada"
const TSCN := OUT_DIR + "/criatura_alada.tscn"
const PNG := OUT_DIR + "/criatura_alada_albedo.png"
const WAV := OUT_DIR + "/criatura_alada_motor.wav"
const GD := OUT_DIR + "/criatura_alada.gd"

var _root: Node3D


func _initialize() -> void:
	var da := DirAccess.open("res://")
	da.make_dir_recursive(REL_DIR)

	var img := _make_texture(256)
	var perr := img.save_png(PNG)
	print("PNG err=", perr)
	var tex := ImageTexture.create_from_image(img)

	var wav := _make_motor_wav()
	var werr := wav.save_to_wav(WAV)
	print("WAV err=", werr)

	var root := _build(tex, wav)
	_set_owner(root, root)
	var packed := PackedScene.new()
	print("pack err=", packed.pack(root))
	print("SAVE err=", ResourceSaver.save(packed, TSCN))

	var aabb := _scene_aabb(root)
	print("ALTURA(m)=", aabb.size.y, "  largura(m)=", aabb.size.x)
	quit()


# ---------------------------------------------------------------- textura
func _make_texture(s: int) -> Image:
	var img := Image.create_empty(s, s, false, Image.FORMAT_RGB8)
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.frequency = 0.04
	n.seed = 7331
	var grime := FastNoiseLite.new()
	grime.noise_type = FastNoiseLite.TYPE_SIMPLEX
	grime.frequency = 0.012
	grime.seed = 99
	var steel_a := Color(0.26, 0.30, 0.36)
	var steel_b := Color(0.58, 0.62, 0.68)
	var grime_c := Color(0.16, 0.20, 0.22)
	var seam := Color(0.06, 0.07, 0.09)
	for y in s:
		for x in s:
			var v := (n.get_noise_2d(x, y) + 1.0) * 0.5
			v = pow(v, 0.8)
			var c := steel_a.lerp(steel_b, v)
			var g := (grime.get_noise_2d(x, y) + 1.0) * 0.5
			if g > 0.62:
				c = c.lerp(grime_c, (g - 0.62) * 2.2)
			var mx := x % 64
			var my := y % 64
			if mx < 2 or my < 2:
				c = c.lerp(seam, 0.85)
			if mx < 6 and my < 6:
				if Vector2(mx - 3, my - 3).length() < 2.2:
					c = c.lerp(Color(0.8, 0.83, 0.88), 0.7)
			img.set_pixel(x, y, c)
	return img


# ---------------------------------------------------------------- som (motor grave)
func _make_motor_wav() -> AudioStreamWAV:
	var rate := 22050
	var f0 := 75.0           # mais grave; 75 Hz * 0.6 s = 45 ciclos (loop perfeito)
	var dur := 0.6
	var frames := int(rate * dur)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var t := float(i) / rate
		var fund := sin(TAU * t * f0)
		var h2 := 0.5 * sin(TAU * t * f0 * 2.0)
		var ph := fmod(t * f0, 1.0)
		var saw := 2.0 * ph - 1.0
		var throb := 0.78 + 0.22 * sin(TAU * t * 5.0)   # pulsação lenta (5 Hz -> 3 ciclos)
		var s := (0.6 * fund + 0.25 * h2 + 0.15 * saw) * throb * 0.6
		s = clampf(s, -1.0, 1.0)
		data.encode_s16(i * 2, int(s * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.stereo = false
	w.mix_rate = rate
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = frames
	return w


# ---------------------------------------------------------------- materiais
func _mat(albedo: Color, metallic: float, rough: float, tex: Texture2D = null, uv := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.metallic = metallic
	m.roughness = rough
	if tex:
		m.albedo_texture = tex
		m.uv1_scale = Vector3(uv, uv, 1.0)
	return m


func _glow(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


# ---------------------------------------------------------------- helpers de malha
func _mi(parent: Node, nm: String, mesh: Mesh, mat: Material, pos: Vector3,
		rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _pivot(parent: Node, nm: String, pos: Vector3) -> Node3D:
	var p := Node3D.new()
	p.name = nm
	p.position = pos
	parent.add_child(p)
	return p


func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new(); m.radius = r; m.height = h; return m


func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new(); m.radius = r; m.height = r * 2.0; return m


func _box(sz: Vector3) -> BoxMesh:
	var m := BoxMesh.new(); m.size = sz; return m


func _cyl(rt: float, rb: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new(); m.top_radius = rt; m.bottom_radius = rb; m.height = h; return m


func _prism(sz: Vector3) -> PrismMesh:
	var m := PrismMesh.new(); m.size = sz; return m


# ---------------------------------------------------------------- construção
func _build(tex: Texture2D, wav: AudioStreamWAV) -> Node3D:
	var root := CharacterBody3D.new()
	root.name = "CriaturaAlada"
	root.collision_layer = 2   # bit2 — atingível pelos tiros do player (bullet mask=3)
	root.collision_mask = 1    # colide com o mundo (bit1)
	root.set_script(load(GD))
	_root = root

	# colisão (cápsula do corpo) — para usar como inimigo
	var col := CollisionShape3D.new()
	col.name = "Collision"
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.6
	col.shape = cap
	col.position = Vector3(0, 0.95, 0)
	root.add_child(col)

	# ponto de soltura das bombas (compartimento frontal, ventre-frente = -Z)
	var bay := Marker3D.new()
	bay.name = "BombBay"
	bay.position = Vector3(0, 0.55, -0.3)
	root.add_child(bay)

	var rig := Node3D.new()
	rig.name = "Rig"
	root.add_child(rig)

	var body := _mat(Color(0.34, 0.38, 0.44), 0.9, 0.4, tex, 2.0)
	var dark := _mat(Color(0.11, 0.12, 0.15), 1.0, 0.3, tex, 3.0)
	var wing_mat := _mat(Color(0.16, 0.4, 0.42), 0.35, 0.6, tex, 1.0)
	var prop_mat := _mat(Color(0.08, 0.09, 0.11), 0.9, 0.25)
	var eye_mat := _glow(Color(1.0, 0.22, 0.1), 6.0)        # olhos vermelhos (inimigo)
	var exhaust_mat := _glow(Color(1.0, 0.5, 0.12), 7.0)    # escapamento laranja
	var intake_mat := _glow(Color(0.2, 0.8, 1.0), 4.0)      # tomada de motor ciano

	# ---- tronco (mais esguio)
	_mi(rig, "Torso", _capsule(0.3, 1.0), body, Vector3(0, 1.0, 0), Vector3.ZERO, Vector3(1, 1, 0.8))
	_mi(rig, "Chest", _box(Vector3(0.42, 0.46, 0.2)), dark, Vector3(0, 1.06, -0.24))
	_mi(rig, "Pelvis", _capsule(0.2, 0.36), body, Vector3(0, 0.55, 0))

	# ---- compartimento frontal de bombas (ventre-frente)
	_mi(rig, "BombHatch", _box(Vector3(0.3, 0.18, 0.1)), dark, Vector3(0, 0.62, -0.26))
	_mi(rig, "BombHatchGlow", _box(Vector3(0.26, 0.03, 0.02)), exhaust_mat, Vector3(0, 0.62, -0.31))

	# ---- cabeça (menor)
	_mi(rig, "Neck", _cyl(0.1, 0.12, 0.2), dark, Vector3(0, 1.5, -0.03))
	_mi(rig, "Head", _sphere(0.22), body, Vector3(0, 1.66, -0.04))
	_mi(rig, "Snout", _cyl(0.0, 0.12, 0.3), dark, Vector3(0, 1.63, -0.26), Vector3(-90, 0, 0))
	_mi(rig, "EyeL", _sphere(0.05), eye_mat, Vector3(0.095, 1.71, -0.2))
	_mi(rig, "EyeR", _sphere(0.05), eye_mat, Vector3(-0.095, 1.71, -0.2))
	_mi(rig, "AntL", _cyl(0.0, 0.018, 0.18), dark, Vector3(0.12, 1.78, 0.02), Vector3(20, 0, 18))
	_mi(rig, "AntR", _cyl(0.0, 0.018, 0.18), dark, Vector3(-0.12, 1.78, 0.02), Vector3(20, 0, -18))

	# ---- asas (pivôs nos ombros; mais altas e levemente recuadas; batem na animação)
	var lw := _pivot(rig, "LeftWing", Vector3(0.3, 1.42, 0.05))
	_mi(lw, "WingPlateL", _box(Vector3(1.0, 0.05, 0.6)), wing_mat, Vector3(0.6, 0, 0.06))
	_mi(lw, "WingRibL1", _cyl(0.02, 0.03, 0.95), dark, Vector3(0.58, 0.03, 0.22), Vector3(0, 0, 90))
	_mi(lw, "WingRibL2", _cyl(0.02, 0.03, 0.95), dark, Vector3(0.58, 0.03, -0.12), Vector3(0, 0, 90))
	_mi(lw, "WingTipL", _prism(Vector3(0.5, 0.05, 0.55)), wing_mat, Vector3(1.26, 0, 0.06), Vector3(0, 90, 90))

	var rw := _pivot(rig, "RightWing", Vector3(-0.3, 1.42, 0.05))
	_mi(rw, "WingPlateR", _box(Vector3(1.0, 0.05, 0.6)), wing_mat, Vector3(-0.6, 0, 0.06))
	_mi(rw, "WingRibR1", _cyl(0.02, 0.03, 0.95), dark, Vector3(-0.58, 0.03, 0.22), Vector3(0, 0, 90))
	_mi(rw, "WingRibR2", _cyl(0.02, 0.03, 0.95), dark, Vector3(-0.58, 0.03, -0.12), Vector3(0, 0, 90))
	_mi(rw, "WingTipR", _prism(Vector3(0.5, 0.05, 0.55)), wing_mat, Vector3(-1.26, 0, 0.06), Vector3(0, -90, 90))

	# ---- motores em pilones rígidos, BEM afastados (disco da hélice livre do corpo)
	_build_engine(rig, "EngineL", Vector3(0.92, 1.0, -0.12), 1.0, dark, prop_mat, intake_mat)
	_build_engine(rig, "EngineR", Vector3(-0.92, 1.0, -0.12), -1.0, dark, prop_mat, intake_mat)

	# ---- bloco de motor traseiro + escapamentos
	_mi(rig, "EngineBlock", _box(Vector3(0.42, 0.36, 0.32)), dark, Vector3(0, 1.12, 0.28))
	_mi(rig, "PipeL", _cyl(0.05, 0.06, 0.24), dark, Vector3(0.12, 0.98, 0.46), Vector3(70, 0, 0))
	_mi(rig, "PipeR", _cyl(0.05, 0.06, 0.24), dark, Vector3(-0.12, 0.98, 0.46), Vector3(70, 0, 0))
	_mi(rig, "ExhL", _sphere(0.05), exhaust_mat, Vector3(0.12, 0.93, 0.56))
	_mi(rig, "ExhR", _sphere(0.05), exhaust_mat, Vector3(-0.12, 0.93, 0.56))

	# ---- cauda (mais longa)
	_mi(rig, "Tail1", _capsule(0.08, 0.55), dark, Vector3(0, 0.78, 0.5), Vector3(62, 0, 0))
	_mi(rig, "TailFin", _prism(Vector3(0.04, 0.32, 0.36)), wing_mat, Vector3(0, 0.55, 0.84), Vector3(40, 0, 0))

	# ---- pernas
	_mi(rig, "ThighL", _capsule(0.08, 0.4), body, Vector3(0.16, 0.4, 0.02))
	_mi(rig, "ShinL", _cyl(0.055, 0.065, 0.3), dark, Vector3(0.18, 0.17, 0.04))
	_mi(rig, "FootL", _box(Vector3(0.18, 0.07, 0.32)), dark, Vector3(0.19, 0.04, 0.06))
	_mi(rig, "ThighR", _capsule(0.08, 0.4), body, Vector3(-0.16, 0.4, 0.02))
	_mi(rig, "ShinR", _cyl(0.055, 0.065, 0.3), dark, Vector3(-0.18, 0.17, 0.04))
	_mi(rig, "FootR", _box(Vector3(0.18, 0.07, 0.32)), dark, Vector3(-0.19, 0.04, 0.06))

	# ---- animação
	root.add_child(_build_anim())

	# ---- som do motor
	var audio := AudioStreamPlayer3D.new()
	audio.name = "Motor"
	audio.stream = wav
	audio.autoplay = true
	audio.unit_size = 4.0
	audio.max_distance = 35.0
	audio.volume_db = -4.0
	audio.position = Vector3(0, 1.05, 0.2)
	root.add_child(audio)

	return root


func _build_engine(rig: Node3D, nm: String, pos: Vector3, side: float,
		dark: Material, prop_mat: Material, intake_mat: Material) -> void:
	# pilone rígido do tronco até a pod
	var px := side * 0.58
	_mi(rig, nm + "Pylon", _box(Vector3(0.62, 0.1, 0.12)), dark, Vector3(px, pos.y, pos.z + 0.1))
	# nacele
	_mi(rig, nm + "Nacelle", _capsule(0.13, 0.5), dark, pos, Vector3(-90, 0, 0))
	# tomada brilhante na frente
	_mi(rig, nm + "Intake", _cyl(0.1, 0.1, 0.03), intake_mat, Vector3(pos.x, pos.y, pos.z - 0.27), Vector3(90, 0, 0))
	# hélice (pivô que gira)
	var prop := _pivot(rig, nm.replace("Engine", "Prop"), Vector3(pos.x, pos.y, pos.z - 0.4))
	_mi(prop, "Hub", _cyl(0.04, 0.05, 0.08), prop_mat, Vector3.ZERO, Vector3(90, 0, 0))
	for b in 3:
		var blade := _pivot(prop, "BladePivot%d" % b, Vector3.ZERO)
		blade.rotation_degrees = Vector3(0, 0, b * 120.0)
		_mi(blade, "Blade%d" % b, _box(Vector3(0.36, 0.06, 0.014)), prop_mat, Vector3(0.2, 0, 0))


# ---------------------------------------------------------------- animação
func _build_anim() -> AnimationPlayer:
	var a := Animation.new()
	a.length = 1.2
	a.loop_mode = Animation.LOOP_LINEAR

	_rot_track(a, "Rig/LeftWing", [
		[0.0, Vector3(0, 0, 0.18)], [0.6, Vector3(0, 0, -0.28)], [1.2, Vector3(0, 0, 0.18)]])
	_rot_track(a, "Rig/RightWing", [
		[0.0, Vector3(0, 0, -0.18)], [0.6, Vector3(0, 0, 0.28)], [1.2, Vector3(0, 0, -0.18)]])
	# hélices girando — mais suave (6 voltas por loop ~= 5 rps)
	_rot_track(a, "Rig/PropL", [[0.0, Vector3.ZERO], [1.2, Vector3(0, 0, TAU * 6.0)]])
	_rot_track(a, "Rig/PropR", [[0.0, Vector3.ZERO], [1.2, Vector3(0, 0, -TAU * 6.0)]])
	# leve flutuar local
	var bob := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(bob, NodePath("Rig:position"))
	a.value_track_set_update_mode(bob, Animation.UPDATE_CONTINUOUS)
	a.track_insert_key(bob, 0.0, Vector3(0, 0, 0))
	a.track_insert_key(bob, 0.6, Vector3(0, 0.05, 0))
	a.track_insert_key(bob, 1.2, Vector3(0, 0, 0))

	var lib := AnimationLibrary.new()
	lib.add_animation("voar", a)
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	ap.add_animation_library("", lib)
	ap.autoplay = "voar"
	return ap


func _rot_track(a: Animation, path: String, keys: Array) -> void:
	var t := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, NodePath(path + ":rotation"))
	a.track_set_interpolation_type(t, Animation.INTERPOLATION_LINEAR)
	for k in keys:
		a.track_insert_key(t, k[0], k[1])


# ---------------------------------------------------------------- util
func _set_owner(node: Node, owner: Node) -> void:
	for c in node.get_children():
		c.owner = owner
		_set_owner(c, owner)


func _scene_aabb(node: Node) -> AABB:
	var ab := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var world := _xform_to_root(m) * m.get_aabb()
		if first:
			ab = world
			first = false
		else:
			ab = ab.merge(world)
	return ab


func _xform_to_root(n: Node3D) -> Transform3D:
	var x := n.transform
	var p := n.get_parent()
	while p != null and p is Node3D and p != _root:
		x = (p as Node3D).transform * x
		p = p.get_parent()
	return x

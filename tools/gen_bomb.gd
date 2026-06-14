extends SceneTree
# Gera a bomb.tscn (projétil lançado pela criatura alada).

const OUT := "res://scenes3D/library/characters/criatura_alada/bomb.tscn"
const GD := "res://scenes3D/library/characters/criatura_alada/bomb.gd"
const BOOM := "res://scenes3D/library/characters/player/bullet/bullet_explode.wav"

var _root: Node


func _initialize() -> void:
	var root := CharacterBody3D.new()
	root.name = "Bomb"
	root.collision_layer = 8   # projétil
	root.collision_mask = 3    # mundo (bit1) + player (bit2)
	root.set_script(load(GD))
	_root = root

	# ---- visual
	var mesh := Node3D.new()
	mesh.name = "Mesh"
	root.add_child(mesh)

	var metal := _mat(Color(0.12, 0.13, 0.16), 0.95, 0.3)
	var band := _mat(Color(0.85, 0.65, 0.05), 0.5, 0.4)
	var tip := _glow(Color(1.0, 0.15, 0.08), 5.0)

	_mi(mesh, "Body", _capsule(0.12, 0.4), metal, Vector3.ZERO)
	_mi(mesh, "Band", _cyl(0.125, 0.125, 0.06), band, Vector3(0, 0.04, 0))
	_mi(mesh, "Nose", _cyl(0.0, 0.12, 0.18), metal, Vector3(0, -0.27, 0), Vector3(180, 0, 0))
	_mi(mesh, "Tip", _sphere(0.045), tip, Vector3(0, 0.22, 0))
	for f in 4:
		var fin := Node3D.new()
		fin.name = "FinPivot%d" % f
		fin.rotation_degrees = Vector3(0, f * 90.0, 0)
		mesh.add_child(fin)
		_mi(fin, "Fin%d" % f, _box(Vector3(0.02, 0.16, 0.12)), metal, Vector3(0.1, 0.16, 0))

	# ---- colisão
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var sph := SphereShape3D.new()
	sph.radius = 0.18
	col.shape = sph
	root.add_child(col)

	# ---- explosão (partículas)
	var ex := CPUParticles3D.new()
	ex.name = "Explosion"
	ex.emitting = false
	ex.one_shot = true
	ex.explosiveness = 1.0
	ex.amount = 28
	ex.lifetime = 0.7
	var pm := _sphere(0.07)
	pm.material = _glow(Color(1.0, 0.55, 0.12), 4.0)
	ex.mesh = pm
	ex.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	ex.emission_sphere_radius = 0.1
	ex.direction = Vector3(0, 1, 0)
	ex.spread = 180.0
	ex.initial_velocity_min = 3.0
	ex.initial_velocity_max = 7.0
	ex.gravity = Vector3(0, -3, 0)
	ex.scale_amount_min = 0.5
	ex.scale_amount_max = 1.3
	ex.color = Color(1.0, 0.55, 0.12)
	root.add_child(ex)

	# ---- som
	var boom := AudioStreamPlayer3D.new()
	boom.name = "Boom"
	boom.stream = load(BOOM)
	boom.unit_size = 6.0
	boom.max_distance = 60.0
	root.add_child(boom)

	_set_owner(root, root)
	var packed := PackedScene.new()
	print("pack err=", packed.pack(root))
	print("SAVE err=", ResourceSaver.save(packed, OUT))
	quit()


func _mat(albedo: Color, metallic: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.metallic = metallic
	m.roughness = rough
	return m


func _glow(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


func _mi(parent: Node, nm: String, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new(); m.radius = r; m.height = h; return m


func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new(); m.radius = r; m.height = r * 2.0; return m


func _box(sz: Vector3) -> BoxMesh:
	var m := BoxMesh.new(); m.size = sz; return m


func _cyl(rt: float, rb: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new(); m.top_radius = rt; m.bottom_radius = rb; m.height = h; return m


func _set_owner(node: Node, owner: Node) -> void:
	for c in node.get_children():
		c.owner = owner
		_set_owner(c, owner)

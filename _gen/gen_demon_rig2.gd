extends Node3D
## Rigger PROCEDURAL (lógica extraída do player): monta um Skeleton3D humanoide
## (mesma convenção de ossos do player), uma MALHA CONTÍNUA SKINADA (tubos com
## pesos misturados nas juntas → cotovelo/joelho dobram suave), acessórios rígidos
## presos por BoneAttachment3D (chifres/canhão/garras, como a arma do player na mão)
## e animações por ROTAÇÃO DE OSSOS (walk/run/jump). Salva .tscn autocontido.

const OUT_DIR := "res://library3D/characters/demonio_rig2"
const OUT_PATH := OUT_DIR + "/demonio_rig2.tscn"
const SIDES := 12   # lados de cada anel dos tubos (mais suave)

# Ossos: [nome, pai, cabeça(pos no espaço do esqueleto)]. Convenção do player.
const BONES := [
	["hips", -1, Vector3(0.0, 0.86, 0.0)],
	["spine", 0, Vector3(0.0, 0.97, 0.0)],
	["chest", 1, Vector3(0.0, 1.12, 0.0)],
	["neck", 2, Vector3(0.0, 1.30, 0.0)],
	["head", 3, Vector3(0.0, 1.40, 0.0)],
	["shoulder.L", 2, Vector3(-0.15, 1.25, 0.0)],
	["forearm.L", 5, Vector3(-0.31, 1.06, 0.0)],
	["hand.L", 6, Vector3(-0.41, 0.89, 0.0)],
	["shoulder.R", 2, Vector3(0.15, 1.25, 0.0)],
	["forearm.R", 8, Vector3(0.31, 1.06, 0.0)],
	["hand.R", 9, Vector3(0.41, 0.89, 0.0)],
	["thigh.L", 0, Vector3(-0.11, 0.84, 0.0)],
	["shin.L", 11, Vector3(-0.12, 0.48, 0.0)],
	["foot.L", 12, Vector3(-0.12, 0.10, 0.0)],
	["thigh.R", 0, Vector3(0.11, 0.84, 0.0)],
	["shin.R", 14, Vector3(0.12, 0.48, 0.0)],
	["foot.R", 15, Vector3(0.12, 0.10, 0.0)],
]

var _bi := {}                       # nome -> índice
var _head := []                     # índice -> Vector3 (cabeça/global rest)
var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _bones := PackedInt32Array()
var _weights := PackedFloat32Array()
var _idx := PackedInt32Array()

var _detail: ImageTexture
var _body_mat: StandardMaterial3D
var _red: StandardMaterial3D
var _steel: StandardMaterial3D
var _green: StandardMaterial3D


func _ready() -> void:
	for i in BONES.size():
		_bi[BONES[i][0]] = i
		_head.append(BONES[i][2])
	_detail = _detail_tex()
	_body_mat = _tmat(Color(0.13, 0.13, 0.16), 0.6, 0.5, 2.0)
	# Malha procedural: não arriscar faces invisíveis por winding — desliga o cull.
	_body_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_red = _tmat(Color(0.55, 0.07, 0.07), 0.5, 0.45, 1.8)
	_steel = _tmat(Color(0.62, 0.64, 0.68), 0.9, 0.3, 2.2)
	_green = _emat(Color(0.45, 1.0, 0.2), 5.0)

	var root := _build()
	var err := _save(root)
	print("GEN demonio_rig -> %s (err=%d, verts=%d, bones=%d)" % [OUT_PATH, err, _v.size(), BONES.size()])
	print("GEN_DONE")
	get_tree().quit()


func _build() -> Node3D:
	var root := Node3D.new()
	root.name = "DemonioRig"
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)

	var skel := Skeleton3D.new()
	skel.name = "Skeleton3D"
	body.add_child(skel)
	for i in BONES.size():
		skel.add_bone(BONES[i][0])
	for i in BONES.size():
		var parent: int = BONES[i][1]
		if parent >= 0:
			skel.set_bone_parent(i, parent)
		var parent_head: Vector3 = _head[parent] if parent >= 0 else Vector3.ZERO
		var rest := Transform3D(Basis.IDENTITY, _head[i] - parent_head)
		skel.set_bone_rest(i, rest)
		# A POSE inicial precisa IGUALAR o rest (a pose padrão tem posição 0, o que
		# colapsaria a malha skinada); só a rotação é animada depois.
		skel.set_bone_pose_position(i, rest.origin)
		skel.set_bone_pose_rotation(i, Quaternion.IDENTITY)

	# ---- Malha skinada (corpo contínuo) ----
	_build_body_mesh()
	var mesh := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = _v
	arr[Mesh.ARRAY_NORMAL] = _n
	arr[Mesh.ARRAY_BONES] = _bones
	arr[Mesh.ARRAY_WEIGHTS] = _weights
	arr[Mesh.ARRAY_INDEX] = _idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, _body_mat)

	var skin := Skin.new()
	skin.set_bind_count(BONES.size())
	for i in BONES.size():
		skin.set_bind_bone(i, i)
		skin.set_bind_name(i, BONES[i][0])
		# Bind = inverso do rest GLOBAL do osso (via API, p/ casar exatamente).
		skin.set_bind_pose(i, skel.get_bone_global_rest(i).affine_inverse())

	var mi := MeshInstance3D.new()
	mi.name = "DemonBody"
	mi.mesh = mesh
	mi.skin = skin
	mi.skeleton = NodePath("..")
	skel.add_child(mi)

	# ---- Acessórios + placas de armadura presos a ossos ----
	_accessories(skel)
	_armor(skel)

	# ---- Áudio + animações ----
	var audio := AudioStreamPlayer3D.new()
	audio.name = "Sound"
	audio.stream = _growl_wav()
	audio.unit_size = 8.0
	root.add_child(audio)

	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	var lib := AnimationLibrary.new()
	lib.add_animation("walk", _anim_walk(1.05, 0.42, 0.05, false))
	lib.add_animation("run", _anim_walk(0.66, 0.7, 0.09, true))
	lib.add_animation("jump", _anim_jump())
	ap.add_animation_library("", lib)
	root.add_child(ap)

	_set_owner(root, root)
	return root


# ── Malha skinada ─────────────────────────────────────────────────────────────

func _build_body_mesh() -> void:
	# Tronco com FORMA: quadril -> cintura estreita -> peito largo (V) -> ombros.
	_chain([
		_cp("hips", 0.17, [["hips", 1.0]]),
		_cp_at(Vector3(0.0, 0.95, 0.0), 0.145, [["hips", 0.5], ["spine", 0.5]]),
		_cp_at(Vector3(0.0, 1.05, 0.0), 0.175, [["spine", 0.6], ["chest", 0.4]]),
		_cp("chest", 0.215, [["chest", 1.0]]),
		_cp_at(Vector3(0.0, 1.24, 0.0), 0.185, [["chest", 1.0]]),
		_cp_at(Vector3(0.0, 1.30, 0.0), 0.11, [["chest", 0.6], ["neck", 0.4]]),
	])
	# Pescoço -> cabeça.
	_chain([
		_cp("neck", 0.07, [["neck", 1.0]]),
		_cp_at(Vector3(0.0, 1.40, 0.0), 0.09, [["neck", 0.4], ["head", 0.6]]),
	])
	# Cabeça grande (chibi).
	_sphere(Vector3(0.0, 1.56, 0.0), 0.22, [["head", 1.0]])

	# Braços (ombro -> cotovelo -> punho) com mistura nas juntas.
	for s in ["L", "R"]:
		_chain([
			_cp("shoulder." + s, 0.105, [["shoulder." + s, 1.0]]),
			_cp_mid("shoulder." + s, "forearm." + s, 0.45, 0.092, [["shoulder." + s, 1.0]]),
			_cp("forearm." + s, 0.078, [["shoulder." + s, 0.5], ["forearm." + s, 0.5]]),
			_cp_mid("forearm." + s, "hand." + s, 0.5, 0.07, [["forearm." + s, 1.0]]),
			_cp("hand." + s, 0.062, [["forearm." + s, 0.4], ["hand." + s, 0.6]]),
		])
		_sphere(_head[_bi["hand." + s]] + Vector3(0.0, -0.04, 0.0), 0.078, [["hand." + s, 1.0]])

	# Pernas com coxa CHEIA afilando para o joelho/canela.
	for s in ["L", "R"]:
		_chain([
			_cp_at(_head[_bi["thigh." + s]] + Vector3(0.0, 0.05, 0.0), 0.14, [["hips", 0.5], ["thigh." + s, 0.5]]),
			_cp_mid("thigh." + s, "shin." + s, 0.42, 0.125, [["thigh." + s, 1.0]]),
			_cp("shin." + s, 0.088, [["thigh." + s, 0.5], ["shin." + s, 0.5]]),
			_cp_mid("shin." + s, "foot." + s, 0.5, 0.078, [["shin." + s, 1.0]]),
			_cp("foot." + s, 0.066, [["shin." + s, 0.4], ["foot." + s, 0.6]]),
		])
		_foot(s)


func _foot(s: String) -> void:
	# Pé como caixa skinada ao osso do pé, apontando para -Z (frente).
	var c: Vector3 = _head[_bi["foot." + s]] + Vector3(0.0, -0.03, -0.06)
	_box_verts(c, Vector3(0.16, 0.09, 0.28), [["foot." + s, 1.0]])


# Um "control point" por nome de osso (na cabeça do osso).
func _cp(bone: String, r: float, w: Array) -> Dictionary:
	return {"pos": _head[_bi[bone]], "r": r, "w": w}


func _cp_at(pos: Vector3, r: float, w: Array) -> Dictionary:
	return {"pos": pos, "r": r, "w": w}


func _cp_mid(a: String, b: String, t: float, r: float, w: Array) -> Dictionary:
	return {"pos": _head[_bi[a]].lerp(_head[_bi[b]], t), "r": r, "w": w}


# Constrói um tubo skinado ao longo dos control points, subdividindo cada trecho.
func _chain(cps: Array) -> void:
	var prev_base := -1
	var prev_count := 0
	for k in cps.size() - 1:
		var a: Dictionary = cps[k]
		var b: Dictionary = cps[k + 1]
		var seg := 4
		var dir: Vector3 = (b["pos"] - a["pos"])
		if dir.length() < 0.0001:
			continue
		dir = dir.normalized()
		var start := 1 if k > 0 else 0
		for i in range(start, seg + 1):
			var t := float(i) / float(seg)
			var pos: Vector3 = (a["pos"] as Vector3).lerp(b["pos"], t)
			var r: float = lerpf(a["r"], b["r"], t)
			var bw := _interp_w(a["w"], b["w"], t)
			var base := _ring(pos, dir, r, bw)
			if prev_base >= 0:
				_connect(prev_base, base, SIDES)
			prev_base = base
			prev_count = SIDES


# Anel de SIDES vértices em torno de `center`, no plano perpendicular a `dir`.
func _ring(center: Vector3, dir: Vector3, radius: float, bw: Array) -> int:
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.FORWARD
	var u := dir.cross(up).normalized()
	var vv := dir.cross(u).normalized()
	var base := _v.size()
	for i in SIDES:
		var ang := TAU * float(i) / float(SIDES)
		var radial := (u * cos(ang) + vv * sin(ang))
		_v.append(center + radial * radius)
		_n.append(radial)
		_push_w(bw)
	return base


func _connect(baseA: int, baseB: int, sides: int) -> void:
	for i in sides:
		var i2 := (i + 1) % sides
		var a0 := baseA + i
		var a1 := baseA + i2
		var b0 := baseB + i
		var b1 := baseB + i2
		_idx.append_array([a0, b0, a1, a1, b0, b1])


func _sphere(center: Vector3, radius: float, w: Array) -> void:
	var rings := 8
	var sectors := 10
	var bw := _interp_w(w, w, 0.0)
	var base := _v.size()
	for ri in rings + 1:
		var phi := PI * float(ri) / float(rings)
		for si in sectors + 1:
			var th := TAU * float(si) / float(sectors)
			var nrm := Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th))
			_v.append(center + nrm * radius)
			_n.append(nrm)
			_push_w(bw)
	for ri in rings:
		for si in sectors:
			var a := base + ri * (sectors + 1) + si
			var b := a + sectors + 1
			_idx.append_array([a, b, a + 1, a + 1, b, b + 1])


func _box_verts(center: Vector3, size: Vector3, w: Array) -> void:
	var bw := _interp_w(w, w, 0.0)
	var h := size * 0.5
	var corners := [
		Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z),
		Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z),
		Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z),
		Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z),
	]
	var faces := [
		[0, 1, 2, 3, Vector3.DOWN], [4, 7, 6, 5, Vector3.UP],
		[0, 4, 5, 1, Vector3(0, 0, -1)], [2, 6, 7, 3, Vector3(0, 0, 1)],
		[0, 3, 7, 4, Vector3(-1, 0, 0)], [1, 5, 6, 2, Vector3(1, 0, 0)],
	]
	for f in faces:
		var base := _v.size()
		for j in 4:
			_v.append(center + corners[f[j]])
			_n.append(f[4])
			_push_w(bw)
		_idx.append_array([base, base + 1, base + 2, base, base + 2, base + 3])


# ── Pesos ─────────────────────────────────────────────────────────────────────

func _interp_w(wa: Array, wb: Array, t: float) -> Array:
	var acc := {}
	for pair in wa:
		acc[_bi[pair[0]]] = acc.get(_bi[pair[0]], 0.0) + float(pair[1]) * (1.0 - t)
	for pair in wb:
		acc[_bi[pair[0]]] = acc.get(_bi[pair[0]], 0.0) + float(pair[1]) * t
	var items := []
	for k in acc:
		items.append([k, acc[k]])
	items.sort_custom(func(x, y): return x[1] > y[1])
	var bones := PackedInt32Array([0, 0, 0, 0])
	var weights := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var total := 0.0
	for i in mini(4, items.size()):
		bones[i] = items[i][0]
		weights[i] = items[i][1]
		total += items[i][1]
	if total <= 0.0:
		weights[0] = 1.0
	else:
		for i in 4:
			weights[i] /= total
	return [bones, weights]


func _push_w(bw: Array) -> void:
	var bones: PackedInt32Array = bw[0]
	var weights: PackedFloat32Array = bw[1]
	_bones.append_array(bones)
	_weights.append_array(weights)


# ── Acessórios presos a ossos ─────────────────────────────────────────────────

func _accessories(skel: Skeleton3D) -> void:
	# Offsets são LOCAIS ao osso: o BoneAttachment3D já coloca os filhos na posição
	# do osso (cabeça), então não somamos a posição global do osso.
	# Cabeça fica em y≈+0.16 acima do osso head (centro da esfera da cabeça).
	var head := _att(skel, "head")
	_acc_box(head, Vector3(0.0, 0.18, -0.20), Vector3(0.16, 0.10, 0.05), _green, Vector3(0, 0, deg_to_rad(-22)))
	_acc_box(head, Vector3(0.0, 0.18, -0.20), Vector3(0.16, 0.10, 0.05), _green, Vector3(0, 0, deg_to_rad(22)))
	_acc_prism(head, Vector3(0.0, 0.12, -0.21), Vector3(0.08, 0.09, 0.04), _green, Vector3(deg_to_rad(180), 0, 0))
	for i in 7:
		var tx := -0.13 + i * 0.045
		_acc_prism(head, Vector3(tx, 0.04, -0.21), Vector3(0.04, 0.06, 0.03), _green, Vector3(deg_to_rad(180) if i % 2 == 0 else 0, 0, 0))
	for sx in [-1.0, 1.0]:
		_acc_cyl(head, Vector3(0.13 * sx, 0.34, 0.02), 0.05, 0.0, 0.26, _red, Vector3(0, 0, deg_to_rad(55 * sx)))
	# Gema verde no peito (à frente do osso chest).
	var chest := _att(skel, "chest")
	_acc_prism(chest, Vector3(0.0, 0.02, -0.18), Vector3(0.16, 0.18, 0.06), _green, Vector3.ZERO)
	# Pauldrons com espinhos nos ombros.
	for s in ["L", "R"]:
		var sx := -1.0 if s == "L" else 1.0
		var sh := _att(skel, "shoulder." + s)
		_acc_box(sh, Vector3(0.02 * sx, 0.02, 0.0), Vector3(0.20, 0.18, 0.26), _red, Vector3.ZERO)
		for i in 3:
			_acc_cyl(sh, Vector3((0.0 + i * 0.05) * sx, 0.12, -0.08 + i * 0.08), 0.0, 0.03, 0.14, _steel, Vector3(deg_to_rad(-30), 0, deg_to_rad(-25 * sx)))
	# Canhão de plasma no antebraço direito (ao longo do braço, boca para baixo).
	var fr := _att(skel, "forearm.R")
	_acc_cyl(fr, Vector3(0.0, -0.16, 0.0), 0.13, 0.15, 0.34, _body_mat, Vector3.ZERO)
	_acc_cyl(fr, Vector3(0.0, -0.34, 0.0), 0.16, 0.16, 0.05, _green, Vector3.ZERO)
	# Garras verdes na mão esquerda (abaixo/à frente do osso hand).
	var hl := _att(skel, "hand.L")
	for i in 3:
		_acc_cyl(hl, Vector3(-0.05 + i * 0.05, -0.14, -0.06), 0.0, 0.025, 0.16, _green, Vector3(deg_to_rad(-40), 0, 0))
	# Garras nos pés (à frente do osso foot).
	for s in ["L", "R"]:
		var ft := _att(skel, "foot." + s)
		for i in 3:
			_acc_cyl(ft, Vector3(-0.05 + i * 0.05, -0.02, -0.22), 0.0, 0.022, 0.10, _steel, Vector3(deg_to_rad(-75), 0, 0))


# Placas de armadura presas a ossos (acompanham o membro como armadura rígida).
func _armor(skel: Skeleton3D) -> void:
	# Peitoral + costas no chest.
	var chest := _att(skel, "chest")
	_acc_box(chest, Vector3(0.0, 0.06, -0.15), Vector3(0.36, 0.22, 0.12), _red, Vector3.ZERO)
	_acc_box(chest, Vector3(-0.14, 0.06, -0.16), Vector3(0.10, 0.20, 0.06), _steel, Vector3.ZERO)
	_acc_box(chest, Vector3(0.14, 0.06, -0.16), Vector3(0.10, 0.20, 0.06), _steel, Vector3.ZERO)
	_acc_box(chest, Vector3(0.0, 0.07, 0.16), Vector3(0.32, 0.24, 0.08), _body_mat, Vector3.ZERO)
	# Abdômen segmentado (spine) + cinto (hips).
	var spine := _att(skel, "spine")
	_acc_box(spine, Vector3(0.0, -0.02, -0.14), Vector3(0.26, 0.10, 0.10), _body_mat, Vector3.ZERO)
	var hips := _att(skel, "hips")
	_acc_box(hips, Vector3(0.0, 0.0, 0.0), Vector3(0.36, 0.09, 0.34), _steel, Vector3.ZERO)
	_acc_box(hips, Vector3(0.0, -0.06, -0.16), Vector3(0.30, 0.12, 0.12), _red, Vector3.ZERO)
	# Coxeiras (thigh) e caneleiras (shin).
	for s in ["L", "R"]:
		var th := _att(skel, "thigh." + s)
		_acc_box(th, Vector3(0.0, -0.12, -0.05), Vector3(0.22, 0.22, 0.14), _red, Vector3.ZERO)
		var sh := _att(skel, "shin." + s)
		_acc_box(sh, Vector3(0.0, -0.16, -0.06), Vector3(0.17, 0.22, 0.11), _body_mat, Vector3.ZERO)
		_acc_box(sh, Vector3(0.0, -0.16, -0.07), Vector3(0.10, 0.20, 0.04), _steel, Vector3.ZERO)


func _att(skel: Skeleton3D, bone: String) -> BoneAttachment3D:
	var a := BoneAttachment3D.new()
	a.name = "Acc_" + bone
	skel.add_child(a)
	a.bone_name = bone
	return a


func _acc_box(parent: Node, pos: Vector3, size: Vector3, mat: Material, rot: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)


func _acc_cyl(parent: Node, pos: Vector3, tr: float, br: float, h: float, mat: Material, rot: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = tr
	m.bottom_radius = br
	m.height = h
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)


func _acc_prism(parent: Node, pos: Vector3, size: Vector3, mat: Material, rot: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var m := PrismMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)


# ── Animações (rotação de ossos) ──────────────────────────────────────────────

func _anim_walk(length: float, swing: float, bob: float, lean: bool) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR
	var h := length * 0.5
	_rot(a, "thigh.L", _key_swing(swing, length, 0.0))
	_rot(a, "thigh.R", _key_swing(swing, length, h))
	_rot(a, "shin.L", _key_bend(swing * 0.9, length, 0.0))
	_rot(a, "shin.R", _key_bend(swing * 0.9, length, h))
	_rot(a, "shoulder.L", _key_swing(swing * 0.7, length, h))
	_rot(a, "shoulder.R", _key_swing(swing * 0.7, length, 0.0))
	_rot(a, "forearm.L", _key_bend(0.3, length, h))
	_rot(a, "forearm.R", _key_bend(0.3, length, 0.0))
	var ts := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ts, "Body:position")
	a.track_insert_key(ts, 0.0, Vector3.ZERO)
	a.track_insert_key(ts, length * 0.25, Vector3(0.0, bob, 0.0))
	a.track_insert_key(ts, length * 0.5, Vector3.ZERO)
	a.track_insert_key(ts, length * 0.75, Vector3(0.0, bob, 0.0))
	a.track_insert_key(ts, length, Vector3.ZERO)
	if lean:
		_rot(a, "spine", [[0.0, Vector3(deg_to_rad(12.0), 0.0, 0.0)]])
	var tm := a.add_track(Animation.TYPE_METHOD)
	a.track_set_path(tm, "Sound")
	a.track_insert_key(tm, length * 0.02, {"method": "play", "args": [0.0]})
	return a


func _anim_jump() -> Animation:
	var a := Animation.new()
	a.length = 1.0
	a.loop_mode = Animation.LOOP_LINEAR
	var ts := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ts, "Body:position")
	a.track_insert_key(ts, 0.0, Vector3.ZERO)
	a.track_insert_key(ts, 0.18, Vector3(0.0, -0.12, 0.0))
	a.track_insert_key(ts, 0.45, Vector3(0.0, 0.55, 0.0))
	a.track_insert_key(ts, 0.72, Vector3.ZERO)
	a.track_insert_key(ts, 0.85, Vector3(0.0, -0.08, 0.0))
	a.track_insert_key(ts, 1.0, Vector3.ZERO)
	for s in ["L", "R"]:
		_rot(a, "thigh." + s, [[0.0, Vector3.ZERO], [0.18, Vector3(deg_to_rad(40), 0, 0)], [0.45, Vector3(deg_to_rad(55), 0, 0)], [0.72, Vector3.ZERO], [1.0, Vector3.ZERO]])
		_rot(a, "shin." + s, [[0.0, Vector3.ZERO], [0.18, Vector3(deg_to_rad(-70), 0, 0)], [0.45, Vector3(deg_to_rad(-90), 0, 0)], [0.72, Vector3.ZERO], [1.0, Vector3.ZERO]])
		_rot(a, "shoulder." + s, [[0.0, Vector3.ZERO], [0.45, Vector3(deg_to_rad(-110), 0, 0)], [0.72, Vector3.ZERO], [1.0, Vector3.ZERO]])
	var tm := a.add_track(Animation.TYPE_METHOD)
	a.track_set_path(tm, "Sound")
	a.track_insert_key(tm, 0.2, {"method": "play", "args": [0.0]})
	return a


func _key_swing(amp: float, length: float, phase: float) -> Array:
	var keys := []
	for i in 5:
		var t: float = fmod(phase + length * 0.25 * i, length)
		keys.append([t, Vector3(amp * sin(TAU * 0.25 * i), 0.0, 0.0)])
	keys.sort_custom(func(x, y): return x[0] < y[0])
	keys.append([0.0, Vector3(amp * sin(TAU * (-phase / length)), 0.0, 0.0)])
	keys.append([length, Vector3(amp * sin(TAU * (1.0 - phase / length)), 0.0, 0.0)])
	return keys


func _key_bend(amp: float, length: float, phase: float) -> Array:
	# Joelho/cotovelo: dobra só num sentido (sempre <= 0 em X), defasado.
	var keys := []
	for i in 5:
		var t: float = fmod(phase + length * 0.25 * i, length)
		keys.append([t, Vector3(-absf(amp * sin(TAU * 0.25 * i)), 0.0, 0.0)])
	keys.sort_custom(func(x, y): return x[0] < y[0])
	return keys


func _rot(a: Animation, bone: String, keys: Array) -> void:
	var t := a.add_track(Animation.TYPE_ROTATION_3D)
	a.track_set_path(t, "Body/Skeleton3D:%s" % bone)
	for k in keys:
		a.rotation_track_insert_key(t, k[0], Quaternion.from_euler(k[1]))


# ── Textura / áudio / helpers ─────────────────────────────────────────────────

func _detail_tex() -> ImageTexture:
	var size := 160
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var v := 0.82 + (_hash(x * 7 + y * 131) - 0.5) * 0.14
			if (x % 40) < 2 or (y % 40) < 2:
				v *= 0.55
			var rx: int = mini(x % 40, 40 - (x % 40))
			var ry: int = mini(y % 40, 40 - (y % 40))
			if rx * rx + ry * ry < 9:
				v = 1.0
			v = clampf(v, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v))
	return ImageTexture.create_from_image(img)


func _hash(i: int) -> float:
	var hh := (i * 2654435761) & 0x7fffffff
	hh = ((hh ^ (hh >> 13)) * 1274126177) & 0x7fffffff
	return float(hh % 10007) / 10007.0


func _growl_wav() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.5
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var seed_v := 99173
	for i in n:
		var p := float(i) / float(n)
		var freq: float = lerp(90.0, 55.0, p) + sin(p * TAU * 6.0) * 8.0
		phase += TAU * freq / float(rate)
		seed_v = (seed_v * 1103515245 + 12345) & 0x7fffffff
		var noise := (float(seed_v) / 1073741823.0 - 1.0)
		var env: float = sin(PI * p) * exp(-p * 1.2)
		var s: float = (sin(phase) * 0.7 + noise * 0.15) * env
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


func _tmat(c: Color, metallic: float, rough: float, scale: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.albedo_texture = _detail
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	m.metallic = metallic
	m.roughness = rough
	return m


func _emat(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


func _set_owner(node: Node, owner: Node) -> void:
	for c in node.get_children():
		c.owner = owner
		_set_owner(c, owner)


func _save(root: Node3D) -> int:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(OUT_DIR)):
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var packed := PackedScene.new()
	packed.pack(root)
	return ResourceSaver.save(packed, OUT_PATH)

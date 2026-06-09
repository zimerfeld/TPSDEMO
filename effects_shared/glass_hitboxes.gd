extends Node3D
## Hitboxes funcionais com aparência de vidro, UMA por MEMBRO grande.
## Grupos: CABEÇA, TRONCO, BRAÇO (D/E), PERNA (D/E).
##
## Cada membro vira uma única BoxShape3D ajustada aos VÉRTICES da malha skinados
## àquele membro (AABB no espaço local do osso-raiz do membro → caixa orientada
## que "abraça" a parte). A caixa é presa via BoneAttachment3D ao osso-raiz, então
## acompanha a pose/animação. Um Label3D por membro o identifica.
## As áreas detectam projéteis e aplicam DANO LOCALIZADO (cabeça = +50%).

const HEAD_MULTIPLIER := 1.5
const BODY_MULTIPLIER := 1.0

@export var enabled: bool = true
## Margem (m) somada a cada lado da caixa, para folga sobre a superfície.
@export var padding: float = 0.03
@export var glass_color: Color = Color(0.45, 0.8, 1.0, 0.22)

@export_group("Labels 3D")
@export var show_labels: bool = true
@export var label_color: Color = Color(1, 1, 1)
@export var label_pixel_size: float = 0.0009

@export_group("Mapeamento de Bones")
## Nomes de bones forçados para o grupo HEAD (ignora exclusões).
@export var head_bone_names: Array[String] = []

@export_group("Colisão")
@export_flags_3d_physics var hitbox_layer: int = 16
@export_flags_3d_physics var detect_layer: int = 8

var _character: Node = null
var _material: StandardMaterial3D


func build_for(skel: Skeleton3D) -> void:
	if not enabled or skel == null:
		return
	_character = get_parent()
	_material = _make_glass_material()
	# group → {"bone": int (osso-raiz), "aabb": AABB (no espaço local do osso-raiz)}
	var members := _collect_member_boxes(skel)
	for group in members:
		_build_member_shape(skel, group, members[group]["bone"], members[group]["aabb"])


# ── Coleta de vértices por membro ─────────────────────────────────────────────

func _collect_member_boxes(skel: Skeleton3D) -> Dictionary:
	# 1) Agrupa ossos por membro e escolhe o osso-raiz (mais raso na hierarquia).
	var group_bones := {}
	for b in skel.get_bone_count():
		var g := BodyParts.group_of(skel.get_bone_name(b), head_bone_names)
		if g == "":
			continue
		if not group_bones.has(g):
			group_bones[g] = []
		group_bones[g].append(b)

	var root_bone := {}
	for g in group_bones:
		var best: int = group_bones[g][0]
		var best_depth := _bone_depth(skel, best)
		for b in group_bones[g]:
			var d := _bone_depth(skel, b)
			if d < best_depth:
				best_depth = d
				best = b
		root_bone[g] = best

	# 2) Acumula AABB por membro a partir dos vértices skinados (espaço do osso-raiz).
	# A posição de cada vértice no REST é reconstruída via a BIND POSE da skin
	# (get_bind_pose) — isso corrige esqueletos cuja pose de bind difere da de
	# rest (p.ex. o player); usar só get_bone_global_rest deslocaria as caixas.
	var bone_rest: Array[Transform3D] = []
	bone_rest.resize(skel.get_bone_count())
	for b in skel.get_bone_count():
		bone_rest[b] = skel.get_bone_global_rest(b)
	var root_rest_inv := {}
	for g in root_bone:
		root_rest_inv[g] = bone_rest[root_bone[g]].affine_inverse()

	var acc := {}  # group → {"min": Vector3, "max": Vector3}
	for mi in _skinned_meshes(skel):
		var skin: Skin = mi.skin
		if skin == null:
			continue
		# Por índice de bind: osso do esqueleto + matriz de skinning no rest
		# (mesh-space → skeleton-space) = rest_global(osso) * bind_pose.
		var idx_to_bone: PackedInt32Array = PackedInt32Array()
		idx_to_bone.resize(skin.get_bind_count())
		var skin_xform: Array[Transform3D] = []
		skin_xform.resize(skin.get_bind_count())
		for i in skin.get_bind_count():
			var bb := skin.get_bind_bone(i)
			var skb_i := bb if bb >= 0 else skel.find_bone(skin.get_bind_name(i))
			idx_to_bone[i] = skb_i
			if skb_i >= 0:
				skin_xform[i] = bone_rest[skb_i] * skin.get_bind_pose(i)

		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			if verts.is_empty() or bones.is_empty() or weights.is_empty():
				continue
			var per := bones.size() / verts.size()  # influências por vértice (4 ou 8)
			for vi in verts.size():
				var best_w := 0.0
				var best_b := -1
				for k in per:
					var w := weights[vi * per + k]
					if w > best_w:
						best_w = w
						best_b = bones[vi * per + k]
				if best_b < 0 or best_b >= idx_to_bone.size():
					continue
				var skb := idx_to_bone[best_b]
				if skb < 0:
					continue
				var g := BodyParts.group_of(skel.get_bone_name(skb), head_bone_names)
				if g == "":
					continue
				var p: Vector3 = root_rest_inv[g] * (skin_xform[best_b] * verts[vi])
				if not acc.has(g):
					acc[g] = {"min": p, "max": p}
				else:
					acc[g]["min"] = acc[g]["min"].min(p)
					acc[g]["max"] = acc[g]["max"].max(p)

	# 3) Monta AABB final (com folga) por membro que tenha vértices.
	var out := {}
	var pad := Vector3(padding, padding, padding)
	for g in acc:
		var mn: Vector3 = acc[g]["min"] - pad
		var mx: Vector3 = acc[g]["max"] + pad
		out[g] = {"bone": root_bone[g], "aabb": AABB(mn, mx - mn)}
	return out


func _bone_depth(skel: Skeleton3D, b: int) -> int:
	var d := 0
	var p := skel.get_bone_parent(b)
	while p != -1:
		d += 1
		p = skel.get_bone_parent(p)
	return d


func _skinned_meshes(skel: Skeleton3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var stack: Array = [skel]
	while stack.size() > 0:
		var n: Node = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).skin != null \
				and (n as MeshInstance3D).mesh != null:
			out.append(n as MeshInstance3D)
		for c in n.get_children():
			stack.append(c)
	return out


# ── Construção da hitbox de um membro ─────────────────────────────────────────

func _build_member_shape(skel: Skeleton3D, group: String, bone_idx: int, box_aabb: AABB) -> void:
	var att := BoneAttachment3D.new()
	att.name = "Hitbox_%s" % group
	skel.add_child(att)
	att.bone_name = skel.get_bone_name(bone_idx)

	var area := Area3D.new()
	area.collision_layer = hitbox_layer
	area.collision_mask = detect_layer
	area.monitoring = true
	area.monitorable = true
	area.set_meta("group", group)
	var mult: float = HEAD_MULTIPLIER if group == BodyParts.HEAD else BODY_MULTIPLIER
	area.set_meta("damage_multiplier", mult)

	var center := box_aabb.position + box_aabb.size * 0.5

	var box := BoxShape3D.new()
	box.size = box_aabb.size
	var shape := CollisionShape3D.new()
	shape.shape = box
	shape.position = center
	area.add_child(shape)

	# Visual de vidro (desnecessário em servidor dedicado).
	if DisplayServer.get_name() != "headless":
		var mesh := BoxMesh.new()
		mesh.size = box_aabb.size
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _material
		mi.position = center
		area.add_child(mi)

		if show_labels:
			var label_pos := center + Vector3(0.0, box_aabb.size.y * 0.5 + 0.08, 0.0)
			area.add_child(_make_label(BodyParts.label_of(group), label_pos))

	area.body_entered.connect(_on_hitbox_body_entered.bind(area))
	att.add_child(area)


func _make_label(text: String, pos: Vector3) -> Label3D:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.fixed_size = true
	lbl.pixel_size = label_pixel_size
	lbl.font_size = 32
	lbl.outline_size = 6
	lbl.modulate = label_color
	lbl.outline_modulate = Color(0, 0, 0, 0.8)
	lbl.position = pos
	return lbl


func _on_hitbox_body_entered(body: Node, area: Area3D) -> void:
	if not multiplayer.is_server():
		return
	if body == null or not body.has_method(&"register_hit"):
		return
	if body.get(&"shooter") == _character:
		return
	body.register_hit(_character, area.get_meta("damage_multiplier", BODY_MULTIPLIER))


func _make_glass_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = glass_color
	m.roughness = 0.05
	m.metallic = 0.0
	m.metallic_specular = 0.95
	m.rim_enabled = true
	m.rim = 0.9
	m.rim_tint = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

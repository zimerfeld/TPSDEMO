extends Node3D
## Hitboxes funcionais com aparência de vidro, agrupadas por MEMBRO grande.
## Grupos: CABEÇA, TRONCO, BRAÇO (D/E), PERNA (D/E).
##
## Cada osso-membro vira: BoneAttachment3D → Area3D (CollisionShape3D capsule)
## + MeshInstance3D de vidro. As áreas seguem o ângulo/movimento das meshes via
## BoneAttachment3D. O volume é proporcional ao tamanho do membro (cobre membros
## grandes, p.ex. do robô). Um Label3D por grupo identifica o membro.
## As áreas detectam projéteis e aplicam DANO LOCALIZADO (cabeça = +50%).

# Grupos
const G_HEAD := "HEAD"
const G_TORSO := "TORSO"
const G_ARM_L := "ARM_L"
const G_ARM_R := "ARM_R"
const G_LEG_L := "LEG_L"
const G_LEG_R := "LEG_R"

const GROUP_LABELS := {
	"HEAD": "CABEÇA",
	"TORSO": "TRONCO",
	"ARM_L": "BRAÇO E",
	"ARM_R": "BRAÇO D",
	"LEG_L": "PERNA E",
	"LEG_R": "PERNA D",
}

const HEAD_MULTIPLIER := 1.5
const BODY_MULTIPLIER := 1.0

const EXCLUDE_KEYWORDS: Array[String] = [
	"ik", "scaler", "piston", "pad", "cover", "guard", "cable", "flap",
	"dongle", "sight", "mod", "slider", "rotator", "orient", "control",
	"target", "master", "empty", "eye", "mouth", "track", "extender",
	"recoil", "booster", "fuel", "plate", "heel", "toe", "core", "aim", "dead",
]

@export var enabled: bool = true
## Raio mínimo da cápsula.
@export var radius: float = 0.1
## Fração do comprimento do membro usada como raio (volume proporcional).
@export var radius_factor: float = 0.4
## Raio máximo (limita membros muito longos, p.ex. o tronco do robô).
@export var max_radius: float = 0.25
## Raio da cabeça (zona de headshot mais generosa).
@export var head_radius: float = 0.18
@export var glass_color: Color = Color(0.45, 0.8, 1.0, 0.22)
@export var min_bone_length: float = 0.05

@export_group("Labels 3D")
@export var show_labels: bool = true
@export var label_color: Color = Color(1, 1, 1)
@export var label_pixel_size: float = 0.0009

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
	var labeled := {}  # grupos que já receberam um Label3D
	for i in skel.get_bone_count():
		var group := _group_for(skel.get_bone_name(i))
		if group == "":
			continue
		# Maior segmento osso→filho define direção/comprimento do membro.
		var best := Vector3.ZERO
		var best_len := min_bone_length
		for c in skel.get_bone_children(i):
			var off: Vector3 = skel.get_bone_rest(c).origin
			if off.length() > best_len:
				best_len = off.length()
				best = off
		if best == Vector3.ZERO:
			continue

		var att := BoneAttachment3D.new()
		att.name = "Hitbox_%s_%s" % [group, skel.get_bone_name(i)]
		skel.add_child(att)
		att.bone_name = skel.get_bone_name(i)

		var want_label: bool = show_labels and not labeled.has(group) \
				and DisplayServer.get_name() != "headless"
		att.add_child(_make_hitbox(best, group, want_label))
		if want_label:
			labeled[group] = true


func _group_for(bone_name: String) -> String:
	var n := bone_name.to_lower()
	for ex in EXCLUDE_KEYWORDS:
		if n.contains(ex):
			return ""

	if n.contains("head") or n.contains("neck"):
		return G_HEAD
	if n.contains("hips") or n.contains("pelvis") or n.contains("spine") \
			or n.contains("chest") or n.contains("torso") or n.contains("body"):
		return G_TORSO

	var side := _side_of(n)
	if n.contains("shoulder") or n.contains("arm") or n.contains("hand"):
		if side == "":
			return ""
		return G_ARM_L if side == "L" else G_ARM_R
	if n.contains("thigh") or n.contains("shin") or n.contains("calf") \
			or n.contains("knee") or n.contains("foot") or n.contains("leg"):
		if side == "":
			return ""
		return G_LEG_L if side == "L" else G_LEG_R
	return ""


func _side_of(n: String) -> String:
	if n.begins_with("l-") or n.ends_with(".l") or n.contains(".l.") or n.ends_with("_l"):
		return "L"
	if n.begins_with("r-") or n.ends_with(".r") or n.contains(".r.") or n.ends_with("_r"):
		return "R"
	return ""


func _radius_for(group: String, length: float) -> float:
	if group == G_HEAD:
		return head_radius
	return clampf(length * radius_factor, radius, max_radius)


func _make_hitbox(offset: Vector3, group: String, with_label: bool) -> Area3D:
	var length: float = offset.length()
	var r: float = _radius_for(group, length)
	var mult: float = HEAD_MULTIPLIER if group == G_HEAD else BODY_MULTIPLIER

	var area := Area3D.new()
	area.collision_layer = hitbox_layer
	area.collision_mask = detect_layer
	area.monitoring = true
	area.monitorable = true
	area.set_meta("group", group)
	area.set_meta("damage_multiplier", mult)

	# Alinha o eixo +Y à direção do osso (cápsula acompanha o ângulo do membro).
	var aligned_basis := _basis_aligned_to(offset.normalized())
	var xform := Transform3D(aligned_basis, offset * 0.5)

	var cap := CapsuleShape3D.new()
	cap.radius = r
	cap.height = maxf(length, r * 2.0)
	var shape := CollisionShape3D.new()
	shape.shape = cap
	shape.transform = xform
	area.add_child(shape)

	# Visual de vidro (desnecessário em servidor dedicado).
	if DisplayServer.get_name() != "headless":
		var mesh := CapsuleMesh.new()
		mesh.radius = r
		mesh.height = maxf(length, r * 2.0)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _material
		mi.transform = xform
		area.add_child(mi)

	if with_label:
		area.add_child(_make_label(GROUP_LABELS.get(group, group), offset * 0.5))

	area.body_entered.connect(_on_hitbox_body_entered.bind(area))
	return area


func _make_label(text: String, pos: Vector3) -> Label3D:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.fixed_size = true
	lbl.pixel_size = label_pixel_size
	lbl.font_size = 64
	lbl.outline_size = 12
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


# Rotação que leva +Y até a direção `dir`.
func _basis_aligned_to(dir: Vector3) -> Basis:
	var up := Vector3.UP
	if dir.is_equal_approx(up):
		return Basis()
	if dir.is_equal_approx(-up):
		return Basis.from_euler(Vector3(PI, 0.0, 0.0))
	var axis := up.cross(dir).normalized()
	return Basis(axis, up.angle_to(dir))

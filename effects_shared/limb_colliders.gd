class_name LimbColliders
extends Node3D
## Colliders 3D NATIVOS (StaticBody3D + CollisionShape3D), UM por MEMBRO grande.
## Grupos: CABEÇA, TRONCO, BRAÇO (D/E), PERNA (D/E).
##
## Cada membro vira uma única BoxShape3D ajustada aos VÉRTICES da malha skinados
## àquele membro (AABB no espaço local do osso-raiz do membro → caixa orientada
## que "abraça" a parte). O collider é preso via BoneAttachment3D ao osso-raiz,
## então acompanha a pose/animação. Cada StaticBody3D carrega o multiplicador de
## DANO LOCALIZADO (cabeça = +50%) e uma referência ao personagem dono, em metas.
## Os projéteis colidem fisicamente com esses corpos (move_and_collide) e o laser
## do inimigo os atinge por raycast contra CORPOS. São StaticBody3D PASSIVOS
## (collision_mask=0): só geometria de colisão, sem Area3D de detecção e sem
## malha visual.
##
## Os MEMBROS de cada modelo vêm do seu PLANO CORPORAL (body_type): bípede tem
## CABEÇA/TRONCO/BRAÇO/PERNA, quadrúpede tem 4 PERNAS, rastejante só CABEÇA/TRONCO
## (ver [[BodyPlans]]/[[BodyParts]]). O multiplicador de DANO de cada membro vem de
## LimbConfig (lido por model_key), com fallback para o default do plano.

# Prefixo de "grupo" interno para uma peça com collider próprio (sub-membro).
# Cada peça vira um grupo único "PART_<osso>", reaproveitando todo o pipeline de membros.
# Sem ":" no prefixo: nomes de nó do Godot não aceitam ":".
const _PART_PREFIX := "PART_"

@export var enabled: bool = true
## Plano corporal do modelo — escolhe o classificador de membros (ver BodyPlans).
@export_enum("biped", "quadruped", "crawler") var body_type: String = "biped"
## Margem (m) somada a cada lado da caixa, para folga sobre a superfície.
@export var padding: float = 0.03
## Chave do modelo (nome da pasta, ex.: "red_robot"/"player") para buscar os
## multiplicadores de dano e os sub-membros em LimbConfig. Vazio → usa os defaults do plano.
@export var model_key: String = ""

@export_group("Mapeamento de Bones")
## Nomes de bones forçados para o grupo HEAD (ignora exclusões).
@export var head_bone_names: Array[String] = []
## Nomes de bones forçados para o grupo TRONCO (ignora exclusões) — para corpos
## cujo osso principal tem nome genérico que o classificador não reconhece
## (ex.: red_robot, cujo corpo é o osso "Bone.001").
@export var torso_bone_names: Array[String] = []
## Nomes de bones forçados para PERNA E/D (ignora exclusões; lado vem do nome L-/R-).
## Para placas/peças da perna que o classificador descartaria (ex.: red_robot,
## "L-RearLegGuard"/"R-RearLegGuard", excluídas pela palavra "guard").
@export var leg_bone_names: Array[String] = []
## Bones que recebem um collider PRÓPRIO (uma caixa ajustada só aos seus vértices), em vez
## de serem absorvidos por um membro maior. Para peças SALIENTES que a cápsula do membro não
## cobriria — ex.: as placas traseiras das pernas do red_robot ("L-/R-RearLegGuard"), que
## ficam atrás da perna e escapariam da cápsula. O lado (E/D) vem do nome do osso (L-/R-).
@export var standalone_part_bones: Array[String] = []

@export_group("Colisão")
## Layer dos colliders de membro (bit5=16 player, bit6=32 enemy). Os projéteis
## incluem essas layers no seu collision_mask para colidir com os membros.
@export_flags_3d_physics var hitbox_layer: int = 16

var _character: Node = null
## Todos os StaticBody3D criados (para o atirador excluir os próprios da colisão).
var _bodies: Array[StaticBody3D] = []
## Classificador do plano corporal (resolvido em build_for por body_type).
var _classifier: BodyParts = null
## Sub-membros efetivos = export ∪ LimbConfig(model_key) ∪ default do plano (em minúsculas).
var _sub_member_set: Dictionary = {}


func build_for(skel: Skeleton3D) -> void:
	if not enabled or skel == null:
		return
	_character = get_parent()
	_classifier = BodyPlans.for_type(body_type)
	_resolve_sub_members()
	# group → {"bone": int (osso-raiz), "aabb": AABB (no espaço local do osso-raiz)}
	var members := _collect_member_boxes(skel)
	for group in members:
		_build_member_shape(skel, group, members[group]["bone"], members[group]["aabb"])


# Junta os sub-membros das 3 fontes (export do nó, config por modelo, default do plano)
# num set em minúsculas para o _classify reconhecê-los independentemente de origem.
func _resolve_sub_members() -> void:
	_sub_member_set = {}
	for src in [standalone_part_bones, LimbConfig.sub_members(model_key), _classifier.default_sub_members()]:
		for b in src:
			_sub_member_set[String(b).to_lower()] = true


## Lista os StaticBody3D dos membros (usada para excluir os próprios colliders da
## colisão do projétil que o personagem dispara — senão ele acertaria a si mesmo).
func get_limb_bodies() -> Array[StaticBody3D]:
	return _bodies


# ── Coleta de vértices por membro ─────────────────────────────────────────────

# Classifica um osso num grupo de MEMBRO, ou num grupo individual "PART_<osso>" quando o
# osso está em standalone_part_bones (peça com collider próprio). Intercepta ANTES do
# classificador normal, então a peça nunca é absorvida pelo membro vizinho.
func _classify(bone_name: String) -> String:
	if _sub_member_set.has(bone_name.to_lower()):
		return _PART_PREFIX + bone_name
	return _classifier.group_of(bone_name, head_bone_names, torso_bone_names, leg_bone_names)


# Rótulo legível de uma peça standalone (a partir do nome do osso). Placas de perna viram
# "PLACA PERNA E/D"; demais peças usam o próprio nome do osso.
func _part_label(bone_name: String) -> String:
	var ln := bone_name.to_lower()
	if ln.contains("leg") and ln.contains("guard"):
		match BodyParts.side_of(bone_name):
			"L": return "PLACA PERNA E"
			"R": return "PLACA PERNA D"
	return bone_name


func _collect_member_boxes(skel: Skeleton3D) -> Dictionary:
	# 1) Agrupa ossos por membro e escolhe o osso-raiz (mais raso na hierarquia).
	var group_bones := {}
	for b in skel.get_bone_count():
		var g := _classify(skel.get_bone_name(b))
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
			@warning_ignore("integer_division")
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
				var g := _classify(skel.get_bone_name(skb))
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


# ── Construção do collider de um membro ───────────────────────────────────────

func _build_member_shape(skel: Skeleton3D, group: String, bone_idx: int, box_aabb: AABB) -> void:
	var att := BoneAttachment3D.new()
	att.name = "Hitbox_%s" % group
	skel.add_child(att)
	att.bone_name = skel.get_bone_name(bone_idx)

	var body := StaticBody3D.new()
	body.name = "Collider_%s" % group
	body.collision_layer = hitbox_layer
	body.collision_mask = 0   # passivo: é atingido, não detecta nada
	var mult: float = LimbConfig.get_multiplier(model_key, group, _classifier)
	# Peças standalone (PART_*) usam o rótulo derivado do osso; membros normais, o do plano.
	var label: String = _part_label(skel.get_bone_name(bone_idx)) if group.begins_with(_PART_PREFIX) else _classifier.label_of(group)
	body.set_meta("group", group)
	body.set_meta("damage_multiplier", mult)
	body.set_meta("member_label", label)
	body.set_meta("character", _character)

	body.add_child(make_member_shape(group, box_aabb))

	att.add_child(body)
	_bodies.append(body)


# How tightly the wrapped geometry hugs the body. The raw AABB (already padded)
# tends to float a little loose around the limb, so we pull the cross-section
# (radius / box width+depth) in and trim the length slightly — the colliders sit
# closer to the character without leaving the mesh poking out.
const CROSS_SHRINK := 0.82   # width/depth and radius multiplier
const LENGTH_SHRINK := 0.95  # along a limb's long axis
const LIMB_RADIUS_RATIO := 0.32  # max capsule radius as a fraction of its length


# Pick the geometry that best wraps a member from its (padded) AABB: a SPHERE for
# the head, a BOX for the torso, and a CAPSULE aligned to the long axis for the
# elongated limbs (arms/legs). Returns a positioned/oriented CollisionShape3D.
# Static so the model browser can reuse it for non-skeleton rigs (criatura).
static func make_member_shape(group: String, box_aabb: AABB) -> CollisionShape3D:
	var kind := "capsule"
	if group == BodyParts.HEAD:
		kind = "sphere"
	elif group == BodyParts.TORSO or group.begins_with(_PART_PREFIX):
		# Peças salientes (placas) são chatas/retangulares → caixa, não cápsula.
		kind = "box"
	return make_shape(kind, box_aabb)


# Build a positioned/oriented CollisionShape3D of an explicit `kind`
# ("sphere"/"box"/"capsule") fitted to the AABB. Lets non-character rigs (weapons)
# choose the shape per part (e.g. a CAPSULE barrel, BOX receiver/grip).
static func make_shape(kind: String, box_aabb: AABB) -> CollisionShape3D:
	var size := box_aabb.size
	var center := box_aabb.position + size * 0.5
	var shape := CollisionShape3D.new()
	shape.position = center

	if kind == "sphere":
		var sphere := SphereShape3D.new()
		sphere.radius = 0.5 * maxf(size.x, maxf(size.y, size.z)) * CROSS_SHRINK
		shape.shape = sphere
		return shape

	if kind == "box":
		var box := BoxShape3D.new()
		# Keep the full height; pull only width/depth in so it hugs the part.
		box.size = Vector3(size.x * CROSS_SHRINK, size.y, size.z * CROSS_SHRINK)
		shape.shape = box
		return shape

	# Capsule along the longest axis (0=x, 1=y, 2=z).
	var long_axis := 0
	if size.y >= size.x and size.y >= size.z:
		long_axis = 1
	elif size.z >= size.x and size.z >= size.y:
		long_axis = 2
	var others := [size.x, size.y, size.z]
	others.remove_at(long_axis)
	var length := size[long_axis] * LENGTH_SHRINK
	var radius := 0.5 * maxf(others[0], others[1]) * CROSS_SHRINK
	# Keep limbs visibly elongated: cap the radius to a fraction of the length so a
	# compact, near-cubic AABB (e.g. the player's gun-holding right arm, whose pose
	# fattens its bounds) still reads as a proper capsule instead of a ball.
	radius = minf(radius, length * LIMB_RADIUS_RATIO)
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	# CapsuleShape3D.height is the full length including the two hemisphere caps.
	capsule.height = maxf(length, 2.0 * capsule.radius)
	shape.shape = capsule
	# The capsule extends along its local Y; rotate so Y maps onto the long axis.
	if long_axis == 0:
		shape.rotation = Vector3(0.0, 0.0, PI * 0.5)   # Y -> X
	elif long_axis == 2:
		shape.rotation = Vector3(PI * 0.5, 0.0, 0.0)   # Y -> Z
	return shape

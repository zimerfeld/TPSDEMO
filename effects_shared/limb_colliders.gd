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
## Forma do collider da CABEÇA: "sphere" (padrão) ou "capsule". A cápsula é alinhada ao
## eixo mais longo da cabeça (mesma orientação do osso) e mantém o raio cheio para abraçar
## a cabeça — usada pelo player. Demais membros não são afetados.
@export_enum("sphere", "capsule") var head_shape: String = "sphere"
## Forma do collider do TRONCO: "box" (padrão) ou "sphere". O red_robot usa "sphere" (corpo
## arredondado). Demais membros não são afetados.
@export_enum("box", "sphere") var torso_shape: String = "box"
## Fator de escala do collider da CABEÇA (1.0 = ajustado à malha). > 1 aumenta o VOLUME da cabeça
## em torno do seu centro — ex.: red_robot usa ~1.3 para um headshot mais generoso.
@export var head_scale: float = 1.0
## Só no PREVIEW da tela Models (true): SUB-MEMBROS marcados "Selecione..." (SHAPE_NONE) ainda são
## construídos com a forma automática e gizmo escondido (meta "suppressed"), p/ continuarem na árvore/
## dropdown e poderem ser reconfigurados. No gameplay (false, default) são PULADOS (sem hitbox).
@export var include_suppressed: bool = false
## Subdivisão AUTOMÁTICA das extremidades: antebraço/mão e canela/pé viram sub-membros próprios
## (collider e dano localizados, herdando o BRAÇO/PERNA quando sem valor próprio), em vez de serem
## absorvidos no membro grande. Ligado por padrão (modelos novos). player/red_robot fazem opt-out
## (false) para manter o hitbox de braço/perna INTEIRO já ajustado. Ver BodyParts.is_distal_sub_member.
@export var auto_distal_sub_members: bool = true

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

# ───────────────────────── cache das caixas de membro ─────────────────────────
# As caixas de membro são calculadas a partir da MALHA e do REST do esqueleto — nunca da pose — então
# duas instâncias do mesmo modelo produzem o resultado IDÊNTICO. Sem cache, cada entidade que nasce
# refaz a varredura inteira dos vértices skinados: uma sala com 16 inimigos gastava mais de um segundo
# de CPU calculando a mesma resposta 16 vezes (é parte do que o spawn gradual do RoomManager cobre).
# Guarda só tipos por valor ({grupo: {bone: int, aabb: AABB}}, ~1 KB por entrada) — nenhum nó, nenhum
# recurso: não segura esqueleto nem personagem vivo na memória.
static var _box_cache: Dictionary = {}


## Descarta as caixas memorizadas. A tela Models chama ao mexer no que MUDA o conjunto de membros
## (promover/remover sub-membro); o resto do que ela edita (forma, offset, escala, dano) é aplicado
## depois das caixas e não passa por aqui.
static func invalidate_box_cache() -> void:
	_box_cache.clear()


func build_for(skel: Skeleton3D) -> void:
	if not enabled or skel == null:
		return
	_character = get_parent()
	_classifier = BodyPlans.for_type(body_type)
	_resolve_sub_members()
	# group → {"bone": int (osso-raiz), "aabb": AABB (no espaço local do osso-raiz)}
	var members := _cached_member_boxes(skel)
	for group in members:
		# "Selecione..." no dropdown de geometria (tela Models) marca o grupo como SEM collider
		# (SHAPE_NONE) — pula a construção, então ele não é atingível. Lido aqui no spawn. EXCEÇÃO: no
		# PREVIEW da tela Models (include_suppressed), um SUB-MEMBRO suprimido ainda é construído (forma
		# automática, gizmo escondido) p/ continuar na árvore/dropdown e poder ser reconfigurado.
		if LimbConfig.collider_shape(model_key, group) == LimbConfig.SHAPE_NONE:
			if include_suppressed and group.begins_with(_PART_PREFIX):
				_build_member_shape(skel, group, members[group]["bone"], members[group]["aabb"], true)
			continue
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

# Classifica um osso num grupo de MEMBRO, ou num grupo individual "PART_<osso>" quando é sub-membro:
# (a) explícito — em standalone_part_bones/LimbConfig/default do plano (_sub_member_set); ou
# (b) DISTAL automático — antebraço/mão/canela/pé, quando auto_distal_sub_members está ligado.
# Intercepta ANTES do classificador de membro, então a extremidade nunca é absorvida pelo membro
# vizinho (o dono para herança de dano é resolvido depois via resolve_sub_member_owner).
func _classify(bone_name: String) -> String:
	if _sub_member_set.has(bone_name.to_lower()):
		return _PART_PREFIX + bone_name
	if auto_distal_sub_members and _classifier.is_distal_sub_member(bone_name):
		return _PART_PREFIX + bone_name
	return _classifier.group_of(bone_name, head_bone_names, torso_bone_names, leg_bone_names)


# Membro-DONO de um sub-membro (peça/placa), resolvido em camadas — compartilhado pelo rótulo
# (_part_label) e pelo agrupamento da tela Models (_sub_member_owner_map), para os dois
# concordarem. Ordem: (1) NOME da própria peça (owner_hint); (2) sobe na hierarquia de ossos e, em
# CADA ancestral, tenta owner_hint (pega placas penduradas num osso AUX/IK cujo nome diz o membro,
# ex.: "L-Shield" → pai "L-ARMIK" → BRAÇO E) e depois group_of (com os overrides head/torso/leg).
# "" quando nada decide.
static func resolve_sub_member_owner(skel: Skeleton3D, bone_name: String, classifier: BodyParts,
		head: Array = [], torso: Array = [], leg: Array = []) -> String:
	var oh := classifier.owner_hint(bone_name)
	if oh != "":
		return oh
	var b := skel.find_bone(bone_name)
	while b != -1:
		var nm := skel.get_bone_name(b)
		var h := classifier.owner_hint(nm)
		if h != "":
			return h
		var g := classifier.group_of(nm, head, torso, leg)
		if g != "":
			return g
		b = skel.get_bone_parent(b)
	return ""


# Rótulo legível de uma peça standalone. Quando dá pra resolver a que membro a peça pertence
# O sub-membro PRESERVA o nome ORIGINAL do osso, mesmo após ser adicionado a um membro-dono
# (o dono só agrupa o dano; não renomeia a peça). Antes virava "PLACA <MEMBRO>" — descartado a
# pedido: o nome original deve ser mantido.
func _part_label(_skel: Skeleton3D, bone_name: String) -> String:
	return bone_name


# Caixas de membro do modelo, calculadas uma vez por configuração e reusadas pelas demais entidades.
# O dicionário devolvido é COMPARTILHADO (Dictionary é por referência): quem chama apenas LÊ.
func _cached_member_boxes(skel: Skeleton3D) -> Dictionary:
	var key := _box_cache_key(skel)
	if key == "":
		return _collect_member_boxes(skel)   # identidade indefinida: não arrisca colidir chaves
	if _box_cache.has(key):
		return _box_cache[key]
	var boxes := _collect_member_boxes(skel)
	_box_cache[key] = boxes
	return boxes


# Tudo que MUDA as caixas entra na chave; o que só afeta a forma/dano do collider fica de fora (é
# aplicado depois, por entidade). A identidade vem da MALHA, não do `model_key`: este tem default
# vazio e a tela Models o devolve vazio sem modelo carregado — duas entidades diferentes colidiriam
# na mesma chave. Por malha, `playera` compartilha a entrada do `player` de graça (é a mesma cena).
func _box_cache_key(skel: Skeleton3D) -> String:
	var mesh_ids := PackedStringArray()
	for mi in _skinned_meshes(skel):
		if mi.mesh == null or mi.mesh.resource_path == "":
			return ""   # malha sem caminho (gerada em runtime): sem identidade estável, sem cache
		mesh_ids.append(mi.mesh.resource_path)
	if mesh_ids.is_empty():
		return ""
	mesh_ids.sort()
	# `padding` entra na chave e as caixas são guardadas JÁ com a folga aplicada: as caixas-fallback
	# dos sub-membros sem vértices próprios não recebem padding, então somá-lo na leitura engordaria
	# esses hitboxes em silêncio. São só dois valores no projeto (0,03 no jogo, 0,04 no preview).
	var subs := PackedStringArray()
	for s in _sub_member_set:
		subs.append(String(s))
	subs.sort()   # o Dictionary preserva a ordem de inserção; sem ordenar, a mesma config daria chaves diferentes
	return "|".join(PackedStringArray([
		"|".join(mesh_ids),
		str(skel.get_bone_count()),
		body_type,
		str(auto_distal_sub_members),
		str(padding),
		"|".join(subs),
		# Mapeamentos forçados de osso: mudam a CLASSIFICAÇÃO, logo mudam as caixas.
		",".join(head_bone_names), ",".join(torso_bone_names), ",".join(leg_bone_names),
	]))


func _collect_member_boxes(skel: Skeleton3D) -> Dictionary:
	# 1) Agrupa ossos por membro e escolhe o osso-raiz (mais raso na hierarquia).
	# A classificação de cada osso é GUARDADA numa tabela indexada por índice de osso: o laço de
	# vértices (passo 2) precisa dela dezenas de milhares de vezes, e reclassificar a string do osso a
	# cada vértice respondia por ~85% de todo o custo de construir os colliders. São 145 ossos contra
	# 38.858 vértices no player — a mesma resposta, recalculada 268 vezes cada.
	var group_bones := {}
	var bone_group: Array[String] = []
	bone_group.resize(skel.get_bone_count())
	for b in skel.get_bone_count():
		var g := _classify(skel.get_bone_name(b))
		bone_group[b] = g
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
				# O limite SUPERIOR é obrigatório, não cosmético: com um índice fora da faixa, o
				# `get_bone_name` de antes só imprimia erro e pulava o vértice; um acesso à tabela
				# abortaria a função inteira e o personagem nasceria SEM NENHUM hitbox. Os modelos do
				# projeto ligam tudo por nome, mas a tela Models ingere GLB arbitrário.
				if skb < 0 or skb >= bone_group.size():
					continue
				var g: String = bone_group[skb]
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

	# 4) FALLBACK para SUB-MEMBROS (PART_*) SEM vértices skinados próprios (ossos auxiliares/vazios,
	# ex.: "Mouth"; um osso só "estrutural" cuja região é dominada pelo osso-pai). Sem isto, o
	# sub-membro promovido pelo usuário não gera collider e SOME da árvore/dropdown da tela Models.
	# Damos a ele uma pequena CAIXA centrada na origem do próprio osso (rest), para que apareça e
	# possa carregar dano localizado. O tamanho é uma fração do maior membro medido (escala-aware).
	var fb := _fallback_part_size(out)
	for g in group_bones:
		if not g.begins_with(_PART_PREFIX) or out.has(g):
			continue
		var s := Vector3(fb, fb, fb)
		out[g] = {"bone": root_bone[g], "aabb": AABB(-s * 0.5, s)}
	return out


# Lado (m) da caixa-fallback de um sub-membro sem vértices: ~20% da maior dimensão de um membro já
# medido (assim acompanha a escala do modelo), com um piso mínimo quando nada foi medido ainda.
func _fallback_part_size(measured: Dictionary) -> float:
	var biggest := 0.0
	for g in measured:
		var sz: Vector3 = measured[g]["aabb"].size
		biggest = maxf(biggest, maxf(sz.x, maxf(sz.y, sz.z)))
	return maxf(biggest * 0.2, 0.05)


func _bone_depth(skel: Skeleton3D, b: int) -> int:
	var d := 0
	var p := skel.get_bone_parent(b)
	while p != -1:
		d += 1
		p = skel.get_bone_parent(p)
	return d


static func _skinned_meshes(skel: Skeleton3D) -> Array[MeshInstance3D]:
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


# AABB (no espaço LOCAL do osso `bone_idx`, em REST) dos vértices cujo osso DOMINANTE (maior peso)
# é bone_idx. AABB de tamanho ZERO se nenhum vértice pertence a ele. Mesma matemática de skinning
# de _collect_member_boxes, mas para UM osso — usado pelo realce de "osso avulso" na tela Models
# (sem precisar promovê-lo a sub-membro). STATIC: não depende de estado de instância.
static func bone_vertex_box(skel: Skeleton3D, bone_idx: int) -> AABB:
	if skel == null or bone_idx < 0 or bone_idx >= skel.get_bone_count():
		return AABB()
	var bone_rest: Array[Transform3D] = []
	bone_rest.resize(skel.get_bone_count())
	for b in skel.get_bone_count():
		bone_rest[b] = skel.get_bone_global_rest(b)
	var root_inv := bone_rest[bone_idx].affine_inverse()
	var has := false
	var mn := Vector3.ZERO
	var mx := Vector3.ZERO
	for mi in _skinned_meshes(skel):
		var skin: Skin = mi.skin
		if skin == null:
			continue
		var idx_to_bone := PackedInt32Array()
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
			var per := bones.size() / verts.size()
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
				if idx_to_bone[best_b] != bone_idx:
					continue
				var p: Vector3 = root_inv * (skin_xform[best_b] * verts[vi])
				if not has:
					mn = p
					mx = p
					has = true
				else:
					mn = mn.min(p)
					mx = mx.max(p)
	if not has:
		return AABB()
	return AABB(mn, mx - mn)


# ── Construção do collider de um membro ───────────────────────────────────────

# `suppressed` (só no PREVIEW da tela Models, via include_suppressed): constrói o corpo com a forma
# AUTOMÁTICA (ignora o "none") e o marca com a meta "suppressed", p/ o sub-membro continuar na árvore/
# dropdown e poder ser reconfigurado, mas SEM gizmo (ver _add_collider_gizmos) e sem hitbox no gameplay.
func _build_member_shape(skel: Skeleton3D, group: String, bone_idx: int, box_aabb: AABB, suppressed: bool = false) -> void:
	var att := BoneAttachment3D.new()
	att.name = "Hitbox_%s" % group
	skel.add_child(att)
	att.bone_name = skel.get_bone_name(bone_idx)

	var body := StaticBody3D.new()
	body.name = "Collider_%s" % group
	body.collision_layer = hitbox_layer
	body.collision_mask = 0   # passivo: é atingido, não detecta nada
	# Dano EFETIVO: um sub-membro (PART_*) sem valor próprio herda o do membro-DONO. O dono vem
	# da escolha EXPLÍCITA salva (LimbConfig); na falta, da resolução automática por nome/hierarquia.
	var owner_group := ""
	if group.begins_with(_PART_PREFIX):
		var bn := skel.get_bone_name(bone_idx)
		owner_group = LimbConfig.sub_member_owner(model_key, bn)
		if owner_group == "":
			owner_group = resolve_sub_member_owner(skel, bn, _classifier, head_bone_names, torso_bone_names, leg_bone_names)
	var mult: float = LimbConfig.effective_multiplier(model_key, group, _classifier, owner_group)
	# Peças standalone (PART_*) usam o rótulo derivado do osso; membros normais, o do plano.
	var label: String = _part_label(skel, skel.get_bone_name(bone_idx)) if group.begins_with(_PART_PREFIX) else _classifier.label_of(group)
	body.set_meta("group", group)
	body.set_meta("damage_multiplier", mult)
	body.set_meta("member_label", label)
	# Membro-DONO de um sub-membro ("" para membros normais). Além da herança de dano, é o que permite
	# ao [[limb-health]] derrubar os sub-membros junto com o membro pai.
	body.set_meta("owner_group", owner_group)
	body.set_meta("character", _character)
	if suppressed:
		body.set_meta("suppressed", true)   # collider de preview (sem gizmo); sem hitbox no gameplay
	# Afastamento (offset) do collider em espaço LOCAL do osso, editável na tela Models. Move o corpo
	# inteiro (shape/gizmo/rótulo acompanham). Vazio/ausente = Vector3.ZERO (sem afastamento).
	body.position = LimbConfig.collider_offset(model_key, group)
	# Rotação (graus) do collider, editável na tela Models — gira o corpo inteiro em torno da sua origem
	# (ponto de afastamento). Relativa à pose do osso (acompanha a animação). Ausente = sem rotação.
	body.rotation_degrees = LimbConfig.collider_rotation(model_key, group)

	# Forma do collider: override explícito da tela Models (LimbConfig.collider_shape) ou a automática.
	# Um grupo SUPRIMIDO (preview) usa a forma AUTOMÁTICA (ignora o "none").
	var shape_override := "" if suppressed else LimbConfig.collider_shape(model_key, group)
	var shape_node := make_member_shape(group, box_aabb, head_shape, torso_shape, head_scale, shape_override)
	# Escala por eixo (espaço local da forma), editável na tela Models — escala a forma em torno do
	# seu centro (o gizmo, filho dela, acompanha). Vazio/ausente = Vector3.ONE (sem escala).
	shape_node.scale = LimbConfig.collider_scale(model_key, group)
	body.add_child(shape_node)

	att.add_child(body)
	_bodies.append(body)


# ── Refit em tempo real (preview da Models) ───────────────────────────────────
# Cache de skinning, montado UMA vez (o caro `surface_get_arrays` roda só aqui): por vértice
# guardamos o grupo, o osso DOMINANTE e `bind_pose * vértice` (mesh→skel, fixo). O refit depois
# só lê as poses ATUAIS dos ossos — sem reconstruir arrays de malha — então fica barato.
var _rc_ready := false
# Vértices ORDENADOS POR GRUPO: os de cada grupo ocupam o intervalo contíguo
# [_rc_gstart[gi], _rc_gstart[gi] + _rc_gcount[gi]) em _rc_bone/_rc_bv. É o que permite refitar só
# UM SUBCONJUNTO de grupos (rodízio) percorrendo apenas os vértices deles, em vez de varrer o cache
# inteiro descartando o que não interessa.
var _rc_bone := PackedInt32Array()     # osso do esqueleto por vértice
var _rc_bv := PackedVector3Array()     # bind_pose * vértice (fixo)
var _rc_names: Array[String] = []      # índice do grupo → nome
var _rc_root := PackedInt32Array()     # índice do grupo → osso-raiz
var _rc_gstart := PackedInt32Array()   # índice do grupo → 1º vértice seu
var _rc_gcount := PackedInt32Array()   # índice do grupo → quantos vértices tem
# Grupos que REALMENTE mudam de forma com a pose (2+ ossos). Um grupo de OSSO ÚNICO tem AABB local
# INVARIANTE: como o osso-raiz é o próprio osso dos seus vértices, o termo inv(pose_raiz)·pose_osso se
# cancela e o resultado não depende da pose — ele já gira/transladada junto via BoneAttachment3D.
# Depois da subdivisão automática quase todo grupo virou de osso único (só o TRONCO costuma ter 2+),
# então refitar todos era recalcular o mesmo valor. O refit percorre apenas esta lista.
var _rc_dyn := PackedInt32Array()
# Cursor do RODÍZIO: próximo grupo DINÂMICO a processar quando refit() recebe um lote (max_groups > 0).
var _refit_cursor := 0


func _build_refit_cache(skel: Skeleton3D) -> void:
	_rc_bone = PackedInt32Array(); _rc_bv = PackedVector3Array()
	_rc_names = []; _rc_root = PackedInt32Array()
	_rc_gstart = PackedInt32Array(); _rc_gcount = PackedInt32Array()
	_rc_dyn = PackedInt32Array()
	_refit_cursor = 0
	# Mesma tabela osso→grupo do _collect_member_boxes: sem ela, a montagem deste cache reclassifica a
	# string do osso uma vez por VÉRTICE (era o outro lado do mesmo gargalo, aqui na tela Models).
	var group_bones := {}
	var bone_group: Array[String] = []
	bone_group.resize(skel.get_bone_count())
	for b in skel.get_bone_count():
		var g := _classify(skel.get_bone_name(b))
		bone_group[b] = g
		if g == "":
			continue
		if not group_bones.has(g):
			group_bones[g] = []
		group_bones[g].append(b)
	var gidx := {}
	for g in group_bones:
		var best: int = group_bones[g][0]
		var bd := _bone_depth(skel, best)
		for b in group_bones[g]:
			var d := _bone_depth(skel, b)
			if d < bd:
				bd = d; best = b
		gidx[g] = _rc_names.size()
		_rc_names.append(g)
		_rc_root.append(best)
		# 2+ ossos → a forma do grupo muda ao animar (ex.: TRONCO = quadril+peito, ou um BRAÇO inteiro
		# quando o modelo faz opt-out da subdivisão). 1 osso → AABB local invariante: não entra no refit.
		if (group_bones[g] as Array).size() > 1:
			_rc_dyn.append(int(gidx[g]))
	# Coleta PLANA numa passada (grupo/osso/vértice); a ordenação por grupo vem depois.
	var tmp_group := PackedInt32Array()
	var tmp_bone := PackedInt32Array()
	var tmp_bv := PackedVector3Array()
	for mi in _skinned_meshes(skel):
		var skin: Skin = mi.skin
		if skin == null:
			continue
		var idx_to_bone := PackedInt32Array(); idx_to_bone.resize(skin.get_bind_count())
		var bind_pose: Array[Transform3D] = []; bind_pose.resize(skin.get_bind_count())
		for i in skin.get_bind_count():
			var bb := skin.get_bind_bone(i)
			idx_to_bone[i] = bb if bb >= 0 else skel.find_bone(skin.get_bind_name(i))
			bind_pose[i] = skin.get_bind_pose(i)
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			if verts.is_empty() or bones.is_empty() or weights.is_empty():
				continue
			@warning_ignore("integer_division")
			var per := bones.size() / verts.size()
			for vi in verts.size():
				var best_w := 0.0
				var best_i := -1
				for k in per:
					var w := weights[vi * per + k]
					if w > best_w:
						best_w = w; best_i = bones[vi * per + k]
				if best_i < 0 or best_i >= idx_to_bone.size():
					continue
				var skb := idx_to_bone[best_i]
				if skb < 0 or skb >= bone_group.size():
					continue
				var g: String = bone_group[skb]
				if g == "":
					continue
				tmp_group.append(gidx[g])
				tmp_bone.append(skb)
				tmp_bv.append(bind_pose[best_i] * verts[vi])
	# COUNTING SORT por grupo: deixa os vértices de cada grupo CONTÍGUOS em _rc_bone/_rc_bv, com o
	# intervalo registrado em _rc_gstart/_rc_gcount — é o que permite refitar um subconjunto de grupos
	# sem varrer o cache inteiro. (Acumular em "baldes" Packed*Array dentro de um Array NÃO funciona:
	# ao ser lido de dentro do Array, um Packed*Array vem COPIADO, e os appends se perdem.)
	var ng := _rc_names.size()
	var total := tmp_group.size()
	_rc_gstart.resize(ng); _rc_gcount.resize(ng)
	for gi in ng:
		_rc_gcount[gi] = 0
	for i in total:
		_rc_gcount[tmp_group[i]] += 1
	var cursor := 0
	for gi in ng:
		_rc_gstart[gi] = cursor
		cursor += _rc_gcount[gi]
	_rc_bone.resize(total); _rc_bv.resize(total)
	var fill := PackedInt32Array(); fill.resize(ng)
	for gi in ng:
		fill[gi] = _rc_gstart[gi]
	for i in total:
		var gi: int = tmp_group[i]
		var pos: int = fill[gi]
		_rc_bone[pos] = tmp_bone[i]
		_rc_bv[pos] = tmp_bv[i]
		fill[gi] = pos + 1
	_rc_ready = true


# Re-encaixa os colliders de membro/sub-membro à pose ANIMADA atual (acompanham movimentos/dobra),
# usando o cache acima — barato, sem `surface_get_arrays`. Preview da tela Models. A 1ª chamada monta
# o cache (custo único). Mantém offset/escala editados e atualiza o gizmo "_ColliderGizmo".
#
# `max_groups` > 0 ativa o RODÍZIO: processa só esse tanto de grupos por chamada, avançando o cursor
# a cada passada até dar a volta. Chamando todo frame com um lote pequeno, o custo por frame cai na
# proporção do lote e o pico que engasgava a animação desaparece — com a pose completa reencaixada
# a cada (nº de grupos ÷ lote) frames. 0 (padrão) = todos de uma vez, como antes.
func refit(skel: Skeleton3D, max_groups: int = 0) -> void:
	if skel == null:
		return
	if not _rc_ready:
		_build_refit_cache(skel)
	# Só os grupos DINÂMICOS (2+ ossos) entram: os de osso único têm AABB local invariante e já foram
	# resolvidos no build (ver _rc_dyn). Com a subdivisão automática isso costuma sobrar só o TRONCO.
	var nd := _rc_dyn.size()
	if nd == 0:
		return
	# Lote desta passada: TODOS os dinâmicos (max_groups <= 0, comportamento original) ou apenas os
	# próximos `max_groups` a partir do cursor — o RODÍZIO, que espalha o custo por vários frames
	# em vez de concentrar tudo num pico que estoura o orçamento de 16,67 ms do frame.
	var batch: int = nd if max_groups <= 0 else mini(max_groups, nd)
	var gpose: Array[Transform3D] = []; gpose.resize(skel.get_bone_count())
	for b in skel.get_bone_count():
		gpose[b] = skel.get_bone_global_pose(b)
	var pad := Vector3(padding, padding, padding)
	var boxes := {}
	for k in batch:
		var gi: int = _rc_dyn[(_refit_cursor + k) % nd]
		var cnt: int = _rc_gcount[gi]
		if cnt <= 0:
			continue
		# Só os vértices DESTE grupo (intervalo contíguo montado por _build_refit_cache).
		var root_inv := gpose[_rc_root[gi]].affine_inverse()
		var start: int = _rc_gstart[gi]
		var mn := Vector3.ZERO
		var mx := Vector3.ZERO
		var first := true
		for i in range(start, start + cnt):
			var p: Vector3 = root_inv * (gpose[_rc_bone[i]] * _rc_bv[i])
			if first:
				mn = p; mx = p; first = false
			else:
				mn = mn.min(p); mx = mx.max(p)
		if not first:
			boxes[_rc_names[gi]] = AABB(mn - pad, (mx - mn) + pad * 2.0)
	if max_groups > 0:
		_refit_cursor = (_refit_cursor + batch) % nd
	for body in _bodies:
		if not is_instance_valid(body) or not body.has_meta("group"):
			continue
		var g := str(body.get_meta("group"))
		if not boxes.has(g):
			continue
		var sns := body.find_children("*", "CollisionShape3D", false, false)
		if sns.is_empty():
			continue
		var sn := sns[0] as CollisionShape3D
		var fresh := make_member_shape(g, boxes[g], head_shape, torso_shape, head_scale, LimbConfig.collider_shape(model_key, g))
		sn.shape = fresh.shape
		sn.transform = fresh.transform
		sn.scale = LimbConfig.collider_scale(model_key, g)
		fresh.free()
		# get_debug_mesh() GERA geometria a cada chamada — só vale para um gizmo de fato VISÍVEL.
		# Um gizmo escondido (toggle do tipo desligado, ou fora do membro em foco) é atualizado no
		# primeiro refit depois de reaparecer; a defasagem máxima é um intervalo de refit.
		var giz := sn.get_node_or_null(NodePath("_ColliderGizmo"))
		if giz is MeshInstance3D and sn.shape != null and (giz as MeshInstance3D).is_visible_in_tree():
			(giz as MeshInstance3D).mesh = sn.shape.get_debug_mesh()


# How tightly the wrapped geometry hugs the body. The raw AABB (already padded)
# tends to float a little loose around the limb, so we pull the cross-section
# (radius / box width+depth) in and trim the length slightly — the colliders sit
# closer to the character without leaving the mesh poking out.
const CROSS_SHRINK := 0.72   # width/depth and radius multiplier (limbs only; head keeps full radius)
const LENGTH_SHRINK := 0.95  # along a limb's long axis
const LIMB_RADIUS_RATIO := 0.32  # max capsule radius as a fraction of its length


# Pick the geometry that best wraps a member from its (padded) AABB: the HEAD is a
# SPHERE by default but a CAPSULE when `head_kind` asks for it (player), the TORSO a
# BOX, and the elongated limbs (arms/legs) a CAPSULE aligned to the long axis.
# `shape_override` ("sphere"/"box"/"capsule"), quando setado, FORÇA a forma do grupo
# (escolha do dropdown de geometria da tela Models, lida de LimbConfig) sobre a automática.
# Returns a positioned/oriented CollisionShape3D. Static so the model browser can reuse
# it for non-skeleton rigs (criatura).
static func make_member_shape(group: String, box_aabb: AABB, head_kind: String = "sphere", torso_kind: String = "box", head_scale_arg: float = 1.0, shape_override: String = "") -> CollisionShape3D:
	if shape_override == "sphere" or shape_override == "box" or shape_override == "capsule":
		# Forma escolhida na tela Models, sobrepondo a automática. A cabeça mantém o head_scale e, em
		# cápsula, o RAIO CHEIO (cap_radius=false) p/ abraçá-la; demais grupos usam o raio de membro.
		if group == BodyParts.HEAD:
			return make_shape(shape_override, _scaled_aabb(box_aabb, head_scale_arg), shape_override != "capsule")
		return make_shape(shape_override, box_aabb)
	if group == BodyParts.HEAD:
		# head_scale aumenta o volume da cabeça em torno do centro (AABB escalado simétrico).
		var head_aabb := _scaled_aabb(box_aabb, head_scale_arg)
		# Head capsule keeps its FULL radius (cap_radius=false) so it hugs the roughly
		# round head along its long axis, instead of pinching to a thin limb capsule.
		if head_kind == "capsule":
			return make_shape("capsule", head_aabb, false)
		return make_shape(head_kind, head_aabb)
	var kind := "capsule"
	if group == BodyParts.TORSO:
		# Tronco: "box" (padrão) ou "sphere" por modelo (ex.: red_robot tem corpo arredondado).
		kind = torso_kind
	elif group.begins_with(_PART_PREFIX):
		# Peças salientes (placas) são chatas/retangulares → caixa, não cápsula.
		kind = "box"
	return make_shape(kind, box_aabb)


# AABB com o TAMANHO multiplicado por `s` em torno do CENTRO (cresce/encolhe simétrico). s==1 → igual.
static func _scaled_aabb(a: AABB, s: float) -> AABB:
	if is_equal_approx(s, 1.0):
		return a
	var c := a.position + a.size * 0.5
	var ns := a.size * s
	return AABB(c - ns * 0.5, ns)


# Build a positioned/oriented CollisionShape3D of an explicit `kind`
# ("sphere"/"box"/"capsule") fitted to the AABB. Lets non-character rigs (weapons)
# choose the shape per part (e.g. a CAPSULE barrel, BOX receiver/grip). `cap_radius`
# clamps a capsule's radius to a fraction of its length (keeps slim limbs slim); pass
# false for round parts like the head so the capsule keeps its full hugging radius.
static func make_shape(kind: String, box_aabb: AABB, cap_radius: bool = true) -> CollisionShape3D:
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
	var radius := 0.5 * maxf(others[0], others[1])
	# Limbs (cap_radius=true): pull the cross-section in (CROSS_SHRINK) so they hug the
	# part, and keep them visibly elongated by capping the radius to a fraction of the
	# length — a compact, near-cubic AABB (e.g. the player's gun-holding right arm, whose
	# pose fattens its bounds) still reads as a proper capsule instead of a ball.
	# Round parts (head, cap_radius=false) skip BOTH: full radius so the capsule covers
	# the whole mesh.
	if cap_radius:
		radius *= CROSS_SHRINK
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


# ── Auto-fit da cápsula de LOCOMOÇÃO por modelo ───────────────────────────────
# O bloqueio físico entre personagens (move_and_slide) usa UMA cápsula por corpo — barata,
# estável e determinística (independe da pose animada, então servidor e cliente-predição
# concordam). Em vez de uma cápsula default (0.5×2.0) igual p/ todo modelo, derivamos raio e
# altura dos MESMOS boxes de membro que já medimos aqui: assim cada modelo da biblioteca ganha
# um corpo físico proporcional a ele, mantendo 1 shape/personagem. Ver [[sistemas/player]].

## Raio mínimo (m) da cápsula auto-ajustada — evita um corpo degenerado (fino demais) num
## modelo com footprint minúsculo ou mal medido.
const MIN_BODY_CAPSULE_RADIUS: float = 0.12


# AABBs dos colliders de membro JÁ CONSTRUÍDOS, no espaço LOCAL de `space` (avaliado na pose
# atual — no spawn, a pose de rest). Keyed por grupo (HEAD/TORSO/ARM_*/LEG_*/PART_<osso>). Lê a
# geometria REAL das formas (pós-encolhimento), então reflete os colliders que o jogador vê/edita.
func member_boxes_in(space: Node3D) -> Dictionary:
	var out := {}
	if space == null or not space.is_inside_tree():
		return out
	var inv := space.global_transform.affine_inverse()
	for body in _bodies:
		if not is_instance_valid(body) or not body.has_meta("group"):
			continue
		if body.has_meta("suppressed"):
			continue  # collider só de preview (sem hitbox no gameplay) — não conta p/ a cápsula
		var g := str(body.get_meta("group"))
		for sn in body.find_children("*", "CollisionShape3D", false, false):
			var cs := sn as CollisionShape3D
			if cs == null or cs.shape == null:
				continue
			var local := _shape_local_aabb(cs.shape)
			if local.size == Vector3.ZERO:
				continue
			var box := _transform_aabb(inv * cs.global_transform, local)
			out[g] = box if not out.has(g) else out[g].merge(box)
	return out


# Ajusta a cápsula de locomoção `shape_node` (o CollisionShape3D do CORPO do personagem) ao
# modelo real, a partir dos boxes de membro. RAIO vem do FOOTPRINT em pé (tronco + pernas; braços
# e cabeça são excluídos p/ um T-pose não engordar o raio); ALTURA vem da extensão vertical total
# (topo da cabeça → pés). A BASE é ancorada no chão do personagem (y=0) p/ não flutuar. Duplica a
# forma p/ não mutar um sub-recurso compartilhado entre instâncias. No-op (devolve {}) se nada foi
# construído (ex.: modelo sem membros classificados) — preserva a cápsula autorada como fallback.
func fit_locomotion_capsule(shape_node: CollisionShape3D, character: Node3D) -> Dictionary:
	if shape_node == null or character == null:
		return {}
	var boxes := member_boxes_in(character)
	if boxes.is_empty():
		return {}
	var full := AABB()
	var full_set := false
	var foot := AABB()
	var foot_set := false
	for g in boxes:
		var b: AABB = boxes[g]
		full = b if not full_set else full.merge(b)
		full_set = true
		if _is_footprint_group(g):
			foot = b if not foot_set else foot.merge(b)
			foot_set = true
	if not full_set:
		return {}
	# Footprint (tronco+pernas) define o raio; sem ele (ex.: só cabeça/tronco), usa o corpo inteiro.
	var src: AABB = foot if foot_set else full
	var radius := maxf(0.5 * maxf(src.size.x, src.size.z), MIN_BODY_CAPSULE_RADIUS)
	# Altura: do CHÃO do personagem (y=0, ou abaixo se o pé passar da origem) ao topo da cabeça.
	var top: float = full.position.y + full.size.y
	var bottom: float = minf(full.position.y, 0.0)
	var height := maxf(top - bottom, 2.0 * radius)
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = height
	shape_node.shape = capsule
	# Centro no eixo do modelo (x/z do footprint) e no meio vertical entre base e topo.
	var cx: float = full.position.x + full.size.x * 0.5
	var cz: float = full.position.z + full.size.z * 0.5
	shape_node.position = Vector3(cx, (bottom + top) * 0.5, cz)
	shape_node.rotation = Vector3.ZERO
	return {"radius": radius, "height": height}


# Grupos que formam o FOOTPRINT em pé (base da cápsula de locomoção): TRONCO + PERNAS (qualquer
# plano — LEG_L/R do bípede, LEG_F?/R? do quadrúpede). Braços (envergadura), cabeça (topo) e peças
# PART_* ficam de fora p/ não distorcer o raio do corpo.
static func _is_footprint_group(group: String) -> bool:
	return group == BodyParts.TORSO or group.begins_with("LEG_")


# AABB LOCAL (centrado na origem da forma) de uma forma primitiva de collider de membro.
# Sphere/Box/Capsule cobrem tudo o que make_shape produz; AABB vazio p/ tipos inesperados.
static func _shape_local_aabb(shape: Shape3D) -> AABB:
	if shape is SphereShape3D:
		var r := (shape as SphereShape3D).radius
		return AABB(Vector3(-r, -r, -r), Vector3(r, r, r) * 2.0)
	if shape is BoxShape3D:
		var s := (shape as BoxShape3D).size
		return AABB(-s * 0.5, s)
	if shape is CapsuleShape3D:
		var c := shape as CapsuleShape3D
		return AABB(Vector3(-c.radius, -c.height * 0.5, -c.radius),
				Vector3(c.radius * 2.0, c.height, c.radius * 2.0))
	return AABB()


# AABB que ENVOLVE `box` transformado por `xf` (une os 8 cantos no espaço destino). Usado p/
# levar cada forma de membro ao espaço local do personagem (a rotação da cápsula de membro faz
# a caixa deixar de ser eixo-alinhada, então o envelope dos cantos é o correto).
static func _transform_aabb(xf: Transform3D, box: AABB) -> AABB:
	var p := box.position
	var s := box.size
	var mn := xf * p
	var mx := mn
	for i in 8:
		var corner := p + Vector3(
				s.x if (i & 1) else 0.0,
				s.y if (i & 2) else 0.0,
				s.z if (i & 4) else 0.0)
		var w: Vector3 = xf * corner
		mn = mn.min(w)
		mx = mx.max(w)
	return AABB(mn, mx - mn)

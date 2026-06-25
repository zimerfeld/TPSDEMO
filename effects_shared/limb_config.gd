class_name LimbConfig
extends RefCounted
## Config de DANO LOCALIZADO por personagem, persistida em UM ARQUIVO POR MODELO na PASTA DO MODELO
## (res://library3D/<categoria>/<model_key>/limb_config.json; override de runtime em
## user://limb_config/<model_key>.json — ver bloco "ONDE FICA" abaixo). Cada arquivo guarda, daquele modelo: o multiplicador
## de cada MEMBRO/sub-membro ("damage"), a LISTA de sub-membros promovidos ("sub_members") e a
## RELAÇÃO de DONO de cada sub-membro ("sub_member_owners" — de quem ele HERDA o dano quando não
## tem valor próprio). A tela Models grava; LimbColliders.build_for() lê na construção dos
## colliders e carimba a meta "damage_multiplier"; os projéteis/laser leem essa meta.
##
## Formato de cada arquivo <model_key>.json:
##   { "damage": { "<GROUP>": <mult> }, "sub_members": [<osso>],
##     "sub_member_owners": { "<osso>": "<GROUP_DONO>" },
##     "collider_offsets": { "<GROUP>": [x, y, z] }, "collider_scales": { "<GROUP>": [x, y, z] },
##     "collider_shapes": { "<GROUP>": "sphere"|"box"|"capsule"|"none" } }
## - "collider_offsets" = afastamento (em metros, espaço LOCAL do osso/collider) aplicado à posição do
##   StaticBody3D de cada membro/sub-membro, editável na tela Models. Ausente/zero = sem afastamento.
## - "collider_scales" = escala (por eixo, espaço LOCAL) aplicada à forma do collider de cada
##   membro/sub-membro, editável na tela Models. Ausente/[1,1,1] = sem escala.
## - "collider_shapes" = forma escolhida na tela Models para o collider do grupo: "sphere"/"box"/
##   "capsule" sobrescreve a forma automática; "none" SUPRIME o collider do MEMBRO (sem dano);
##   ausente = forma automática do plano. Lido por LimbColliders.build_for no spawn.
## - model_key = nome da pasta do modelo ("red_robot", "player"), o MESMO valor que
##   LimbColliders.model_key recebe no gameplay; é o nome do arquivo.
## - GROUP = chave do plano corporal (HEAD/TORSO/ARM_L/…) ou "PART_<osso>" p/ sub-membro.
## - "damage" só guarda os AJUSTES do usuário — sem entrada = SEM valor próprio (herda/usa o padrão).
## - "sub_member_owners" = membro-DONO escolhido EXPLICITAMENTE p/ cada sub-membro (agrupamento só
##   lógico, p/ herança de dano). Ausente = resolução automática (LimbColliders.resolve_sub_member_owner).
##
## HERANÇA (effective_multiplier): valor explícito do grupo > valor do membro-dono (sub-membro sem
## valor próprio) > default do plano. "Nenhum valor de dano é obrigatório."
##
## ONDE FICA (2026-06-22): a config de cada modelo vive em UM ARQUIVO NA PASTA DO PRÓPRIO MODELO —
## res://library3D/<categoria>/<model_key>/limb_config.json — junto da malha/cena, versionável e
## editável no Godot. Como o res:// é SOMENTE-LEITURA no .exe exportado (PCK embutido), as edições
## feitas RODANDO O JOGO (tela Models no .exe) são gravadas num OVERRIDE gravável em
## user://limb_config/<model_key>.json, que tem precedência na leitura — assim o que você edita em
## tela é relido e aparece. No editor, o save vai direto pra pasta do modelo (a fonte canônica) e
## limpa qualquer override de user:// obsoleto daquele modelo.
##
## LEITURA (ordem): user:// (override de runtime) → pasta do modelo (autorado/shipado) →
## res://data/limb_config/<key>.json (formato antigo) → res://data/limb_config.json (combinado legado).

const LIBRARY_ROOT := "res://library3D"
const MODEL_FILE := "limb_config.json"
const USER_DIR := "user://limb_config"
const OLD_DIR := "res://data/limb_config"
const LEGACY_PATH := "res://data/limb_config.json"

# Cache model_key → pasta do modelo (res://library3D/<cat>/<model_key>), resolvida varrendo as
# categorias. "" quando o modelo não está na biblioteca. Evita re-varrer a cada leitura/escrita.
static var _dir_cache: Dictionary = {}


# Pasta do modelo na biblioteca (res://library3D/<cat>/<model_key>), ou "" se não achar.
static func _model_dir(model_key: String) -> String:
	if model_key == "":
		return ""
	if _dir_cache.has(model_key):
		return _dir_cache[model_key]
	var found := ""
	var root := DirAccess.open(LIBRARY_ROOT)
	if root != null:
		for cat in root.get_directories():
			var p := "%s/%s/%s" % [LIBRARY_ROOT, cat, model_key]
			if DirAccess.dir_exists_absolute(p):
				found = p
				break
	_dir_cache[model_key] = found
	return found


# Caminho do arquivo na PASTA DO MODELO (res://), ou "" se o modelo não está na biblioteca.
static func _model_path(model_key: String) -> String:
	var d := _model_dir(model_key)
	return "" if d == "" else "%s/%s" % [d, MODEL_FILE]


# Caminho do OVERRIDE gravável (user://), sempre disponível (inclusive no .exe).
static func _user_path(model_key: String) -> String:
	return "%s/%s.json" % [USER_DIR, model_key]


# Lê e faz parse de um JSON-objeto de `path`; {} se não der (inexistente/corrompido).
static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}


# Entrada (dicionário) de um modelo, na ordem: override user:// → pasta do modelo → formato antigo
# (res://data/limb_config/<key>.json) → combinado legado (res://data/limb_config.json). {} se nada.
static func _load_entry(model_key: String) -> Dictionary:
	if model_key == "":
		return {}
	var up := _user_path(model_key)
	if FileAccess.file_exists(up):
		return _read_json(up)
	var mp := _model_path(model_key)
	if mp != "" and FileAccess.file_exists(mp):
		return _read_json(mp)
	var oldp := "%s/%s.json" % [OLD_DIR, model_key]
	if FileAccess.file_exists(oldp):
		return _read_json(oldp)
	if FileAccess.file_exists(LEGACY_PATH):
		var lparsed := _read_json(LEGACY_PATH)
		if lparsed.has(model_key) and lparsed[model_key] is Dictionary:
			return lparsed[model_key]
	return {}


# Grava a entrada do modelo: tenta a PASTA DO MODELO (res://, editor) — fonte canônica, versionável;
# se conseguir, apaga o override user:// obsoleto. Se o res:// for somente-leitura (.exe) ou o modelo
# não estiver na biblioteca, grava o OVERRIDE em user:// (sempre gravável) — relido com precedência.
static func _save_entry(model_key: String, entry: Dictionary) -> void:
	if model_key == "":
		return
	var json := JSON.stringify(entry, "\t")
	var mp := _model_path(model_key)
	if mp != "":
		var f := FileAccess.open(mp, FileAccess.WRITE)
		if f != null:
			f.store_string(json)
			f.close()
			var up := _user_path(model_key)
			if FileAccess.file_exists(up):
				DirAccess.remove_absolute(up)
			return
	# res:// somente-leitura (.exe) ou sem pasta do modelo → override gravável em user://.
	DirAccess.make_dir_recursive_absolute(USER_DIR)
	var uf := FileAccess.open(_user_path(model_key), FileAccess.WRITE)
	if uf == null:
		push_error("LimbConfig: não foi possível gravar config de '%s'" % model_key)
		return
	uf.store_string(json)
	uf.close()


# Sub-dicionário "damage" do modelo (ou {} se não existir).
static func _damage_of_model(model_key: String) -> Dictionary:
	return _load_entry(model_key).get("damage", {})


## Multiplicador salvo para (modelo, membro), ou o default do PLANO se não houver. (Wrapper SEM
## herança de effective_multiplier; mantido para chamadores antigos.)
static func get_multiplier(model_key: String, group: String, classifier: BodyParts) -> float:
	return effective_multiplier(model_key, group, classifier, "")


## Multiplicador EFETIVO de (modelo, grupo) COM herança: o valor explícito do próprio grupo tem
## precedência; um sub-membro (PART_*) SEM valor próprio herda o do membro-DONO (owner_group) —
## explícito do dono, senão o default do plano para o dono; sem nada disso, cai no default do plano
## para o próprio grupo. owner_group só é usado para sub-membros.
static func effective_multiplier(model_key: String, group: String, classifier: BodyParts, owner_group: String = "") -> float:
	if model_key != "":
		var dmg := _damage_of_model(model_key)
		if dmg.has(group):
			return float(dmg[group])
		if group.begins_with("PART_") and owner_group != "":
			if dmg.has(owner_group):
				return float(dmg[owner_group])
			return classifier.default_multiplier(owner_group)
	return classifier.default_multiplier(group)


## True se há um multiplicador EXPLÍCITO salvo para (modelo, grupo) — distinto de "herda/usa o
## padrão". O editor usa isto para o estado do checkbox "Definir dano".
static func has_multiplier(model_key: String, group: String) -> bool:
	if model_key == "":
		return false
	return _damage_of_model(model_key).has(group)


## Remove o multiplicador explícito de (modelo, grupo) — volta a herdar/usar o padrão. Persiste.
static func clear_multiplier(model_key: String, group: String) -> void:
	if model_key == "":
		return
	var entry := _load_entry(model_key)
	var dmg: Dictionary = entry.get("damage", {})
	if dmg.has(group):
		dmg.erase(group)
		entry["damage"] = dmg
		_save_entry(model_key, entry)


## Grava o multiplicador de (modelo, membro) e persiste.
static func set_multiplier(model_key: String, group: String, mult: float) -> void:
	if model_key == "":
		return
	var entry := _load_entry(model_key)
	var dmg: Dictionary = entry.get("damage", {})
	dmg[group] = mult
	entry["damage"] = dmg
	_save_entry(model_key, entry)


## Lista de sub-membros (ossos promovidos) salvos para o modelo. [] se não houver.
static func sub_members(model_key: String) -> Array[String]:
	var out: Array[String] = []
	for b in _load_entry(model_key).get("sub_members", []):
		out.append(String(b))
	return out


## Promove um osso a sub-membro do modelo (idempotente) e persiste. `owner` != "" grava o
## membro-DONO explícito do sub-membro (para herança de dano e agrupamento na tela).
static func add_sub_member(model_key: String, bone: String, owner: String = "") -> void:
	if model_key == "" or bone == "":
		return
	var entry := _load_entry(model_key)
	var list: Array = entry.get("sub_members", [])
	if not list.has(bone):
		list.append(bone)
	entry["sub_members"] = list
	if owner != "":
		var owners: Dictionary = entry.get("sub_member_owners", {})
		owners[bone] = owner
		entry["sub_member_owners"] = owners
	_save_entry(model_key, entry)


## Afastamento (Vector3, espaço local do collider) salvo para (modelo, grupo), ou Vector3.ZERO. O grupo
## é a chave do membro (HEAD/TORSO/…) ou "PART_<osso>" do sub-membro.
static func collider_offset(model_key: String, group: String) -> Vector3:
	var raw: Variant = _load_entry(model_key).get("collider_offsets", {}).get(group, null)
	if raw is Array and raw.size() == 3:
		return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	return Vector3.ZERO


## Define (ou limpa, quando == Vector3.ZERO) o afastamento do collider de (modelo, grupo) e persiste.
static func set_collider_offset(model_key: String, group: String, offset: Vector3) -> void:
	if model_key == "" or group == "":
		return
	var entry := _load_entry(model_key)
	var offs: Dictionary = entry.get("collider_offsets", {})
	if offset == Vector3.ZERO:
		offs.erase(group)
	else:
		offs[group] = [offset.x, offset.y, offset.z]
	entry["collider_offsets"] = offs
	_save_entry(model_key, entry)


## Escala (Vector3, por eixo, espaço local) salva para (modelo, grupo), ou Vector3.ONE (sem escala).
static func collider_scale(model_key: String, group: String) -> Vector3:
	var raw: Variant = _load_entry(model_key).get("collider_scales", {}).get(group, null)
	if raw is Array and raw.size() == 3:
		return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	return Vector3.ONE


## Define (ou limpa, quando == Vector3.ONE) a escala do collider de (modelo, grupo) e persiste.
static func set_collider_scale(model_key: String, group: String, scale: Vector3) -> void:
	if model_key == "" or group == "":
		return
	var entry := _load_entry(model_key)
	var sc: Dictionary = entry.get("collider_scales", {})
	if scale == Vector3.ONE:
		sc.erase(group)
	else:
		sc[group] = [scale.x, scale.y, scale.z]
	entry["collider_scales"] = sc
	_save_entry(model_key, entry)


## Sentinela de FORMA que SUPRIME o collider de um MEMBRO (escolha "Selecione..." no dropdown de
## geometria da tela Models). Distinto de ausência (= forma automática do plano). Só usado para membros.
const SHAPE_NONE := "none"


## Forma EXPLÍCITA do collider de (modelo, grupo), escolhida na tela Models ("collider_shapes"):
## "sphere"/"box"/"capsule" (override da forma automática), SHAPE_NONE ("none" = membro SEM collider)
## ou "" quando não há escolha (usa a forma automática do plano). O grupo é a chave do membro
## (HEAD/TORSO/…) ou "PART_<osso>" do sub-membro.
static func collider_shape(model_key: String, group: String) -> String:
	return String(_load_entry(model_key).get("collider_shapes", {}).get(group, ""))


## Define (ou limpa, quando shape == "") a forma explícita do collider de (modelo, grupo) e persiste.
## shape: "sphere"/"box"/"capsule" (override), SHAPE_NONE (suprime o collider do membro) ou ""
## (remove o override → volta à forma automática). Lido por LimbColliders na construção (spawn).
static func set_collider_shape(model_key: String, group: String, shape: String) -> void:
	if model_key == "" or group == "":
		return
	var entry := _load_entry(model_key)
	var shapes: Dictionary = entry.get("collider_shapes", {})
	if shape == "":
		shapes.erase(group)
	else:
		shapes[group] = shape
	entry["collider_shapes"] = shapes
	_save_entry(model_key, entry)


## Mapa { osso → GROUP dono } dos sub-membros com dono EXPLÍCITO salvo. {} se não houver.
static func sub_member_owners(model_key: String) -> Dictionary:
	var out: Dictionary = {}
	var raw: Dictionary = _load_entry(model_key).get("sub_member_owners", {})
	for b in raw:
		out[String(b)] = String(raw[b])
	return out


## Dono (GROUP) explícito de um sub-membro, ou "" se não houver (cai na resolução automática).
static func sub_member_owner(model_key: String, bone: String) -> String:
	return String(sub_member_owners(model_key).get(bone, ""))


## Define (group != "") ou limpa (group == "") o dono explícito de um sub-membro e persiste.
## É só agrupamento LÓGICO (herança de dano) — não toca em nó/malha algum.
static func set_sub_member_owner(model_key: String, bone: String, group: String) -> void:
	if model_key == "" or bone == "":
		return
	var entry := _load_entry(model_key)
	var owners: Dictionary = entry.get("sub_member_owners", {})
	if group == "":
		owners.erase(bone)
	else:
		owners[bone] = group
	entry["sub_member_owners"] = owners
	_save_entry(model_key, entry)


## Remove um sub-membro do modelo (e o multiplicador "PART_<osso>" + o dono associados) e persiste.
static func remove_sub_member(model_key: String, bone: String) -> void:
	if model_key == "":
		return
	var entry := _load_entry(model_key)
	var list: Array = entry.get("sub_members", [])
	list.erase(bone)
	entry["sub_members"] = list
	var dmg: Dictionary = entry.get("damage", {})
	dmg.erase("PART_" + bone)
	entry["damage"] = dmg
	var owners: Dictionary = entry.get("sub_member_owners", {})
	owners.erase(bone)
	entry["sub_member_owners"] = owners
	var offs: Dictionary = entry.get("collider_offsets", {})
	offs.erase("PART_" + bone)
	entry["collider_offsets"] = offs
	var scs: Dictionary = entry.get("collider_scales", {})
	scs.erase("PART_" + bone)
	entry["collider_scales"] = scs
	var shapes: Dictionary = entry.get("collider_shapes", {})
	shapes.erase("PART_" + bone)
	entry["collider_shapes"] = shapes
	_save_entry(model_key, entry)

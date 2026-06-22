class_name LimbConfig
extends RefCounted
## Config de DANO LOCALIZADO por personagem, persistida em UM ARQUIVO POR MODELO em
## res://data/limb_config/<model_key>.json. Cada arquivo guarda, daquele modelo: o multiplicador
## de cada MEMBRO/sub-membro ("damage"), a LISTA de sub-membros promovidos ("sub_members") e a
## RELAÇÃO de DONO de cada sub-membro ("sub_member_owners" — de quem ele HERDA o dano quando não
## tem valor próprio). A tela Models grava; LimbColliders.build_for() lê na construção dos
## colliders e carimba a meta "damage_multiplier"; os projéteis/laser leem essa meta.
##
## Formato de cada arquivo <model_key>.json:
##   { "damage": { "<GROUP>": <mult> }, "sub_members": [<osso>],
##     "sub_member_owners": { "<osso>": "<GROUP_DONO>" },
##     "collider_offsets": { "<GROUP>": [x, y, z] } }
## - "collider_offsets" = afastamento (em metros, espaço LOCAL do osso/collider) aplicado à posição do
##   StaticBody3D de cada membro/sub-membro, editável na tela Models. Ausente/zero = sem afastamento.
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
## MIGRAÇÃO: o formato antigo era um ÚNICO res://data/limb_config.json ({ model_key: {...} }). Ele é
## lido automaticamente quando o arquivo por modelo ainda não existe; o primeiro SAVE de um modelo
## grava o arquivo próprio dele (res://data/limb_config/<model_key>.json), sem perder os dados.

const DIR := "res://data/limb_config"
const LEGACY_PATH := "res://data/limb_config.json"


# Caminho do arquivo por modelo.
static func _path_for(model_key: String) -> String:
	return "%s/%s.json" % [DIR, model_key]


# Entrada (dicionário) de um modelo: do arquivo PRÓPRIO, ou — se ainda não existir — do arquivo
# combinado ANTIGO (migração transparente na leitura). {} quando não há nada / está corrompido.
static func _load_entry(model_key: String) -> Dictionary:
	if model_key == "":
		return {}
	var p := _path_for(model_key)
	if FileAccess.file_exists(p):
		var f := FileAccess.open(p, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if parsed is Dictionary:
				return parsed
		return {}
	# Fallback de migração: a entrada deste modelo no arquivo combinado antigo.
	if FileAccess.file_exists(LEGACY_PATH):
		var lf := FileAccess.open(LEGACY_PATH, FileAccess.READ)
		if lf != null:
			var lparsed: Variant = JSON.parse_string(lf.get_as_text())
			lf.close()
			if lparsed is Dictionary and lparsed.has(model_key) and lparsed[model_key] is Dictionary:
				return lparsed[model_key]
	return {}


# Grava a entrada do modelo no seu arquivo próprio (criando o diretório).
static func _save_entry(model_key: String, entry: Dictionary) -> void:
	if model_key == "":
		return
	DirAccess.make_dir_recursive_absolute(DIR)
	var p := _path_for(model_key)
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		push_error("LimbConfig: não foi possível gravar '%s': %s" % [p, error_string(FileAccess.get_open_error())])
		return
	f.store_string(JSON.stringify(entry, "\t"))
	f.close()


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
	_save_entry(model_key, entry)

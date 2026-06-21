class_name LimbConfig
extends RefCounted
## Config de DANO LOCALIZADO por modelo, persistida em res://data/limb_config.json.
## Guarda, por modelo: o multiplicador de cada MEMBRO/sub-membro e a LISTA de
## sub-membros (ossos auxiliares PROMOVIDOS a peça com collider próprio). A tela Models
## grava; LimbColliders.build_for() lê na construção dos colliders e carimba a meta
## "damage_multiplier". Os projéteis/laser (bullet.gd, laser_shooter.gd) leem essa meta.
##
## Formato: { "<model_key>": { "damage": { "<GROUP>": <mult> }, "sub_members": [<osso>],
##            "sub_member_owners": { "<osso>": "<GROUP_DONO>" } } }
## - model_key = nome da pasta do modelo ("red_robot", "player"), o MESMO valor que
##   LimbColliders.model_key recebe no gameplay.
## - GROUP = chave do plano corporal (HEAD/TORSO/ARM_L/…/LEG_FL/…) ou "PART_<osso>" p/ sub-membro.
## - O default de cada grupo vem do PLANO ([[BodyParts]].default_multiplier), então o
##   arquivo só guarda os ajustes do usuário — sem entrada em "damage" = SEM valor próprio.
## - sub_member_owners: membro-DONO escolhido EXPLICITAMENTE para cada sub-membro (agrupamento
##   só lógico, p/ herança de dano). Vazio/ausente = cai na resolução automática por nome+
##   hierarquia (LimbColliders.resolve_sub_member_owner).
##
## HERANÇA (ver effective_multiplier): o valor EXPLÍCITO de um grupo tem precedência; um
## sub-membro SEM valor próprio herda o do membro-dono; sem nenhum, usa o default do plano.
## "Nenhum valor de dano é obrigatório" — sem entrada em "damage" significa herdar/usar o padrão.

const PATH := "res://data/limb_config.json"


## Lê a tabela inteira do JSON. {} se ausente/corrompido (o jogo cai nos defaults).
static func load_table() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


## Multiplicador salvo para (modelo, membro), ou o default do PLANO (`classifier`) se
## não houver. model_key vazio também cai no default. (Sem herança — wrapper de
## effective_multiplier sem owner; mantido para chamadores antigos.)
static func get_multiplier(model_key: String, group: String, classifier: BodyParts) -> float:
	return effective_multiplier(model_key, group, classifier, "")


## Multiplicador EFETIVO de (modelo, grupo) COM herança: o valor explícito do próprio grupo
## tem precedência; um sub-membro (PART_*) SEM valor próprio herda o do membro-DONO
## (owner_group) — explícito do dono, senão o default do plano para o dono; sem nada disso,
## cai no default do plano para o próprio grupo. owner_group só é usado para sub-membros.
static func effective_multiplier(model_key: String, group: String, classifier: BodyParts, owner_group: String = "") -> float:
	if model_key != "":
		var dmg := _damage_of(load_table(), model_key)
		if dmg.has(group):
			return float(dmg[group])
		if group.begins_with("PART_") and owner_group != "":
			if dmg.has(owner_group):
				return float(dmg[owner_group])
			return classifier.default_multiplier(owner_group)
	return classifier.default_multiplier(group)


## True se há um multiplicador EXPLÍCITO salvo para (modelo, grupo) — distinto de "herda/usa
## o padrão". O editor usa isto para o estado do checkbox "Definir dano".
static func has_multiplier(model_key: String, group: String) -> bool:
	if model_key == "":
		return false
	return _damage_of(load_table(), model_key).has(group)


## Remove o multiplicador explícito de (modelo, grupo) — volta a herdar/usar o padrão. Persiste.
static func clear_multiplier(model_key: String, group: String) -> void:
	if model_key == "":
		return
	var table := load_table()
	if not table.has(model_key):
		return
	var entry: Dictionary = table[model_key]
	var dmg: Dictionary = entry.get("damage", {})
	if dmg.has(group):
		dmg.erase(group)
		entry["damage"] = dmg
		table[model_key] = entry
		_save_table(table)


## Grava o multiplicador de (modelo, membro) e persiste o JSON.
static func set_multiplier(model_key: String, group: String, mult: float) -> void:
	if model_key == "":
		return
	var table := load_table()
	var entry := _entry_of(table, model_key)
	if not entry.has("damage"):
		entry["damage"] = {}
	entry["damage"][group] = mult
	table[model_key] = entry
	_save_table(table)


## Lista de sub-membros (ossos promovidos) salvos para o modelo. [] se não houver.
static func sub_members(model_key: String) -> Array[String]:
	var out: Array[String] = []
	if model_key == "":
		return out
	var entry: Dictionary = load_table().get(model_key, {})
	for b in entry.get("sub_members", []):
		out.append(String(b))
	return out


## Promove um osso a sub-membro do modelo (idempotente) e persiste. `owner` != "" grava o
## membro-DONO explícito do sub-membro (para herança de dano e agrupamento na tela).
static func add_sub_member(model_key: String, bone: String, owner: String = "") -> void:
	if model_key == "" or bone == "":
		return
	var table := load_table()
	var entry := _entry_of(table, model_key)
	var list: Array = entry.get("sub_members", [])
	if not list.has(bone):
		list.append(bone)
	entry["sub_members"] = list
	if owner != "":
		var owners: Dictionary = entry.get("sub_member_owners", {})
		owners[bone] = owner
		entry["sub_member_owners"] = owners
	table[model_key] = entry
	_save_table(table)


## Mapa { osso → GROUP dono } dos sub-membros com dono EXPLÍCITO salvo. {} se não houver.
static func sub_member_owners(model_key: String) -> Dictionary:
	var out: Dictionary = {}
	if model_key == "":
		return out
	var entry: Dictionary = load_table().get(model_key, {})
	var raw: Dictionary = entry.get("sub_member_owners", {})
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
	var table := load_table()
	var entry := _entry_of(table, model_key)
	var owners: Dictionary = entry.get("sub_member_owners", {})
	if group == "":
		owners.erase(bone)
	else:
		owners[bone] = group
	entry["sub_member_owners"] = owners
	table[model_key] = entry
	_save_table(table)


## Remove um sub-membro do modelo (e o multiplicador "PART_<osso>" associado) e persiste.
static func remove_sub_member(model_key: String, bone: String) -> void:
	if model_key == "":
		return
	var table := load_table()
	if not table.has(model_key):
		return
	var entry: Dictionary = table[model_key]
	var list: Array = entry.get("sub_members", [])
	list.erase(bone)
	entry["sub_members"] = list
	var dmg: Dictionary = entry.get("damage", {})
	dmg.erase("PART_" + bone)
	entry["damage"] = dmg
	var owners: Dictionary = entry.get("sub_member_owners", {})
	owners.erase(bone)
	entry["sub_member_owners"] = owners
	table[model_key] = entry
	_save_table(table)


# ── Internos ──────────────────────────────────────────────────────────────────

# Sub-dicionário "damage" do modelo (ou {} se não existir).
static func _damage_of(table: Dictionary, model_key: String) -> Dictionary:
	var entry: Dictionary = table.get(model_key, {})
	return entry.get("damage", {})


# Entrada do modelo, criando-a se preciso (referência mutável dentro de `table`).
static func _entry_of(table: Dictionary, model_key: String) -> Dictionary:
	if not table.has(model_key):
		table[model_key] = {}
	return table[model_key]


static func _save_table(table: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_error("LimbConfig: não foi possível gravar '%s': %s" % [PATH, error_string(FileAccess.get_open_error())])
		return
	f.store_string(JSON.stringify(table, "\t"))
	f.close()

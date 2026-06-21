class_name LimbConfig
extends RefCounted
## Config de DANO LOCALIZADO por modelo, persistida em res://data/limb_config.json.
## Guarda, por modelo: o multiplicador de cada MEMBRO/sub-membro e a LISTA de
## sub-membros (ossos auxiliares PROMOVIDOS a peça com collider próprio). A tela Models
## grava; LimbColliders.build_for() lê na construção dos colliders e carimba a meta
## "damage_multiplier". Os projéteis/laser (bullet.gd, laser_shooter.gd) leem essa meta.
##
## Formato: { "<model_key>": { "damage": { "<GROUP>": <mult> }, "sub_members": [<osso>] } }
## - model_key = nome da pasta do modelo ("red_robot", "player"), o MESMO valor que
##   LimbColliders.model_key recebe no gameplay.
## - GROUP = chave do plano corporal (HEAD/TORSO/ARM_L/…/LEG_FL/…) ou "PART_<osso>" p/ sub-membro.
## - O default de cada grupo vem do PLANO ([[BodyParts]].default_multiplier), então o
##   arquivo só guarda os ajustes do usuário — sem entrada = comportamento padrão.

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
## não houver. model_key vazio também cai no default.
static func get_multiplier(model_key: String, group: String, classifier: BodyParts) -> float:
	if model_key != "":
		var dmg := _damage_of(load_table(), model_key)
		if dmg.has(group):
			return float(dmg[group])
	return classifier.default_multiplier(group)


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


## Promove um osso a sub-membro do modelo (idempotente) e persiste.
static func add_sub_member(model_key: String, bone: String) -> void:
	if model_key == "" or bone == "":
		return
	var table := load_table()
	var entry := _entry_of(table, model_key)
	var list: Array = entry.get("sub_members", [])
	if not list.has(bone):
		list.append(bone)
	entry["sub_members"] = list
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

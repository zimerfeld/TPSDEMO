extends Node
## Templates persistidos de composição de level.
##
## Cada template define personagens aliados/inimigos e estruturas a serem instanciados no level,
## com placement por posições explícitas, área aleatória ou formação de combate.

const FILE_PATH := "user://level_templates.json"
const DEFAULT_RANDOM_SIZE := Vector3(34.0, 0.0, 34.0)
## Raízes da navegação em CASCATA por pastas (um OptionButton por nível de pasta, no diálogo):
## personagens no Gerenciador de Templates, cenários no Gerenciador de Cenários.
const CHARACTERS_ROOT := "res://library3D/characters"
const SCENERIES_ROOT := "res://library3D/sceneries"

var templates: Array[Dictionary] = []
var _active_by_level: Dictionary = {}
var _active_scenery_by_level: Dictionary = {}


func _ready() -> void:
	load_templates()
	if templates.is_empty():
		_install_defaults()


func load_templates() -> void:
	templates.clear()
	if not FileAccess.file_exists(FILE_PATH):
		return
	var file := FileAccess.open(FILE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_active_by_level = (parsed as Dictionary).get("active_by_level", {})
		_active_scenery_by_level = (parsed as Dictionary).get("active_scenery_by_level", {})
		for raw in (parsed as Dictionary).get("templates", []):
			if raw is Dictionary:
				templates.append(_normalize_template(raw))


func save_templates() -> void:
	var data := {
		"templates": templates,
		"active_by_level": _active_by_level,
		"active_scenery_by_level": _active_scenery_by_level,
	}
	var file := FileAccess.open(FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("LevelTemplateManager: não foi possível salvar templates.")
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func all_templates() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t in templates:
		out.append(t.duplicate(true))
	return out


# Templates do level filtrados por CATEGORIA: "spawn" (Gerenciador de Templates — personagens)
# ou "scenery" (Gerenciador de Cenários — objetos de cenário). Categorias têm listas e ativos
# independentes, mas dividem o mesmo arquivo/armazenamento.
func templates_for_level(level_path: String, category: String = "spawn") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t in templates:
		if String(t.get("category", "spawn")) != category:
			continue
		var template_level := String(t.get("level_path", ""))
		if template_level == "" or template_level == level_path:
			out.append(t.duplicate(true))
	return out


func upsert_template(template: Dictionary) -> String:
	var normalized := _normalize_template(template)
	var id := String(normalized.get("id", ""))
	if id == "":
		id = "tpl_%d" % Time.get_unix_time_from_system()
		normalized["id"] = id
	for i in templates.size():
		if String(templates[i].get("id", "")) == id:
			templates[i] = normalized
			save_templates()
			return id
	templates.append(normalized)
	save_templates()
	return id


func remove_template(id: String) -> void:
	for i in range(templates.size() - 1, -1, -1):
		if String(templates[i].get("id", "")) == id:
			templates.remove_at(i)
			break
	for level_path in _active_by_level.keys():
		if String(_active_by_level[level_path]) == id:
			_active_by_level.erase(level_path)
	for level_path in _active_scenery_by_level.keys():
		if String(_active_scenery_by_level[level_path]) == id:
			_active_scenery_by_level.erase(level_path)
	save_templates()


func set_active_template(level_path: String, template_id: String) -> void:
	if template_id == "":
		_active_by_level.erase(level_path)
	else:
		_active_by_level[level_path] = template_id
	save_templates()


func active_template_id(level_path: String) -> String:
	return String(_active_by_level.get(level_path, ""))


func active_template(level_path: String) -> Dictionary:
	return _template_by_id(active_template_id(level_path))


# Ativo da categoria "scenery" — espelho do ativo de spawn, num mapa próprio (um level pode ter
# um template de personagens E um de cenário ativos ao mesmo tempo).
func set_active_scenery(level_path: String, template_id: String) -> void:
	if template_id == "":
		_active_scenery_by_level.erase(level_path)
	else:
		_active_scenery_by_level[level_path] = template_id
	save_templates()


func active_scenery_id(level_path: String) -> String:
	return String(_active_scenery_by_level.get(level_path, ""))


func active_scenery(level_path: String) -> Dictionary:
	return _template_by_id(active_scenery_id(level_path))


func _template_by_id(id: String) -> Dictionary:
	if id == "":
		return {}
	for t in templates:
		if String(t.get("id", "")) == id:
			return t.duplicate(true)
	return {}


# Aplica os templates ATIVOS do level (spawn E cenário) ao iniciar — solo ou sala online.
func apply_active_template(level_path: String, spawned_nodes: Node3D, _spawn_points_parent: Node3D = null) -> bool:
	if spawned_nodes == null:
		return false
	var applied := false
	for template in [active_template(level_path), active_scenery(level_path)]:
		if not (template as Dictionary).is_empty():
			_apply_template(template, spawned_nodes)
			applied = true
	return applied


# ---- Navegação em cascata por pastas (diálogos de template/cenário) ------------------------

# Um passo da navegação: as SUBPASTAS navegáveis de `dir_path` (só as que contêm algum modelo,
# em qualquer profundidade) e o MODELO da própria pasta (cena cujo basename == nome da pasta),
# se houver. O diálogo monta um OptionButton por passo e desce a árvore com isto.
func browse_dir(dir_path: String) -> Dictionary:
	var folders: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return {"folders": folders, "model": {}}
	for child in dir.get_directories():
		if child.begins_with("."):
			continue
		if _dir_has_models("%s/%s" % [dir_path, child]):
			folders.append(child)
	folders.sort()
	return {"folders": folders, "model": _dir_model(dir_path)}


# O modelo "da pasta": a cena cujo basename é o nome da pasta (convenção da biblioteca —
# cenas irmãs como bomb.tscn/impact_effect.tscn não representam a pasta).
func _dir_model(dir_path: String) -> Dictionary:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return {}
	var key := dir_path.get_file()
	for raw_name in dir.get_files():
		var file := _logical_name(raw_name)
		if file.ends_with(".tscn") and file.get_basename() == key:
			return {"key": key, "path": "%s/%s" % [dir_path, file], "label": _display_name(key)}
	return {}


func _dir_has_models(dir_path: String) -> bool:
	if not _dir_model(dir_path).is_empty():
		return true
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return false
	for child in dir.get_directories():
		if child.begins_with("."):
			continue
		if _dir_has_models("%s/%s" % [dir_path, child]):
			return true
	return false


func _apply_template(template: Dictionary, spawned_nodes: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var index := 0
	for raw_entry in template.get("entries", []):
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		var scene_path := String(entry.get("scene_path", ""))
		var scene := load(scene_path) as PackedScene
		if scene == null:
			push_warning("LevelTemplateManager: cena inválida no template: %s" % scene_path)
			continue
		var positions := _positions_for(entry, rng)
		for position in positions:
			var node := scene.instantiate()
			if not node is Node3D:
				node.queue_free()
				continue
			var n3d := node as Node3D
			n3d.name = "%s_%s_%03d" % [
				String(entry.get("kind", "node")).capitalize(),
				String(entry.get("model_key", scene_path.get_file().get_basename())),
				index,
			]
			index += 1
			n3d.position = position
			n3d.rotation.y = deg_to_rad(float(entry.get("rotation_y", 0.0)))
			_configure_spawned_node(n3d, entry)
			spawned_nodes.add_child(n3d, true)


func _configure_spawned_node(node: Node3D, entry: Dictionary) -> void:
	var faction := String(entry.get("faction", "neutral"))
	node.set_meta("template_faction", faction)
	if faction == "friendly" and node.get("bot_controlled") != null:
		node.set("bot_controlled", true)
		if node.get("player_id") != null:
			node.set("player_id", 1)
	if faction == "enemy" and node.get("bot_controlled") != null:
		node.set("bot_controlled", false)


func _positions_for(entry: Dictionary, rng: RandomNumberGenerator) -> Array[Vector3]:
	var placement: String = String(entry.get("placement", "random"))
	var count: int = maxi(1, int(entry.get("count", 1)))
	if placement == "coordinates":
		var out: Array[Vector3] = []
		for p in entry.get("positions", []):
			out.append(_vector3_from(p))
		return out if not out.is_empty() else [Vector3.ZERO]
	if placement == "formation":
		return _formation_positions(entry, count)
	var center: Vector3 = _vector3_from(entry.get("random_center", Vector3.ZERO))
	var size: Vector3 = _vector3_from(entry.get("random_size", DEFAULT_RANDOM_SIZE))
	var out_random: Array[Vector3] = []
	for i in range(count):
		out_random.append(center + Vector3(
			rng.randf_range(-size.x * 0.5, size.x * 0.5),
			rng.randf_range(-size.y * 0.5, size.y * 0.5),
			rng.randf_range(-size.z * 0.5, size.z * 0.5)))
	return out_random


func _formation_positions(entry: Dictionary, count: int) -> Array[Vector3]:
	var origin: Vector3 = _vector3_from(entry.get("formation_origin", Vector3.ZERO))
	var spacing: float = maxf(0.5, float(entry.get("spacing", 4.0)))
	var formation: String = String(entry.get("formation", "line"))
	var out: Array[Vector3] = []
	if formation == "circle":
		var radius := maxf(spacing, spacing * float(count) / TAU)
		for i in range(count):
			var a := TAU * float(i) / float(maxi(count, 1))
			out.append(origin + Vector3(cos(a) * radius, 0.0, sin(a) * radius))
	elif formation == "wedge":
		out.append(origin)
		var row := 1
		while out.size() < count:
			out.append(origin + Vector3(-spacing * row, 0.0, spacing * row))
			if out.size() >= count:
				break
			out.append(origin + Vector3(spacing * row, 0.0, spacing * row))
			row += 1
	elif formation == "grid":
		var cols := ceili(sqrt(float(count)))
		for i in range(count):
			# i / cols é divisão inteira PROPOSITAL: dá a linha (row) da grade.
			@warning_ignore("integer_division")
			var grid_row := i / cols
			out.append(origin + Vector3(float(i % cols) * spacing, 0.0, float(grid_row) * spacing))
	else:
		for i in range(count):
			out.append(origin + Vector3(float(i) * spacing, 0.0, 0.0))
	return out


func _normalize_template(raw: Dictionary) -> Dictionary:
	var t := raw.duplicate(true)
	t["id"] = String(t.get("id", ""))
	t["name"] = String(t.get("name", "Template"))
	t["level_path"] = String(t.get("level_path", ""))
	t["category"] = String(t.get("category", "spawn"))
	if not t.get("entries", []) is Array:
		t["entries"] = []
	# Migração: o antigo kind "structure" virou a categoria/kind "scenery" (a pasta
	# library3D/structures deixou de existir; cenários vivem em library3D/sceneries).
	for raw_entry in t["entries"]:
		if raw_entry is Dictionary and String((raw_entry as Dictionary).get("kind", "")) == "structure":
			(raw_entry as Dictionary)["kind"] = "scenery"
	return t


func _vector3_from(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and (value as Array).size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	if value is Dictionary:
		return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))
	if value is String:
		var parts := (value as String).split(",", false)
		if parts.size() >= 3:
			return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
	return Vector3.ZERO


# No .exe exportado os arquivos aparecem como "*.tscn.remap" (e imports como
# "*.import") no DirAccess; o nome lógico remove esses sufixos para o filtro
# de extensão funcionar igual no editor e no build (mesmo padrão da tela Models).
func _logical_name(file_name: String) -> String:
	var ext := file_name.get_extension().to_lower()
	if ext == "remap" or ext == "import":
		return file_name.get_basename()
	return file_name


func _display_name(key: String) -> String:
	return key.replace("_", " ").capitalize()


func _install_defaults() -> void:
	templates = [
		{
			"id": "default_level_2_air_support",
			"name": "Level 2 - Caça aérea",
			"level_path": "res://scenes3D/level_2/level_2.tscn",
			"entries": [
				{"kind": "character", "faction": "enemy", "model_key": "criatura_alada", "scene_path": "res://library3D/characters/criatura_alada/criatura_alada.tscn", "placement": "random", "random_center": [18, 1, 0], "random_size": [18, 0, 18], "count": 2},
				{"kind": "character", "faction": "friendly", "model_key": "player", "scene_path": "res://library3D/characters/player/player.tscn", "placement": "formation", "formation": "line", "formation_origin": [-10, 1, -4], "count": 1, "spacing": 4.0}
			]
		}
	]
	save_templates()

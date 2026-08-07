class_name TemplateManagerBase
extends Node
## Base compartilhada dos gerenciadores de composição de level. Cada SUBCLASSE (autoload) cuida de
## UMA responsabilidade/pasta da biblioteca 3D e persiste no SEU próprio arquivo `user://`:
##   • CharacterTemplateManager → personagens (`library3D/characters`), com facção;
##   • SceneryTemplateManager    → cenários  (`library3D/sceneries`), sem facção.
##
## Cada template define entradas a instanciar no level, com placement por posições explícitas, área
## aleatória ou formação de combate. As subclasses só declaram arquivo/raiz/kind e o default inicial.

const DEFAULT_RANDOM_SIZE := Vector3(34.0, 0.0, 34.0)
## Raiz das armas (usada pelo dropdown "Arma" do gerenciador de personagens). Fixa — as armas não
## dependem da categoria do manager.
const WEAPONS_DIR := "res://library3D/weapons"
## Arquivo legado (categorias juntas) do antigo LevelTemplateManager — migrado 1x por subclasse.
const LEGACY_FILE := "user://level_templates.json"

var templates: Array[Dictionary] = []
var _active_by_level: Dictionary = {}
# scene_path → problemas de replicação (ver contract_issues_of). A cascata dos gerenciadores
# reconsulta a cada clique e a checagem instancia a cena; sem o cache seria I/O a cada seleção.
var _contract_cache: Dictionary = {}


func _ready() -> void:
	_load_or_migrate()
	if templates.is_empty():
		_install_defaults()
	# Cura caminhos obsoletos: entradas salvas com um scene_path que não existe mais (ex.: a pasta foi
	# movida/renomeada, como a extinta library3D/characters/enemies/) são relocalizadas pelo model_key
	# sob a raiz ATUAL da categoria, e o arquivo é regravado. Sem isto, a cascata do diálogo não
	# consegue re-selecionar o modelo salvo (abre em "Selecione...").
	if _heal_entry_paths():
		save()


# ---- Ganchos virtuais (cada subclasse define) ---------------------------------------------

# Arquivo próprio da subclasse (ex.: "user://character_templates.json").
func _file_path() -> String:
	return ""


# Raiz da navegação em cascata por pastas (ex.: "res://library3D/characters"). Público: a UI lê.
func root_dir() -> String:
	return ""


# Kind gravado nas entradas ("character" ou "scenery").
func _entry_kind() -> String:
	return "node"


# Chave do mapa de ativos no arquivo LEGADO ("active_by_level" ou "active_scenery_by_level").
func _legacy_active_key() -> String:
	return "active_by_level"


# True se um template do arquivo legado pertence a ESTA subclasse (por categoria).
func _matches_legacy(_raw: Dictionary) -> bool:
	return true


# Templates instalados quando não há nada salvo (default de fábrica). Vazio por padrão.
func _install_defaults() -> void:
	pass


# ---- Persistência -------------------------------------------------------------------------

# Carrega o arquivo próprio; na 1ª execução (sem arquivo próprio) migra do arquivo legado.
func _load_or_migrate() -> void:
	if FileAccess.file_exists(_file_path()):
		_load()
	else:
		_migrate_from_legacy()


func _load() -> void:
	templates.clear()
	_active_by_level.clear()
	var file := FileAccess.open(_file_path(), FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Dictionary:
		_active_by_level = (parsed as Dictionary).get("active_by_level", {})
		for raw in (parsed as Dictionary).get("templates", []):
			if raw is Dictionary:
				templates.append(_normalize_template(raw))


# Divide o arquivo legado (personagens + cenários juntos): traz só os templates desta categoria e o
# mapa de ativos correspondente, e grava no arquivo próprio. Roda uma única vez (depois já existe
# o arquivo próprio). Sem arquivo legado, é no-op — a subclasse cai nos defaults de fábrica.
func _migrate_from_legacy() -> void:
	if not FileAccess.file_exists(LEGACY_FILE):
		return
	var file := FileAccess.open(LEGACY_FILE, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return
	_active_by_level = (parsed as Dictionary).get(_legacy_active_key(), {})
	for raw in (parsed as Dictionary).get("templates", []):
		if raw is Dictionary and _matches_legacy(raw):
			templates.append(_normalize_template(raw))
	if not templates.is_empty() or not _active_by_level.is_empty():
		save()


func save() -> void:
	var data := {
		"templates": templates,
		"active_by_level": _active_by_level,
	}
	var file := FileAccess.open(_file_path(), FileAccess.WRITE)
	if file == null:
		push_error("%s: não foi possível salvar templates." % get_class())
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


# ---- API de templates ---------------------------------------------------------------------

# Templates aplicáveis a `level_path` (os presos a este level + os globais de level_path "").
func templates_for_level(level_path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t in templates:
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
			save()
			return id
	templates.append(normalized)
	save()
	return id


func remove_template(id: String) -> void:
	for i in range(templates.size() - 1, -1, -1):
		if String(templates[i].get("id", "")) == id:
			templates.remove_at(i)
			break
	for level_path in _active_by_level.keys():
		if String(_active_by_level[level_path]) == id:
			_active_by_level.erase(level_path)
	save()


func set_active(level_path: String, template_id: String) -> void:
	if template_id == "":
		_active_by_level.erase(level_path)
	else:
		_active_by_level[level_path] = template_id
	save()


func active_id(level_path: String) -> String:
	return String(_active_by_level.get(level_path, ""))


func active(level_path: String) -> Dictionary:
	return _template_by_id(active_id(level_path))


func _template_by_id(id: String) -> Dictionary:
	if id == "":
		return {}
	for t in templates:
		if String(t.get("id", "")) == id:
			return t.duplicate(true)
	return {}


# Aplica o template ATIVO do level (se houver) ao iniciar — solo ou "Hospedar Somente". True se HÁ
# template ativo (mesmo que alguma entrada tenha caminho morto e seja pulada). Spawn IMEDIATO.
func apply_active(level_path: String, spawned_nodes: Node3D) -> bool:
	if spawned_nodes == null:
		return false
	var template := active(level_path)
	if template.is_empty():
		return false
	for job in _plan_template(template):
		_spawn_job(job, spawned_nodes)
	return true


# Igual a apply_active, mas ESPALHA os spawns ao longo de vários frames (per_frame por frame de física)
# em vez de materializar tudo de uma vez. Usado nas SALAS online: 16+ entidades nascendo no mesmo frame
# davam um pico de stall no CLIENTE (compilação de shader + construção de LimbColliders) longo o
# bastante p/ o inimigo "congelar" e, em hardware fraco, estourar o timeout do ENet (a conexão cai e o
# tiro deixa de chegar ao servidor → "não detecta colisão"). Espalhando o spawn, o cliente recebe as
# entidades ao longo de frames → sem pico. Corrotina (fire-and-forget): aparecem nos próximos frames.
# Ver [[salas-multilevel-fases]].
func apply_active_gradual(level_path: String, spawned_nodes: Node3D, per_frame: int = 1) -> bool:
	if spawned_nodes == null:
		return false
	var template := active(level_path)
	if template.is_empty():
		return false
	var count := 0
	for job in _plan_template(template):
		if not is_instance_valid(spawned_nodes):
			return true  # sala fechada no meio do spawn gradual
		_spawn_job(job, spawned_nodes)
		count += 1
		if count % maxi(1, per_frame) == 0:
			await get_tree().physics_frame
	return true


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


# Lista as ARMAS disponíveis para o dropdown "Arma": cada subpasta de library3D/weapons que tem uma
# cena homônima (convenção da biblioteca). Cada entrada: {key, path, label}, ordenadas por rótulo.
# Reusa _dir_model/_logical_name, então funciona igual no editor e no .exe exportado.
func list_weapons() -> Array:
	var out: Array = []
	var dir := DirAccess.open(WEAPONS_DIR)
	if dir == null:
		return out
	for child in dir.get_directories():
		if child.begins_with("."):
			continue
		var model := _dir_model("%s/%s" % [WEAPONS_DIR, child])
		if not model.is_empty():
			out.append(model)
	out.sort_custom(func(a, b): return String(a["label"]) < String(b["label"]))
	return out


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


# Percorre todos os templates e conserta scene_paths que não existem mais, relocalizando o modelo
# pelo model_key sob a raiz atual. Devolve true se algo mudou (o chamador regrava). No-op quando
# todos os caminhos são válidos.
func _heal_entry_paths() -> bool:
	var changed := false
	for t in templates:
		for raw_entry in t.get("entries", []):
			if not raw_entry is Dictionary:
				continue
			var entry: Dictionary = raw_entry
			var path := String(entry.get("scene_path", ""))
			var key := String(entry.get("model_key", ""))
			if path == "" or key == "" or ResourceLoader.exists(path):
				continue
			var fixed := _find_model_path(root_dir(), key)
			if fixed != "" and fixed != path:
				entry["scene_path"] = fixed
				changed = true
	return changed


# Procura, recursivamente sob `dir_path`, a pasta-modelo cujo key (nome da pasta) == `key` e devolve
# o caminho da sua cena; "" se não encontrar.
func _find_model_path(dir_path: String, key: String) -> String:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return ""
	for child in dir.get_directories():
		if child.begins_with("."):
			continue
		var sub := "%s/%s" % [dir_path, child]
		var model := _dir_model(sub)
		if not model.is_empty() and String(model.get("key", "")) == key:
			return String(model.get("path", ""))
		var deeper := _find_model_path(sub, key)
		if deeper != "":
			return deeper
	return ""


# ---- Instanciação no level ----------------------------------------------------------------

# Monta a lista PLANA de spawns (cena + posição + entrada) SEM tocar na árvore. Entradas com caminho
# de cena inexistente (modelo removido/movido — ex.: a extinta library3D/structures) são PULADAS com
# aviso, sem derrubar o resto do template. Cada job: {scene, entry, position, index}.
func _plan_template(template: Dictionary) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var jobs: Array = []
	var index := 0
	for raw_entry in template.get("entries", []):
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		var scene_path := String(entry.get("scene_path", ""))
		# Caminho morto (modelo removido/movido, ex.: a extinta library3D/structures): checa ANTES de
		# load() p/ pular a entrada sem o log de erro da engine, sem derrubar o resto do template.
		if scene_path == "" or not ResourceLoader.exists(scene_path):
			push_warning("%s: cena inexistente no template (entrada pulada): %s" % [get_class(), scene_path])
			continue
		var scene := load(scene_path) as PackedScene
		if scene == null:
			continue
		for position in _positions_for(entry, rng):
			jobs.append({"scene": scene, "entry": entry, "position": position, "index": index})
			index += 1
	return jobs


# Instancia e posiciona UM job no SpawnedNodes. O child_entered_tree do RoomManager aplica a
# visibilidade da sala; o MultiplayerSpawner replica a cena aos peers da sala.
func _spawn_job(job: Dictionary, spawned_nodes: Node3D) -> void:
	var scene: PackedScene = job["scene"]
	var entry: Dictionary = job["entry"]
	var node := scene.instantiate()
	if not node is Node3D:
		node.queue_free()
		return
	var n3d := node as Node3D
	var scene_path := String(entry.get("scene_path", ""))
	n3d.name = "%s_%s_%03d" % [
		String(entry.get("kind", "node")).capitalize(),
		String(entry.get("model_key", scene_path.get_file().get_basename())),
		int(job["index"]),
	]
	n3d.position = job["position"]
	n3d.rotation.y = deg_to_rad(float(entry.get("rotation_y", 0.0)))
	_configure_spawned_node(n3d, entry)
	# O MultiplayerSpawner replica QUAL cena instanciar — o transform aplicado acima NÃO viaja com ela.
	# Peças de cenário são estáticas (nada sincroniza sua posição depois), então elas chegavam ao
	# cliente em (0,0,0), empilhadas na origem. Copiar o transform para as PROPERTIES DE SPAWN antes do
	# add_child o coloca dentro do pacote de criação do nó, e o cliente nasce nas coordenadas do
	# servidor. Ver [[SceneryPiece]].
	if n3d is SceneryPiece:
		var piece := n3d as SceneryPiece
		piece.spawn_position = n3d.position
		piece.spawn_rotation_y = n3d.rotation.y
		piece.spawn_scale = n3d.scale.x
	elif String(entry.get("kind", "")) == "scenery":
		_warn_off_contract(scene_path, n3d)
	spawned_nodes.add_child(n3d, true)


# Modelos de cenário JÁ EM TELA que não cumprem o contrato de replicação: avisa uma única vez por
# cena (o spawn acontece em rajada; sem o guard o log viraria ruído). Não dá para consertar aqui —
# as spawn properties precisam existir na CENA, que os dois lados instanciam. Corrigir com:
#   godot --headless --path . --script scripts/scenery_contract.gd -- --apply
static var _warned_scenes: Dictionary = {}


static func _warn_off_contract(scene_path: String, node: Node) -> void:
	if _warned_scenes.has(scene_path):
		return
	_warned_scenes[scene_path] = true
	push_warning("Cenário fora do contrato de replicação (%s): %s. No cliente esta peça nasce em (0,0,0). Rode: godot --headless --path . --script scripts/scenery_contract.gd -- --apply" % [
		scene_path, ", ".join(SceneryPiece.contract_issues(node))])


## Problemas de replicação do modelo em `scene_path` (vazio = ok: nasce nas coordenadas do servidor
## também no cliente). Usado pelos gerenciadores para avisar na hora em que o modelo é ESCOLHIDO na
## tela — antes de o template ir para uma sala online. Instancia a cena só para inspecionar e a
## libera em seguida; o resultado é memorizado (a cascata reconsulta a cada clique).
func contract_issues_of(scene_path: String) -> PackedStringArray:
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		return PackedStringArray()
	if _contract_cache.has(scene_path):
		return _contract_cache[scene_path]
	var packed: PackedScene = load(scene_path)
	if packed == null:
		return PackedStringArray()
	var probe := packed.instantiate()
	var issues := _node_contract_issues(probe)
	probe.free()
	_contract_cache[scene_path] = issues
	return issues


## Requisito de replicação DESTA categoria (cada subclasse responde pelo seu). Vazio = cumpre.
func _node_contract_issues(_root: Node) -> PackedStringArray:
	return PackedStringArray()


## Um modelo replica a posição se ALGUM MultiplayerSynchronizer da cena envia, no pacote de spawn,
## uma property de transform. É o que impede a entidade de nascer em (0,0,0) no cliente — ver
## SceneryPiece. Serve de base para o requisito das duas categorias.
static func replicates_transform(root: Node) -> bool:
	for sync in _synchronizers_of(root):
		var cfg := sync.replication_config
		if cfg == null:
			continue
		for p in cfg.get_properties():
			var prop := String(p).get_slice(":", 1)
			if prop in ["net_transform", "spawn_position", "position", "transform", "global_position"]:
				return true
	return false


static func _synchronizers_of(node: Node) -> Array[MultiplayerSynchronizer]:
	var out: Array[MultiplayerSynchronizer] = []
	if node is MultiplayerSynchronizer:
		out.append(node as MultiplayerSynchronizer)
	for c in node.get_children():
		out.append_array(_synchronizers_of(c))
	return out


# Escala mínima aceita (5% do tamanho original): abaixo disso o modelo vira um ponto e seus colliders
# degeneram. O campo "Escala (%)" dos gerenciadores já limita a entrada; aqui é a rede de segurança
# para templates salvos à mão.
const MIN_SCALE_FACTOR := 0.05


# Fator de escala de uma entrada: "scale_percent" é a variação PERCENTUAL sobre o tamanho original
# (0 = natural, +50 = uma vez e meia, -30 = 30% menor).
static func scale_factor_of(entry: Dictionary) -> float:
	return maxf(MIN_SCALE_FACTOR, 1.0 + float(entry.get("scale_percent", 0.0)) / 100.0)


func _configure_spawned_node(node: Node3D, entry: Dictionary) -> void:
	# Escala do template. Guardada também como meta para quem precisar do valor depois do spawn
	# (o nó já nasce escalado; a meta evita ter de re-derivar o fator a partir do transform).
	var factor := scale_factor_of(entry)
	if not is_equal_approx(factor, 1.0):
		node.scale = Vector3.ONE * factor
	node.set_meta("template_scale_factor", factor)
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
	# Campo "category" do formato antigo é descartado: cada arquivo já é de UMA categoria.
	t.erase("category")
	if not t.get("entries", []) is Array:
		t["entries"] = []
	# Toda entrada carrega o kind desta categoria (arquivo single-category); migra o kind legado
	# "structure" (pasta library3D/structures extinta) junto.
	for raw_entry in t["entries"]:
		if raw_entry is Dictionary:
			(raw_entry as Dictionary)["kind"] = _entry_kind()
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


# No .exe exportado os arquivos aparecem como "*.tscn.remap" (e imports como "*.import") no
# DirAccess; o nome lógico remove esses sufixos para o filtro de extensão funcionar igual no
# editor e no build (mesmo padrão da tela Models).
func _logical_name(file_name: String) -> String:
	var ext := file_name.get_extension().to_lower()
	if ext == "remap" or ext == "import":
		return file_name.get_basename()
	return file_name


func _display_name(key: String) -> String:
	return key.replace("_", " ").capitalize()

extends Node

signal replace_main_scene(resource: PackedScene)

const DEVELOPER_PATH: String = "res://scenes2D/developer/developer.tscn"

# Root of the 3D model library. Models live in res://scenes3D/library/<tipo>/<modelo>/
# (e.g. characters/red_robot, props/forklift, structures/core). The selection
# dropdowns below are built by scanning this folder, so dropping a new model
# folder in here makes it show up automatically — no code change needed.
const LIBRARY_ROOT: String = "res://scenes3D/library"

# Model categories shown in the dropdown, in display order. Only these
# subfolders of LIBRARY_ROOT are scanned — support folders that also live under
# library/ (e.g. geometry/, textures/) are intentionally ignored here.
const CATEGORIES: Array[Dictionary] = [
	{"key": "characters", "label": "Personagens"},
	{"key": "props", "label": "Props"},
	{"key": "structures", "label": "Estruturas"},
]

# Built at _ready by scanning LIBRARY_ROOT. Each entry:
#   {"key": String, "label": String, "models": Array[{"name", "path"}]}
var _categories: Array = []

# Currently selected model and the breakdown of its sub-parts. Big collection
# models (structures, props) bundle dozens/hundreds of meshes — _parts groups
# them by base name so each distinct piece can be viewed on its own.
# Each part entry: {"label": String, "key": String}; key "" means "whole model".
var _model_scene: PackedScene = null
var _parts: Array = []

var _model_rot_y: float = 0.0
var _suffix_re: RegEx = RegEx.new()

@onready var model_holder: Node3D = $ModelHolder
@onready var cbo_category: OptionButton = $UI/Selectors/CategoryRow/cboCategory
@onready var cbo_models: OptionButton = $UI/Selectors/ModelRow/cboModels
@onready var cbo_parts: OptionButton = $UI/Selectors/PartRow/cboParts
@onready var part_row: HBoxContainer = $UI/Selectors/PartRow


func _ready() -> void:
	_suffix_re.compile("_[0-9]+$")
	_categories = _scan_library()

	cbo_category.clear()
	for category in _categories:
		cbo_category.add_item(category["label"])
	cbo_category.item_selected.connect(_on_category_selected)
	cbo_models.item_selected.connect(_on_model_selected)
	cbo_parts.item_selected.connect(_on_part_selected)

	if not _categories.is_empty():
		cbo_category.select(0)
		_on_category_selected(0)


func _process(delta: float) -> void:
	# Slowly rotate the previewed model, like the character on the choose-player screen.
	_model_rot_y += delta * 0.6
	model_holder.rotation.y = _model_rot_y


func _on_category_selected(index: int) -> void:
	cbo_models.clear()
	var models: Array = _categories[index]["models"]
	for entry in models:
		cbo_models.add_item(entry["name"])
	if cbo_models.item_count > 0:
		cbo_models.select(0)
		_on_model_selected(0)


func _on_model_selected(index: int) -> void:
	var models: Array = _categories[cbo_category.selected]["models"]
	_model_scene = load(models[index]["path"])
	_populate_parts()


func _on_part_selected(index: int) -> void:
	_apply_part(index)


# --- Library scanning -------------------------------------------------------

# For each category in CATEGORIES, scan LIBRARY_ROOT/<categoria>/<modelo>/ and
# collect one entry per model folder. Categories with no models are dropped.
func _scan_library() -> Array:
	var result: Array = []
	for category in CATEGORIES:
		var type_path := LIBRARY_ROOT.path_join(category["key"])
		var type_access := DirAccess.open(type_path)
		if type_access == null:
			continue

		var models: Array = []
		for model_dir in type_access.get_directories():
			var model_path := type_path.path_join(model_dir)
			var file_path := _find_model_file(model_path)
			if file_path != "":
				models.append({"name": _prettify(model_dir), "path": file_path})

		if not models.is_empty():
			models.sort_custom(func(a, b): return a["name"] < b["name"])
			result.append({
				"key": category["key"],
				"label": category["label"],
				"models": models,
			})

	return result


# Pick the previewable resource in a model folder: the raw imported model
# (.glb / .gltf) if present — so we show the mesh without running any gameplay
# script — otherwise an assembled scene (.tscn). Only files directly in the
# folder are considered (subfolders like audio/ or bullet/ are ignored).
func _find_model_file(folder: String) -> String:
	var access := DirAccess.open(folder)
	if access == null:
		return ""
	var mesh_path: String = ""
	var scene_path: String = ""
	for file_name in access.get_files():
		match file_name.get_extension().to_lower():
			"glb", "gltf":
				if mesh_path == "":
					mesh_path = folder.path_join(file_name)
			"tscn":
				if scene_path == "":
					scene_path = folder.path_join(file_name)
	return mesh_path if mesh_path != "" else scene_path


# --- Parts (sub-model breakdown) --------------------------------------------

# Inspect the selected model's top-level children, group them by base name
# (e.g. "prop_cargobox5b_022" -> "prop_cargobox5b") and fill the Peça dropdown
# with one entry per distinct piece, plus a "Tudo" entry for the whole model.
# The Peça row is hidden for single-piece models (characters, props).
func _populate_parts() -> void:
	_parts = _build_parts(_model_scene)
	cbo_parts.clear()
	for part in _parts:
		cbo_parts.add_item(part["label"])
	part_row.visible = _parts.size() > 1
	cbo_parts.select(0)
	_apply_part(0)


func _build_parts(scene: PackedScene) -> Array:
	var result: Array = [{"label": "Tudo (modelo inteiro)", "key": ""}]
	if scene == null:
		return result

	var instance := scene.instantiate()
	var order: Array = []
	var counts: Dictionary = {}
	for child in instance.get_children():
		# Skip non-visual children (auto-generated collision bodies, etc.) so the
		# list only offers pieces that actually render.
		if not _has_visual(child):
			continue
		var key := _group_key(child.name)
		if not counts.has(key):
			counts[key] = 0
			order.append(key)
		counts[key] += 1
	instance.free()

	# Nothing to subdivide when every child collapses to a single group.
	if order.size() <= 1:
		return result

	order.sort()
	for key in order:
		var label: String = _prettify(key)
		if counts[key] > 1:
			label += " (%d)" % counts[key]
		result.append({"label": label, "key": key})
	return result


# "prop_cargobox5b_022" -> "prop_cargobox5b", "Spot_010" -> "Spot".
# Strips trailing _<number> groups without eating mid-name digits
# (e.g. "FLOOR_reactor120_Eleavotr_002" -> "FLOOR_reactor120_Eleavotr").
func _has_visual(node: Node) -> bool:
	if node is VisualInstance3D:
		return true
	return not node.find_children("*", "VisualInstance3D", true, false).is_empty()


func _group_key(node_name: String) -> String:
	var result := node_name
	while true:
		var match_result := _suffix_re.search(result)
		if match_result == null:
			break
		var stripped := result.substr(0, match_result.get_start())
		if stripped == "":
			break
		result = stripped
	return result


# --- Preview ----------------------------------------------------------------

# Show the whole model (key "") or just the children belonging to one part group.
func _apply_part(index: int) -> void:
	for child in model_holder.get_children():
		child.queue_free()
	model_holder.rotation = Vector3.ZERO
	_model_rot_y = 0.0

	if _model_scene == null or index < 0 or index >= _parts.size():
		return

	var part_key: String = _parts[index]["key"]
	var instance := _model_scene.instantiate()

	if part_key == "":
		model_holder.add_child(instance)
		if instance is Node3D:
			_fit_to_view(instance as Node3D)
		return

	# Isolate: reparent the first child of this group into the holder and drop
	# the rest, so the chosen piece is shown alone and re-centered.
	var picked: Node = null
	for child in instance.get_children():
		if _has_visual(child) and _group_key(child.name) == part_key:
			picked = child
			break
	if picked != null:
		instance.remove_child(picked)
		picked.owner = null
		model_holder.add_child(picked)
		if picked is Node3D:
			(picked as Node3D).transform = Transform3D.IDENTITY
			_fit_to_view(picked as Node3D)
	instance.free()


# Center and scale the model so it fits nicely in front of the camera, regardless
# of its original size.
func _fit_to_view(model: Node3D) -> void:
	var visuals: Array = model.find_children("*", "VisualInstance3D", true, false)
	if model is VisualInstance3D:
		visuals.append(model)
	if visuals.is_empty():
		return

	var bounds := AABB()
	var first := true
	for node in visuals:
		var vi := node as VisualInstance3D
		var rel := model.global_transform.affine_inverse() * vi.global_transform
		var box := rel * vi.get_aabb()
		if first:
			bounds = box
			first = false
		else:
			bounds = bounds.merge(box)

	var max_dim: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if max_dim <= 0.0:
		return
	var scale_factor := 2.0 / max_dim
	model.scale = Vector3.ONE * scale_factor
	model.position = -bounds.get_center() * scale_factor


# "red_robot" -> "Red Robot", "core_out_light" -> "Core Out Light".
func _prettify(raw_name: String) -> String:
	var words := raw_name.replace("_", " ").replace("-", " ").split(" ", false)
	var out: Array[String] = []
	for word in words:
		out.append(word.capitalize())
	return " ".join(out)


func _on_back_pressed() -> void:
	emit_signal("replace_main_scene", load(DEVELOPER_PATH))


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()

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

# When a model breaks down into more part-groups than this, the flat Peça list
# becomes too long to fit on screen, so we insert a "Grupo" dropdown that
# partitions the pieces by name prefix (Peça then lists only the chosen group).
const SUBGROUP_THRESHOLD: int = 12

# How fast the dragged model rotates, in radians per pixel of mouse motion.
const DRAG_SENSITIVITY: float = 0.01

# Auto-rotation speed in radians per second when the toggle is on.
const AUTO_ROTATE_SPEED: float = 0.6

# Built at _ready by scanning LIBRARY_ROOT. Each entry:
#   {"key": String, "label": String, "models": Array[{"name", "path"}]}
var _categories: Array = []

# Currently selected model and the breakdown of its sub-parts. Big collection
# models (structures, props) bundle dozens/hundreds of meshes — they get grouped
# by base name so each distinct piece can be viewed on its own.
# Each part entry: {"label": String, "key": String}; key "" means "whole model".
var _model_scene: PackedScene = null

# When the part list is large it is partitioned into prefix sub-groups. Each
# entry: {"label": String, "parts": Array[{"label","key"}]}; index 0 is always
# "Tudo (modelo inteiro)" with an empty parts list.
var _subgroups: Array = []
var _use_subgroups: bool = false

# Parts currently listed in the Peça dropdown (each {"label","key"}). With the
# Grupo dropdown active this is the chosen group's slice; otherwise it is the
# whole flat list.
var _current_parts: Array = []

var _suffix_re: RegEx = RegEx.new()

# Rotation state. The holder either spins on its own (auto) or follows the mouse
# while the left button is held; dragging temporarily overrides auto-rotation.
var _auto_rotate: bool = true
var _dragging: bool = false

@onready var model_holder: Node3D = $ModelHolder
@onready var cbo_category: OptionButton = $UI/Selectors/CategoryRow/cboCategory
@onready var cbo_models: OptionButton = $UI/Selectors/ModelRow/cboModels
@onready var cbo_group: OptionButton = $UI/Selectors/GroupRow/cboGroup
@onready var group_row: HBoxContainer = $UI/Selectors/GroupRow
@onready var cbo_parts: OptionButton = $UI/Selectors/PartRow/cboParts
@onready var part_row: HBoxContainer = $UI/Selectors/PartRow
@onready var rotate_toggle: CheckButton = $UI/RotateToggle


func _ready() -> void:
	_suffix_re.compile("_[0-9]+$")
	_categories = _scan_library()

	cbo_category.clear()
	for category in _categories:
		cbo_category.add_item(category["label"])
	cbo_category.item_selected.connect(_on_category_selected)
	cbo_models.item_selected.connect(_on_model_selected)
	cbo_group.item_selected.connect(_on_group_selected)
	cbo_parts.item_selected.connect(_on_part_selected)

	rotate_toggle.button_pressed = _auto_rotate
	rotate_toggle.toggled.connect(_on_rotate_toggled)

	if not _categories.is_empty():
		cbo_category.select(0)
		_on_category_selected(0)


func _process(delta: float) -> void:
	# Slowly spin the previewed model, like the character on the choose-player
	# screen — but pause while the user is hand-rotating it with the mouse.
	if _auto_rotate and not _dragging:
		model_holder.rotate(Vector3.UP, delta * AUTO_ROTATE_SPEED)


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


func _on_rotate_toggled(pressed: bool) -> void:
	_auto_rotate = pressed


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

# Build the flat part list for the selected model, then decide how to surface it:
# a short list goes straight into the Peça dropdown; a long list is partitioned
# into prefix sub-groups behind the Grupo dropdown.
func _populate_parts() -> void:
	var entries := _build_parts(_model_scene)
	var real_parts: Array = entries.slice(1)
	_use_subgroups = real_parts.size() > SUBGROUP_THRESHOLD

	if _use_subgroups:
		_subgroups = _build_subgroups(real_parts)
		group_row.visible = true
		cbo_group.clear()
		for sub in _subgroups:
			cbo_group.add_item(sub["label"])
		cbo_group.select(0)
		_on_group_selected(0)
	else:
		_subgroups = []
		group_row.visible = false
		cbo_group.clear()
		_current_parts = entries
		_fill_parts_dropdown()
		part_row.visible = _current_parts.size() > 1
		_apply_part(_current_parts[0]["key"] if not _current_parts.is_empty() else "")


# Partition the flat part list into "Tipo › Prefixo" buckets: first by node type
# (Personagem / Node3D / Malha), then by the first segment of each base name
# (e.g. "prop_cargobox5b" / "prop_barrel" -> "Malha › Prop"). Buckets are ordered
# by type rank then prefix. Index 0 is the whole-model entry; selecting it hides
# the Peça dropdown.
func _build_subgroups(real_parts: Array) -> Array:
	var buckets: Dictionary = {}
	var order: Array = []
	for part in real_parts:
		var prefix := _prefix_of(part["key"])
		var combo := "%d|%s" % [part["type_rank"], prefix]
		if not buckets.has(combo):
			buckets[combo] = {
				"type_rank": part["type_rank"],
				"type_label": part["type_label"],
				"prefix": prefix,
				"parts": [],
			}
			order.append(combo)
		buckets[combo]["parts"].append(part)

	order.sort_custom(func(a, b):
		var ba: Dictionary = buckets[a]
		var bb: Dictionary = buckets[b]
		if ba["type_rank"] != bb["type_rank"]:
			return ba["type_rank"] < bb["type_rank"]
		return ba["prefix"] < bb["prefix"])

	var groups: Array = [{"label": "Tudo (modelo inteiro)", "parts": []}]
	for combo in order:
		var bucket: Dictionary = buckets[combo]
		groups.append({
			"label": "%s › %s (%d)" % [
				bucket["type_label"], _prettify(bucket["prefix"]), bucket["parts"].size()
			],
			"parts": bucket["parts"],
		})
	return groups


func _on_group_selected(index: int) -> void:
	if index <= 0:
		_current_parts = []
		part_row.visible = false
		_apply_part("")
		return

	_current_parts = _subgroups[index]["parts"]
	part_row.visible = true
	_fill_parts_dropdown()
	if not _current_parts.is_empty():
		_apply_part(_current_parts[0]["key"])


func _on_part_selected(index: int) -> void:
	if index < 0 or index >= _current_parts.size():
		return
	_apply_part(_current_parts[index]["key"])


func _fill_parts_dropdown() -> void:
	cbo_parts.clear()
	for part in _current_parts:
		cbo_parts.add_item(part["label"])
	if cbo_parts.item_count > 0:
		cbo_parts.select(0)


# Inspect the selected model's top-level children, group them by base name
# (e.g. "prop_cargobox5b_022" -> "prop_cargobox5b") and return one entry per
# distinct piece, plus a leading "Tudo" entry for the whole model. A single-group
# model returns just the "Tudo" entry.
func _build_parts(scene: PackedScene) -> Array:
	var result: Array = [{"label": "Tudo (modelo inteiro)", "key": ""}]
	if scene == null:
		return result

	var instance := scene.instantiate()
	var order: Array = []
	var counts: Dictionary = {}
	var types: Dictionary = {}
	for child in instance.get_children():
		# Skip non-visual children (auto-generated collision bodies, etc.) so the
		# list only offers pieces that actually render.
		if not _has_visual(child):
			continue
		var key := _group_key(child.name)
		if not counts.has(key):
			counts[key] = 0
			order.append(key)
			# Remember the node class of the first child in this group so the Grupo
			# dropdown can bucket pieces by type (see _type_bucket / _build_subgroups).
			types[key] = _type_bucket(child)
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
		var bucket: Dictionary = types[key]
		result.append({
			"label": label,
			"key": key,
			"type_rank": bucket["rank"],
			"type_label": bucket["label"],
		})
	return result


# Classify a top-level child into a node-type bucket. Tested most-specific-first
# so MeshInstance3D is matched before the Node3D catch-all (every 3D node is a
# Node3D — testing it first would swallow everything). "rank" sets the display
# order in the Grupo dropdown (Personagem, then Node3D, then Malha).
func _type_bucket(node: Node) -> Dictionary:
	if node is CharacterBody3D:
		return {"rank": 0, "label": "Personagem"}
	if node is MeshInstance3D:
		return {"rank": 2, "label": "Malha"}
	return {"rank": 1, "label": "Node3D"}


func _has_visual(node: Node) -> bool:
	if node is VisualInstance3D:
		return true
	return not node.find_children("*", "VisualInstance3D", true, false).is_empty()


# "prop_cargobox5b_022" -> "prop_cargobox5b", "Spot_010" -> "Spot".
# Strips trailing _<number> groups without eating mid-name digits
# (e.g. "FLOOR_reactor120_Eleavotr_002" -> "FLOOR_reactor120_Eleavotr").
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


# First name segment used to bucket parts into sub-groups: the text before the
# first underscore (e.g. "prop_cargobox5b" -> "prop"), or the whole name when
# there is no underscore.
func _prefix_of(key: String) -> String:
	var idx := key.find("_")
	return key.substr(0, idx) if idx > 0 else key


# --- Preview ----------------------------------------------------------------

# Show the whole model (key "") or just the children belonging to one part group.
func _apply_part(part_key: String) -> void:
	for child in model_holder.get_children():
		child.queue_free()
	model_holder.rotation = Vector3.ZERO

	if _model_scene == null:
		return

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


# Hold the left mouse button over the render area and drag to hand-rotate the
# model on any axis (horizontal -> yaw, vertical -> pitch). Clicks that land on a
# dropdown or button are consumed by those controls first, so only drags over the
# empty 3D view reach here.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		model_holder.rotate(Vector3.UP, -motion.relative.x * DRAG_SENSITIVITY)
		model_holder.rotate(Vector3.RIGHT, -motion.relative.y * DRAG_SENSITIVITY)

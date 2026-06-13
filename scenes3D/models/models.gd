extends Node

signal replace_main_scene(resource: PackedScene)

const DEVELOPER_PATH: String = "res://scenes2D/developer/developer.tscn"

# Gallery of everything under library/extracted/, opened by the "Exportados" button.
const EXPORTED_PATH: String = "res://scenes3D/library/extracted/Exported.tscn"

# Models that level_base.gd assembles dynamically (red robot + player). Copied
# into library/extracted/ and surfaced as the synthetic "Level Base" entry in the
# Personagens category, which previews them side by side.
const LEVEL_BASE_GROUP: Array[String] = [
	"res://scenes3D/library/extracted/red_robot.glb",
	"res://scenes3D/library/extracted/player.glb",
]
const LEVEL_BASE_LABEL: String = "Level Base (dinâmicos)"

# Root of the 3D model library. Models live in res://scenes3D/library/<tipo>/<modelo>/
# (e.g. characters/red_robot, props/forklift, structures/core). The selection
# dropdowns below are built by scanning this folder, so dropping a new model
# folder in here makes it show up automatically — no code change needed.
const LIBRARY_ROOT: String = "res://scenes3D/library"

# Where "Salvar como cena 3D" writes the extracted, reusable mesh scenes.
const EXTRACT_ROOT: String = "res://scenes3D/library/extracted"

# Model categories shown in the dropdown, in display order. Only these
# subfolders of LIBRARY_ROOT are scanned — support folders that also live under
# library/ (e.g. geometry/, textures/) are intentionally ignored here.
const CATEGORIES: Array[Dictionary] = [
	{"key": "characters", "label": "Personagens"},
	{"key": "props", "label": "Props"},
	{"key": "structures", "label": "Estruturas"},
]

# How fast the dragged model rotates, in radians per pixel of mouse motion.
const DRAG_SENSITIVITY: float = 0.01

# Auto-rotation speed in radians per second when the toggle is on.
const AUTO_ROTATE_SPEED: float = 0.6

# Built at _ready by scanning LIBRARY_ROOT. Each entry:
#   {"key": String, "label": String, "models": Array[{"name", "path"}]}
var _categories: Array = []

# Currently selected model scene and its de-duplicated mesh catalog. A big level
# model bundles hundreds of placed MeshInstance3D, but they share a small palette
# of unique meshes — the catalog lists each distinct mesh once (the reusable
# asset), not every placement. Each entry:
#   {"label", "mesh": Mesh, "name": String, "count": int, "has_collision": bool, "skinned": bool}
var _model_scene: PackedScene = null
var _mesh_catalog: Array = []
var _selected_mesh: int = -1

# Rotation state. The holder either spins on its own (auto) or follows the mouse
# while the left button is held; dragging temporarily overrides auto-rotation.
# Yaw and pitch are tracked separately and rebuilt as an Euler rotation with no
# roll, so mouse motion only ever turns the model about the two orthogonal axes
# (horizontal -> yaw on Y, vertical -> pitch on X).
var _auto_rotate: bool = true
var _dragging: bool = false
var _yaw: float = 0.0
var _pitch: float = 0.0

@onready var model_holder: Node3D = $ModelHolder
@onready var cbo_category: OptionButton = $UI/Selectors/CategoryRow/cboCategory
@onready var cbo_models: OptionButton = $UI/Selectors/ModelRow/cboModels
@onready var cbo_meshes: OptionButton = $UI/Selectors/MeshRow/cboMeshes
@onready var save_button: Button = $UI/Selectors/SaveRow/SaveButton
@onready var status_label: Label = $UI/Selectors/StatusLabel
@onready var rotate_toggle: CheckButton = $UI/RotateToggle


func _ready() -> void:
	_categories = _scan_library()

	cbo_category.clear()
	for category in _categories:
		cbo_category.add_item(category["label"])
	cbo_category.item_selected.connect(_on_category_selected)
	cbo_models.item_selected.connect(_on_model_selected)
	cbo_meshes.item_selected.connect(_on_mesh_selected)
	save_button.pressed.connect(_on_save_pressed)

	rotate_toggle.button_pressed = _auto_rotate
	rotate_toggle.toggled.connect(_on_rotate_toggled)

	if not _categories.is_empty():
		cbo_category.select(0)
		_on_category_selected(0)


func _process(delta: float) -> void:
	# Slowly spin the previewed mesh, like the character on the choose-player
	# screen — but pause while the user is hand-rotating it with the mouse.
	if _auto_rotate and not _dragging:
		_yaw += delta * AUTO_ROTATE_SPEED
	# Rebuild rotation from yaw/pitch with roll fixed at 0 (orthogonal axes only).
	model_holder.rotation = Vector3(_pitch, _yaw, 0.0)


func _on_category_selected(index: int) -> void:
	cbo_models.clear()
	var models: Array = _categories[index]["models"]
	for entry in models:
		cbo_models.add_item(entry["name"])
	if cbo_models.item_count > 0:
		cbo_models.select(0)
		_on_model_selected(0)


func _on_model_selected(index: int) -> void:
	var model: Dictionary = _categories[cbo_category.selected]["models"][index]

	# Synthetic grouping entry (e.g. "Level Base"): show its models together
	# instead of browsing a single model's distinct meshes.
	if model.has("group_paths"):
		_show_group(model["group_paths"])
		return

	_model_scene = load(model["path"])
	_mesh_catalog = _build_mesh_catalog(_model_scene)

	cbo_meshes.clear()
	for entry in _mesh_catalog:
		cbo_meshes.add_item(entry["label"])
	status_label.text = "%d malha(s) distinta(s)" % _mesh_catalog.size()
	if not _mesh_catalog.is_empty():
		cbo_meshes.select(0)
		_on_mesh_selected(0)
	else:
		_selected_mesh = -1
		_clear_preview()


# Show every model in a group side by side (used by the "Level Base" entry,
# which mirrors the models level_base.gd spawns dynamically).
func _show_group(paths: Array) -> void:
	_clear_preview()
	_model_scene = null
	_mesh_catalog = []
	_selected_mesh = -1
	cbo_meshes.clear()

	var shown := 0
	var total := paths.size()
	for index in total:
		var scene := load(paths[index]) as PackedScene
		if scene == null:
			continue
		var instance := scene.instantiate()
		model_holder.add_child(instance)
		if instance is Node3D:
			_fit_to_view(instance as Node3D, 1.6)
			(instance as Node3D).position.x += (index - (total - 1) * 0.5) * 2.2
		shown += 1
	status_label.text = "Grupo: %d modelo(s) lado a lado" % shown


func _on_mesh_selected(index: int) -> void:
	_selected_mesh = index
	_preview_mesh(index)


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

		if category["key"] == "characters" and _level_base_group_available():
			models.append({"name": LEVEL_BASE_LABEL, "group_paths": LEVEL_BASE_GROUP})

		if not models.is_empty():
			models.sort_custom(func(a, b): return a["name"] < b["name"])
			result.append({
				"key": category["key"],
				"label": category["label"],
				"models": models,
			})

	return result


# The synthetic "Level Base" entry only shows up once its models exist in
# library/extracted/ (they are plain copies of the glb the level spawns).
func _level_base_group_available() -> bool:
	for path in LEVEL_BASE_GROUP:
		if not ResourceLoader.exists(path):
			return false
	return true


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


# --- Mesh catalog (de-duplicated reusable assets) ---------------------------

# Walk every MeshInstance3D in the model and group them by their shared Mesh
# resource, so each distinct mesh shows up once. Entries are sorted by how many
# times the mesh is placed (most-used first), which surfaces the "main" pieces.
func _build_mesh_catalog(scene: PackedScene) -> Array:
	var result: Array = []
	if scene == null:
		return result

	var instance := scene.instantiate()
	var nodes: Array = instance.find_children("*", "MeshInstance3D", true, false)
	if instance is MeshInstance3D:
		nodes.append(instance)

	var by_mesh: Dictionary = {}
	var entries: Array = []
	for node in nodes:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var id := mesh_instance.mesh.get_instance_id()
		if not by_mesh.has(id):
			var has_collision := not mesh_instance.find_children(
				"*", "CollisionShape3D", true, false
			).is_empty()
			by_mesh[id] = entries.size()
			entries.append({
				"mesh": mesh_instance.mesh,
				"name": _group_key(mesh_instance.name),
				"count": 0,
				"has_collision": has_collision,
				"skinned": mesh_instance.skin != null,
			})
		entries[by_mesh[id]]["count"] += 1
	instance.free()

	entries.sort_custom(func(a, b):
		if a["count"] != b["count"]:
			return a["count"] > b["count"]
		return a["name"] < b["name"])

	for entry in entries:
		var label: String = _prettify(entry["name"])
		if entry["count"] > 1:
			label += " (×%d)" % entry["count"]
		if entry["skinned"]:
			label += " [skin]"
		elif entry["has_collision"]:
			label += " [+col]"
		entry["label"] = label
		result.append(entry)
	return result


# "prop_cargobox5b_022" -> "prop_cargobox5b", "Spot_010" -> "Spot".
# Strips trailing _<number> groups without eating mid-name digits.
func _group_key(node_name: String) -> String:
	var regex := RegEx.new()
	regex.compile("_[0-9]+$")
	var result := node_name
	while true:
		var match_result := regex.search(result)
		if match_result == null:
			break
		var stripped := result.substr(0, match_result.get_start())
		if stripped == "":
			break
		result = stripped
	return result


# --- Preview ----------------------------------------------------------------

func _clear_preview() -> void:
	for child in model_holder.get_children():
		child.queue_free()
	_yaw = 0.0
	_pitch = 0.0
	model_holder.rotation = Vector3.ZERO


# Show a single instance of the selected distinct mesh, centered and fit to view.
func _preview_mesh(index: int) -> void:
	_clear_preview()
	if index < 0 or index >= _mesh_catalog.size():
		return
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = _mesh_catalog[index]["mesh"]
	model_holder.add_child(mesh_instance)
	_fit_to_view(mesh_instance)


# Center and scale a model so it fits nicely in front of the camera, regardless
# of its original size. target_size is the largest dimension after scaling.
func _fit_to_view(model: Node3D, target_size: float = 2.0) -> void:
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
	var scale_factor := target_size / max_dim
	model.scale = Vector3.ONE * scale_factor
	model.position = -bounds.get_center() * scale_factor


# --- Extraction (save as reusable scene) ------------------------------------

# Re-instantiate the source model, grab the first node that uses the selected
# mesh (with its collision subtree, if any), normalize its transform and pack it
# into a standalone .tscn under EXTRACT_ROOT/<categoria>/.
func _on_save_pressed() -> void:
	if _selected_mesh < 0 or _selected_mesh >= _mesh_catalog.size() or _model_scene == null:
		return
	var entry: Dictionary = _mesh_catalog[_selected_mesh]
	var target_id := (entry["mesh"] as Mesh).get_instance_id()

	var instance := _model_scene.instantiate()
	var nodes: Array = instance.find_children("*", "MeshInstance3D", true, false)
	if instance is MeshInstance3D:
		nodes.append(instance)
	var source: Node = null
	for node in nodes:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null and mesh_instance.mesh.get_instance_id() == target_id:
			source = node
			break

	if source == null:
		instance.free()
		status_label.text = "Não foi possível localizar a malha."
		return

	# Duplicate the subtree (mesh + collision), drop the baked placement transform
	# so the reusable prop sits at the origin, and re-own it under the new root.
	var root := source.duplicate()
	instance.free()
	root.name = entry["name"]
	if root is Node3D:
		(root as Node3D).transform = Transform3D.IDENTITY
	_reown(root, root)

	var dir := EXTRACT_ROOT.path_join(_categories[cbo_category.selected]["key"])
	DirAccess.make_dir_recursive_absolute(dir)
	var file := dir.path_join(entry["name"] + ".tscn")

	var packed := PackedScene.new()
	var pack_err := packed.pack(root)
	root.free()
	if pack_err != OK:
		status_label.text = "Erro ao empacotar (%d)." % pack_err
		return
	var save_err := ResourceSaver.save(packed, file)
	status_label.text = ("Salvo: " + file) if save_err == OK else "Erro ao salvar (%d)." % save_err


func _reown(node: Node, owner_root: Node) -> void:
	for child in node.get_children():
		child.owner = owner_root
		_reown(child, owner_root)


# --- Misc -------------------------------------------------------------------

# "red_robot" -> "Red Robot", "core_out_light" -> "Core Out Light".
func _prettify(raw_name: String) -> String:
	var words := raw_name.replace("_", " ").replace("-", " ").split(" ", false)
	var out: Array[String] = []
	for word in words:
		out.append(word.capitalize())
	return " ".join(out)


func _on_back_pressed() -> void:
	emit_signal("replace_main_scene", load(DEVELOPER_PATH))


func _on_open_exported_pressed() -> void:
	emit_signal("replace_main_scene", load(EXPORTED_PATH))


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


# Hold the left mouse button over the render area and drag to hand-rotate the
# mesh on the two orthogonal axes (horizontal -> yaw, vertical -> pitch). Clicks
# that land on a dropdown or button are consumed by those controls first, so only
# drags over the empty 3D view reach here.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		_yaw += motion.relative.x * DRAG_SENSITIVITY
		# Pitch is clamped to ±90° so the model can't roll past vertical and flip.
		_pitch = clampf(_pitch + motion.relative.y * DRAG_SENSITIVITY, -PI * 0.5, PI * 0.5)

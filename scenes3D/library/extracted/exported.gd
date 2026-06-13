extends Node3D

# Gallery scene for everything saved under library/extracted/. On load it scans
# the folder for .tscn / .glb files (skipping itself), instantiates each and
# lays them out in a centered row, normalized to a common size. Reached from the
# Models screen ("Exportados" button) and returns there on Voltar / ESC.

signal replace_main_scene(resource: PackedScene)

const MODELS_PATH: String = "res://scenes3D/models/models.tscn"
const EXTRACTED_DIR: String = "res://scenes3D/library/extracted"

# Fit size and gap (in metres) applied to each model in the row.
const ITEM_SIZE: float = 1.6
const ITEM_SPACING: float = 2.2

@onready var models_holder: Node3D = $Models
@onready var camera: Camera3D = $Camera3D
@onready var count_label: Label = $UI/CountLabel


func _ready() -> void:
	var files := _scan_extracted()
	for index in files.size():
		var scene := load(EXTRACTED_DIR.path_join(files[index])) as PackedScene
		if scene == null:
			continue
		var instance := scene.instantiate()
		models_holder.add_child(instance)
		if instance is Node3D:
			_fit_and_place(instance as Node3D, index, files.size())

	count_label.text = "%d modelo(s) em extracted/" % models_holder.get_child_count()
	# Pull the camera back enough to frame the whole row.
	var span := maxf(1, files.size()) * ITEM_SPACING
	camera.position = Vector3(0.0, 0.6, maxf(4.5, span * 0.7))


func _scan_extracted() -> Array:
	var files: Array = []
	var dir := DirAccess.open(EXTRACTED_DIR)
	if dir == null:
		return files
	for file_name in dir.get_files():
		if file_name == "Exported.tscn":
			continue
		match file_name.get_extension().to_lower():
			"tscn", "glb", "gltf":
				files.append(file_name)
	files.sort()
	return files


# Center, scale to ITEM_SIZE and slot the model into its column of the row.
func _fit_and_place(model: Node3D, index: int, total: int) -> void:
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
	if max_dim > 0.0:
		model.scale = Vector3.ONE * (ITEM_SIZE / max_dim)
	model.position = -bounds.get_center() * model.scale
	model.position.x += (index - (total - 1) * 0.5) * ITEM_SPACING


func _on_back_pressed() -> void:
	emit_signal("replace_main_scene", load(MODELS_PATH))


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()

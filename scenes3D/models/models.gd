extends Node

signal replace_main_scene(resource: PackedScene)

const DEVELOPER_PATH: String = "res://scenes2D/developer/developer.tscn"

# Cascading selection: category → list of {name, path}. The paths are the 3D
# objects that exist in level_base and can be instanced into another 3D scene.
const CATEGORY_ORDER: Array[String] = [
	"Cenas Principais",
	"Cenas de Colisão",
	"Arquivos Brutos",
]

const CATEGORIES: Dictionary = {
	"Cenas Principais": [
		{"name": "Core", "path": "res://scenes3D/level_base/geometry/scenes/core.tscn"},
		{"name": "Structure", "path": "res://scenes3D/level_base/geometry/scenes/structure.tscn"},
		{"name": "Props", "path": "res://scenes3D/level_base/geometry/scenes/props.tscn"},
		{"name": "Lights", "path": "res://scenes3D/level_base/geometry/scenes/lights.tscn"},
		{"name": "Flying Forklift", "path": "res://scenes3D/level_base/forklift/flying_forklift.tscn"},
	],
	"Cenas de Colisão": [
		{"name": "Radial Colliders", "path": "res://scenes3D/level_base/geometry/scenes/collision/radial_colliders.tscn"},
		{"name": "Radial Player Only", "path": "res://scenes3D/level_base/geometry/scenes/collision/radial_player_only.tscn"},
		{"name": "Stair Pillar", "path": "res://scenes3D/level_base/geometry/scenes/collision/stair_pillar.tscn"},
	],
	"Arquivos Brutos": [
		{"name": "core.glb", "path": "res://scenes3D/level_base/geometry/models/core.glb"},
		{"name": "structure.glb", "path": "res://scenes3D/level_base/geometry/models/structure.glb"},
		{"name": "props.glb", "path": "res://scenes3D/level_base/geometry/models/props.glb"},
		{"name": "lights.glb", "path": "res://scenes3D/level_base/geometry/models/lights.glb"},
		{"name": "flying_forklift.glb", "path": "res://scenes3D/level_base/forklift/flying_forklift.glb"},
		{"name": "CoreOutLight.glb", "path": "res://scenes3D/level_base/textures/structure/Core/CoreOutLight.glb"},
	],
}

var _model_rot_y: float = 0.0

@onready var model_holder: Node3D = $ModelHolder
@onready var cbo_category: OptionButton = $UI/Selectors/CategoryRow/cboCategory
@onready var cbo_models: OptionButton = $UI/Selectors/ModelRow/cboModels


func _ready() -> void:
	cbo_category.clear()
	for category in CATEGORY_ORDER:
		cbo_category.add_item(category)
	cbo_category.item_selected.connect(_on_category_selected)
	cbo_models.item_selected.connect(_on_model_selected)
	_on_category_selected(0)


func _process(delta: float) -> void:
	# Slowly rotate the previewed model, like the character on the choose-player screen.
	_model_rot_y += delta * 0.6
	model_holder.rotation.y = _model_rot_y


func _on_category_selected(index: int) -> void:
	var category: String = CATEGORY_ORDER[index]
	cbo_models.clear()
	for entry in CATEGORIES[category]:
		cbo_models.add_item(entry["name"])
	if cbo_models.item_count > 0:
		cbo_models.select(0)
		_on_model_selected(0)


func _on_model_selected(index: int) -> void:
	var category: String = CATEGORY_ORDER[cbo_category.selected]
	var entry: Dictionary = CATEGORIES[category][index]
	_load_model(entry["path"])


func _load_model(path: String) -> void:
	for child in model_holder.get_children():
		child.queue_free()
	model_holder.rotation = Vector3.ZERO
	_model_rot_y = 0.0

	var scene: PackedScene = load(path)
	if scene == null:
		return
	var instance: Node = scene.instantiate()
	model_holder.add_child(instance)
	if instance is Node3D:
		_fit_to_view(instance as Node3D)


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


func _on_back_pressed() -> void:
	emit_signal("replace_main_scene", load(DEVELOPER_PATH))


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()

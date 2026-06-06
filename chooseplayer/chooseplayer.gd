extends Node

signal replace_main_scene(resource: PackedScene)
signal quit

const CHARACTERS: Array[Dictionary] = [
	{
		"name": "PLAYER",
		"scene_path": "res://player/player.tscn",
		"tint": Color(1.0, 1.0, 1.0, 1.0),
	},
	{
		"name": "PLAYERA",
		"scene_path": "res://playera/playera.tscn",
		"tint": Color(1.0, 0.55, 0.65, 1.0),
	},
]

const LEVELS_PATH: String = "res://levels/levels.tscn"

var current_index: int = 0
var _model_rot_y: float = 0.0
var _loading_path: String = ""

@onready var model_holder: Node3D = $ModelHolder
@onready var character_name_label: Label = $UI/NameLabel
@onready var loading: HBoxContainer = $UI/Loading
@onready var loading_progress: ProgressBar = $UI/Loading/Progress
@onready var loading_done_timer: Timer = $UI/Loading/DoneTimer


func _ready() -> void:
	_load_character(current_index)


func _process(delta: float) -> void:
	_model_rot_y += delta * 0.6
	model_holder.rotation.y = _model_rot_y

	if not loading.visible or _loading_path == "":
		return
	var progress: Array = []
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(_loading_path, progress)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		loading_progress.value = progress[0] * 100.0
	elif status == ResourceLoader.THREAD_LOAD_LOADED:
		loading_progress.value = 100.0
		set_process(false)
		loading_done_timer.start()
	else:
		_loading_path = ""
		loading.hide()
		set_process(true)


func _load_character(index: int) -> void:
	for child in model_holder.get_children():
		child.queue_free()

	var char_data: Dictionary = CHARACTERS[index]
	character_name_label.text = char_data["name"]

	var model_scene: PackedScene = load("res://player/model/player.glb")
	if model_scene == null:
		return
	var model: Node3D = model_scene.instantiate()

	# Apply the same scale used in player.tscn
	var skeleton := model.get_node_or_null("Robot_Skeleton") as Node3D
	if skeleton:
		skeleton.scale = Vector3(0.803991, 0.803991, 0.803991)

	model_holder.add_child(model)

	# Play idle animation
	var anim_players := model.find_children("*", "AnimationPlayer", true, false)
	if anim_players.size() > 0:
		var ap := anim_players[0] as AnimationPlayer
		if ap.has_animation(&"Idlecombatrest"):
			ap.play(&"Idlecombatrest")

	var tint: Color = char_data["tint"]
	if tint != Color.WHITE:
		_apply_tint(model, tint)


func _apply_tint(node: Node3D, tint: Color) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := mi as MeshInstance3D
		for i in mesh_inst.get_surface_override_material_count():
			var orig: Material = mesh_inst.mesh.surface_get_material(i)
			if orig is BaseMaterial3D:
				var mat := orig.duplicate() as BaseMaterial3D
				mat.albedo_color = Color(
					mat.albedo_color.r * tint.r,
					mat.albedo_color.g * tint.g,
					mat.albedo_color.b * tint.b,
					mat.albedo_color.a
				)
				mesh_inst.set_surface_override_material(i, mat)


func _on_left_pressed() -> void:
	current_index = (current_index - 1 + CHARACTERS.size()) % CHARACTERS.size()
	_load_character(current_index)


func _on_right_pressed() -> void:
	current_index = (current_index + 1) % CHARACTERS.size()
	_load_character(current_index)


func _on_play_pressed() -> void:
	PlayerSelection.scene_path = CHARACTERS[current_index]["scene_path"]
	_loading_path = LEVELS_PATH
	loading.show()
	ResourceLoader.load_threaded_request(_loading_path, "", true)


func _on_back_pressed() -> void:
	quit.emit()


func _on_loading_done_timer_timeout() -> void:
	emit_signal("replace_main_scene", ResourceLoader.load_threaded_get(_loading_path))

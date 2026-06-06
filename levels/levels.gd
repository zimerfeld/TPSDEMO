extends Node

signal replace_main_scene
signal quit

const LEVEL_1_PATH: String = "res://level_1/level_1.tscn"
const LEVEL_BASE_PATH: String = "res://level_base/level_base.tscn"
const CHOOSEPLAYER_PATH: String = "res://chooseplayer/chooseplayer.tscn"

var loading_path: String = ""

@onready var level1_button: Button = $UI/ButtonGrid/Level1Button
@onready var level_base_button: Button = $UI/ButtonGrid/LevelBaseButton
@onready var back_button: Button = $UI/BackButton
@onready var loading: HBoxContainer = $UI/Loading
@onready var loading_progress: ProgressBar = $UI/Loading/Progress
@onready var loading_done_timer: Timer = $UI/Loading/DoneTimer


func _process(_delta: float) -> void:
	if loading.visible and loading_path != "":
		var progress: Array = []
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(loading_path, progress)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			loading_progress.value = progress[0] * 100.0
		elif status == ResourceLoader.THREAD_LOAD_LOADED:
			loading_progress.value = 100.0
			set_process(false)
			loading_done_timer.start()
		else:
			print("Error while loading scene: " + str(status))
			level1_button.show()
			level_base_button.show()
			loading.hide()


func _on_loading_done_timer_timeout() -> void:
	emit_signal("replace_main_scene", ResourceLoader.load_threaded_get(loading_path))


func _on_level_1_pressed() -> void:
	loading_path = LEVEL_1_PATH
	level1_button.hide()
	level_base_button.hide()
	loading.show()
	ResourceLoader.load_threaded_request(loading_path, "", true)


func _on_level_base_pressed() -> void:
	loading_path = LEVEL_BASE_PATH
	level1_button.hide()
	level_base_button.hide()
	loading.show()
	ResourceLoader.load_threaded_request(loading_path, "", true)


func _on_back_pressed() -> void:
	emit_signal("replace_main_scene", load(CHOOSEPLAYER_PATH))


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		quit.emit()

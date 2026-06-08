extends Node


signal replace_main_scene

const CHOOSEPLAYER_PATH: String = "res://scenes2D/chooseplayer/chooseplayer.tscn"
const DEVELOPER_PATH: String = "res://scenes2D/developer/developer.tscn"
const PLAYONLINE_PATH: String = "res://scenes2D/playonline/playonline.tscn"
const SETTINGS_PATH: String = "res://scenes2D/settings/settings.tscn"

var loading_path: String = ""

var peer: MultiplayerPeer = OfflineMultiplayerPeer.new()

@onready var world_environment: WorldEnvironment = $WorldEnvironment

@onready var ui: Control = $UI
@onready var main: Control = ui.get_node(^"VBox")
@onready var play_button: Button = main.get_node(^"PlayRow/Play")
@onready var play_online_button: Button = main.get_node(^"PlayOnlineRow/PlayOnline")
@onready var settings_button: Button = main.get_node(^"SettingsRow/Settings")
@onready var quit_button: Button = main.get_node(^"QuitRow/Quit")

@onready var loading: HBoxContainer = ui.get_node(^"Loading")
@onready var loading_progress: ProgressBar = loading.get_node(^"Progress")
@onready var loading_done_timer: Timer = loading.get_node(^"DoneTimer")


func _ready() -> void:
	Settings.apply_graphics_settings(get_window(), world_environment.environment, self)

	if DisplayServer.get_name() == "headless":
		_on_play_online_pressed.call_deferred()

	play_button.grab_focus()


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
			print("Error while loading level: " + str(status))
			main.show()
			loading.hide()


func _on_loading_done_timer_timeout() -> void:
	multiplayer.multiplayer_peer = peer
	emit_signal("replace_main_scene", ResourceLoader.load_threaded_get(loading_path))


func _on_play_pressed() -> void:
	loading_path = CHOOSEPLAYER_PATH
	main.hide()
	loading.show()
	ResourceLoader.load_threaded_request(loading_path, "", true)


func _on_settings_pressed() -> void:
	emit_signal("replace_main_scene", load(SETTINGS_PATH))


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_play_online_pressed() -> void:
	emit_signal("replace_main_scene", load(PLAYONLINE_PATH))


func _on_developer_pressed() -> void:
	emit_signal("replace_main_scene", load(DEVELOPER_PATH))


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		_on_quit_pressed()

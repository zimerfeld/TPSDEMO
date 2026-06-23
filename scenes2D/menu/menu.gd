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
@onready var main: Control = %VBox
@onready var play_button: Button = main.get_node(^"PlayRow/Play")
@onready var play_online_button: Button = main.get_node(^"PlayOnlineRow/PlayOnline")
@onready var settings_button: Button = main.get_node(^"SettingsRow/Settings")
@onready var quit_button: Button = main.get_node(^"QuitRow/Quit")

@onready var loading: HBoxContainer = %Loading
@onready var loading_progress: ProgressBar = loading.get_node(^"Progress")
@onready var loading_done_timer: Timer = loading.get_node(^"DoneTimer")

@onready var portuguese_button: Button = %PortugueseButton
@onready var english_button: Button = %EnglishButton


func _ready() -> void:
	# Read every stored setting from disk and apply it before the menu is shown, so the
	# window, rendering, resolution and audio all reflect the saved configuration on
	# entry (not just whatever was applied when the game first launched).
	Settings.load_settings()
	Settings.apply_graphics_settings(get_window(), world_environment.environment, self)
	Settings.apply_window_resolution(get_window())
	Settings.apply_audio_settings()

	if DisplayServer.get_name() == "headless":
		# Servidor dedicado: pula chooseplayer/levels e abre direto a tela online.
		_start_online_headless.call_deferred()

	_update_language_buttons()

	play_button.grab_focus()


# Headless auto-host: vai direto para playonline (que auto-hospeda o level_base).
# Deferido porque main.gd só conecta replace_main_scene DEPOIS do _ready do menu.
func _start_online_headless() -> void:
	PlayerSelection.online_mode = true
	emit_signal("replace_main_scene", load(PLAYONLINE_PATH))


# Grey out the button for the language already active so the current choice is clear.
func _update_language_buttons() -> void:
	var lang := Locale.get_language()
	portuguese_button.disabled = lang == "pt"
	english_button.disabled = lang == "en"


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
	# Offline: chooseplayer → levels → carrega o nível localmente.
	PlayerSelection.online_mode = false
	loading_path = CHOOSEPLAYER_PATH
	main.hide()
	loading.show()
	ResourceLoader.load_threaded_request(loading_path, "", true)


func _on_settings_pressed() -> void:
	emit_signal("replace_main_scene", load(SETTINGS_PATH))


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_play_online_pressed() -> void:
	# Online: mesma sequência do offline (chooseplayer → levels); a tela de levels é
	# que, vendo online_mode, abre a playonline em vez de carregar o nível direto.
	PlayerSelection.online_mode = true
	loading_path = CHOOSEPLAYER_PATH
	main.hide()
	loading.show()
	ResourceLoader.load_threaded_request(loading_path, "", true)


func _on_developer_pressed() -> void:
	emit_signal("replace_main_scene", load(DEVELOPER_PATH))


# Language buttons (anchored at the bottom of the menu): switch + persist the UI
# language. Locale re-localizes the live tree, so the menu updates in place.
func _on_portuguese_pressed() -> void:
	Locale.set_language("pt")
	_update_language_buttons()


func _on_english_pressed() -> void:
	Locale.set_language("en")
	_update_language_buttons()


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		_on_quit_pressed()

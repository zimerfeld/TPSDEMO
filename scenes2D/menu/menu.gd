extends Node


signal replace_main_scene

const CHOOSEPLAYER_PATH: String = "res://scenes2D/chooseplayer/chooseplayer.tscn"
const DEVELOPER_PATH: String = "res://scenes2D/developer/developer.tscn"
const LEVEL_BASE_PATH: String = "res://scenes2D/level_base/level_base.tscn"
const SETTINGS_PATH: String = "res://scenes2D/settings/settings.tscn"

var loading_path: String = ""

var peer: MultiplayerPeer = OfflineMultiplayerPeer.new()

@onready var world_environment: WorldEnvironment = $WorldEnvironment

@onready var ui: Control = $UI
@onready var main: Control = ui.get_node(^"Main")
@onready var play_button: Button = main.get_node(^"Play")
@onready var play_online_button: Button = main.get_node(^"PlayOnline")
@onready var settings_button: Button = main.get_node(^"Settings")
@onready var quit_button: Button = main.get_node(^"Quit")

@onready var online: Control = ui.get_node(^"Online")
@onready var online_port: SpinBox = online.get_node(^"Port")
@onready var online_address: LineEdit = online.get_node(^"Address")

@onready var loading: HBoxContainer = ui.get_node(^"Loading")
@onready var loading_progress: ProgressBar = loading.get_node(^"Progress")
@onready var loading_done_timer: Timer = loading.get_node(^"DoneTimer")


func _ready() -> void:
	Settings.apply_graphics_settings(get_window(), world_environment.environment, self)

	if DisplayServer.get_name() == "headless":
		_on_host_pressed.call_deferred()

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


func _on_cancel_pressed() -> void:
	main.show()
	play_button.grab_focus()
	online.hide()


func _on_play_online_pressed() -> void:
	online.show()
	main.hide()


func _on_host_pressed() -> void:
	peer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(int(online_port.value))
	if err != OK:
		CrashHandler.show_error(
			"Falha ao criar servidor na porta %d.\nErro: %s\n\nVerifique se a porta está em uso." % [int(online_port.value), error_string(err)],
			_on_play_online_pressed
		)
		return
	if peer.host == null:
		CrashHandler.show_error(
			"Servidor criado, mas host ENet é nulo.\nTente outra porta ou reinicie o jogo.",
			_on_play_online_pressed
		)
		return
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	loading_path = LEVEL_BASE_PATH
	online.hide()
	main.hide()
	loading.show()
	ResourceLoader.load_threaded_request(loading_path, "", true)


func _on_developer_pressed() -> void:
	emit_signal("replace_main_scene", load(DEVELOPER_PATH))


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		if online.visible:
			_on_cancel_pressed()
		else:
			_on_quit_pressed()


func _on_connect_pressed() -> void:
	peer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(online_address.text, int(online_port.value))
	if err != OK:
		CrashHandler.show_error(
			"Falha ao conectar em %s:%d.\nErro: %s\n\nVerifique o endereço e a porta." % [online_address.text, int(online_port.value), error_string(err)],
			_on_play_online_pressed
		)
		return
	if peer.host == null:
		CrashHandler.show_error(
			"Conexão iniciada, mas host ENet é nulo.\nTente novamente.",
			_on_play_online_pressed
		)
		return
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	loading_path = LEVEL_BASE_PATH
	online.hide()
	main.hide()
	loading.show()
	ResourceLoader.load_threaded_request(loading_path, "", true)

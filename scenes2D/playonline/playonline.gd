extends Node

signal replace_main_scene
signal quit

const LEVEL_BASE_PATH: String = "res://scenes3D/level_base/level_base.tscn"

var loading_path: String = ""
var peer: MultiplayerPeer = OfflineMultiplayerPeer.new()

@onready var port: SpinBox = $UI/VBox/HostRow/Port
@onready var address: LineEdit = $UI/VBox/ConnectRow/Address
@onready var loading: HBoxContainer = $UI/Loading
@onready var loading_progress: ProgressBar = $UI/Loading/Progress
@onready var loading_done_timer: Timer = $UI/Loading/DoneTimer


func _ready() -> void:
	# Dedicated server: auto-host when running headless.
	if DisplayServer.get_name() == "headless":
		_on_host_pressed.call_deferred()


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
			loading.hide()


func _on_loading_done_timer_timeout() -> void:
	multiplayer.multiplayer_peer = peer
	emit_signal("replace_main_scene", ResourceLoader.load_threaded_get(loading_path))


func _on_host_pressed() -> void:
	peer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(int(port.value))
	if err != OK:
		CrashHandler.show_error(
			"Falha ao criar servidor na porta %d.\nErro: %s\n\nVerifique se a porta está em uso." % [int(port.value), error_string(err)],
			_on_host_pressed
		)
		return
	if peer.host == null:
		CrashHandler.show_error(
			"Servidor criado, mas host ENet é nulo.\nTente outra porta ou reinicie o jogo.",
			_on_host_pressed
		)
		return
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	loading_path = LEVEL_BASE_PATH
	loading.show()
	ResourceLoader.load_threaded_request(loading_path, "", true)


func _on_connect_pressed() -> void:
	peer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address.text, int(port.value))
	if err != OK:
		CrashHandler.show_error(
			"Falha ao conectar em %s:%d.\nErro: %s\n\nVerifique o endereço e a porta." % [address.text, int(port.value), error_string(err)],
			_on_connect_pressed
		)
		return
	if peer.host == null:
		CrashHandler.show_error(
			"Conexão iniciada, mas host ENet é nulo.\nTente novamente.",
			_on_connect_pressed
		)
		return
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	loading_path = LEVEL_BASE_PATH
	loading.show()
	ResourceLoader.load_threaded_request(loading_path, "", true)


func _on_back_pressed() -> void:
	quit.emit()


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		quit.emit()

extends Node

## main.tscn é a tela inicial autossuficiente E o roteador de telas. A abertura
## (robô 3D sobre um pedestal de fundo + overlay 2D) vive na sub-árvore StartScreen,
## filha desta raiz; quando a abertura termina, change_scene_to_packed troca a
## StartScreen pelo menu (e, dali em diante, por qualquer outra tela do jogo).

const MENU_PATH: String = "res://scenes2D/menu/menu.tscn"
const STATUS_TEXT: String = "SINCRONIZANDO ARENA DE TREINO"

@export_range(1.0, 10.0, 0.1) var minimum_wait_time: float = 2.0
@export_range(0.1, 5.0, 0.05) var fade_out_time: float = 0.35

@onready var start_screen: Node3D = $StartScreen
@onready var hold_timer: Timer = $StartScreen/HoldTimer
@onready var overlay_ui: Control = $StartScreen/Overlay/UI
@onready var title_block: VBoxContainer = $StartScreen/Overlay/UI/TitleBlock
@onready var status_label: Label = $StartScreen/Overlay/UI/StatusFrame/StatusLabel
@onready var boot_flash: ColorRect = $StartScreen/Overlay/UI/BootFlash

var _elapsed: float = 0.0
var _title_origin: Vector2
var _opening_done: bool = false


func _ready() -> void:
	multiplayer.server_relay = false
	if DisplayServer.get_name() == "headless":
		Engine.max_fps = 60
	randomize()
	get_window().mode = Settings.config_file.get_value("video", "display_mode")
	_start_opening()


# Roda a abertura: o robô já está montado na cena; aqui só animamos o overlay 2D
# e disparamos o timer que leva ao menu.
func _start_opening() -> void:
	# A tela inicial (e seu robô decorativo) nunca exibe overlays/tooltips de debug.
	start_screen.add_to_group("no_debug_overlay")
	overlay_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_origin = title_block.position
	title_block.position = _title_origin + Vector2(-28.0, 0.0)
	title_block.modulate.a = 0.0
	status_label.modulate.a = 0.0
	boot_flash.color = Color(0.88, 0.96, 1.0, 0.85)
	hold_timer.wait_time = minimum_wait_time
	hold_timer.timeout.connect(_on_hold_timer_timeout, CONNECT_ONE_SHOT)
	hold_timer.start()
	_play_intro()


func _process(delta: float) -> void:
	# Após a troca pro menu a sub-árvore StartScreen é liberada; pare de tocá-la.
	if _opening_done or not is_instance_valid(status_label):
		return
	_elapsed += delta
	var dot_count: int = int(floor(_elapsed * 3.0)) % 4
	status_label.text = STATUS_TEXT + ".".repeat(dot_count)


func _play_intro() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(boot_flash, "color", Color(0.88, 0.96, 1.0, 0.0), 0.45)
	tween.tween_property(title_block, "modulate:a", 1.0, 0.55)
	tween.tween_property(title_block, "position", _title_origin, 0.55)
	tween.tween_property(status_label, "modulate:a", 1.0, 0.55).set_delay(0.22)


func _on_hold_timer_timeout() -> void:
	_opening_done = true
	var tween: Tween = create_tween()
	tween.tween_property(overlay_ui, "modulate:a", 0.0, fade_out_time)
	tween.finished.connect(go_to_main_menu, CONNECT_ONE_SHOT)


func go_to_main_menu() -> void:
	_swap_root_scene(ResourceLoader.load(MENU_PATH))


func _swap_root_scene(resource: PackedScene) -> void:
	if multiplayer != null and multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	change_scene_to_packed(resource)


func replace_main_scene(resource: PackedScene) -> void:
	call_deferred("change_scene_to_packed", resource)


func change_scene_to_packed(resource: PackedScene) -> void:
	var node: Node = resource.instantiate()
	for child in get_children():
		remove_child(child)
		child.queue_free()
	add_child(node)
	if node.has_signal(&"quit"):
		node.quit.connect(go_to_main_menu)
	if node.has_signal(&"replace_main_scene"):
		node.replace_main_scene.connect(replace_main_scene)

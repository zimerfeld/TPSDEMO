extends Node

signal replace_main_scene(resource: PackedScene)
signal quit

const CHARACTERS: Array[Dictionary] = [
	{
		"name": "PLAYER",
		"scene_path": "res://library3D/characters/player/player.tscn",
		"tint": Color(1.0, 1.0, 1.0, 1.0),
	},
	{
		"name": "PLAYERA",
		"scene_path": "res://library3D/characters/playera/playera.tscn",
		"tint": Color(1.0, 0.55, 0.65, 1.0),
	},
]

const LEVELS_PATH: String = "res://scenes2D/levels/levels.tscn"

var current_index: int = 0
var _model_rot_y: float = 0.0
var _loading_path: String = ""

@onready var model_holder: Node3D = $ModelHolder
@onready var character_name_label: Label = %Name
@onready var loading: HBoxContainer = %Loading
@onready var loading_progress: ProgressBar = %Progress
@onready var loading_done_timer: Timer = %DoneTimer
@onready var portuguese_button: Button = %Portuguese
@onready var english_button: Button = %English
@onready var spanish_button: Button = %Spanish


func _ready() -> void:
	_load_character(current_index)
	_update_language_buttons()
	# Foco inicial no Tab = 1 + anel de Tab na ordem de leitura. Re-liga quando o DebugOverlay injeta
	# o toggle "Debug 2D" na barra Actions (entra DEPOIS do _ready).
	UINav.focus_tab_one.call_deferred(self)
	_wire_tab_order.call_deferred()
	($UI/Actions as HBoxContainer).child_entered_tree.connect(
		func(_n: Node) -> void: _wire_tab_order.call_deferred())


# (Re)liga o anel de Tab da tela na ordem de leitura. Idempotente — re-chamável quando o conjunto
# de focáveis muda (toggle injetado, botão de idioma habilitando/desabilitando).
func _wire_tab_order() -> void:
	UINav.wire_tab_ring(self)


# Grey out the button for the language already active (same pattern as the menu).
func _update_language_buttons() -> void:
	var lang := Locale.get_language()
	portuguese_button.disabled = lang == "pt"
	english_button.disabled = lang == "en"
	spanish_button.disabled = lang == "es"
	# O idioma ativo fica desabilitado (fora do Tab) — re-liga o anel p/ a sequência fechar sem ele.
	if is_node_ready():
		_wire_tab_order.call_deferred()


func _on_portuguese_pressed() -> void:
	Locale.set_language("pt")
	_update_language_buttons()


func _on_english_pressed() -> void:
	Locale.set_language("en")
	_update_language_buttons()


func _on_spanish_pressed() -> void:
	Locale.set_language("es")
	_update_language_buttons()


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

	var model_scene: PackedScene = load("res://library3D/characters/player/player.glb")
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
	# Índice da variante (CHARACTERS está na mesma ordem de PlayerSelection.VARIANTS): enviado
	# ao servidor no multiplayer para spawnar o modelo/cor certos deste peer em todos os clientes.
	PlayerSelection.variant_id = current_index
	# Fluxo de salas (Host/Client): a sala já foi escolhida ANTES desta tela; volta para a
	# sessão (que está em /root) e é ela quem spawna o player na sala correspondente.
	if RoomManager.pending_play_room >= 0:
		emit_signal("replace_main_scene", load(RoomManager.pending_play_return))
		return
	# Offline (solo): chooseplayer → levels.
	_loading_path = LEVELS_PATH
	loading.show()
	ResourceLoader.load_threaded_request(_loading_path, "", true)


func _on_back_pressed() -> void:
	_go_back()


# Volta da tela de personagem. No fluxo de salas, CANCELA o "Jogar" (limpa o marcador pendente)
# e retorna à sessão Host/Client SEM spawnar e SEM fechar o peer. Fora dele, volta ao menu.
func _go_back() -> void:
	if RoomManager.pending_play_room >= 0:
		var ret: String = RoomManager.pending_play_return
		RoomManager.pending_play_room = -1
		emit_signal("replace_main_scene", load(ret))
	else:
		quit.emit()


func _on_loading_done_timer_timeout() -> void:
	emit_signal("replace_main_scene", ResourceLoader.load_threaded_get(_loading_path))


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		# ESC encerra primeiro um campo em edição; só o 2º ESC volta (sessão ou menu).
		if UINav.cancel_active_edit(get_viewport()):
			get_viewport().set_input_as_handled()
			return
		get_viewport().set_input_as_handled()
		_go_back()

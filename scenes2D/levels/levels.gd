extends Node

signal replace_main_scene

const LEVEL_1_PATH: String = "res://scenes3D/level_1/level_1.tscn"
const LEVEL_2_PATH: String = "res://scenes3D/level_2/level_2.tscn"
const CHOOSEPLAYER_PATH: String = "res://scenes2D/chooseplayer/chooseplayer.tscn"
const LevelTemplateDialogScene := preload("res://scenes2D/level_templates/level_template_dialog.gd")

var loading_path: String = ""

@onready var level1_button: Button = %Level1
@onready var level2_button: Button = %Level2
@onready var loading: HBoxContainer = %Loading
@onready var loading_progress: ProgressBar = %Progress
@onready var loading_done_timer: Timer = %DoneTimer
@onready var portuguese_button: Button = %Portuguese
@onready var english_button: Button = %English

var _template_dialog: LevelTemplateDialog = null
var _template_buttons: Dictionary = {}


func _ready() -> void:
	_update_language_buttons()
	_add_template_buttons()
	# Foco inicial SEMPRE no controle de Tab = 1 (cabeça do anel), p/ as setas/Tab começarem do 1º.
	UINav.focus_tab_one.call_deferred(self)
	# Tab incremental de 1 na ordem de leitura (Level/Template de cima p/ baixo, depois Voltar/idiomas).
	# Re-liga quando o DebugOverlay injeta o toggle "Debug 2D" na barra Actions (ele entra DEPOIS),
	# para o toggle entrar na mesma sequência de Tab.
	_wire_tab_order.call_deferred()
	($UI/Actions as HBoxContainer).child_entered_tree.connect(
		func(_n: Node) -> void: _wire_tab_order.call_deferred())


# (Re)liga o anel de Tab da tela na ordem de leitura. Idempotente — pode ser chamado quantas vezes
# o conjunto de controles focáveis mudar (toggle injetado, botão de idioma habilitando/desabilitando).
func _wire_tab_order() -> void:
	UINav.wire_tab_ring(self)


# Grey out the button for the language already active (same pattern as the menu).
func _update_language_buttons() -> void:
	var lang := Locale.get_language()
	portuguese_button.disabled = lang == "pt"
	english_button.disabled = lang == "en"
	# O botão do idioma ativo fica desabilitado (fora do Tab) — re-liga o anel p/ a sequência fechar
	# sem ele. call_deferred: o estado disabled já assentou quando o anel é remontado.
	if is_node_ready():
		_wire_tab_order.call_deferred()


func _on_portuguese_pressed() -> void:
	Locale.set_language("pt")
	_update_language_buttons()


func _on_english_pressed() -> void:
	Locale.set_language("en")
	_update_language_buttons()


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
			level2_button.show()
			loading.hide()


func _on_loading_done_timer_timeout() -> void:
	emit_signal("replace_main_scene", ResourceLoader.load_threaded_get(loading_path))


func _on_level_1_pressed() -> void:
	_select_level(LEVEL_1_PATH)


func _on_level_2_pressed() -> void:
	_select_level(LEVEL_2_PATH)


# Offline (solo): carrega o nível direto. O fluxo online não passa mais por aqui — a tela de
# salas (PlayOnline → HostSession/ClientSession) escolhe o level por sala.
func _select_level(level_path: String) -> void:
	# Garante o player controlado (sem herdar um "Hospedar Somente" anterior).
	PlayerSelection.spectator_host = false
	loading_path = level_path
	level1_button.hide()
	level2_button.hide()
	loading.show()
	ResourceLoader.load_threaded_request(loading_path, "", true)


func _on_back_pressed() -> void:
	emit_signal("replace_main_scene", load(CHOOSEPLAYER_PATH))


func _add_template_buttons() -> void:
	# Cada botão de template fica à DIREITA do botão do level, na mesma linha. Recebe NOME próprio
	# (senão o Godot os auto-nomeia "@Button@2/3…", que aparecia no Debug 2D) e o tab_order da ordem
	# de leitura (level → seu template): Level1=1, Level1Template=2, Level2=3, … (ver levels.tscn).
	var rows := {
		LEVEL_1_PATH: {"row": %Level1.get_parent(), "name": "Level1Template", "tab": 2},
		LEVEL_2_PATH: {"row": %Level2.get_parent(), "name": "Level2Template", "tab": 4},
	}
	for level_path in rows:
		var info: Dictionary = rows[level_path]
		var btn := Button.new()
		btn.name = info["name"]
		btn.set_meta(UINav.TAB_ORDER_META, info["tab"])
		btn.text = _template_button_text(level_path)
		btn.custom_minimum_size = Vector2(220, 50)
		btn.pressed.connect(_open_template_dialog.bind(level_path))
		(info["row"] as Node).add_child(btn)
		_template_buttons[level_path] = btn


func _open_template_dialog(level_path: String) -> void:
	if _template_dialog == null:
		_template_dialog = LevelTemplateDialogScene.new()
		_template_dialog.templates_changed.connect(_refresh_template_buttons)
		add_child(_template_dialog)
	_template_dialog.popup_for_level(level_path)


func _refresh_template_buttons() -> void:
	for level_path in _template_buttons:
		(_template_buttons[level_path] as Button).text = _template_button_text(level_path)


func _template_button_text(level_path: String) -> String:
	var active := LevelTemplateManager.active_template(level_path)
	if active.is_empty():
		return "Templates: padrão"
	return "Template: %s" % String(active.get("name", "ativo"))


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		# ESC encerra primeiro um campo em edição; só o 2º ESC volta de tela.
		if UINav.cancel_active_edit(get_viewport()):
			get_viewport().set_input_as_handled()
			return
		get_viewport().set_input_as_handled()
		emit_signal("replace_main_scene", load(CHOOSEPLAYER_PATH))

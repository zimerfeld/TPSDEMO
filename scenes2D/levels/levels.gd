extends Node

signal replace_main_scene

const LEVEL_1_PATH: String = "res://scenes3D/level_1/level_1.tscn"
const LEVEL_2_PATH: String = "res://scenes3D/level_2/level_2.tscn"
const LEVEL_BASE_PATH: String = "res://scenes3D/level_base/level_base.tscn"
const CHOOSEPLAYER_PATH: String = "res://scenes2D/chooseplayer/chooseplayer.tscn"
const LevelTemplateDialogScene := preload("res://scenes2D/level_templates/level_template_dialog.gd")

var loading_path: String = ""

@onready var level1_button: Button = %Level1Button
@onready var level2_button: Button = %Level2Button
@onready var level_base_button: Button = %LevelBaseButton
@onready var back_button: Button = %BackButton
@onready var loading: HBoxContainer = %Loading
@onready var loading_progress: ProgressBar = %Progress
@onready var loading_done_timer: Timer = %DoneTimer
@onready var portuguese_button: Button = %PortugueseButton
@onready var english_button: Button = %EnglishButton

var _template_dialog: Window = null
var _template_buttons: Dictionary = {}


func _ready() -> void:
	_update_language_buttons()
	_add_template_buttons()
	# Foco inicial para a navegação por setas do teclado.
	UINav.focus_first.call_deferred(self)


# Grey out the button for the language already active (same pattern as the menu).
func _update_language_buttons() -> void:
	var lang := Locale.get_language()
	portuguese_button.disabled = lang == "pt"
	english_button.disabled = lang == "en"


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
			level_base_button.show()
			loading.hide()


func _on_loading_done_timer_timeout() -> void:
	emit_signal("replace_main_scene", ResourceLoader.load_threaded_get(loading_path))


func _on_level_1_pressed() -> void:
	_select_level(LEVEL_1_PATH)


func _on_level_2_pressed() -> void:
	_select_level(LEVEL_2_PATH)


func _on_level_base_pressed() -> void:
	_select_level(LEVEL_BASE_PATH)


# Offline (solo): carrega o nível direto. O fluxo online não passa mais por aqui — a tela de
# salas (PlayOnline → HostSession/ClientSession) escolhe o level por sala.
func _select_level(level_path: String) -> void:
	# Garante o player controlado (sem herdar um "Hospedar Somente" anterior).
	PlayerSelection.spectator_host = false
	loading_path = level_path
	level1_button.hide()
	level2_button.hide()
	level_base_button.hide()
	loading.show()
	ResourceLoader.load_threaded_request(loading_path, "", true)


func _on_back_pressed() -> void:
	emit_signal("replace_main_scene", load(CHOOSEPLAYER_PATH))


func _add_template_buttons() -> void:
	var rows := {
		LEVEL_1_PATH: %Level1Button.get_parent(),
		LEVEL_2_PATH: %Level2Button.get_parent(),
		LEVEL_BASE_PATH: %LevelBaseButton.get_parent(),
	}
	for level_path in rows:
		var btn := Button.new()
		btn.text = _template_button_text(level_path)
		btn.custom_minimum_size = Vector2(220, 50)
		btn.pressed.connect(_open_template_dialog.bind(level_path))
		rows[level_path].add_child(btn)
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
		emit_signal("replace_main_scene", load(CHOOSEPLAYER_PATH))
		get_viewport().set_input_as_handled()

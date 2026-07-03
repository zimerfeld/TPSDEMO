extends Node

signal replace_main_scene

const LEVEL_1_PATH: String = "res://scenes3D/level_1/level_1.tscn"
const LEVEL_2_PATH: String = "res://scenes3D/level_2/level_2.tscn"
const CHOOSEPLAYER_PATH: String = "res://scenes2D/chooseplayer/chooseplayer.tscn"
const LevelTemplateDialogScene := preload("res://scenes2D/level_templates/level_template_dialog.gd")

var loading_path: String = ""

@onready var levels_grid: GridContainer = %LevelsGrid
@onready var loading: HBoxContainer = %Loading
@onready var loading_progress: ProgressBar = %Progress
@onready var loading_done_timer: Timer = %DoneTimer
@onready var portuguese_button: Button = %Portuguese
@onready var english_button: Button = %English

var _template_dialog: LevelTemplateDialog = null
var _scenery_dialog: LevelTemplateDialog = null
var _template_buttons: Dictionary = {}
var _scenery_buttons: Dictionary = {}


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
			levels_grid.show()
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
	# Esconde o GRID inteiro (não só os botões de level): num GridContainer, filhos ocultos são
	# pulados e o resto REFLUI — sumir só com os levels embaralharia as linhas durante o loading.
	levels_grid.hide()
	loading.show()
	ResourceLoader.load_threaded_request(loading_path, "", true)


func _on_back_pressed() -> void:
	emit_signal("replace_main_scene", load(CHOOSEPLAYER_PATH))


func _add_template_buttons() -> void:
	# Os controles vivem num GridContainer de 3 COLUNAS (%LevelsGrid): cada LINHA é um level e as
	# colunas são Level | Template | Cenário — o grid iguala a largura de cada coluna (a célula
	# mais larga manda), então as duas linhas ficam com o MESMO espaçamento/alinhamento. Os botões
	# são inseridos LOGO APÓS o botão do seu level (move_child) para caírem na linha certa. Nomes
	# próprios (senão o Godot os auto-nomeia "@Button@2/3…") e tab_order na ordem de leitura:
	# Level1=1, Template=2, Cenário=3, Level2=4, Template=5, Cenário=6 (ver levels.tscn).
	var rows := {
		LEVEL_1_PATH: {"level_button": %Level1, "prefix": "Level1", "tab": 2},
		LEVEL_2_PATH: {"level_button": %Level2, "prefix": "Level2", "tab": 5},
	}
	for level_path in rows:
		var info: Dictionary = rows[level_path]
		var level_button := info["level_button"] as Control
		var tpl_btn := _make_row_button(String(info["prefix"]) + "Template",
				int(info["tab"]), _template_button_text(level_path))
		tpl_btn.pressed.connect(_open_template_dialog.bind(level_path))
		levels_grid.add_child(tpl_btn)
		levels_grid.move_child(tpl_btn, level_button.get_index() + 1)
		_template_buttons[level_path] = tpl_btn
		var scn_btn := _make_row_button(String(info["prefix"]) + "Scenery",
				int(info["tab"]) + 1, _scenery_button_text(level_path))
		scn_btn.pressed.connect(_open_scenery_dialog.bind(level_path))
		levels_grid.add_child(scn_btn)
		levels_grid.move_child(scn_btn, level_button.get_index() + 2)
		_scenery_buttons[level_path] = scn_btn


func _make_row_button(button_name: String, tab: int, text: String) -> Button:
	var btn := Button.new()
	btn.name = button_name
	btn.set_meta(UINav.TAB_ORDER_META, tab)
	btn.text = text
	btn.custom_minimum_size = Vector2(220, 50)
	# As colunas Template/Cenário EXPANDEM: com o grid em largura total e a coluna Level fixa
	# (300 px), as duas dividem o RESTO do espaço em tela meio a meio, responsivamente.
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return btn


func _open_template_dialog(level_path: String) -> void:
	if _template_dialog == null:
		_template_dialog = LevelTemplateDialogScene.new()
		_template_dialog.configure("spawn")
		_template_dialog.templates_changed.connect(_refresh_template_buttons)
		add_child(_template_dialog)
	_template_dialog.popup_for_level(level_path)


func _open_scenery_dialog(level_path: String) -> void:
	if _scenery_dialog == null:
		_scenery_dialog = LevelTemplateDialogScene.new()
		_scenery_dialog.configure("scenery")
		_scenery_dialog.templates_changed.connect(_refresh_template_buttons)
		add_child(_scenery_dialog)
	_scenery_dialog.popup_for_level(level_path)


func _refresh_template_buttons() -> void:
	for level_path in _template_buttons:
		(_template_buttons[level_path] as Button).text = _template_button_text(level_path)
	for level_path in _scenery_buttons:
		(_scenery_buttons[level_path] as Button).text = _scenery_button_text(level_path)


func _template_button_text(level_path: String) -> String:
	var active := LevelTemplateManager.active_template(level_path)
	if active.is_empty():
		return "Templates: padrão"
	return "Template: %s" % String(active.get("name", "ativo"))


func _scenery_button_text(level_path: String) -> String:
	var active := LevelTemplateManager.active_scenery(level_path)
	if active.is_empty():
		return "Cenários: padrão"
	return "Cenário: %s" % String(active.get("name", "ativo"))


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		# ESC encerra primeiro um campo em edição; só o 2º ESC volta de tela.
		if UINav.cancel_active_edit(get_viewport()):
			get_viewport().set_input_as_handled()
			return
		get_viewport().set_input_as_handled()
		emit_signal("replace_main_scene", load(CHOOSEPLAYER_PATH))

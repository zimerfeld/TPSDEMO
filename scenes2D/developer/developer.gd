extends Node

signal quit
signal replace_main_scene(resource: PackedScene)

const MODELS_PATH: String = "res://scenes3D/models/models.tscn"
const CONTROLS_PATH: String = "res://scenes2D/controls/controls.tscn"

# Each row is a Disabled/Enabled pair behaving like a single toggle. Maps the row
# node name (found anywhere under UI) to the "game" config key it controls. Changes
# are saved and applied to the DebugOverlay immediately.
# OBS: o Debug 3D (esqueleto/malha/membros/type-name-id 3D) foi MOVIDO para a tela Models
# (toggles próprios sobre o preview). Aqui ficou só o Debug 2D (tooltips dos controles).
const _TOGGLES: Dictionary = {
	"Debug2DRow": "debug_2d",
	"ShowTypeRow": "show_type",
	"ShowNameRow": "show_name",
	"ShowIDRow": "show_id",
	"ShowPathRow": "show_path",
	"ShowTabRow": "show_tab",
}

# Os toggles "gerais" (abaixo do título) vivem num GridContainer (UI/Margin/Main/General)
# para alinhar os botões em colunas — então não têm um nó "row" (HBox) como os demais. Cada
# chave de config mapeia o par [botão Desativado, botão Ativado], com nomes únicos no grid.
const _GENERAL_TOGGLES: Dictionary = {
	"hud_version": ["VersionDisabled", "VersionEnabled"],
	"hud_fps": ["FPSDisabled", "FPSEnabled"],
	"performance_hud": ["PerfDisabled", "PerfEnabled"],
}

# Sub-rows do Debug 2D: só fazem efeito enquanto o master (Debug 2D) está ligado; seus
# botões ficam acinzentados (disabled) caso contrário, deixando a dependência clara.
const _DEBUG2D_SUBROWS: Array[String] = [
	"ShowTypeRow", "ShowNameRow", "ShowIDRow", "ShowPathRow", "ShowTabRow",
]

# The theme has no "disabled" Button stylebox and the buttons carry a green/yellow
# `modulate`, so a `disabled` button still looks active. We dim it to this greyed,
# semi-transparent tint while disabled and restore its saved base color when enabled.
const _DISABLED_MODULATE := Color(0.5, 0.5, 0.55, 0.5)
const _BASE_MODULATE_META := &"_base_modulate"

# Estilo de cor como na tela Settings: o botão SELECIONADO de cada par fica na cor (modulate) autorada
# cheia (verde/amarelo) e o NÃO selecionado fica bem menos iluminado — a cor base multiplicada por este
# fator (mantém o matiz). Sobreposto pelo estado "disabled" (acinzentado) das sub-linhas do Debug 2D.
const OPTION_DIM_FACTOR: float = 0.42

@onready var portuguese_button: Button = $UI/Actions/LangBar/Portuguese
@onready var english_button: Button = $UI/Actions/LangBar/English
@onready var spanish_button: Button = $UI/Actions/LangBar/Spanish

# Toggle "Debug 2D" reutilizável injetado na barra Actions, na MESMA posição padrão das demais telas
# (último item, à direita). Espelha o par Desativado/Ativado da coluna Debug 2D: os dois controlam a
# mesma chave `debug_2d` e são mantidos em sincronia (ver _ensure_actions_debug2d / _sync_*).
var _actions_debug2d: Debug2DToggle = null


func _ready() -> void:
	# Toggles gerais (grid alinhado): mesma lógica dos demais, mas referenciando o par de
	# botões direto (não há nó "row" no GridContainer).
	var general := $UI/Margin/Main/General
	for key in _GENERAL_TOGGLES:
		var pair: Array = _GENERAL_TOGGLES[key]
		var disabled_btn: Button = general.get_node(pair[0])
		var enabled_btn: Button = general.get_node(pair[1])
		var group := ButtonGroup.new()
		disabled_btn.button_group = group
		enabled_btn.button_group = group
		var general_on: bool = Settings.config_file.get_value("game", key, false)
		enabled_btn.set_pressed_no_signal(general_on)
		disabled_btn.set_pressed_no_signal(not general_on)
		enabled_btn.toggled.connect(_on_toggle.bind(key))
		# Estilo de cor como na Settings: selecionado na cor cheia, não selecionado escurecido.
		_setup_toggle_button(disabled_btn)
		_setup_toggle_button(enabled_btn)

	for row_name in _TOGGLES:
		var row: HBoxContainer = _row(row_name)
		var key: String = _TOGGLES[row_name]
		var enabled_btn: Button = row.get_node("Enabled")
		var disabled_btn: Button = row.get_node("Disabled")
		_make_button_group(row)
		# Sync from saved settings without triggering the handler.
		var on: bool = Settings.config_file.get_value("game", key, false)
		enabled_btn.set_pressed_no_signal(on)
		disabled_btn.set_pressed_no_signal(not on)
		enabled_btn.toggled.connect(_on_toggle.bind(key))
		_setup_toggle_button(disabled_btn)
		_setup_toggle_button(enabled_btn)
	# Guarda a cor autorada dos RÓTULOS das sub-linhas do Debug 2D p/ restaurar após o estado acinzentado
	# (os BOTÕES já guardaram a sua em _setup_toggle_button, ANTES de qualquer dimming).
	for row_name in _DEBUG2D_SUBROWS:
		for child in _row(row_name).get_children():
			if child is Control and not (child is BaseButton):
				child.set_meta(_BASE_MODULATE_META, (child as Control).modulate)
	# As sub-toggles do Debug 2D só valem com o master (Debug 2D) ligado.
	_update_subrows_enabled()

	# Toggle "Debug 2D" na barra Actions (igual às outras telas), sincronizado com o par da coluna.
	_ensure_actions_debug2d()

	_update_language_buttons()

	# Foco inicial no Tab = 1 + anel de Tab na ordem de leitura. Re-liga quando o DebugOverlay (ou esta
	# tela) injeta o toggle "Debug 2D" na barra Actions. As sub-toggles do Debug 2D entram/saem do anel
	# conforme o master liga/desliga — _update_subrows_enabled também re-liga (ver lá).
	UINav.focus_tab_one.call_deferred(self)
	_wire_tab_order.call_deferred()
	($UI/Actions as HBoxContainer).child_entered_tree.connect(
		func(_n: Node) -> void: _wire_tab_order.call_deferred())


# (Re)liga o anel de Tab da tela na ordem de leitura. Idempotente — re-chamável quando o conjunto de
# focáveis muda (toggle injetado, idioma habilitando/desabilitando, sub-toggles do Debug 2D).
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


func _row(row_name: String) -> HBoxContainer:
	return $UI.find_child(row_name, true, false) as HBoxContainer


# Injeta o toggle "Debug 2D" reutilizável (Debug2DToggle) na barra Actions, no MESMO lugar padrão das
# outras telas: como último item (à direita, depois da LangBar), igual ao que o DebugOverlay anexa nas
# demais. O DebugOverlay PULA a developer de propósito (ela gerencia o seu aqui), para os dois ficarem
# em sincronia com o par Desativado/Ativado da coluna. O próprio Debug2DToggle grava `debug_2d` e
# atualiza o DebugOverlay; só refletimos a mudança no par e nas sub-linhas via _on_actions_debug2d_toggled.
func _ensure_actions_debug2d() -> void:
	var actions := $UI/Actions
	if actions.has_node("Debug2D"):
		return
	var toggle := Debug2DToggle.new()
	toggle.name = "Debug2D"
	# Texto definido ANTES de add_child para o auto-localizador (Locale) capturá-lo como fonte.
	toggle.text = "Debug 2D"
	actions.add_child(toggle)
	toggle.toggled.connect(_on_actions_debug2d_toggled)
	_actions_debug2d = toggle


# O toggle da barra Actions mudou: ele mesmo já gravou a chave e atualizou o DebugOverlay; aqui só
# espelhamos o novo estado no par Desativado/Ativado da coluna (sem disparar handlers) e reavaliamos as
# sub-linhas, mantendo os dois controles do Debug 2D coerentes na mesma tela.
func _on_actions_debug2d_toggled(toggled_on: bool) -> void:
	var row := _row("Debug2DRow")
	var enabled_btn := row.get_node("Enabled") as BaseButton
	var disabled_btn := row.get_node("Disabled") as BaseButton
	enabled_btn.set_pressed_no_signal(toggled_on)
	disabled_btn.set_pressed_no_signal(not toggled_on)
	_style_toggle_button(enabled_btn)
	_style_toggle_button(disabled_btn)
	_update_subrows_enabled()


# Grey out the Debug 2D sub-toggle buttons unless the Debug 2D master is enabled.
func _update_subrows_enabled() -> void:
	var on_2d: bool = Settings.config_file.get_value("game", "debug_2d", false)
	_set_subrows_disabled(_DEBUG2D_SUBROWS, not on_2d)
	# As sub-toggles (des)habilitadas entram/saem do anel de Tab — re-liga p/ a numeração fechar de 1.
	if is_node_ready():
		_wire_tab_order.call_deferred()


func _set_subrows_disabled(rows: Array[String], is_disabled: bool) -> void:
	for row_name in rows:
		for child in _row(row_name).get_children():
			if child is BaseButton:
				# Botão: o estado "disabled" (master off) tem prioridade no estilo (acinzentado);
				# reativado, _style_toggle_button repinta conforme selecionado/não selecionado.
				(child as BaseButton).disabled = is_disabled
				_style_toggle_button(child as BaseButton)
			elif child is Control:
				# O rótulo (ShowType/…/ShowTab) também está "ligado" ao Debug 2D: escurece
				# junto para a linha INTEIRA refletir o estado desativado, restaurando a cor original
				# quando reativada (o tema não tem estilo "disabled" próprio).
				var ctrl := child as Control
				ctrl.modulate = _DISABLED_MODULATE if is_disabled else ctrl.get_meta(_BASE_MODULATE_META, ctrl.modulate)


func _make_button_group(row: Node) -> void:
	var group := ButtonGroup.new()
	for btn in row.get_children():
		if btn is BaseButton:
			btn.button_group = group


# Prepara um botão de toggle (par Desativado/Ativado) p/ o estilo de cor da Settings: guarda a cor
# autorada como base (ANTES de qualquer dimming), repinta a si mesmo a cada (des)seleção e aplica o
# estilo inicial. Os dois botões do par reagem (o radio anterior emite toggled(false) e o novo true).
func _setup_toggle_button(btn: BaseButton) -> void:
	btn.set_meta(_BASE_MODULATE_META, btn.modulate)
	btn.toggled.connect(func(_pressed: bool) -> void: _style_toggle_button(btn))
	_style_toggle_button(btn)


# Pinta UM botão de toggle: "disabled" (master off) → acinzentado; selecionado → cor autorada cheia;
# não selecionado → cor autorada escurecida (OPTION_DIM_FACTOR). Igual ao realce da tela Settings.
func _style_toggle_button(btn: BaseButton) -> void:
	if btn.disabled:
		btn.modulate = _DISABLED_MODULATE
		return
	var base: Color = btn.get_meta(_BASE_MODULATE_META, btn.modulate)
	btn.modulate = base if btn.button_pressed else _dim_color(base)


# Escurece uma cor multiplicando o RGB por OPTION_DIM_FACTOR (mantém matiz e alfa) — opção inativa.
func _dim_color(c: Color) -> Color:
	return Color(c.r * OPTION_DIM_FACTOR, c.g * OPTION_DIM_FACTOR, c.b * OPTION_DIM_FACTOR, c.a)


func _on_toggle(button_pressed: bool, key: String) -> void:
	Settings.config_file.set_value("game", key, button_pressed)
	Settings.save_settings()
	DebugOverlay.refresh()
	# Show/hide the Performance HUD overlay immediately.
	if key == "performance_hud":
		PerformanceHUD.refresh()
	# Toggling the Debug 2D master enables/disables its dependent sub-toggle buttons.
	if key == "debug_2d":
		_update_subrows_enabled()
		# Espelha o novo estado no toggle da barra Actions (sem disparar o handler dele).
		if _actions_debug2d != null:
			_actions_debug2d.set_pressed_no_signal(button_pressed)


func _on_models_pressed() -> void:
	emit_signal("replace_main_scene", load(MODELS_PATH))


func _on_controls_pressed() -> void:
	emit_signal("replace_main_scene", load(CONTROLS_PATH))


func _on_back_pressed() -> void:
	quit.emit()


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		# ESC encerra primeiro um campo em edição; só o 2º ESC volta ao menu.
		if UINav.cancel_active_edit(get_viewport()):
			get_viewport().set_input_as_handled()
			return
		get_viewport().set_input_as_handled()
		quit.emit()

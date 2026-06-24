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
	"ShowTabRow": "show_tab",
}

# Os toggles "gerais" (abaixo do título) vivem num GridContainer (UI/Margin/Main/General)
# para alinhar os botões em colunas — então não têm um nó "row" (HBox) como os demais. Cada
# chave de config mapeia o par [botão Desativado, botão Ativado], com nomes únicos no grid.
const _GENERAL_TOGGLES: Dictionary = {
	"hud_fps": ["FPSDisabled", "FPSEnabled"],
	"performance_hud": ["PerfDisabled", "PerfEnabled"],
}

# Sub-rows do Debug 2D: só fazem efeito enquanto o master (Debug 2D) está ligado; seus
# botões ficam acinzentados (disabled) caso contrário, deixando a dependência clara.
const _DEBUG2D_SUBROWS: Array[String] = [
	"ShowTypeRow", "ShowNameRow", "ShowIDRow", "ShowTabRow",
]

# The theme has no "disabled" Button stylebox and the buttons carry a green/yellow
# `modulate`, so a `disabled` button still looks active. We dim it to this greyed,
# semi-transparent tint while disabled and restore its saved base color when enabled.
const _DISABLED_MODULATE := Color(0.5, 0.5, 0.55, 0.5)
const _BASE_MODULATE_META := &"_base_modulate"

@onready var portuguese_button: Button = $UI/LangBar/PortugueseButton
@onready var english_button: Button = $UI/LangBar/EnglishButton


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
	# Remember each sub-toggle ROW child's authored color (os botões E o rótulo) so it can be
	# restored after the greyed-out (disabled) state.
	for row_name in _DEBUG2D_SUBROWS:
		for child in _row(row_name).get_children():
			if child is Control:
				child.set_meta(_BASE_MODULATE_META, (child as Control).modulate)
	# As sub-toggles do Debug 2D só valem com o master (Debug 2D) ligado.
	_update_subrows_enabled()

	_update_language_buttons()

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


func _row(row_name: String) -> HBoxContainer:
	return $UI.find_child(row_name, true, false) as HBoxContainer


# Grey out the Debug 2D sub-toggle buttons unless the Debug 2D master is enabled.
func _update_subrows_enabled() -> void:
	var on_2d: bool = Settings.config_file.get_value("game", "debug_2d", false)
	_set_subrows_disabled(_DEBUG2D_SUBROWS, not on_2d)


func _set_subrows_disabled(rows: Array[String], is_disabled: bool) -> void:
	for row_name in rows:
		for child in _row(row_name).get_children():
			if child is Control:
				var ctrl := child as Control
				# O rótulo (ShowTypeLabel/…/ShowIDLabel/ShowTabLabel) também está "ligado" ao
				# Debug 2D: escurece junto dos botões para a linha INTEIRA refletir o estado
				# desativado, restaurando a cor original quando reativada (o tema não tem
				# estilo "disabled" próprio).
				ctrl.modulate = _DISABLED_MODULATE if is_disabled else ctrl.get_meta(_BASE_MODULATE_META, ctrl.modulate)
				if ctrl is BaseButton:
					(ctrl as BaseButton).disabled = is_disabled


func _make_button_group(row: Node) -> void:
	var group := ButtonGroup.new()
	for btn in row.get_children():
		if btn is BaseButton:
			btn.button_group = group


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
		quit.emit()
		get_viewport().set_input_as_handled()

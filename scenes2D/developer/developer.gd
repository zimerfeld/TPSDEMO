extends Node

signal quit
signal replace_main_scene(resource: PackedScene)

const MODELS_PATH: String = "res://scenes3D/models/models.tscn"
const CONTROLS_PATH: String = "res://scenes2D/controls/controls.tscn"

# Each row is a Disabled/Enabled pair behaving like a single toggle. Maps the row
# node name (found anywhere under UI) to the "game" config key it controls. Changes
# are saved and applied to the DebugOverlay immediately.
const _TOGGLES: Dictionary = {
	"FPSRow": "hud_fps",
	"SystemHealthRow": "system_health",
	"ShowGridRow": "show_grid",
	# Debug 2D column.
	"Debug2DRow": "debug_2d",
	"ShowTypeRow": "show_type",
	"ShowNameRow": "show_name",
	"ShowIDRow": "show_id",
	# Debug 3D column.
	"Debug3DRow": "debug_3d",
	"ShowType3DRow": "show_type_3d",
	"ShowName3DRow": "show_name_3d",
	"ShowID3DRow": "show_id_3d",
	"MembrosRow": "show_members",
	"ShowSkeleton3DRow": "show_skeleton3d",
	"ShowMesh3DRow": "show_mesh3d",
}

# Sub-rows that only take effect while their column's master toggle is on (their
# buttons are greyed out otherwise) — making the dependency between the column
# header (Debug 2D / Debug 3D) and its lines clear.
const _DEBUG2D_SUBROWS: Array[String] = [
	"ShowTypeRow", "ShowNameRow", "ShowIDRow",
]
const _DEBUG3D_SUBROWS: Array[String] = [
	"ShowType3DRow", "ShowName3DRow", "ShowID3DRow",
	"MembrosRow", "ShowSkeleton3DRow", "ShowMesh3DRow",
]

# The theme has no "disabled" Button stylebox and the buttons carry a green/yellow
# `modulate`, so a `disabled` button still looks active. We dim it to this greyed,
# semi-transparent tint while disabled and restore its saved base color when enabled,
# making the dependency on the column master visually clear. Each button's original
# modulate is stashed in this meta at startup.
const _DISABLED_MODULATE := Color(0.5, 0.5, 0.55, 0.5)
const _BASE_MODULATE_META := &"_base_modulate"


func _ready() -> void:
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
	# Remember each sub-toggle button's authored color so it can be restored after the
	# greyed-out (disabled) state.
	for row_name in _DEBUG2D_SUBROWS + _DEBUG3D_SUBROWS:
		for btn in _row(row_name).get_children():
			if btn is BaseButton:
				btn.set_meta(_BASE_MODULATE_META, btn.modulate)
	# Each column's sub-toggles only take effect while its master (Debug 2D / Debug 3D)
	# is on, so grey their buttons out when the master is disabled.
	_update_subrows_enabled()

	_update_language_buttons()


@onready var portuguese_button: Button = $UI/LangBar/PortugueseButton
@onready var english_button: Button = $UI/LangBar/EnglishButton


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


# Grey out a column's sub-toggle buttons unless its master toggle is enabled.
func _update_subrows_enabled() -> void:
	var on_2d: bool = Settings.config_file.get_value("game", "debug_2d", false)
	var on_3d: bool = Settings.config_file.get_value("game", "debug_3d", false)
	_set_subrows_disabled(_DEBUG2D_SUBROWS, not on_2d)
	_set_subrows_disabled(_DEBUG3D_SUBROWS, not on_3d)


func _set_subrows_disabled(rows: Array[String], is_disabled: bool) -> void:
	for row_name in rows:
		for child in _row(row_name).get_children():
			if child is BaseButton:
				var btn := child as BaseButton
				btn.disabled = is_disabled
				# Dim while disabled, restore the authored color when re-enabled, so the
				# enable/disable state is visible (the theme has no disabled style).
				btn.modulate = _DISABLED_MODULATE if is_disabled else btn.get_meta(_BASE_MODULATE_META, btn.modulate)


func _make_button_group(row: Node) -> void:
	var group := ButtonGroup.new()
	for btn in row.get_children():
		if btn is BaseButton:
			btn.button_group = group


func _on_toggle(button_pressed: bool, key: String) -> void:
	Settings.config_file.set_value("game", key, button_pressed)
	Settings.save_settings()
	DebugOverlay.refresh()
	# Show/hide the System Health monitor overlay immediately.
	if key == "system_health":
		SystemHealth.refresh()
	# Toggling a column master enables/disables its dependent sub-toggle buttons.
	if key == "debug_2d" or key == "debug_3d":
		_update_subrows_enabled()


func _on_models_pressed() -> void:
	emit_signal("replace_main_scene", load(MODELS_PATH))


func _on_controls_pressed() -> void:
	emit_signal("replace_main_scene", load(CONTROLS_PATH))


func _on_back_pressed() -> void:
	quit.emit()


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		quit.emit()

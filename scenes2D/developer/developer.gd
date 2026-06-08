extends Node

signal quit
signal replace_main_scene(resource: PackedScene)

const MODELS_PATH: String = "res://scenes3D/models/models.tscn"

# Each row is a Disabled/Enabled pair behaving like a single toggle. Maps the row
# node (under UI/Options) to the "game" config key it controls. Changes are saved
# and applied to the DebugOverlay immediately.
const _TOGGLES: Dictionary = {
	"FPSRow": "hud_fps",
	"ShowGridRow": "show_grid",
	"Debug2DRow": "debug_2d",
	"Debug3DRow": "debug_3d",
	"ShowTypeRow": "show_type",
	"ShowNameRow": "show_name",
	"ShowIDRow": "show_id",
}


func _ready() -> void:
	var options := $UI/Options
	for row_name in _TOGGLES:
		var row: HBoxContainer = options.get_node(row_name)
		var key: String = _TOGGLES[row_name]
		var enabled_btn: Button = row.get_node("Enabled")
		var disabled_btn: Button = row.get_node("Disabled")
		_make_button_group(row)
		# Sync from saved settings without triggering the handler.
		var on: bool = Settings.config_file.get_value("game", key, false)
		enabled_btn.set_pressed_no_signal(on)
		disabled_btn.set_pressed_no_signal(not on)
		enabled_btn.toggled.connect(_on_toggle.bind(key))


func _make_button_group(row: Node) -> void:
	var group := ButtonGroup.new()
	for btn in row.get_children():
		if btn is BaseButton:
			btn.button_group = group


func _on_toggle(button_pressed: bool, key: String) -> void:
	Settings.config_file.set_value("game", key, button_pressed)
	Settings.save_settings()
	DebugOverlay.refresh()


func _on_models_pressed() -> void:
	emit_signal("replace_main_scene", load(MODELS_PATH))


func _on_back_pressed() -> void:
	quit.emit()


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		quit.emit()

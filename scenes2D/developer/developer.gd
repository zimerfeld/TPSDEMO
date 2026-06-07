extends Node

signal quit
signal replace_main_scene(resource: PackedScene)

const MODELS_PATH: String = "res://scenes3D/models/models.tscn"


@onready var fps_disabled: Button = $UI/Options/FPSRow/Disabled
@onready var fps_enabled: Button = $UI/Options/FPSRow/Enabled
@onready var show_grid_disabled: Button = $UI/Options/ShowGridRow/Disabled
@onready var show_grid_enabled: Button = $UI/Options/ShowGridRow/Enabled


func _ready() -> void:
	# Each row is a Disabled/Enabled pair behaving like a single toggle, matching
	# the Settings screen style. Group them and sync from saved settings without
	# triggering the signal handlers. (Modo Debug / Show ID moved to Settings → Debug.)
	_make_button_group($UI/Options/FPSRow)
	_make_button_group($UI/Options/ShowGridRow)

	var fps_on: bool = Settings.config_file.get_value("game", "hud_fps", false)
	fps_enabled.set_pressed_no_signal(fps_on)
	fps_disabled.set_pressed_no_signal(not fps_on)

	var grid_on: bool = Settings.config_file.get_value("game", "show_grid", false)
	show_grid_enabled.set_pressed_no_signal(grid_on)
	show_grid_disabled.set_pressed_no_signal(not grid_on)


func _make_button_group(row: Node) -> void:
	var group := ButtonGroup.new()
	for btn in row.get_children():
		if btn is BaseButton:
			btn.button_group = group


func _on_fps_toggle_toggled(button_pressed: bool) -> void:
	Settings.config_file.set_value("game", "hud_fps", button_pressed)
	Settings.save_settings()
	DebugOverlay.refresh()


func _on_show_grid_toggle_toggled(button_pressed: bool) -> void:
	Settings.config_file.set_value("game", "show_grid", button_pressed)
	Settings.save_settings()
	DebugOverlay.refresh()


func _on_models_pressed() -> void:
	emit_signal("replace_main_scene", load(MODELS_PATH))


func _on_back_pressed() -> void:
	quit.emit()


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		quit.emit()

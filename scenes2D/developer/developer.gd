extends Node

signal quit


@onready var debug_toggle: CheckButton = $UI/Options/DebugRow/DebugToggle
@onready var show_id_toggle: CheckButton = $UI/Options/ShowIDRow/ShowIDToggle
@onready var fps_toggle: CheckButton = $UI/Options/FPSRow/FPSToggle
@onready var show_grid_toggle: CheckButton = $UI/Options/ShowGridRow/ShowGridToggle


func _ready() -> void:
	# Controls are defined and visible directly in the scene; just sync their state
	# from saved settings without triggering their signal handlers.
	debug_toggle.set_pressed_no_signal(Settings.config_file.get_value("game", "debug_mode", false))
	show_id_toggle.set_pressed_no_signal(Settings.config_file.get_value("game", "show_id", false))
	fps_toggle.set_pressed_no_signal(Settings.config_file.get_value("game", "hud_fps", false))
	show_grid_toggle.set_pressed_no_signal(Settings.config_file.get_value("game", "show_grid", false))


func _on_debug_toggle_toggled(button_pressed: bool) -> void:
	Settings.config_file.set_value("game", "debug_mode", button_pressed)
	Settings.save_settings()
	DebugOverlay.refresh()


func _on_show_id_toggle_toggled(button_pressed: bool) -> void:
	Settings.config_file.set_value("game", "show_id", button_pressed)
	Settings.save_settings()
	DebugOverlay.refresh()


func _on_fps_toggle_toggled(button_pressed: bool) -> void:
	Settings.config_file.set_value("game", "hud_fps", button_pressed)
	Settings.save_settings()
	DebugOverlay.refresh()


func _on_show_grid_toggle_toggled(button_pressed: bool) -> void:
	Settings.config_file.set_value("game", "show_grid", button_pressed)
	Settings.save_settings()
	DebugOverlay.refresh()


func _on_back_pressed() -> void:
	quit.emit()


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		quit.emit()

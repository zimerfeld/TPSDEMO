extends Node

signal quit


@onready var debug_toggle: CheckButton = $UI/Options/DebugRow/DebugToggle
@onready var fps_toggle: CheckButton = $UI/Options/FPSRow/FPSToggle


func _ready() -> void:
	debug_toggle.button_pressed = Settings.config_file.get_value("game", "debug_mode", false)
	fps_toggle.button_pressed = Settings.config_file.get_value("game", "hud_fps", false)


func _on_debug_toggle_toggled(button_pressed: bool) -> void:
	Settings.config_file.set_value("game", "debug_mode", button_pressed)
	Settings.save_settings()
	DebugOverlay.refresh()


func _on_fps_toggle_toggled(button_pressed: bool) -> void:
	Settings.config_file.set_value("game", "hud_fps", button_pressed)
	Settings.save_settings()
	DebugOverlay.refresh()


func _on_back_pressed() -> void:
	quit.emit()

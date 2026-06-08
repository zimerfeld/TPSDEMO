extends Node

signal quit
signal replace_main_scene(resource: PackedScene)


func _on_back_pressed() -> void:
	quit.emit()


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		quit.emit()

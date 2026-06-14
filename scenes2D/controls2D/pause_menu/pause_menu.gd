extends Control

## Pause overlay with a menu + collapsible settings sub-panel. Emits signals
## for the host scene to handle; optionally pauses the SceneTree itself.

signal resume_pressed
signal settings_pressed
signal quit_pressed

## When true, open()/close() also toggle get_tree().paused.
@export var pause_tree: bool = false
## Listen for the "pause" input action to toggle visibility (if it exists).
@export var bind_pause_action: bool = true

@onready var _menu: VBoxContainer = $Dimmer/PauseMenu
@onready var _settings: PanelContainer = $Dimmer/PauseMenu/SettingsPanel

func _ready() -> void:
	visible = false
	_menu.get_node("ResumeBtn").pressed.connect(close)
	_menu.get_node("SettingsBtn").pressed.connect(_on_settings)
	_menu.get_node("QuitBtn").pressed.connect(func() -> void: quit_pressed.emit())

func _unhandled_input(event: InputEvent) -> void:
	if bind_pause_action and InputMap.has_action("pause") \
			and event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()

func toggle() -> void:
	if visible:
		close()
	else:
		open()

func open() -> void:
	visible = true
	if pause_tree:
		get_tree().paused = true
	_menu.position = Vector2(0, -30)
	modulate = Color(1, 1, 1, 0)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "modulate", Color.WHITE, 0.3)
	t.tween_property(_menu, "position", Vector2.ZERO, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func close() -> void:
	visible = false
	if pause_tree:
		get_tree().paused = false
	resume_pressed.emit()

func _on_settings() -> void:
	_settings.visible = not _settings.visible
	settings_pressed.emit()

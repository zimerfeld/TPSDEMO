extends Node3D

signal quit

const RedRobot: PackedScene = preload("res://enemies/red_robot/red_robot.tscn")
const PlayerScene: PackedScene = preload("res://player/player.tscn")

@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var spawned_nodes: Node3D = $SpawnedNodes


func _ready() -> void:
	Settings.apply_graphics_settings(get_window(), world_environment.environment, self)

	var player: CharacterBody3D = PlayerScene.instantiate()
	player.name = "1"
	player.player_id = 1
	player.position = Vector3(0, 1, 0)
	spawned_nodes.add_child(player)

	var robot: CharacterBody3D = RedRobot.instantiate()
	robot.position = Vector3(10, 1, 0)
	spawned_nodes.add_child(robot)


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		quit.emit()

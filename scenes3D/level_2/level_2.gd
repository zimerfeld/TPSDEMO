extends Node3D

signal quit

const CriaturaAlada: PackedScene = preload("res://library3D/characters/criatura_alada/criatura_alada.tscn")

## Distância horizontal inicial (em metros) entre o player e a criatura alada.
const SPAWN_DISTANCE := 20.0

var _player_scene: PackedScene

@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var spawned_nodes: Node3D = $SpawnedNodes


func _ready() -> void:
	Settings.apply_graphics_settings(get_window(), world_environment.environment, self)
	_player_scene = load(PlayerSelection.scene_path)

	var player: CharacterBody3D = _player_scene.instantiate()
	player.name = "1"
	player.player_id = 1
	player.position = Vector3(0, 1, 0)
	spawned_nodes.add_child(player)

	var criatura: CharacterBody3D = CriaturaAlada.instantiate()
	criatura.position = Vector3(SPAWN_DISTANCE, 1, 0)
	spawned_nodes.add_child(criatura)


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		quit.emit()

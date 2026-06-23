extends Node3D

signal quit

const CriaturaAlada: PackedScene = preload("res://library3D/characters/criatura_alada/criatura_alada.tscn")

## Distância horizontal inicial (em metros) entre o player e a criatura alada.
const SPAWN_DISTANCE := 20.0

var _player_scene: PackedScene

@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var spawned_nodes: Node3D = $SpawnedNodes
@onready var player_spawn_points: Node3D = $PlayerSpawnpoints


func _ready() -> void:
	Settings.apply_graphics_settings(get_window(), world_environment.environment, self)
	_player_scene = load(PlayerSelection.scene_path)

	if multiplayer == null:
		CrashHandler.show_error(
			"MultiplayerAPI indisponível ao inicializar o nível.\n" +
			"Verifique a configuração de rede e tente novamente."
		)
		return

	# Offline (OfflineMultiplayerPeer) e host (ENet) entram aqui como servidor; o cliente
	# recebe criatura/players via MultiplayerSpawner. Mesmo padrão do level_base.
	if multiplayer.is_server():
		var criatura: CharacterBody3D = CriaturaAlada.instantiate()
		criatura.position = Vector3(SPAWN_DISTANCE, 1, 0)
		spawned_nodes.add_child(criatura, true)

		randomize()
		var spawn_points: Array = player_spawn_points.get_children()
		spawn_points.shuffle()
		add_player(1, spawn_points.pop_front())
		for id in multiplayer.get_peers():
			add_player(id, spawn_points.pop_front())

		multiplayer.peer_connected.connect(add_player)
		multiplayer.peer_disconnected.connect(del_player)


func del_player(id: int) -> void:
	if not spawned_nodes.has_node(str(id)):
		return
	spawned_nodes.get_node(str(id)).queue_free()


func add_player(id: int, spawn_point: Marker3D = null) -> void:
	if spawn_point == null:
		spawn_point = player_spawn_points.get_child(randi() % player_spawn_points.get_child_count())
	var player: CharacterBody3D = _player_scene.instantiate()
	player.name = str(id)
	player.player_id = id
	player.transform = spawn_point.transform
	# Posição de spawn replicada (spawn property): garante que o cliente conectado
	# nasça aqui em vez de (0,0,0) e caia do mapa (o sync do transform não chega a tempo).
	player.spawn_position = spawn_point.transform.origin
	spawned_nodes.add_child(player)


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		quit.emit()

extends Node3D

signal quit

const CriaturaAlada: PackedScene = preload("res://library3D/characters/criatura_alada/criatura_alada.tscn")

## Distância horizontal inicial (em metros) entre o player e a criatura alada.
const SPAWN_DISTANCE := 20.0

@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var spawned_nodes: Node3D = $SpawnedNodes
@onready var player_spawn_points: Node3D = $PlayerSpawnpoints


func _ready() -> void:
	Settings.apply_graphics_settings(get_window(), world_environment.environment, self)

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

	# Spawn de players (host + clientes, cada um com a variante escolhida) via NetSpawn.
	# spawn_host = false no modo "Hospedar Somente" → NetSpawn adiciona a câmera livre (sem player).
	NetSpawn.setup(spawned_nodes, player_spawn_points, not PlayerSelection.spectator_host)


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		quit.emit()

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
		# Modo-sala (multi-level): a sala NASCE VAZIA — nada pré-spawnado na criação, NEM o template
		# (o RoomManager o aplica depois, pelo caminho per-peer protegido, quando há gente na sala).
		# Assim nenhum nó é replicado ao client ANTES de o espelho da sala existir — causa raiz da
		# tela cinza (envenenamento do scene-cache). Single-level (offline / "Hospedar Somente", via
		# NetSpawn): template ativo ou, na falta dele, a criatura padrão do jogo original — como sempre.
		# Ver [[salas-nascem-limpas]].
		if not has_meta("room_id"):
			if not LevelTemplateManager.apply_active_template(scene_file_path, spawned_nodes, player_spawn_points):
				var criatura: CharacterBody3D = CriaturaAlada.instantiate()
				criatura.position = Vector3(SPAWN_DISTANCE, 1, 0)
				spawned_nodes.add_child(criatura, true)
		randomize()

	# Modo-sala (servidor multi-level) usa spawn POR-SALA (RoomManager); senão, NetSpawn single-level.
	if has_meta("room_id"):
		RoomManager.register_room_level(int(get_meta("room_id")), spawned_nodes, player_spawn_points)
	else:
		# spawn_host = false no modo "Hospedar Somente" → NetSpawn adiciona a câmera livre (sem player).
		NetSpawn.setup(spawned_nodes, player_spawn_points, not PlayerSelection.spectator_host)


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		quit.emit()

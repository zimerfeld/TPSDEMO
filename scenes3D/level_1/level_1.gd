extends Node3D

signal quit

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
	# recebe inimigo/players via MultiplayerSpawner. Mesmo padrão do level_base.
	if multiplayer.is_server():
		# Sem template ativo: sala "LIMPA" — só os players que entram + o solo (geometria estática da
		# cena). NÃO spawna inimigo padrão na criação da sala: nós pré-spawnados ANTES de qualquer
		# client entrar vazavam para o client sem o espelho pronto ("spawner null") e desalinhavam o
		# scene cache da replicação por-sala. Quem quiser inimigos/estruturas usa um template.
		LevelTemplateManager.apply_active_template(scene_file_path, spawned_nodes, player_spawn_points)
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

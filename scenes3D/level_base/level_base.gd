extends Node3D


signal quit

const RedRobot: PackedScene = preload("res://library3D/characters/red_robot/red_robot.tscn")

var lightmap_gi: LightmapGI = null

@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var robot_spawn_points: Node3D = $RobotSpawnpoints
@onready var player_spawn_points: Node3D = $PlayerSpawnpoints
@onready var spawned_nodes: Node3D = $SpawnedNodes


func _ready() -> void:
	Settings.apply_graphics_settings(get_window(), world_environment.environment, self)

	if Settings.config_file.get_value("rendering", "gi_type") == Settings.GIType.SDFGI:
		setup_sdfgi()
	elif Settings.config_file.get_value("rendering", "gi_type") == Settings.GIType.VOXEL_GI:
		setup_voxelgi()
	else:
		setup_lightmapgi()

	if multiplayer == null:
		CrashHandler.show_error(
			"MultiplayerAPI indisponível ao inicializar o nível.\n" +
			"Verifique a configuração de rede e tente novamente."
		)
		return

	if multiplayer.is_server():
		# Server will spawn the red robots
		for child in robot_spawn_points.get_children():
			spawn_robot(child)
		randomize()

	# Modo-sala (servidor multi-level) usa spawn POR-SALA (RoomManager); senão, NetSpawn single-level.
	if has_meta("room_id"):
		RoomManager.register_room_level(int(get_meta("room_id")), spawned_nodes, player_spawn_points)
	else:
		# spawn_host = false no modo "Hospedar Somente" → NetSpawn adiciona a câmera livre.
		NetSpawn.setup(spawned_nodes, player_spawn_points, not PlayerSelection.spectator_host)


func setup_sdfgi() -> void:
	world_environment.environment.sdfgi_enabled = true
	$VoxelGI.hide()
	$ReflectionProbes.hide()
	# LightmapGI nodes override SDFGI (even when hidden)
	# so we need to free the LightmapGI node if it exists
	if lightmap_gi != null:
		lightmap_gi.queue_free()

	if Settings.config_file.get_value("rendering", "gi_quality") == Settings.GIQuality.HIGH:
		RenderingServer.environment_set_sdfgi_ray_count(RenderingServer.ENV_SDFGI_RAY_COUNT_96)
	elif Settings.config_file.get_value("rendering", "gi_quality") == Settings.GIQuality.LOW:
		RenderingServer.environment_set_sdfgi_ray_count(RenderingServer.ENV_SDFGI_RAY_COUNT_32)
	else:
		world_environment.environment.sdfgi_enabled = false


func setup_voxelgi() -> void:
	world_environment.environment.sdfgi_enabled = false
	$VoxelGI.show()
	$ReflectionProbes.hide()
	# LightmapGI nodes override VoxelGI (even when hidden)
	# so we need to free the LightmapGI node if it exists
	if lightmap_gi != null:
		lightmap_gi.queue_free()

	if Settings.config_file.get_value("rendering", "gi_quality") == Settings.GIQuality.HIGH:
		RenderingServer.voxel_gi_set_quality(RenderingServer.VOXEL_GI_QUALITY_HIGH)
	elif Settings.config_file.get_value("rendering", "gi_quality") == Settings.GIQuality.LOW:
		RenderingServer.voxel_gi_set_quality(RenderingServer.VOXEL_GI_QUALITY_LOW)
	else:
		$VoxelGI.hide()


func setup_lightmapgi() -> void:
	world_environment.environment.sdfgi_enabled = false
	$VoxelGI.hide()
	$ReflectionProbes.show()
	# If no LightmapGI node, create one
	if lightmap_gi == null:
		var new_gi := LightmapGI.new()
		new_gi.light_data = load("res://scenes3D/level_base/level_base.lmbake")
		new_gi.name = "LightmapGI"
		lightmap_gi = new_gi
		add_child(new_gi)

	if Settings.config_file.get_value("rendering", "gi_quality") == Settings.GIQuality.DISABLED:
		lightmap_gi.hide()
		$ReflectionProbes.hide()


func spawn_robot(spawn_point) -> void:
	var robot: CharacterBody3D = RedRobot.instantiate()
	robot.transform = spawn_point.transform
	robot.exploded.connect(_respawn_robot.bind(spawn_point))
	spawned_nodes.add_child(robot, true)


func _respawn_robot(spawn_point) -> void:
	await get_tree().create_timer(15.0).timeout
	spawn_robot(spawn_point)


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		quit.emit()

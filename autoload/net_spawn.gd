extends Node

## Spawn de players em multiplayer, centralizado para todos os níveis (level_base/1/2).
##
## Vive como autoload → o caminho /root/NetSpawn é idêntico em todos os peers, o que torna o
## RPC `register_loadout` confiável (a rota do RPC casa em servidor e cliente). Cada nível
## chama `setup(...)` no `_ready`; este controller cuida de:
##   - spawnar o HOST (peer 1) com a variante que o host escolheu;
##   - para cada cliente que entra, ESPERAR ele informar a variante escolhida ("loadout") via
##     RPC e só então spawnar o modelo certo (assim a variante/cor do cliente aparece em TODOS
##     os peers — o MultiplayerSpawner replica a cena que o servidor instanciou);
##   - remover o player quando o peer sai.
##
## O inimigo de cada fase continua sendo spawnado pelo próprio nível.

# Se o cliente não informar a variante em até este tempo, spawna com a variante padrão.
const LOADOUT_TIMEOUT: float = 5.0
const DEFAULT_VARIANT: int = 0

var _spawned_nodes: Node3D = null
var _spawn_points_parent: Node3D = null
var _spawn_queue: Array = []
# peer_id -> Marker3D do spawn reservado, aguardando o register_loadout daquele cliente.
var _pending: Dictionary = {}


# Chamado pelo nível no _ready. `spawn_host` = false no modo "Hospedar Somente" (sem player do host).
func setup(spawned_nodes: Node3D, spawn_points_parent: Node3D, spawn_host: bool = true) -> void:
	if multiplayer.is_server():
		_begin_server(spawned_nodes, spawn_points_parent, spawn_host)
	else:
		_announce_loadout()


func _begin_server(spawned_nodes: Node3D, spawn_points_parent: Node3D, spawn_host: bool) -> void:
	_spawned_nodes = spawned_nodes
	_spawn_points_parent = spawn_points_parent
	_pending.clear()
	_spawn_queue = spawn_points_parent.get_children()
	_spawn_queue.shuffle()

	if spawn_host:
		_spawn(1, _take_point(), PlayerSelection.variant_id)

	# Peers já conectados quando o nível carregou (caso raro): esperam o loadout deles também.
	for id in multiplayer.get_peers():
		_await_loadout(id)

	# Conexões persistem no autoload entre níveis → guarda contra reconexão dupla.
	if not multiplayer.peer_connected.is_connected(_await_loadout):
		multiplayer.peer_connected.connect(_await_loadout)
	if not multiplayer.peer_disconnected.is_connected(_remove):
		multiplayer.peer_disconnected.connect(_remove)


# Cliente: informa ao servidor a variante escolhida. Se a conexão ainda não foi estabelecida,
# espera o sinal connected_to_server (one-shot) para então enviar.
func _announce_loadout() -> void:
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	if peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		register_loadout.rpc_id(1, PlayerSelection.variant_id)
	elif not multiplayer.connected_to_server.is_connected(_send_loadout):
		multiplayer.connected_to_server.connect(_send_loadout, CONNECT_ONE_SHOT)


func _send_loadout() -> void:
	register_loadout.rpc_id(1, PlayerSelection.variant_id)


# Cliente → servidor: "eu escolhi a variante X". O servidor spawna o player desse peer.
@rpc("any_peer", "reliable")
func register_loadout(variant_id: int) -> void:
	if not multiplayer.is_server():
		return
	var id: int = multiplayer.get_remote_sender_id()
	if not _pending.has(id):
		return  # já spawnou (ou peer desconhecido) — ignora
	var spawn_point: Marker3D = _pending[id]
	_pending.erase(id)
	_spawn(id, spawn_point, variant_id)


# Servidor: reserva um spawn point para o peer e aguarda o loadout (com fallback por timeout).
func _await_loadout(id: int) -> void:
	if not multiplayer.is_server():
		return
	_pending[id] = _take_point()
	var timer: SceneTreeTimer = get_tree().create_timer(LOADOUT_TIMEOUT)
	timer.timeout.connect(_loadout_timeout.bind(id))


func _loadout_timeout(id: int) -> void:
	if not _pending.has(id):
		return  # já respondeu a tempo
	# Peer ainda conectado mas sem loadout → usa a variante padrão para não ficar sem corpo.
	var spawn_point: Marker3D = _pending[id]
	_pending.erase(id)
	if id in multiplayer.get_peers():
		_spawn(id, spawn_point, DEFAULT_VARIANT)


func _spawn(id: int, spawn_point: Marker3D, variant_id: int) -> void:
	if not is_instance_valid(_spawned_nodes):
		return
	if _spawned_nodes.has_node(str(id)):
		return  # já existe (evita duplicar)
	var scene: PackedScene = load(PlayerSelection.variant_scene_path(variant_id))
	if scene == null:
		return
	var player: CharacterBody3D = scene.instantiate()
	player.name = str(id)
	player.player_id = id
	if spawn_point != null:
		player.transform = spawn_point.transform
		# Posição de spawn replicada (spawn property): o cliente nasce aqui em vez de (0,0,0).
		player.spawn_position = spawn_point.transform.origin
	_spawned_nodes.add_child(player)


func _remove(id: int) -> void:
	_pending.erase(id)
	if is_instance_valid(_spawned_nodes) and _spawned_nodes.has_node(str(id)):
		_spawned_nodes.get_node(str(id)).queue_free()


# Próximo spawn point (da fila embaralhada); se esgotar, pega um aleatório do pai.
func _take_point() -> Marker3D:
	if not _spawn_queue.is_empty():
		return _spawn_queue.pop_front()
	if is_instance_valid(_spawn_points_parent) and _spawn_points_parent.get_child_count() > 0:
		return _spawn_points_parent.get_child(randi() % _spawn_points_parent.get_child_count())
	return null

extends Node
## Salas simultâneas (servidor multi-level). Cada "sala" é um nível rodando num SubViewport com
## World3D PRÓPRIO → física, navegação e WorldEnvironment ISOLADOS. Vive neste autoload
## (persistente, caminho /root/RoomManager igual em todos os peers → RPC confiável): iniciar/parar/
## reiniciar salas NUNCA fecha o peer. Só a sala OBSERVADA renderiza (UPDATE_ALWAYS); as demais só
## simulam (otimização de GPU). A SIMULAÇÃO de inimigos roda em todas as salas (no servidor).
##
## FASE 1: criação/observação no host. FASE 2 (este arquivo): spawn de players POR-SALA + join de
## cliente numa sala específica + isolamento de tráfego por-peer (visibilidade). Fica ISOLADO do
## fluxo single-level (NetSpawn), que continua intacto.
##
## Caminho determinístico das salas (server e cliente batem → MultiplayerSpawner replica):
##   /root/RoomManager/Room<id>/Level/SpawnedNodes/...
## (o nó do nível é renomeado para "Level" nos dois lados para o caminho casar).

signal rooms_changed
# Servidor → cliente: a sala em que o cliente jogava foi encerrada (Parar). A ClientSession
# escuta isto para voltar ao navegador com o alerta "O Servidor foi desligado".
signal room_closed(room_id: int)

const ROOM_RESOLUTION := Vector2i(1280, 720)
# Câmera livre p/ o host OBSERVAR cada sala (não replicada — filha do nível, fora do SpawnedNodes).
const SpectatorCamera: PackedScene = preload("res://scenes3D/spectator_camera/spectator_camera.tscn")
const DEFAULT_VARIANT: int = 0

# Cada sala: { id, level_path, viewport, level, spawned_nodes, spawn_points, spawn_queue, pending }
var _rooms: Array[Dictionary] = []
var _next_id: int = 1
# Servidor: peer_id -> room_id (em qual sala cada cliente entrou).
var _peer_room: Dictionary = {}
# Cliente: caminho do nível por sala recebido do servidor (para espelhar a sala escolhida).
var _server_rooms: Array = []   # [{id, level_path}]

# Definido pela playonline antes de abrir o host_session: true = esta instância é CLIENTE
# (navega/junta-se a salas do servidor); false/omitido = SERVIDOR (cria/gerencia salas).
var client_mode: bool = false

# Fluxo "Jogar" (invertido: a sala é escolhida ANTES do ChoosePlayer). A sessão (Host/Client)
# seta estes marcadores, navega para o ChoosePlayer e os CONSOME ao voltar (no _ready), entrando
# em modo de jogo na sala correspondente. pending_play_return = caminho da cena de sessão.
var pending_play_room: int = -1
var pending_play_level: String = ""
var pending_play_return: String = ""
# Servidor: sala em que o player do host (peer 1) está jogando (-1 = nenhuma).
var _host_player_room: int = -1


func _ready() -> void:
	# Limpeza ao perder a conexão (cliente) ou cair o servidor.
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)


# ───────────────────────────── SERVIDOR: ciclo de vida das salas ─────────────────────────────

func start_room(level_path: String) -> int:
	var scene: PackedScene = load(level_path) as PackedScene
	if scene == null:
		push_error("RoomManager: nível inexistente: " + level_path)
		return -1
	var id: int = _next_id
	_next_id += 1
	_instantiate_room(id, level_path, true)  # servidor: SubViewport com World3D próprio (isolado)
	_broadcast_room_list()
	rooms_changed.emit()
	return id


# Cria o container + nível da sala. `as_subviewport` = SERVIDOR (SubViewport com World3D próprio,
# para várias salas isoladas + observação). Cliente (uma sala) usa um Node comum → o nível renderiza
# na JANELA PRINCIPAL (input e câmera normais, sem encanamento de SubViewport). O caminho na árvore
# é o mesmo nos dois (/root/RoomManager/Room<id>/Level) → o MultiplayerSpawner replica igual.
func _instantiate_room(id: int, level_path: String, as_subviewport: bool) -> void:
	var prev_spectator: bool = PlayerSelection.spectator_host
	PlayerSelection.spectator_host = true  # sala = sem player do host; inimigos via servidor

	var container: Node
	if as_subviewport:
		var vp := SubViewport.new()
		vp.own_world_3d = true
		vp.size = ROOM_RESOLUTION
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED  # só a observada renderiza
		container = vp
	else:
		container = Node.new()  # cliente: nível renderiza na janela principal
	container.name = "Room%d" % id
	add_child(container)

	var level: Node = (load(level_path) as PackedScene).instantiate()
	level.name = "Level"                 # nome fixo → caminho casa entre server e cliente
	level.set_meta("room_id", id)        # o nível lê isto no _ready e registra por-sala
	container.add_child(level)

	PlayerSelection.spectator_host = prev_spectator

	_rooms.append({
		"id": id, "level_path": level_path, "viewport": container, "level": level,
		"spawned_nodes": null, "spawn_points": null, "spawn_queue": [], "pending": {},
	})


func stop_room(id: int) -> void:
	for i in _rooms.size():
		if int(_rooms[i]["id"]) == id:
			# Avisa ANTES de liberar: cada cliente que jogava NESTA sala volta ao navegador
			# (peer 1 = o próprio servidor; pula p/ não disparar o handler de cliente nele).
			for peer_id in _peer_room.keys():
				if int(_peer_room[peer_id]) == id and int(peer_id) != 1:
					notify_room_closed.rpc_id(int(peer_id), id)
			# Host jogando nesta sala? despawna o player do host e religa a câmera livre.
			if _host_player_room == id:
				host_leave_room()
			var vp: SubViewport = _rooms[i]["viewport"]
			if is_instance_valid(vp):
				vp.queue_free()
			_rooms.remove_at(i)
			# Tira os peers que estavam nesta sala (terão que reentrar).
			for peer_id in _peer_room.keys():
				if int(_peer_room[peer_id]) == id:
					_peer_room.erase(peer_id)
			_broadcast_room_list()
			rooms_changed.emit()
			return


func restart_room(id: int) -> int:
	var path: String = ""
	for r in _rooms:
		if int(r["id"]) == id:
			path = String(r["level_path"])
			break
	if path == "":
		return -1
	stop_room(id)
	return start_room(path)


func stop_all() -> void:
	for r in _rooms:
		if is_instance_valid(r["viewport"]):
			(r["viewport"] as SubViewport).queue_free()
	_rooms.clear()
	_peer_room.clear()
	rooms_changed.emit()


# Chamado pelo nível no _ready (quando tem meta "room_id"). No SERVIDOR guarda os pontos de spawn
# e passa a observar os filhos do SpawnedNodes p/ aplicar a visibilidade por-sala (inimigos/balas).
func register_room_level(room_id: int, spawned_nodes: Node3D, spawn_points: Node3D) -> void:
	var room := get_room(room_id)
	if room.is_empty():
		return
	room["spawned_nodes"] = spawned_nodes
	if not multiplayer.is_server():
		return  # cliente: só precisa do caminho casando (já tem); sem lógica de spawn
	room["spawn_points"] = spawn_points
	room["spawn_queue"] = spawn_points.get_children().duplicate()
	room["spawn_queue"].shuffle()
	room["pending"] = {}
	# Câmera livre p/ o host observar esta sala (só no servidor; não é replicada).
	var level: Node = room.get("level")
	if is_instance_valid(level):
		var cam: Camera3D = SpectatorCamera.instantiate()
		level.add_child(cam)
		if is_instance_valid(spawn_points) and spawn_points.get_child_count() > 0:
			cam.global_position = (spawn_points.get_child(0) as Node3D).global_position + Vector3(0.0, 8.0, 0.0)
		room["spectator_cam"] = cam  # guardada p/ desligar enquanto o host JOGA nesta sala
	# Visibilidade por-sala em tudo que já está e no que entrar (inimigos, balas, players).
	for c in spawned_nodes.get_children():
		_apply_room_visibility(c, room_id)
	if not spawned_nodes.child_entered_tree.is_connected(_on_room_child_entered):
		spawned_nodes.child_entered_tree.connect(_on_room_child_entered.bind(room_id))


func _on_room_child_entered(node: Node, room_id: int) -> void:
	_apply_room_visibility(node, room_id)


# Interest management: o nó (e seus sub-nós) só é replicado para peers QUE ESTÃO NESTA SALA.
# (Best-effort: mesmo que a engine ainda envie o spawn, o cliente só espelha a SUA sala — os
# caminhos das outras salas não existem nele, então o tráfego cruzado é descartado.)
func _apply_room_visibility(node: Node, room_id: int) -> void:
	for sync in _synchronizers_in(node):
		if sync.has_meta("room_filtered"):
			continue
		sync.set_meta("room_filtered", true)
		sync.public_visibility = false
		sync.add_visibility_filter(func(peer: int) -> bool:
			return int(_peer_room.get(peer, -1)) == room_id)
		sync.update_visibility()


func _synchronizers_in(node: Node) -> Array:
	var out: Array = []
	if node is MultiplayerSynchronizer:
		out.append(node)
	for c in node.get_children():
		out.append_array(_synchronizers_in(c))
	return out


# Reavalia a visibilidade de TODOS os synchronizers da sala (ex.: ao entrar/sair um peer) → a
# engine (re)envia os spawns já existentes aos peers que agora enxergam a sala.
func _refresh_room_visibility(room_id: int) -> void:
	var room := get_room(room_id)
	var spawned: Node3D = room.get("spawned_nodes")
	if not is_instance_valid(spawned):
		return
	for c in spawned.get_children():
		for sync in _synchronizers_in(c):
			sync.update_visibility()


# ───────────────────────────── RPC: lista de salas (servidor ↔ cliente) ─────────────────────────

@rpc("any_peer", "reliable")
func request_room_list() -> void:
	if not multiplayer.is_server():
		return
	receive_room_list.rpc_id(multiplayer.get_remote_sender_id(), _room_list_payload())


func _broadcast_room_list() -> void:
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server():
		receive_room_list.rpc(_room_list_payload())


func _room_list_payload() -> Array:
	var out: Array = []
	for r in _rooms:
		out.append({
			"id": int(r["id"]),
			"level_path": String(r["level_path"]),
			"players": _players_in_room(int(r["id"])),
		})
	return out


@rpc("authority", "reliable")
func receive_room_list(list: Array) -> void:
	_server_rooms = list
	rooms_changed.emit()


func _players_in_room(room_id: int) -> int:
	var n: int = 0
	for peer_id in _peer_room:
		if int(_peer_room[peer_id]) == room_id:
			n += 1
	return n


func server_room_list() -> Array:
	return _server_rooms


# ───────────────────────────── CLIENTE: entrar numa sala ─────────────────────────

# Chamado pelo cliente ao escolher uma sala: espelha a sala localmente (caminho casando) e pede
# ao servidor para spawnar o player nela.
func client_join_room(room_id: int, level_path: String, variant_id: int) -> void:
	if get_room(room_id).is_empty():
		_instantiate_room(room_id, level_path, false)  # espelho local (Node comum, janela principal)
		rooms_changed.emit()
	join_room.rpc_id(1, room_id, variant_id)


@rpc("any_peer", "reliable")
func join_room(room_id: int, variant_id: int) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if get_room(room_id).is_empty():
		return
	_peer_room[sender] = room_id
	# Reavalia a visibilidade: o que JÁ existe na sala (inimigos) passa a replicar p/ este peer.
	_refresh_room_visibility(room_id)
	_reserve_and_spawn(sender, room_id, variant_id)
	_broadcast_room_list()


# Reserva um spawn point na sala e spawna o player do peer (a variante/cor replica a todos os
# peers DA SALA via MultiplayerSpawner + visibilidade).
func _reserve_and_spawn(peer_id: int, room_id: int, variant_id: int) -> void:
	var room := get_room(room_id)
	var spawned: Node3D = room.get("spawned_nodes")
	if spawned == null or not is_instance_valid(spawned):
		return
	if spawned.has_node(str(peer_id)):
		return
	var marker: Node3D = _take_point(room)
	var scene: PackedScene = load(PlayerSelection.variant_scene_path(variant_id)) as PackedScene
	if scene == null:
		return
	var player: CharacterBody3D = scene.instantiate()
	player.name = str(peer_id)
	player.player_id = peer_id
	if marker != null:
		player.transform = marker.transform
		player.spawn_position = marker.transform.origin
	spawned.add_child(player)  # child_entered_tree → aplica visibilidade da sala


func _take_point(room: Dictionary) -> Node3D:
	var queue: Array = room.get("spawn_queue", [])
	if not queue.is_empty():
		return queue.pop_front()
	var sp: Node3D = room.get("spawn_points")
	if is_instance_valid(sp) and sp.get_child_count() > 0:
		return sp.get_child(randi() % sp.get_child_count())
	return null


func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if not _peer_room.has(peer_id):
		return
	var room_id: int = int(_peer_room[peer_id])
	_peer_room.erase(peer_id)
	var room := get_room(room_id)
	var spawned: Node3D = room.get("spawned_nodes")
	if is_instance_valid(spawned) and spawned.has_node(str(peer_id)):
		spawned.get_node(str(peer_id)).queue_free()
	_broadcast_room_list()


# ───────────────────────────── HOST: jogar dentro de uma sala ─────────────────────────────

# O host (peer 1) entra como PLAYER controlado numa das suas salas (SubViewport). Diferente de
# observar: spawna um player de verdade e DESLIGA a câmera livre da sala — senão as duas leriam o
# Input global (WASD/ESPAÇO) ao mesmo tempo. A câmera do player vira current no SubViewport via
# apply_authority(). Só um player do host por vez (peer 1 é único): troca de sala despawna o anterior.
func host_spawn_in_room(room_id: int, variant_id: int) -> void:
	host_leave_room()  # garante um único player do host (despawna o de uma sala anterior)
	var room := get_room(room_id)
	if room.is_empty():
		return
	var spawned: Node3D = room.get("spawned_nodes")
	if not is_instance_valid(spawned):
		return
	# Desliga a câmera livre desta sala enquanto o host joga (evita disputa de Input/câmera).
	var cam: Camera3D = room.get("spectator_cam")
	if is_instance_valid(cam):
		cam.set_process(false)
		cam.set_process_input(false)
	if spawned.has_node("1"):
		return
	var marker: Node3D = _take_point(room)
	var scene: PackedScene = load(PlayerSelection.variant_scene_path(variant_id)) as PackedScene
	if scene == null:
		return
	var player: CharacterBody3D = scene.instantiate()
	player.name = "1"
	player.player_id = 1
	if marker != null:
		player.transform = marker.transform
		player.spawn_position = marker.transform.origin
	_peer_room[1] = room_id
	spawned.add_child(player)  # child_entered_tree → aplica a visibilidade da sala
	_host_player_room = room_id


# Host sai da sala em que jogava: despawna seu player e religa a câmera livre (deixando a sala em
# UPDATE_DISABLED — quem decide renderizar é a sessão). Idempotente.
func host_leave_room() -> void:
	if _host_player_room < 0:
		return
	var room := get_room(_host_player_room)
	var spawned: Node3D = room.get("spawned_nodes")
	if is_instance_valid(spawned) and spawned.has_node("1"):
		spawned.get_node("1").queue_free()
	var cam: Camera3D = room.get("spectator_cam")
	if is_instance_valid(cam):
		cam.set_process(true)
		cam.set_process_input(true)
		cam.make_current()
	_peer_room.erase(1)
	_host_player_room = -1


# ───────────────────────────── CLIENTE: sair de uma sala (sem fechar o peer) ────────────────────

# Cliente sai da sala em que jogava e volta ao navegador: pede ao servidor para despawnar seu
# player e remove o espelho local. NÃO fecha o peer (segue conectado p/ entrar noutra sala).
func client_leave_room(room_id: int) -> void:
	leave_room.rpc_id(1, room_id)
	_drop_local_mirror(room_id)
	rooms_changed.emit()


@rpc("any_peer", "reliable")
func leave_room(room_id: int) -> void:
	if not multiplayer.is_server():
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if not _peer_room.has(sender):
		return
	_peer_room.erase(sender)
	var room := get_room(room_id)
	var spawned: Node3D = room.get("spawned_nodes")
	if is_instance_valid(spawned) and spawned.has_node(str(sender)):
		spawned.get_node(str(sender)).queue_free()
	_broadcast_room_list()


# Servidor → cliente que jogava numa sala parada: limpa o espelho local e emite room_closed
# (a ClientSession reage voltando ao navegador com o alerta "O Servidor foi desligado").
@rpc("authority", "reliable")
func notify_room_closed(room_id: int) -> void:
	_drop_local_mirror(room_id)
	room_closed.emit(room_id)


# Remove o espelho local (Node "Room<id>" sob este autoload) e a entrada em _rooms. Usado quando
# o cliente sai da sala ou ela é encerrada pelo servidor.
func _drop_local_mirror(room_id: int) -> void:
	var container := get_node_or_null("Room%d" % room_id)
	if is_instance_valid(container):
		container.queue_free()
	for i in _rooms.size():
		if int(_rooms[i]["id"]) == room_id:
			_rooms.remove_at(i)
			return


# ───────────────────────────── consultas / util ─────────────────────────

func get_room(id: int) -> Dictionary:
	for r in _rooms:
		if int(r["id"]) == id:
			return r
	return {}


func get_rooms() -> Array[Dictionary]:
	return _rooms


func has_room(id: int) -> bool:
	return not get_room(id).is_empty()


func level_label(level_path: String) -> String:
	return level_path.get_file().get_basename()

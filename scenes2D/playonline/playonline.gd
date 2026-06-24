extends Node

signal replace_main_scene
signal quit

const LEVEL_BASE_PATH: String = "res://scenes3D/level_base/level_base.tscn"
# Quantos valores recentes (porta/IP) guardar para seleção.
const HISTORY_MAX: int = 3
# Tempo máx. de espera pela resposta de cenário do servidor (probe) antes de conectar direto.
const PROBE_TIMEOUT: float = 3.0

var loading_path: String = ""
var peer: MultiplayerPeer = OfflineMultiplayerPeer.new()
# Diálogo de confirmação de reconexão (evita empilhar vários ao clicar Connect repetidas vezes).
var _reconnect_dialog: ConfirmationDialog = null
# Conexão de sondagem ("probe"): conecta brevemente só para descobrir qual cenário o servidor
# hospeda. É descartada antes do join real, preservando a ordem de carga do nível.
var _probe_peer: ENetMultiplayerPeer = null
var _probing: bool = false

@onready var port: SpinBox = %Port
@onready var address: LineEdit = %Address
@onready var host_button: Button = $UI/Margin/Main/FormCenter/VBox/ButtonsRow/HostButton
@onready var port_history: OptionButton = %PortHistory
@onready var address_history: OptionButton = %AddressHistory
@onready var loading: HBoxContainer = $UI/Loading
@onready var loading_progress: ProgressBar = $UI/Loading/Progress
@onready var loading_done_timer: Timer = $UI/Loading/DoneTimer
@onready var portuguese_button: Button = $UI/LangBar/PortugueseButton
@onready var english_button: Button = $UI/LangBar/EnglishButton


func _ready() -> void:
	_update_language_buttons()
	_refresh_history()
	# Salva a porta ao sair do campo (o SpinBox edita por um LineEdit interno).
	port.get_line_edit().focus_exited.connect(_on_port_focus_exited)
	# Dedicated server: auto-host when running headless.
	if DisplayServer.get_name() == "headless":
		_on_host_pressed.call_deferred()
		return
	# Foco inicial para a navegação por setas do teclado (não em headless, sem UI).
	host_button.grab_focus.call_deferred()


# Histórico de porta/IP persistido em Settings.config_file (seção "online"). Mostra os
# últimos HISTORY_MAX valores num OptionButton (item 0 = "Selecione...", convenção do projeto).
func _refresh_history() -> void:
	_fill_history(port_history, "ports")
	_fill_history(address_history, "addresses")


func _fill_history(option: OptionButton, key: String) -> void:
	option.clear()
	option.add_item("Selecione...")
	for value in Settings.config_file.get_value("online", key, []):
		option.add_item(str(value))
	option.selected = 0


# Insere `value` no topo do histórico (sem duplicar), mantém só os HISTORY_MAX mais recentes.
func _remember(key: String, value) -> void:
	var arr: Array = (Settings.config_file.get_value("online", key, []) as Array).duplicate()
	arr.erase(value)
	arr.push_front(value)
	while arr.size() > HISTORY_MAX:
		arr.pop_back()
	Settings.config_file.set_value("online", key, arr)
	Settings.save_settings()


func _on_port_history_item_selected(index: int) -> void:
	if index <= 0:  # item 0 = "Selecione..."
		return
	port.value = float(port_history.get_item_text(index))
	port_history.selected = 0


func _on_address_history_item_selected(index: int) -> void:
	if index <= 0:
		return
	address.text = address_history.get_item_text(index)
	address_history.selected = 0


# Salva o que foi digitado no campo (IP OU domínio) ao pressionar Enter e atualiza o
# dropdown na hora — assim um domínio digitado fica no histórico mesmo sem clicar Connect.
func _on_address_text_submitted(new_text: String) -> void:
	if new_text.strip_edges() == "":
		return
	_remember("addresses", new_text.strip_edges())
	_refresh_history()


# Salva automaticamente ao o campo perder o foco (sem precisar de Enter).
func _on_address_focus_exited() -> void:
	if address.text.strip_edges() == "":
		return
	_remember("addresses", address.text.strip_edges())
	_refresh_history()


func _on_port_focus_exited() -> void:
	_remember("ports", int(port.value))
	_refresh_history()


# Nível escolhido na tela de levels (fluxo online). Fallback p/ level_base — ex.: servidor
# dedicado headless, que entra direto na playonline sem passar pela tela de levels.
func _selected_level() -> String:
	if PlayerSelection.level_path != "":
		return PlayerSelection.level_path
	return LEVEL_BASE_PATH


# Grey out the button for the language already active (same pattern as the menu).
func _update_language_buttons() -> void:
	var lang := Locale.get_language()
	portuguese_button.disabled = lang == "pt"
	english_button.disabled = lang == "en"


func _on_portuguese_pressed() -> void:
	Locale.set_language("pt")
	_update_language_buttons()


func _on_english_pressed() -> void:
	Locale.set_language("en")
	_update_language_buttons()


func _process(_delta: float) -> void:
	if loading.visible and loading_path != "":
		var progress: Array = []
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(loading_path, progress)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			loading_progress.value = progress[0] * 100.0
		elif status == ResourceLoader.THREAD_LOAD_LOADED:
			loading_progress.value = 100.0
			set_process(false)
			loading_done_timer.start()
		else:
			print("Error while loading level: " + str(status))
			loading.hide()


func _on_loading_done_timer_timeout() -> void:
	multiplayer.multiplayer_peer = peer
	emit_signal("replace_main_scene", ResourceLoader.load_threaded_get(loading_path))


# "Hospedar e Conectar": hospeda o servidor E entra no jogo como player controlado
# (comportamento clássico do antigo botão "Host").
func _on_host_pressed() -> void:
	PlayerSelection.spectator_host = false
	_start_host()


# "Hospedar Somente": hospeda o servidor mas NÃO entra como player. O host observa o
# level em tempo real com uma câmera livre (sem colisão, sem player controlado).
func _on_host_only_pressed() -> void:
	PlayerSelection.spectator_host = true
	_start_host()


const HOST_SESSION_PATH: String = "res://scenes2D/host_session/host_session.tscn"


# "Gerenciar Salas": hospeda um servidor PERSISTENTE e abre o painel de salas (host_session),
# onde dá pra iniciar/parar/reiniciar e observar VÁRIOS levels ao mesmo tempo. O peer fica aberto
# até voltar ao menu (sair de uma sala NÃO encerra o servidor). Ver host_session.gd / RoomManager.
func _on_manage_rooms_pressed() -> void:
	PlayerSelection.spectator_host = true  # host observa as salas; não vira player
	_remember("ports", int(port.value))
	peer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(int(port.value))
	if err != OK:
		CrashHandler.show_error(
			"Falha ao criar servidor na porta %d.\nErro: %s\n\nVerifique se a porta está em uso." % [int(port.value), error_string(err)],
			_on_manage_rooms_pressed
		)
		return
	if peer.host == null:
		CrashHandler.show_error("Servidor criado, mas host ENet é nulo.\nTente outra porta.", _on_manage_rooms_pressed)
		return
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	# Servidor já ativo: o host_session é a tela persistente (o peer NÃO é fechado ao navegar nele).
	multiplayer.multiplayer_peer = peer
	RoomManager.client_mode = false
	emit_signal("replace_main_scene", ResourceLoader.load(HOST_SESSION_PATH))


# "Entrar em Salas": conecta como CLIENTE a um servidor de salas e abre o NAVEGADOR de salas
# (host_session em modo cliente), onde escolhe em qual sala/level entrar. Diferente de "Conectar"
# (single-level). Abre o host_session só após o connected_to_server (o peer precisa estar conectado
# para pedir a lista de salas via RPC).
func _on_join_rooms_pressed() -> void:
	if _probing:
		return
	PlayerSelection.spectator_host = false
	_remember("ports", int(port.value))
	if address.text.strip_edges() != "":
		_remember("addresses", address.text.strip_edges())
	peer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address.text, int(port.value))
	if err != OK:
		CrashHandler.show_error(
			"Falha ao conectar em %s:%d.\nErro: %s\n\nVerifique o endereço e a porta." % [address.text, int(port.value), error_string(err)],
			_on_join_rooms_pressed
		)
		return
	if peer.host == null:
		CrashHandler.show_error("Conexão iniciada, mas host ENet é nulo.\nTente novamente.", _on_join_rooms_pressed)
		return
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = peer
	RoomManager.client_mode = true
	loading.show()
	multiplayer.connected_to_server.connect(_open_rooms_client, CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(_on_rooms_connect_failed, CONNECT_ONE_SHOT)


func _open_rooms_client() -> void:
	emit_signal("replace_main_scene", ResourceLoader.load(HOST_SESSION_PATH))


func _on_rooms_connect_failed() -> void:
	loading.hide()
	if multiplayer.connected_to_server.is_connected(_open_rooms_client):
		multiplayer.connected_to_server.disconnect(_open_rooms_client)
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	CrashHandler.show_error(
		"Falha ao conectar em %s:%d.\n\nVerifique o endereço e a porta." % [address.text, int(port.value)],
		_on_join_rooms_pressed
	)


# Cria o servidor ENet e dispara o carregamento do nível (comum aos dois modos de host).
# O modo (player controlado x câmera livre) já foi definido em PlayerSelection.spectator_host.
func _start_host() -> void:
	_remember("ports", int(port.value))
	peer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_server(int(port.value))
	if err != OK:
		CrashHandler.show_error(
			"Falha ao criar servidor na porta %d.\nErro: %s\n\nVerifique se a porta está em uso." % [int(port.value), error_string(err)],
			_start_host
		)
		return
	if peer.host == null:
		CrashHandler.show_error(
			"Servidor criado, mas host ENet é nulo.\nTente outra porta ou reinicie o jogo.",
			_start_host
		)
		return
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	loading_path = _selected_level()
	loading.show()
	ResourceLoader.load_threaded_request(loading_path, "", true)


# Ao clicar Connect, primeiro fazemos uma sondagem ("probe"): conecta brevemente ao servidor
# só para PERGUNTAR qual cenário ele está hospedando. A confirmação "reconectar à partida em
# andamento" só aparece quando o cenário do host for o MESMO que o cliente escolheu — caso
# contrário conecta direto. O probe é descartado antes do join real (que recarrega o nível na
# ordem correta, sem perder os spawns já existentes).
func _on_connect_pressed() -> void:
	if _probing or is_instance_valid(_reconnect_dialog):
		return
	_remember("ports", int(port.value))
	if address.text.strip_edges() != "":
		_remember("addresses", address.text.strip_edges())

	_probe_peer = ENetMultiplayerPeer.new()
	var err: Error = _probe_peer.create_client(address.text, int(port.value))
	if err != OK:
		_probe_peer = null
		CrashHandler.show_error(
			"Falha ao conectar em %s:%d.\nErro: %s\n\nVerifique o endereço e a porta." % [address.text, int(port.value), error_string(err)],
			_on_connect_pressed
		)
		return
	if _probe_peer.host != null:
		_probe_peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = _probe_peer
	_probing = true
	loading.show()
	loading_progress.value = 0.0
	multiplayer.connected_to_server.connect(_on_probe_connected, CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(_on_probe_failed, CONNECT_ONE_SHOT)
	NetSpawn.scenario_received.connect(_on_scenario_received, CONNECT_ONE_SHOT)
	get_tree().create_timer(PROBE_TIMEOUT).timeout.connect(_on_probe_timeout)


# Probe conectou → pergunta o cenário ao servidor (peer 1).
func _on_probe_connected() -> void:
	if not _probing:
		return
	NetSpawn.request_scenario.rpc_id(1)


# Resposta do servidor: se for o MESMO cenário, confirma reconexão; senão, conecta direto.
func _on_scenario_received(scenario_path: String) -> void:
	if not _probing:
		return
	_end_probe()
	if scenario_path == _selected_level():
		_confirm_reconnect()
	else:
		_do_connect()


# Não conseguiu nem conectar → mostra erro (mesmo destino que o join real teria).
func _on_probe_failed() -> void:
	if not _probing:
		return
	_end_probe()
	loading.hide()
	CrashHandler.show_error(
		"Falha ao conectar em %s:%d.\n\nVerifique o endereço e a porta." % [address.text, int(port.value)],
		_on_connect_pressed
	)


# Servidor não respondeu o cenário a tempo (ex.: versão antiga sem o RPC) → conecta direto.
func _on_probe_timeout() -> void:
	if not _probing:
		return
	_end_probe()
	_do_connect()


# Encerra o probe: desliga sinais, fecha o socket de sondagem e volta ao peer offline.
func _end_probe() -> void:
	_probing = false
	if multiplayer.connected_to_server.is_connected(_on_probe_connected):
		multiplayer.connected_to_server.disconnect(_on_probe_connected)
	if multiplayer.connection_failed.is_connected(_on_probe_failed):
		multiplayer.connection_failed.disconnect(_on_probe_failed)
	if NetSpawn.scenario_received.is_connected(_on_scenario_received):
		NetSpawn.scenario_received.disconnect(_on_scenario_received)
	if _probe_peer != null:
		_probe_peer.close()
		_probe_peer = null
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


# Diálogo de confirmação de reconexão (só no caso de MESMO cenário em andamento).
func _confirm_reconnect() -> void:
	if is_instance_valid(_reconnect_dialog):
		return
	loading.hide()
	var dlg := ConfirmationDialog.new()
	dlg.title = Locale.tr_key("Reconectar")
	dlg.dialog_text = Locale.tr_key("Deseja se re-conectar na partida em andamento ?")
	dlg.get_ok_button().text = Locale.tr_key("Sim")
	dlg.get_cancel_button().text = Locale.tr_key("Não")
	dlg.confirmed.connect(func() -> void:
		dlg.queue_free()
		_reconnect_dialog = null
		_do_connect()
	)
	dlg.canceled.connect(func() -> void:
		dlg.queue_free()
		_reconnect_dialog = null
	)
	_reconnect_dialog = dlg
	add_child(dlg)
	dlg.popup_centered()


func _do_connect() -> void:
	# Cliente nunca é spectator: garante o flag limpo ao conectar.
	PlayerSelection.spectator_host = false
	_remember("ports", int(port.value))
	if address.text.strip_edges() != "":
		_remember("addresses", address.text.strip_edges())
	peer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(address.text, int(port.value))
	if err != OK:
		CrashHandler.show_error(
			"Falha ao conectar em %s:%d.\nErro: %s\n\nVerifique o endereço e a porta." % [address.text, int(port.value), error_string(err)],
			_do_connect
		)
		return
	if peer.host == null:
		CrashHandler.show_error(
			"Conexão iniciada, mas host ENet é nulo.\nTente novamente.",
			_do_connect
		)
		return
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	loading_path = _selected_level()
	loading.show()
	ResourceLoader.load_threaded_request(loading_path, "", true)


func _on_back_pressed() -> void:
	quit.emit()


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		# ESC encerra primeiro o preenchimento do IP/porta (devolvendo o foco ao botão
		# Host); só o 2º ESC sai da tela. Cobre a regra do projeto p/ campos editáveis.
		if UINav.cancel_active_edit(get_viewport(), host_button):
			get_viewport().set_input_as_handled()
			return
		quit.emit()
		get_viewport().set_input_as_handled()

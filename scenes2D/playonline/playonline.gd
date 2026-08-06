extends Node

signal replace_main_scene
signal quit

const DEFAULT_ROOM_LEVEL: String = "res://scenes3D/level_1/level_1.tscn"
const HOST_SESSION_PATH: String = "res://scenes2D/host_session/host_session.tscn"
const CLIENT_SESSION_PATH: String = "res://scenes2D/client_session/client_session.tscn"
# Após CONECTAR, quanto tempo (s) esperar o host enviar a sua versão (handshake). Se o host for uma
# build antiga que nem responde ao handshake, a tentativa é abortada com aviso (não fica pendurada
# no loading). Generoso p/ cobrir relays lentos (playit): o RPC é confiável e chega logo ao conectar.
const VERSION_TIMEOUT_SEC: float = 5.0
# Mensagens do handshake de versão (chaves canônicas PT nos dicionários playonline.{pt,en,es}.json,
# traduzidas por Locale.tr_key). Em MSG_VERSION_INCOMPAT, {host}/{client} são preenchidos com os IDs
# de build via String.format.
const MSG_VERSION_INCOMPAT := "Versões incompatíveis.\n\nHost: {host}\nVocê: {client}\n\nAtualizem os dois para a mesma versão do jogo."
const MSG_VERSION_TIMEOUT := "Não foi possível verificar a versão do host.\n\nO host pode estar numa versão antiga. Atualizem os dois para a mesma versão do jogo."
# Rótulo de status (ConnectStatus) e aviso da resolução de DNS. O ENet resolve hostname sozinho, mas
# de forma BLOQUEANTE (trava o frame até o DNS responder); resolvemos antes na fila assíncrona do IP.
const MSG_RESOLVING := "Resolvendo endereço..."
const MSG_CONNECTING := "Conectando..."
const MSG_EMPTY_ADDRESS := "Informe o endereço do host (domínio ou IP) para entrar em salas."
const MSG_RESOLVE_FAILED :="Não foi possível resolver o endereço \"{host}\".\n\nVerifique o nome do domínio e a sua conexão com a internet."
# Quantos valores recentes (porta/IP) guardar para seleção.
const HISTORY_MAX: int = 3
# Domínios completos (FQDN) ficam num histórico PRÓPRIO e persistente (não rolam junto com os IPs
# recentes), para o jogador reusá-los pelo dropdown depois. Cap só p/ a lista não crescer sem fim.
const DOMAIN_MAX: int = 12

var loading_path: String = ""
var peer: MultiplayerPeer = OfflineMultiplayerPeer.new()
# OptionButtons de otimização (com meta "_item_keys") — re-traduzidos no language_changed, já que
# o auto-localizer do Locale pula OptionButton (seus itens são geridos em código).
var _opt_buttons: Array[OptionButton] = []
# True enquanto uma tentativa de "Entrar em Salas" está pendente (conectando). Bloqueia re-clique e
# torna o cancelamento idempotente: o 1º de {conectou, falhou, timeout} "vence" e zera o pending.
var _join_pending: bool = false
# Item da fila de resolução de DNS em andamento (-1 = nenhum) e o hostname que ele resolve. A
# resolução roda na thread do resolver do Godot; o _process só consulta o status (não bloqueia).
var _resolve_id: int = -1
var _resolve_host: String = ""

@onready var player_name_field: LineEdit = %PlayerName
@onready var port: SpinBox = %Port
@onready var address: LineEdit = %Address
@onready var port_history: OptionButton = %PortHistories
@onready var address_history: OptionButton = %AddressHistories
# OptionButtons de otimização — agora ESTÁTICOS na cena (rótulos/colunas/tab_order vêm do .tscn); o
# código só popula itens/seleção e conecta os handlers. Ver _build_optimization_options.
@onready var host_render_picker: OptionButton = %HostRenderModes
@onready var sync_rate_picker: OptionButton = %SyncRates
@onready var interp_picker: OptionButton = %Interpolations
@onready var manage_rooms_button: Button = $UI/Inset/Main/Form/Fields/ButtonsRow/ManageRooms
@onready var join_rooms_button: Button = $UI/Inset/Main/Form/Fields/ButtonsRow/JoinRooms
@onready var connect_status: Label = %ConnectStatus
@onready var loading: HBoxContainer = $UI/Loading
@onready var loading_progress: ProgressBar = $UI/Loading/Progress
@onready var loading_done_timer: Timer = $UI/Loading/DoneTimer
@onready var portuguese_button: Button = $UI/Actions/LangBar/Portuguese
@onready var english_button: Button = $UI/Actions/LangBar/English
@onready var spanish_button: Button = $UI/Actions/LangBar/Spanish


func _ready() -> void:
	_update_language_buttons()
	# Carrega o nome do jogador salvo (persistido ao sair do campo) → campo + PlayerSelection.
	_prefill_player_name()
	# Preenche os campos Porta/IP com o último valor ANTES de montar os dropdowns, para que cada
	# dropdown já nasça com esse valor SELECIONADO (não mais preso em "Selecione...").
	_prefill_last_used()
	_refresh_history()
	_build_optimization_options()
	# Salva a porta ao sair do campo (o SpinBox edita por um LineEdit interno).
	port.get_line_edit().focus_exited.connect(_on_port_focus_exited)
	# Persiste o valor ATUAL a cada mudança (não só no commit/foco) → o último nunca se perde,
	# mesmo fechando o jogo logo após digitar. Grava em chaves dedicadas (não polui o histórico).
	port.value_changed.connect(_on_port_changed)
	address.text_changed.connect(_on_address_changed)
	# Dedicated server: auto-host (servidor de salas) when running headless.
	if DisplayServer.get_name() == "headless":
		_on_manage_rooms_pressed.call_deferred()
		return
	# Sequência de Tab na ordem de leitura: Nome (1) → Porta (2) → Histórico de porta (3) → IP (4) →
	# Histórico de IP (5) → 3 OptionButtons de otimização (6-8) → Gerenciar/Entrar (9-10) → Voltar (11)
	# → Português (12) → English (13) → Español (14) → Debug 2D (15). Re-liga quando o DebugOverlay injeta
	# o toggle "Debug 2D" na barra Actions (ele entra DEPOIS do _ready), p/ o toggle fechar a sequência.
	UINav.focus_tab_one.call_deferred(self)
	_wire_tab_order.call_deferred()
	($UI/Actions as HBoxContainer).child_entered_tree.connect(
		func(_n: Node) -> void: _wire_tab_order.call_deferred())


# (Re)liga o anel de Tab da tela na ordem de leitura. Idempotente — pode ser chamado quantas vezes
# o conjunto de focáveis mudar (toggle injetado, botão de idioma habilitando/desabilitando).
func _wire_tab_order() -> void:
	UINav.wire_tab_ring(self)


# Carrega o nome salvo no campo e no PlayerSelection (que o RoomManager/NetSpawn leem ao spawnar).
func _prefill_player_name() -> void:
	var saved := String(Settings.config_file.get_value("online", "player_name", ""))
	player_name_field.text = saved
	PlayerSelection.player_name = saved


# Salvo ao sair do campo (foco perdido) ou ao pressionar Enter. Persiste em Settings e atualiza o
# PlayerSelection — o nome vira o Label3D acima da cabeça do jogador ao entrar num level.
func _on_player_name_focus_exited() -> void:
	_save_player_name()


func _on_player_name_submitted(_new_text: String) -> void:
	_save_player_name()


func _save_player_name() -> void:
	var pname := player_name_field.text.strip_edges()
	PlayerSelection.player_name = pname
	Settings.config_file.set_value("online", "player_name", pname)
	Settings.save_settings()


# Histórico de porta/IP persistido em Settings.config_file (seção "online"). Mostra os
# últimos HISTORY_MAX valores num OptionButton (item 0 = "Selecione...", convenção do projeto).
func _refresh_history() -> void:
	_fill_history(port_history, "ports", str(int(port.value)))
	_fill_address_history()


func _fill_history(option: OptionButton, key: String, current: String) -> void:
	option.clear()
	option.add_item("Selecione...")
	for value in Settings.config_file.get_value("online", key, []):
		option.add_item(str(value))
	# Deixa SELECIONADO o item igual ao valor atual do campo → o dropdown auto-preenche com o valor
	# armazenado. Se o valor não estiver no histórico, cai em "Selecione..." (índice 0).
	_select_in_history(option, current)


# O dropdown de IP/Domínio mostra os ENDEREÇOS recentes (IP ou domínio, rolando em HISTORY_MAX) E
# TAMBÉM os DOMÍNIOS COMPLETOS salvos (lista própria e persistente), deduplicados → um domínio
# digitado uma vez fica disponível para seleção depois, mesmo que os IPs recentes rolem por cima.
func _fill_address_history() -> void:
	address_history.clear()
	address_history.add_item("Selecione...")
	var seen := {}
	for value in Settings.config_file.get_value("online", "addresses", []):
		var s := str(value)
		if s != "" and not seen.has(s):
			seen[s] = true
			address_history.add_item(s)
	for value in Settings.config_file.get_value("online", "domains", []):
		var s := str(value)
		if s != "" and not seen.has(s):
			seen[s] = true
			address_history.add_item(s)
	_select_in_history(address_history, address.text.strip_edges())


# Seleciona no dropdown o item cujo texto bate com `current` (o valor atual do campo); senão,
# "Selecione..." (0). Setar `.selected` por código NÃO dispara `item_selected` → sem recursão com
# os handlers de seleção / _on_*_changed.
func _select_in_history(option: OptionButton, current: String) -> void:
	for i in range(option.item_count):
		if option.get_item_text(i) == current:
			option.selected = i
			return
	option.selected = 0


# Pré-preenche Porta e IP/Domínio com o ÚLTIMO valor válido usado (histórico guarda o mais recente
# em [0], via _remember/push_front). Sem histórico, mantém os defaults do .tscn (4383 / 127.0.0.1).
# Assim o jogador não precisa redigitar a cada vez — basta confirmar o último que funcionou.
func _prefill_last_used() -> void:
	# Preferimos o "último valor" dedicado (gravado em qualquer mudança, mesmo sem commit); se não
	# houver, caímos no topo do histórico (último commit); senão, o default do .tscn.
	var last_port: int = int(Settings.config_file.get_value("online", "last_port", 0))
	var ports: Array = Settings.config_file.get_value("online", "ports", [])
	if last_port > 0:
		port.value = float(last_port)
	elif not ports.is_empty():
		port.value = float(ports[0])
	var last_addr: String = String(Settings.config_file.get_value("online", "last_address", ""))
	var addrs: Array = Settings.config_file.get_value("online", "addresses", [])
	if last_addr != "":
		address.text = last_addr
	elif not addrs.is_empty():
		address.text = String(addrs[0])


# Insere `value` no topo do histórico `key` (sem duplicar), mantém só os `max_items` mais recentes.
func _remember(key: String, value, max_items: int = HISTORY_MAX) -> void:
	var arr: Array = (Settings.config_file.get_value("online", key, []) as Array).duplicate()
	arr.erase(value)
	arr.push_front(value)
	while arr.size() > max_items:
		arr.pop_back()
	Settings.config_file.set_value("online", key, arr)
	Settings.save_settings()


# Salva um endereço no histórico recente e, se for um DOMÍNIO COMPLETO (tem letra e ponto, ao
# contrário de um IP), também na lista persistente de domínios → fica disponível no dropdown depois.
func _remember_address(value: String) -> void:
	_remember("addresses", value)
	if _is_full_domain(value):
		_remember("domains", value, DOMAIN_MAX)


# Heurística: tem ponto E alguma letra → nome de domínio (IPs são só dígitos/pontos/dois-pontos).
func _is_full_domain(value: String) -> bool:
	var t := value.strip_edges()
	if t == "" or not t.contains("."):
		return false
	for c in t:
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z"):
			return true
	return false


func _on_port_history_item_selected(index: int) -> void:
	if index <= 0:  # "Selecione..." → limpa o campo de porta (mesma regra do endereço).
		_clear_port()
		return
	# Copia o valor para o campo e MANTÉM o item selecionado no dropdown. A mudança persiste sozinha
	# via _on_port_changed (o value_changed do SpinBox dispara mesmo setando por código).
	port.value = float(port_history.get_item_text(index))


func _on_address_history_item_selected(index: int) -> void:
	# "Selecione..." (0) → limpa o campo; qualquer outro item → copia o endereço escolhido p/ o campo.
	# Em AMBOS os casos persiste o valor: setar address.text por código NÃO dispara text_changed (ao
	# contrário do port, cujo value_changed dispara sozinho), então replicamos a persistência em
	# _set_address — sem isso a escolha do dropdown não "ficava" e não recarregava na próxima vez.
	if index <= 0:
		_set_address("")
	else:
		_set_address(address_history.get_item_text(index))


# Aplica um endereço ao campo E persiste (last_address) + reflete a seleção no dropdown — o
# equivalente ao que o port ganha de graça pelo value_changed. Texto vazio limpa o campo e deixa o
# dropdown em "Selecione...". É o ÚNICO caminho (além de digitar e do _prefill no load) que altera o
# campo de endereço, atendendo à regra "o endereço só muda se for digitado ou a seleção mudar".
func _set_address(text: String) -> void:
	address.text = text
	Settings.config_file.set_value("online", "last_address", text)
	Settings.save_settings()
	_select_in_history(address_history, text)


# "Selecione..." na porta: limpa o texto visível (o SpinBox não fica vazio de verdade, mas zeramos o
# que aparece) e a persistência (last_port = 0 = "sem último valor"), deixando o dropdown em
# "Selecione..." — espelha o clear do endereço.
func _clear_port() -> void:
	port.get_line_edit().text = ""
	Settings.config_file.set_value("online", "last_port", 0)
	Settings.save_settings()
	port_history.selected = 0


# Salva o que foi digitado no campo (IP OU domínio) ao pressionar Enter e atualiza o
# dropdown na hora — assim um domínio digitado fica no histórico mesmo sem clicar Connect.
func _on_address_text_submitted(new_text: String) -> void:
	if new_text.strip_edges() == "":
		return
	_remember_address(new_text.strip_edges())
	_refresh_history()


# Salva automaticamente ao o campo perder o foco (sem precisar de Enter).
func _on_address_focus_exited() -> void:
	if address.text.strip_edges() == "":
		return
	_remember_address(address.text.strip_edges())
	_refresh_history()


func _on_port_focus_exited() -> void:
	_remember("ports", int(port.value))
	_refresh_history()


# Grava o valor ATUAL em chave dedicada a cada mudança (sem mexer no histórico/dropdown). É a tela
# de configuração (sem jogo rodando), então o custo de salvar é irrelevante para o FPS.
func _on_port_changed(_value: float) -> void:
	Settings.config_file.set_value("online", "last_port", int(port.value))
	Settings.save_settings()
	# Mantém o dropdown refletindo o valor atual digitado (seleciona o item igual, ou "Selecione...").
	_select_in_history(port_history, str(int(port.value)))


func _on_address_changed(new_text: String) -> void:
	var stripped := new_text.strip_edges()
	Settings.config_file.set_value("online", "last_address", stripped)
	Settings.save_settings()
	_select_in_history(address_history, stripped)


# Grey out the button for the language already active (same pattern as the menu).
func _update_language_buttons() -> void:
	var lang := Locale.get_language()
	portuguese_button.disabled = lang == "pt"
	english_button.disabled = lang == "en"
	spanish_button.disabled = lang == "es"
	# O botão do idioma ativo fica desabilitado (fora do Tab) — re-liga o anel p/ a sequência fechar
	# sem ele. call_deferred: o estado disabled já assentou quando o anel é remontado.
	if is_node_ready():
		_wire_tab_order.call_deferred()


func _on_portuguese_pressed() -> void:
	Locale.set_language("pt")
	_update_language_buttons()


func _on_english_pressed() -> void:
	Locale.set_language("en")
	_update_language_buttons()


func _on_spanish_pressed() -> void:
	Locale.set_language("es")
	_update_language_buttons()


func _process(_delta: float) -> void:
	if _resolve_id != -1:
		_poll_resolve()
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


# "Gerenciar Salas" (Host): hospeda um servidor PERSISTENTE e abre o painel de salas (host_session),
# onde dá pra iniciar/parar/reiniciar, observar e JOGAR em vários levels ao mesmo tempo. O peer fica
# aberto até "Voltar" (sair de uma sala NÃO encerra o servidor). Ver host_session.gd / RoomManager.
func _on_manage_rooms_pressed() -> void:
	if _join_pending:
		return  # não hospeda enquanto uma checagem de "Entrar em Salas" está em andamento
	PlayerSelection.spectator_host = true  # host observa as salas; vira player só pelo "Jogar"
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
	# Servidor dedicado (headless): já inicia uma sala com o Level 1 por padrão.
	if DisplayServer.get_name() == "headless":
		RoomManager.start_room(DEFAULT_ROOM_LEVEL)
	emit_signal("replace_main_scene", ResourceLoader.load(HOST_SESSION_PATH))


# "Entrar em Salas" (Client): conecta como CLIENTE a um servidor de salas e abre o NAVEGADOR de salas
# (ClientSession), onde escolhe em qual sala entrar. Abre a ClientSession só após o connected_to_server
# E o handshake de versão OK (host e cliente na mesma build) — versões diferentes recusam com aviso
# claro (ver _on_version_rejected), evitando o "erro mudo" de tentar jogar entre builds divergentes.
func _on_join_rooms_pressed() -> void:
	if _join_pending or _resolve_id != -1:
		return  # já há uma checagem/conexão (ou resolução de DNS) em andamento
	PlayerSelection.spectator_host = false
	_remember("ports", int(port.value))
	var host := address.text.strip_edges()
	if host == "":
		# Sem endereço não há o que resolver nem conectar — avisa em vez de deixar o ENet falhar mudo.
		CrashHandler.show_error(Locale.tr_key(MSG_EMPTY_ADDRESS), _on_join_rooms_pressed)
		return
	_remember_address(host)
	# IP literal (ex.: 147.185.221.29) → conecta direto, não há o que resolver.
	if host.is_valid_ip_address():
		_start_client(host, host)
		return
	# Hostname (ex.: zimaro.playit.game) → resolve ANTES, na fila assíncrona do IP. Passar o nome
	# direto ao create_client também funciona, mas o ENet resolve de forma bloqueante: numa rede
	# lenta (ou DNS ruim) o frame trava até a resposta, dando a impressão de que o jogo congelou.
	_resolve_host = host
	_resolve_id = IP.resolve_hostname_queue_item(host, IP.TYPE_ANY)
	_set_status(MSG_RESOLVING)
	set_process(true)


# Cria o peer de cliente e arma o handshake. `ip` é sempre um endereço numérico (já resolvido);
# `shown` é o que o jogador digitou (domínio ou IP), usado nas mensagens de erro para ele reconhecer.
func _start_client(ip: String, shown: String) -> void:
	_set_status(MSG_CONNECTING)
	peer = ENetMultiplayerPeer.new()
	var err: Error = peer.create_client(ip, int(port.value))
	if err != OK:
		_clear_status()
		CrashHandler.show_error(
			"Falha ao conectar em %s:%d.\nErro: %s\n\nVerifique o endereço e a porta." % [shown, int(port.value), error_string(err)],
			_on_join_rooms_pressed
		)
		return
	if peer.host == null:
		_clear_status()
		CrashHandler.show_error("Conexão iniciada, mas host ENet é nulo.\nTente novamente.", _on_join_rooms_pressed)
		return
	peer.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = peer
	RoomManager.client_mode = true
	loading.show()
	# Reconexão idempotente: uma tentativa anterior (que falhou e voltou pelo retry do CrashHandler,
	# ou que conectou e deixou sinais ONE_SHOT pendentes) pode ter deixado sinais presos nesta mesma
	# tela. Sem limpar, o connect() repetido estoura "Signal already connected".
	_disconnect_join_signals()
	# Fluxo: connected_to_server → aguarda o host enviar a sua versão (handshake); o RoomManager
	# compara e emite version_verified (abre as salas) ou version_rejected (aviso "incompatíveis").
	multiplayer.connected_to_server.connect(_on_client_connected_await_version, CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(_on_rooms_connect_failed, CONNECT_ONE_SHOT)
	RoomManager.version_verified.connect(_on_version_verified, CONNECT_ONE_SHOT)
	RoomManager.version_rejected.connect(_on_version_rejected, CONNECT_ONE_SHOT)
	# Pendente: bloqueia re-clique e torna o cancelamento idempotente — o 1º de {versão OK, versão
	# recusada, falha de conexão, timeout do handshake} "vence" e zera o pending.
	_join_pending = true


# Consulta (sem bloquear) o item da fila de DNS. Enquanto WAITING não faz nada; ao terminar, libera o
# item e ou conecta com o IP resolvido, ou avisa que o nome não resolveu (domínio errado / sem net).
func _poll_resolve() -> void:
	var status: int = IP.get_resolve_item_status(_resolve_id)
	if status == IP.RESOLVER_STATUS_WAITING:
		return
	var ip: String = ""
	if status == IP.RESOLVER_STATUS_DONE:
		ip = _pick_address(IP.get_resolve_item_addresses(_resolve_id))
	IP.erase_resolve_item(_resolve_id)
	_resolve_id = -1
	var host := _resolve_host
	_resolve_host = ""
	if ip == "":
		_clear_status()
		CrashHandler.show_error(
			Locale.tr_key(MSG_RESOLVE_FAILED).format({"host": host}),
			_on_join_rooms_pressed
		)
		return
	_start_client(ip, host)


# Escolhe QUAL endereço usar entre os resolvidos, preferindo IPv4. O playit publica AAAA além de A
# (zimaro.playit.game → 2602:fbaf:...:1d E 147.185.221.29) e o resolver costuma devolver o IPv6
# primeiro; conectar por ele deixaria de fora quem não tem rota IPv6 (a maioria das operadoras
# domésticas). Só cai no IPv6 se o nome não tiver IPv4 nenhum.
func _pick_address(addresses: Array) -> String:
	var fallback: String = ""
	for a in addresses:
		var s := String(a)
		if s == "":
			continue
		if not s.contains(":"):   # sem dois-pontos = IPv4
			return s
		if fallback == "":
			fallback = s
	return fallback


# Rótulo de status (ConnectStatus): fica no grupo "loc_manual", então o auto-localizador do Locale
# não disputa o texto com o script — traduzimos aqui na hora de exibir.
func _set_status(msg: String) -> void:
	connect_status.text = Locale.tr_key(msg)


func _clear_status() -> void:
	connect_status.text = ""


# Sair da tela com uma resolução pendente: libera o item da fila (o resolver do Godot guarda os
# itens até serem apagados) para não vazar entre entradas na tela.
func _exit_tree() -> void:
	if _resolve_id != -1:
		IP.erase_resolve_item(_resolve_id)
		_resolve_id = -1


# Conectou ao servidor (o ENet fechou o handshake de rede). Agora AGUARDA o host enviar a sua versão
# (RoomManager._on_peer_connected → receive_host_version). Arma um timeout: se o host for uma build
# antiga que nem responde ao handshake de versão, abortamos com aviso em vez de travar no loading.
func _on_client_connected_await_version() -> void:
	if not _join_pending:
		return
	get_tree().create_timer(VERSION_TIMEOUT_SEC).timeout.connect(_on_version_timeout, CONNECT_ONE_SHOT)


# Versão do host == a nossa → segue o fluxo normal: abre o navegador de salas (ClientSession).
func _on_version_verified() -> void:
	if not _join_pending:
		return
	_join_pending = false
	_disconnect_join_signals()
	emit_signal("replace_main_scene", ResourceLoader.load(CLIENT_SESSION_PATH))


# Versão do host != a nossa → recusa com aviso claro (fim do "erro mudo" entre builds diferentes).
func _on_version_rejected(host_version: String, client_version: String) -> void:
	if not _join_pending:
		return
	_join_pending = false
	var msg := Locale.tr_key(MSG_VERSION_INCOMPAT).format({"host": host_version, "client": client_version})
	_abort_join(msg)


# O host conectou mas não respondeu ao handshake de versão a tempo (provável build antiga, sem o
# handshake) → aborta com aviso em vez de ficar pendurado no loading.
func _on_version_timeout() -> void:
	if not _join_pending:
		return
	_join_pending = false
	_abort_join(Locale.tr_key(MSG_VERSION_TIMEOUT))


func _on_rooms_connect_failed() -> void:
	if not _join_pending:
		return
	_join_pending = false
	_abort_join("Falha ao conectar em %s:%d.\n\nVerifique o endereço e a porta." % [address.text, int(port.value)])


# Encerra uma tentativa de join pendente: esconde o loading, desliga os sinais do handshake (os que
# ainda não dispararam), fecha o peer (volta a Offline) e mostra o aviso com opção de tentar de novo.
func _abort_join(msg: String) -> void:
	_clear_status()
	loading.hide()
	_disconnect_join_signals()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	CrashHandler.show_error(msg, _on_join_rooms_pressed)


# Desliga TODOS os sinais de uma tentativa de join (conexão + handshake de versão). Idempotente —
# chamado no (re)início da tentativa, ao concluir e ao abortar, para nenhum sinal ficar preso.
func _disconnect_join_signals() -> void:
	if multiplayer.connected_to_server.is_connected(_on_client_connected_await_version):
		multiplayer.connected_to_server.disconnect(_on_client_connected_await_version)
	if multiplayer.connection_failed.is_connected(_on_rooms_connect_failed):
		multiplayer.connection_failed.disconnect(_on_rooms_connect_failed)
	if RoomManager.version_verified.is_connected(_on_version_verified):
		RoomManager.version_verified.disconnect(_on_version_verified)
	if RoomManager.version_rejected.is_connected(_on_version_rejected):
		RoomManager.version_rejected.disconnect(_on_version_rejected)


# ───────────────────────────── Otimização (escolhida ANTES de hospedar/entrar) ─────────────────
# Seletor de otimização de rede/render aplicado à sessão online. Construído em código e inserido
# ANTES da linha de botões Host/Client. Lê/grava no autoload NetConfig (persiste em Settings).
# Regra do projeto: priorizar resposta/FPS sem comprometer a experiência — daí os trade-offs
# ficarem explícitos para o jogador. Ver [[net_config]] / [[sistemas/salas]].
func _build_optimization_options() -> void:
	# Os 3 OptionButton (com colunas/rótulos coloridos/tab_order) são ESTÁTICOS no .tscn; aqui só
	# preenchemos itens/seleção a partir do NetConfig e conectamos cada um ao seu setter. TAB já vem do
	# .tscn (6 = Render do host, 7 = Taxa de sincronização, 8 = Suavização↔Resposta).
	# SÓ HOST: Render do host — só o host renderiza salas.
	_setup_opt_picker(host_render_picker, ["Janela", "Servidor puro"],
			0 if NetConfig.host_render_observed else 1,
			func(i: int) -> void: NetConfig.set_host_render(i == 0))
	# HOST + CLIENTE: Taxa de sync — host = broadcast das entidades; cliente = upload do input.
	_setup_opt_picker(sync_rate_picker, ["30 Hz", "60 Hz"],
			1 if NetConfig.sync_hz >= 60 else 0,
			func(i: int) -> void: NetConfig.set_sync_hz(60 if i == 1 else 30))
	# SÓ CLIENTE: Suavização ↔ Resposta — interpolação local; só o cliente interpola.
	_setup_opt_picker(interp_picker, NetConfig.INTERP_LABELS, NetConfig.interp_index(),
			func(i: int) -> void: NetConfig.set_interp_index(i))
	# Mudou o idioma → re-traduz os ITENS dos dropdowns (o Locale só auto-traduz Button/Label).
	if not Locale.language_changed.is_connected(_relocalize_options):
		Locale.language_changed.connect(_relocalize_options)


# Preenche um OptionButton de otimização (estático): itens (traduzidos), seleção inicial, chaves-fonte
# p/ re-tradução no idioma e o handler de item_selected. Registra em _opt_buttons (ver _relocalize_options).
func _setup_opt_picker(opt: OptionButton, items: Array, selected: int, on_selected: Callable) -> void:
	opt.clear()
	for it in items:
		opt.add_item(Locale.tr_key(String(it)))
	opt.selected = clampi(selected, 0, items.size() - 1)
	opt.set_meta(&"_item_keys", items)   # chaves-fonte p/ re-traduzir no language_changed
	opt.item_selected.connect(on_selected)
	_opt_buttons.append(opt)


# Re-traduz os ITENS dos OptionButton de otimização quando o idioma muda (o Locale pula OptionButton:
# o `text` deles é a seleção viva). Preserva o índice selecionado.
func _relocalize_options(_lang: String) -> void:
	for opt in _opt_buttons:
		if not is_instance_valid(opt):
			continue
		var keys: Array = opt.get_meta(&"_item_keys", [])
		var sel: int = opt.selected
		opt.clear()
		for k in keys:
			opt.add_item(Locale.tr_key(String(k)))
		opt.selected = clampi(sel, 0, maxi(keys.size() - 1, 0))


func _on_back_pressed() -> void:
	quit.emit()


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		# ESC encerra primeiro o preenchimento do IP/porta (devolvendo o foco ao botão);
		# só o 2º ESC sai da tela. Cobre a regra do projeto p/ campos editáveis.
		if UINav.cancel_active_edit(get_viewport(), manage_rooms_button):
			get_viewport().set_input_as_handled()
			return
		get_viewport().set_input_as_handled()
		quit.emit()

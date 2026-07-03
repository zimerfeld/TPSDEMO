extends Node

signal replace_main_scene
signal quit

const DEFAULT_ROOM_LEVEL: String = "res://scenes3D/level_1/level_1.tscn"
const HOST_SESSION_PATH: String = "res://scenes2D/host_session/host_session.tscn"
const CLIENT_SESSION_PATH: String = "res://scenes2D/client_session/client_session.tscn"
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

@onready var player_name_field: LineEdit = %PlayerName
@onready var port: SpinBox = %Port
@onready var address: LineEdit = %Address
@onready var port_history: OptionButton = %PortHistories
@onready var address_history: OptionButton = %AddressHistories
# OptionButtons de otimização — agora ESTÁTICOS na cena (rótulos/colunas/tab_order vêm do .tscn); o
# código só popula itens/seleção e conecta os handlers. Ver _build_optimization_options.
@onready var host_render_picker: OptionButton = %HostRenderPicker
@onready var sync_rate_picker: OptionButton = %SyncRatePicker
@onready var interp_picker: OptionButton = %InterpPicker
@onready var manage_rooms_button: Button = $UI/Inset/Main/Form/Fields/ButtonsRow/ManageRooms
@onready var join_rooms_button: Button = $UI/Inset/Main/Form/Fields/ButtonsRow/JoinRooms
@onready var loading: HBoxContainer = $UI/Loading
@onready var loading_progress: ProgressBar = $UI/Loading/Progress
@onready var loading_done_timer: Timer = $UI/Loading/DoneTimer
@onready var portuguese_button: Button = $UI/Actions/LangBar/Portuguese
@onready var english_button: Button = $UI/Actions/LangBar/English


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
	# → Português (12) → English (13) → Debug 2D (14). Re-liga quando o DebugOverlay injeta o toggle
	# "Debug 2D" na barra Actions (ele entra DEPOIS do _ready), p/ o toggle fechar a sequência.
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


# "Gerenciar Salas" (Host): hospeda um servidor PERSISTENTE e abre o painel de salas (host_session),
# onde dá pra iniciar/parar/reiniciar, observar e JOGAR em vários levels ao mesmo tempo. O peer fica
# aberto até "Voltar" (sair de uma sala NÃO encerra o servidor). Ver host_session.gd / RoomManager.
func _on_manage_rooms_pressed() -> void:
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
# (o peer precisa estar conectado para pedir a lista de salas via RPC).
func _on_join_rooms_pressed() -> void:
	PlayerSelection.spectator_host = false
	_remember("ports", int(port.value))
	if address.text.strip_edges() != "":
		_remember_address(address.text.strip_edges())
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
	# Reconexão idempotente: uma tentativa anterior (que falhou e voltou pelo retry do CrashHandler,
	# ou que conectou e deixou o connection_failed ONE_SHOT pendente) pode ter deixado o sinal preso
	# nesta mesma tela. Sem limpar, o connect() repetido estoura "Signal already connected".
	if multiplayer.connected_to_server.is_connected(_open_rooms_client):
		multiplayer.connected_to_server.disconnect(_open_rooms_client)
	if multiplayer.connection_failed.is_connected(_on_rooms_connect_failed):
		multiplayer.connection_failed.disconnect(_on_rooms_connect_failed)
	multiplayer.connected_to_server.connect(_open_rooms_client, CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(_on_rooms_connect_failed, CONNECT_ONE_SHOT)


func _open_rooms_client() -> void:
	emit_signal("replace_main_scene", ResourceLoader.load(CLIENT_SESSION_PATH))


func _on_rooms_connect_failed() -> void:
	loading.hide()
	if multiplayer.connected_to_server.is_connected(_open_rooms_client):
		multiplayer.connected_to_server.disconnect(_open_rooms_client)
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	CrashHandler.show_error(
		"Falha ao conectar em %s:%d.\n\nVerifique o endereço e a porta." % [address.text, int(port.value)],
		_on_join_rooms_pressed
	)


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

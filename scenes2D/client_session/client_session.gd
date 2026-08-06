extends Control
## Navegador de SALAS do CLIENTE. Lista as salas em execução no servidor e deixa o jogador ENTRAR
## numa delas (escolhe o personagem no ChoosePlayer e nasce na sala). A sala do cliente é um Node
## comum (renderiza na JANELA PRINCIPAL → input/câmera normais). Durante o jogo esta cena continua
## em /root (só esconde o painel); ESC (com confirmação) ou o encerramento da sala pelo servidor
## (Parar) voltam para o navegador. O peer NÃO é fechado ao ir ao ChoosePlayer e voltar; só no
## "Voltar". Ver [[RoomManager]] / [[sistemas/salas]].

signal replace_main_scene

const PLAYONLINE_PATH: String = "res://scenes2D/playonline/playonline.tscn"
const CHOOSEPLAYER_PATH: String = "res://scenes2D/chooseplayer/chooseplayer.tscn"
const CLIENT_SESSION_PATH: String = "res://scenes2D/client_session/client_session.tscn"

var _playing_room: int = -1            # sala em que o cliente está jogando (-1 = navegando)
var _confirm_dialog: FloatingWindow = null
# Guarda contra tratar a queda de conexão mais de uma vez (o aviso + volta ao PlayOnline rodam 1x).
var _server_lost: bool = false

# Scaffold ESTÁTICO no .tscn (2026-06-30): título/info/lista/Voltar/Actions já vêm da cena; o código só
# popula as linhas de sala (dinâmicas) e religa o foco. Antes a tela inteira era montada em runtime.
@onready var _panel: Control = %Panel
@onready var _rooms_list: VBoxContainer = %RoomsList
@onready var _empty_hint: Label = %EmptyHint
@onready var _actions_bar: HBoxContainer = %Actions
@onready var _back_button: Button = %Back
@onready var _signal_layer: ColorRect = %SignalLayer


func _ready() -> void:
	# Tema, mouse_filter e todo o scaffold vêm do .tscn. Só o aspecto dos anéis do shader depende da
	# viewport (mantém círculos); ring_color/dir já estão no material da cena.
	var mat := _signal_layer.material as ShaderMaterial
	if mat != null:
		var sz: Vector2 = get_viewport().get_visible_rect().size
		mat.set_shader_parameter("aspect", sz.x / maxf(sz.y, 1.0))
	_back_button.pressed.connect(_go_back)
	RoomManager.rooms_changed.connect(_refresh_rooms)
	RoomManager.room_closed.connect(_on_room_closed)
	RoomManager.room_restarted.connect(_on_room_restarted)
	# Queda de conexão com o host (rede, host fechou, ou timeout por stall de render): sem tratar,
	# o cliente ficava preso na sala congelada. Avisa e volta ao PlayOnline. Ver _on_server_lost.
	if not multiplayer.server_disconnected.is_connected(_on_server_lost):
		multiplayer.server_disconnected.connect(_on_server_lost)
	RoomManager.request_room_list.rpc_id(1)  # pede a lista de salas ao servidor
	# Voltou do ChoosePlayer para ENTRAR numa sala? espelha a sala e spawna o player.
	if RoomManager.pending_play_room >= 0:
		var rid: int = RoomManager.pending_play_room
		var path: String = RoomManager.pending_play_level
		RoomManager.pending_play_room = -1
		# Corrida: o host pode ter PARADO/reiniciado a sala enquanto o jogador escolhia o personagem. O
		# RoomManager (autoload) segue recebendo receive_room_list mesmo durante o chooseplayer, então
		# server_room_list() está atualizado. Se a sala sumiu, NÃO nascemos numa sala morta (evita a cena
		# vazia de entrar numa sala que não roda mais): volta ao navegador com um aviso.
		if _server_has_room(rid):
			# Espelhar a sala + nascer nela custa o setup de render do level (stall). A tela de
			# "Carregando" cobre a entrada e revela so com o quadro pronto. Ver [[LoadingScreen]].
			# A revelação espera o PRÓPRIO player aparecer no espelho da sala: o servidor só o spawna
			# depois de povoar a sala inteira, então vê-lo implica cenário completo, nas coordenadas.
			LoadingScreen.cover(func() -> void:
				RoomManager.client_join_room(rid, path, PlayerSelection.variant_id)
				_enter_play(rid),
				LoadingScreen.SETTLE_FRAMES,
				func() -> bool: return RoomManager.player_ready_in_room(rid, multiplayer.get_unique_id()))
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			_refresh_rooms()
			_alert.call_deferred("A sala não está mais disponível")
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_refresh_rooms()
	# Toggle "Debug 2D" na barra Actions (injetado pelo DebugOverlay como nas demais telas) + sequência
	# de Tab. Re-liga ao injetar o toggle e ao remontar as salas; foco inicial no controle de Tab = 1.
	_actions_bar.child_entered_tree.connect(func(_n: Node) -> void: _rewire_tab.call_deferred())
	_rewire_tab.call_deferred()
	UINav.focus_tab_one.call_deferred(self)


# (Re)liga a sequência de Tab do navegador NUMERANDO em ordem de leitura (lista variável): botões
# "Jogar" das salas 1..N → Voltar → Debug 2D. Idempotente: re-chamada quando a lista muda ou o toggle
# é injetado. Numerar por código (e não no .tscn) é necessário porque o nº de salas varia em runtime.
func _rewire_tab() -> void:
	var i := 1
	for row in _rooms_list.get_children():
		var play := row.get_node_or_null("Play")
		if play is BaseButton:
			(play as Control).set_meta(UINav.TAB_ORDER_META, i)
			i += 1
	_back_button.set_meta(UINav.TAB_ORDER_META, i)
	i += 1
	var dbg := _actions_bar.get_node_or_null("Debug2D")
	if dbg != null:
		(dbg as Control).set_meta(UINav.TAB_ORDER_META, i)
	UINav.wire_tab_ring(self)


# True se a sala ainda consta na última lista recebida do servidor (só salas em EXECUÇÃO entram
# nessa lista). Usado para não entrar numa sala que o host parou/reiniciou enquanto o jogador
# escolhia o personagem (guarda de corrida do "Jogar").
func _server_has_room(room_id: int) -> bool:
	for r in RoomManager.server_room_list():
		if int((r as Dictionary).get("id", -1)) == room_id:
			return true
	return false


func _refresh_rooms() -> void:
	if not is_instance_valid(_rooms_list):
		return
	for c in _rooms_list.get_children():
		c.queue_free()
	var rooms: Array = RoomManager.server_room_list()
	# O botão "Jogar" por sala SÓ aparece quando há sala em execução; senão, só o aviso.
	if is_instance_valid(_empty_hint):
		_empty_hint.visible = rooms.is_empty()
	for r in rooms:
		_rooms_list.add_child(_make_client_row(r))
	# As linhas de sala mudaram (novos botões "Jogar") → re-liga a sequência de Tab.
	_rewire_tab.call_deferred()
	# Piloto automático (`-- autojoin`): assim que a PRIMEIRA sala em execução aparece na lista,
	# entra nela sozinho (equivale a clicar "Jogar"). Uma única vez — depois a sessão é do jogador.
	if not rooms.is_empty() and _playing_room < 0 and Autopilot.should_enter_room():
		Autopilot.mark_room_entered()
		var first: Dictionary = rooms[0]
		_on_play_room.call_deferred(int(first["id"]), String(first["level_path"]))


func _make_client_row(r: Dictionary) -> Control:
	var id: int = int(r["id"])
	var path: String = String(r["level_path"])
	var players: int = int(r.get("players", 0))
	var row := HBoxContainer.new()
	row.name = "RoomRow_%d" % id
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.name = "RoomInfo"
	lbl.text = "Sala #%d — %s  (%d jogador%s)" % [
		id, RoomManager.level_label(path), players, "" if players == 1 else "es"]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var play_btn := Button.new()
	play_btn.name = "Play"
	play_btn.text = "Jogar"
	play_btn.pressed.connect(_on_play_room.bind(id, path))
	row.add_child(play_btn)
	return row


# "Jogar": escolhe o personagem ANTES de entrar na sala. Marca a sala pendente (id + level) e vai
# ao ChoosePlayer; ao voltar, o _ready entra na sala (client_join_room). NÃO entra aqui — senão o
# espelho da sala renderizaria atrás do ChoosePlayer.
func _on_play_room(id: int, level_path: String) -> void:
	RoomManager.pending_play_room = id
	RoomManager.pending_play_level = level_path
	RoomManager.pending_play_return = CLIENT_SESSION_PATH
	emit_signal("replace_main_scene", load(CHOOSEPLAYER_PATH))


# ───────────────────────────── jogar / sair da sala ─────────────────────────────

func _enter_play(room_id: int) -> void:
	_playing_room = room_id
	_panel.visible = false                       # esconde a UI → o jogo (janela principal) aparece
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _exit_play() -> void:
	_playing_room = -1
	_panel.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Some com a barra do último inimigo atingido (ela some sozinha só depois de alguns segundos) —
	# o navegador de salas não deve exibir nada de dentro da partida.
	preload("res://controls2D/enemy_health_bar.gd").hide_all()
	RoomManager.request_room_list.rpc_id(1)
	_refresh_rooms()


# Servidor PAROU (botão Parar) a sala em que eu jogava → volta ao navegador com o aviso.
func _on_room_closed(room_id: int) -> void:
	if room_id != _playing_room:
		return
	_exit_play()
	_alert("O nível foi parado pelo host")


# Servidor REINICIOU (botão Reiniciar) a sala em que eu jogava → volta ao navegador com o aviso.
# A sala recriada reaparece na lista (a _exit_play já pede a lista atualizada) para reentrar.
func _on_room_restarted(room_id: int) -> void:
	if room_id != _playing_room:
		return
	_exit_play()
	_alert("O nível foi reiniciado pelo host")


func _alert(message: String) -> void:
	FloatingDialog.alert(self, "Aviso", message, "OK")


# A conexão com o host CAIU no meio da sessão (queda de rede, host encerrou, ou um stall de render
# longo o bastante para estourar o timeout do ENet). Sem tratar isto, o cliente ficava PRESO numa sala
# congelada — os inimigos param de sincronizar e o tiro não chega mais ao servidor ("não detecta
# colisão"). Aqui avisamos e voltamos ao PlayOnline (o peer já está morto; só reseta e navega).
func _on_server_lost() -> void:
	if _server_lost:
		return
	_server_lost = true
	_playing_room = -1
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var dlg := FloatingDialog.alert(self, "Conexão perdida", "A conexão com o host foi perdida.", "OK")
	dlg.closed.connect(_return_to_playonline)


func _return_to_playonline() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	emit_signal("replace_main_scene", load(PLAYONLINE_PATH))


# ───────────────────────────── navegação / ESC ─────────────────────────────

# Voltar ao PlayOnline (a UI que chamou): se estava jogando, sai da sala; depois fecha o peer.
func _go_back() -> void:
	if _playing_room >= 0:
		RoomManager.client_leave_room(_playing_room)
		_playing_room = -1
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	emit_signal("replace_main_scene", load(PLAYONLINE_PATH))


# ESC enquanto jogo: confirma desconectar o player e voltar ao navegador (sem fechar o peer).
func _confirm_disconnect() -> void:
	if is_instance_valid(_confirm_dialog):
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var dlg := FloatingDialog.confirm(self, "Desconectar", "Desconectar e voltar para a lista de salas ?", "Sim", "Não")
	dlg.confirmed.connect(func() -> void:
		var rid := _playing_room
		_exit_play()
		if rid >= 0:
			RoomManager.client_leave_room(rid))
	dlg.canceled.connect(func() -> void:
		if _playing_room >= 0:  # cancelou: continua jogando (recaptura o mouse)
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED))
	dlg.closed.connect(func() -> void:
		_confirm_dialog = null)
	_confirm_dialog = dlg


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"quit"):
		get_viewport().set_input_as_handled()   # marca antes da ação: _go_back() libera a cena (viewport vira null depois)
		if _playing_room >= 0:
			_confirm_disconnect()       # jogando: confirma desconectar e volta ao navegador
		else:
			_go_back()                  # navegador: volta ao PlayOnline (fecha o peer)



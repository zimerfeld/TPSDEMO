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

var _panel: Control
var _rooms_list: VBoxContainer
var _empty_hint: Label
var _confirm_dialog: FloatingWindow = null
var _actions_bar: HBoxContainer = null   # barra "Actions" (Voltar + toggle Debug 2D injetado)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Tema do projeto (mesmo da playonline/menu) → botões/labels/dropdowns/painéis com o visual
	# cyberpunk consistente. Propaga p/ toda a UI montada em código (filhos herdam o theme da raiz).
	theme = load("res://themes/ui_theme.tres")
	# A raiz não captura mouse (o painel/botões sim); ao esconder o painel, o jogo recebe o input.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	RoomManager.rooms_changed.connect(_refresh_rooms)
	RoomManager.room_closed.connect(_on_room_closed)
	RoomManager.room_restarted.connect(_on_room_restarted)
	RoomManager.request_room_list.rpc_id(1)  # pede a lista de salas ao servidor
	# Voltou do ChoosePlayer para ENTRAR numa sala? espelha a sala e spawna o player.
	if RoomManager.pending_play_room >= 0:
		var rid: int = RoomManager.pending_play_room
		var path: String = RoomManager.pending_play_level
		RoomManager.pending_play_room = -1
		RoomManager.client_join_room(rid, path, PlayerSelection.variant_id)
		_enter_play(rid)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_refresh_rooms()
	# Toggle "Debug 2D" na barra Actions (injetado pelo DebugOverlay como nas demais telas) + sequência
	# de Tab. Re-liga ao injetar o toggle e ao remontar as salas; foco inicial no controle de Tab = 1.
	_actions_bar.child_entered_tree.connect(func(_n: Node) -> void: _rewire_tab.call_deferred())
	_rewire_tab.call_deferred()
	UINav.focus_tab_one.call_deferred(self)


# (Re)liga a sequência de Tab do navegador na ordem de leitura (linhas de sala → Voltar → Debug 2D).
# Idempotente: re-chamada quando a lista de salas muda ou o toggle é injetado.
func _rewire_tab() -> void:
	UINav.wire_tab_ring(self)


# ───────────────────────────── UI (navegador) ─────────────────────────────

func _build_ui() -> void:
	var inner := _make_panel("Salas disponíveis no servidor")
	var info := Label.new()
	info.name = "Info"
	info.text = "Escolha uma sala para entrar:"
	info.add_theme_font_size_override("font_size", 18)
	inner.add_child(info)
	_rooms_list = _make_rooms_list(inner)
	_empty_hint = Label.new()
	_empty_hint.name = "EmptyHint"
	_empty_hint.text = "Nenhuma sala em execução."
	_empty_hint.add_theme_font_size_override("font_size", 16)
	inner.add_child(_empty_hint)


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


func _make_client_row(r: Dictionary) -> Control:
	var id: int = int(r["id"])
	var path: String = String(r["level_path"])
	var players: int = int(r.get("players", 0))
	var row := HBoxContainer.new()
	row.name = "RoomRow_%d" % id
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.name = "RoomLabel"
	lbl.text = "Sala #%d — %s  (%d jogador%s)" % [
		id, RoomManager.level_label(path), players, "" if players == 1 else "es"]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var play_btn := Button.new()
	play_btn.name = "PlayButton"
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


# ───────────────────────────── helpers de UI ─────────────────────────────

# Monta o navegador inteiro (tela cheia) e devolve a VBox CENTRALIZADA onde vai a lista de salas.
# Escondido enquanto o cliente JOGA (o nível ocupa a janela principal). Fundo na MESMA cor navy das
# outras telas — o ui_theme só estiliza Button/Label, não dá fundo; sem isto sobrava o cinza padrão
# do PanelContainer (era o "estilo de cores não aplicado"). Conteúdo centralizado (largura máx. 900)
# e botão Voltar de tamanho normal e centralizado, no padrão da playonline/menu.
func _make_panel(title_text: String) -> VBoxContainer:
	_panel = Control.new()
	_panel.name = "Panel"
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	# Fundo: MESMA textura cyberpunk do menu, porém com IDENTIDADE de CLIENTE — graduação FRIA (ciano)
	# + anéis de "radar" CONTRAINDO para dentro (CONECTA-SE ao servidor). Contrasta com o host
	# (quente + anéis expandindo). mouse_filter IGNORE p/ os cliques chegarem aos botões.
	var bg_tex := TextureRect.new()
	bg_tex.name = "Background"
	bg_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_tex.texture = load("res://scenes2D/menu/menu_surreal_training_bg.png")
	bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_tex.modulate = Color(0.55, 0.86, 1.0, 0.98)   # graduação FRIA (ciano) = CLIENTE
	bg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(bg_tex)
	var veil := ColorRect.new()
	veil.name = "Veil"
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.008, 0.03, 0.06, 0.62)      # véu escuro frio
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(veil)
	_panel.add_child(_make_signal_layer(Color(0.2, 0.72, 1.0, 1.0), -1.0))  # anéis ciano CONTRAINDO
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	_panel.add_child(margin)
	var outer := VBoxContainer.new()
	outer.name = "Content"
	outer.add_theme_constant_override("separation", 14)
	margin.add_child(outer)
	var title := Label.new()
	title.name = "Title"
	title.text = title_text
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(title)
	# Área central: VBox de largura máx. 900, centralizada horizontalmente (a lista fica aqui).
	var center := HBoxContainer.new()
	center.name = "Center"
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_child(center)
	var inner := VBoxContainer.new()
	inner.name = "Inner"
	inner.custom_minimum_size = Vector2(900, 0)
	inner.add_theme_constant_override("separation", 14)
	center.add_child(inner)
	# Voltar: tamanho fixo e centralizado embaixo (não mais full-width), como nas outras telas.
	var actions := HBoxContainer.new()
	actions.name = "Actions"   # nome padrão p/ o DebugOverlay injetar o toggle "Debug 2D" (igual às outras telas)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_child(actions)
	_actions_bar = actions
	var back_btn := Button.new()
	back_btn.name = "BackButton"
	back_btn.text = "Voltar"
	back_btn.custom_minimum_size = Vector2(200, 50)
	back_btn.pressed.connect(_go_back)
	actions.add_child(back_btn)
	return inner


# Camada de "radar/sinal": ColorRect em tela cheia com o shader de anéis concêntricos. `dir` = +1
# expande (host transmite) / -1 contrai (cliente conecta). `aspect` mantém os anéis circulares.
func _make_signal_layer(color: Color, dir: float) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = "SignalLayer"
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://themes/session_signal_bg.gdshader")
	mat.set_shader_parameter("ring_color", color)
	mat.set_shader_parameter("dir", dir)
	var sz: Vector2 = get_viewport().get_visible_rect().size
	mat.set_shader_parameter("aspect", sz.x / maxf(sz.y, 1.0))
	rect.material = mat
	return rect


func _make_rooms_list(parent: VBoxContainer) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "RoomsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 360)
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.name = "RoomsList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	return list



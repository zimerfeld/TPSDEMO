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
var _confirm_dialog: ConfirmationDialog = null


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


# ───────────────────────────── UI (navegador) ─────────────────────────────

func _build_ui() -> void:
	var inner := _make_panel("Salas disponíveis no servidor")
	var info := Label.new()
	info.text = "Escolha uma sala para entrar:"
	info.add_theme_font_size_override("font_size", 18)
	inner.add_child(info)
	_rooms_list = _make_rooms_list(inner)
	_empty_hint = Label.new()
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


func _make_client_row(r: Dictionary) -> Control:
	var id: int = int(r["id"])
	var path: String = String(r["level_path"])
	var players: int = int(r.get("players", 0))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = "Sala #%d — %s  (%d jogador%s)" % [
		id, RoomManager.level_label(path), players, "" if players == 1 else "es"]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var play_btn := Button.new()
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


# Servidor encerrou (Parar) a sala em que eu jogava → volta ao navegador com o alerta.
func _on_room_closed(room_id: int) -> void:
	if room_id != _playing_room:
		return
	_exit_play()
	_alert("O Servidor foi desligado")


func _alert(message: String) -> void:
	var dlg := AcceptDialog.new()
	dlg.dialog_text = Locale.tr_key(message)
	dlg.get_ok_button().text = Locale.tr_key("OK")
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered()


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
	var dlg := ConfirmationDialog.new()
	dlg.title = Locale.tr_key("Desconectar")
	dlg.dialog_text = Locale.tr_key("Desconectar e voltar para a lista de salas ?")
	dlg.get_ok_button().text = Locale.tr_key("Sim")
	dlg.get_cancel_button().text = Locale.tr_key("Não")
	dlg.confirmed.connect(func() -> void:
		dlg.queue_free()
		_confirm_dialog = null
		var rid := _playing_room
		_exit_play()
		if rid >= 0:
			RoomManager.client_leave_room(rid))
	dlg.canceled.connect(func() -> void:
		dlg.queue_free()
		_confirm_dialog = null
		if _playing_room >= 0:  # cancelou: continua jogando (recaptura o mouse)
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED))
	_confirm_dialog = dlg
	add_child(dlg)
	dlg.popup_centered()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"quit"):
		if _playing_room >= 0:
			_confirm_disconnect()       # jogando: confirma desconectar e volta ao navegador
		else:
			_go_back()                  # navegador: volta ao PlayOnline (fecha o peer)
		get_viewport().set_input_as_handled()


# ───────────────────────────── helpers de UI ─────────────────────────────

# Monta o navegador inteiro (tela cheia) e devolve a VBox CENTRALIZADA onde vai a lista de salas.
# Escondido enquanto o cliente JOGA (o nível ocupa a janela principal). Fundo na MESMA cor navy das
# outras telas — o ui_theme só estiliza Button/Label, não dá fundo; sem isto sobrava o cinza padrão
# do PanelContainer (era o "estilo de cores não aplicado"). Conteúdo centralizado (largura máx. 900)
# e botão Voltar de tamanho normal e centralizado, no padrão da playonline/menu.
func _make_panel(title_text: String) -> VBoxContainer:
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	# Fundo no MESMO estilo do menu/chooseplayer: textura cyberpunk + véu escuro por cima (o flat navy
	# ficava "sem cor"). O ui_theme só estiliza Button/Label, então o fundo é montado aqui. mouse_filter
	# IGNORE p/ os cliques chegarem aos botões.
	var bg_tex := TextureRect.new()
	bg_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_tex.texture = load("res://scenes2D/menu/menu_surreal_training_bg.png")
	bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_tex.modulate = Color(0.92, 0.97, 1, 0.98)
	bg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(bg_tex)
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.0156863, 0.0313726, 0.0588235, 0.62)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(veil)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	_panel.add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	margin.add_child(outer)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(title)
	# Área central: VBox de largura máx. 900, centralizada horizontalmente (a lista fica aqui).
	var center := HBoxContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_child(center)
	var inner := VBoxContainer.new()
	inner.custom_minimum_size = Vector2(900, 0)
	inner.add_theme_constant_override("separation", 14)
	center.add_child(inner)
	# Voltar: tamanho fixo e centralizado embaixo (não mais full-width), como nas outras telas.
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	outer.add_child(actions)
	var back_btn := Button.new()
	back_btn.text = "Voltar"
	back_btn.custom_minimum_size = Vector2(200, 50)
	back_btn.pressed.connect(_go_back)
	actions.add_child(back_btn)
	return inner


func _make_rooms_list(parent: VBoxContainer) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 360)
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	return list



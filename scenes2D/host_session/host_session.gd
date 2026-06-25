extends Control
## Hub de SALAS do SERVIDOR (host). Grade de gerência: iniciar/parar/reiniciar e OBSERVAR cada
## level ativo (cada sala num SubViewport com World3D próprio; só a observada/jogada renderiza).
## Além de observar, o host pode JOGAR dentro de uma sala — spawna um player controlado nela e
## empurra o mouse para o SubViewport (o movimento vem do Input global).
##
## O peer NÃO é fechado ao navegar aqui (nem ao ir ao ChoosePlayer e voltar): só ao "Voltar",
## que derruba o servidor e retorna ao PlayOnline. Ver [[RoomManager]] / [[sistemas/salas]].

signal replace_main_scene

const LEVELS := [
	{"label": "Level 1", "path": "res://scenes3D/level_1/level_1.tscn"},
	{"label": "Level 2", "path": "res://scenes3D/level_2/level_2.tscn"},
	{"label": "Level Base", "path": "res://scenes3D/level_base/level_base.tscn"},
]
const PLAYONLINE_PATH: String = "res://scenes2D/playonline/playonline.tscn"
const CHOOSEPLAYER_PATH: String = "res://scenes2D/chooseplayer/chooseplayer.tscn"
const HOST_SESSION_PATH: String = "res://scenes2D/host_session/host_session.tscn"

var _observing_id: int = -1        # sala observada (-1 = grade)
var _playing_id: int = -1          # sala em que o host JOGA (-1 = não joga)

var _room_view: TextureRect
var _panel: Control
var _level_picker: OptionButton
var _rooms_list: VBoxContainer
var _hint: Label
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
	_refresh_rooms()
	# Voltou do ChoosePlayer para JOGAR numa sala? spawna o player do host e entra em modo de jogo.
	if RoomManager.pending_play_room >= 0:
		var rid: int = RoomManager.pending_play_room
		RoomManager.pending_play_room = -1
		RoomManager.host_spawn_in_room(rid, PlayerSelection.variant_id)
		_set_playing(rid)
	else:
		_set_observing(-1)


# ───────────────────────────── UI (grade de gerência) ─────────────────────────────

func _build_ui() -> void:
	_room_view = TextureRect.new()
	_room_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_room_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_room_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_room_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_room_view.visible = false
	add_child(_room_view)

	var inner := _make_panel("Servidor — Salas ativas")

	var start_row := HBoxContainer.new()
	start_row.add_theme_constant_override("separation", 12)
	start_row.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_child(start_row)
	_level_picker = OptionButton.new()
	_level_picker.add_item("Selecione...")  # item 0 = sentinela (sem metadata; convenção do projeto)
	for lv in LEVELS:
		_level_picker.add_item(String(lv["label"]))
		_level_picker.set_item_metadata(_level_picker.item_count - 1, String(lv["path"]))
	_level_picker.custom_minimum_size = Vector2(220, 44)
	start_row.add_child(_level_picker)
	var start_btn := Button.new()
	start_btn.text = "Iniciar Sala"
	start_btn.custom_minimum_size = Vector2(160, 44)
	start_btn.pressed.connect(_on_start_pressed)
	start_row.add_child(start_btn)

	inner.add_child(HSeparator.new())
	_rooms_list = _make_rooms_list(inner, "Salas em execução:")

	_hint = _make_hint("")


func _on_start_pressed() -> void:
	var idx: int = _level_picker.selected
	if idx <= 0:  # item 0 = "Selecione..."
		return
	RoomManager.start_room(String(_level_picker.get_item_metadata(idx)))
	_apply_mouse_mode()


# ───────────────────────────── observar / jogar ─────────────────────────────

func _set_observing(id: int) -> void:
	_playing_id = -1
	_observing_id = id
	_render_only(id)
	if id >= 0:
		_show_room_view(id)
		RoomManager.activate_spectator(id)  # garante a câmera livre como current no SubViewport
		_hint.text = "ESC volta à gerência | WASD voa | Espaço+W/S sobe/desce"
		_hint.visible = true
	else:
		_room_view.visible = false
		_room_view.texture = null
		_panel.visible = true
		_hint.visible = false
	_apply_mouse_mode()
	_refresh_rooms()


# O host está JOGANDO na sala id: o player (peer 1) já foi spawnado (host_spawn_in_room) e sua
# câmera virou current no SubViewport via apply_authority(). Aqui só renderizamos essa sala em tela
# cheia, escondemos a grade e capturamos o mouse (o movimento vem do Input global; o mouse é
# encaminhado ao SubViewport no _input).
func _set_playing(id: int) -> void:
	_observing_id = -1
	_playing_id = id
	_render_only(id)
	_show_room_view(id)
	_hint.text = "ESC desconecta e volta à gerência"
	_hint.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_refresh_rooms()


# Só a sala `id` renderiza (UPDATE_ALWAYS); as demais apenas simulam (otimização de GPU). No modo
# "servidor puro" (NetConfig.host_render_observed=false) NENHUMA sala renderiza → GPU ociosa, ideal
# para hospedar muitas salas sem custo de vídeo (a simulação/rede seguem normais nos clientes).
func _render_only(id: int) -> void:
	for room in RoomManager.get_rooms():
		var vp: Variant = room["viewport"]
		if vp is SubViewport:
			var render_this: bool = NetConfig.host_render_observed and int(room["id"]) == id
			(vp as SubViewport).render_target_update_mode = (SubViewport.UPDATE_ALWAYS
					if render_this else SubViewport.UPDATE_DISABLED)


func _show_room_view(id: int) -> void:
	var room := RoomManager.get_room(id)
	if not room.is_empty() and room["viewport"] is SubViewport:
		_room_view.texture = (room["viewport"] as SubViewport).get_texture()
	_room_view.visible = true
	_panel.visible = false


func _apply_mouse_mode() -> void:
	Input.set_mouse_mode(
		Input.MOUSE_MODE_CAPTURED if _observing_id >= 0 else Input.MOUSE_MODE_VISIBLE)


# ───────────────────────────── lista de salas ─────────────────────────────

func _refresh_rooms() -> void:
	if not is_instance_valid(_rooms_list):
		return
	for c in _rooms_list.get_children():
		c.queue_free()
	# Sala observada/jogada sumiu (parada externamente)? volta à grade.
	if _observing_id >= 0 and not RoomManager.has_room(_observing_id):
		_set_observing(-1)
		return
	if _playing_id >= 0 and not RoomManager.has_room(_playing_id):
		_set_observing(-1)
		return
	for room in RoomManager.get_rooms():
		_rooms_list.add_child(_make_server_row(room))


func _make_server_row(room: Dictionary) -> Control:
	var id: int = int(room["id"])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = "Sala #%d — %s" % [id, RoomManager.level_label(String(room["level_path"]))]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	# Modo "servidor puro" (render do host desligado): não há o que ver, então Jogar/Observar ficam
	# desabilitados (o host só gerencia as salas; iniciar/parar/reiniciar seguem funcionando).
	var render_off: bool = not NetConfig.host_render_observed
	var play_btn := Button.new()
	play_btn.text = "Jogar"
	play_btn.disabled = render_off
	if render_off:
		play_btn.tooltip_text = Locale.tr_key("Render do host desativado (servidor puro)")
	play_btn.pressed.connect(_on_play_room.bind(id))
	row.add_child(play_btn)
	var observe_btn := Button.new()
	observe_btn.text = "Observando" if id == _observing_id else "Observar"
	observe_btn.disabled = (id == _observing_id) or render_off
	if render_off:
		observe_btn.tooltip_text = Locale.tr_key("Render do host desativado (servidor puro)")
	observe_btn.pressed.connect(_set_observing.bind(id))
	row.add_child(observe_btn)
	var restart_btn := Button.new()
	restart_btn.text = "Reiniciar"
	restart_btn.pressed.connect(func() -> void:
		var was_obs := _observing_id == id
		var new_id := RoomManager.restart_room(id)
		if was_obs and new_id >= 0:
			_set_observing(new_id))
	row.add_child(restart_btn)
	var stop_btn := Button.new()
	stop_btn.text = "Parar"
	stop_btn.pressed.connect(func() -> void: RoomManager.stop_room(id))
	row.add_child(stop_btn)
	return row


# "Jogar": escolhe o personagem ANTES de nascer na sala. Marca a sala pendente e vai ao
# ChoosePlayer; ao voltar, o _ready spawna o player do host nesta sala (host_spawn_in_room).
func _on_play_room(id: int) -> void:
	RoomManager.pending_play_room = id
	RoomManager.pending_play_return = HOST_SESSION_PATH
	emit_signal("replace_main_scene", load(CHOOSEPLAYER_PATH))


# ───────────────────────────── navegação / ESC ─────────────────────────────

# Voltar ao PlayOnline (a UI que chamou): derruba o servidor e o peer. Sem isso, reabrir o
# PlayOnline com o peer ainda vivo daria "porta em uso" ao tentar hospedar de novo.
func _go_back() -> void:
	RoomManager.stop_all()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	emit_signal("replace_main_scene", load(PLAYONLINE_PATH))


# ESC enquanto o host JOGA: confirma desconectar o player e voltar à grade (sem fechar o servidor).
func _confirm_disconnect() -> void:
	if is_instance_valid(_confirm_dialog):
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var dlg := ConfirmationDialog.new()
	dlg.title = Locale.tr_key("Desconectar")
	dlg.dialog_text = Locale.tr_key("Desconectar e voltar para a gerência de salas ?")
	dlg.get_ok_button().text = Locale.tr_key("Sim")
	dlg.get_cancel_button().text = Locale.tr_key("Não")
	dlg.confirmed.connect(func() -> void:
		dlg.queue_free()
		_confirm_dialog = null
		RoomManager.host_leave_room()
		_set_observing(-1))
	dlg.canceled.connect(func() -> void:
		dlg.queue_free()
		_confirm_dialog = null
		if _playing_id >= 0:  # cancelou: continua jogando (recaptura o mouse)
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED))
	_confirm_dialog = dlg
	add_child(dlg)
	dlg.popup_centered()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"quit"):
		if _playing_id >= 0:
			_confirm_disconnect()       # jogando: confirma desconectar e voltar à gerência
		elif _observing_id >= 0:
			_set_observing(-1)          # observando: 1º ESC sai da observação
		else:
			_go_back()                  # grade: volta ao PlayOnline (derruba o servidor)
		get_viewport().set_input_as_handled()
		return
	# Observando OU jogando: empurra o mouse p/ a sala (câmera livre ou mira do player). NUNCA
	# encaminhamos teclas — assim o ESC fica nesta sessão e o nível dentro do SubViewport não o vê.
	if (_observing_id >= 0 or _playing_id >= 0) and event is InputEventMouseMotion:
		var rid: int = _observing_id if _observing_id >= 0 else _playing_id
		var room := RoomManager.get_room(rid)
		if not room.is_empty() and room["viewport"] is SubViewport:
			(room["viewport"] as SubViewport).push_input(event)


# ───────────────────────────── helpers de UI ─────────────────────────────

# Monta a tela de gerência inteira (tela cheia) e devolve a VBox CENTRALIZADA onde vão as listas.
# Escondida enquanto o host OBSERVA/JOGA (aí o SubViewport ocupa a tela). Fundo na MESMA cor navy das
# outras telas — o ui_theme só estiliza Button/Label, não dá fundo; sem isto sobrava o cinza padrão
# do PanelContainer (era o "estilo de cores não aplicado"). Conteúdo centralizado (largura máx. 900)
# e botão Voltar de tamanho normal e centralizado, no padrão da playonline/menu.
func _make_panel(title_text: String) -> VBoxContainer:
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	# Fundo: MESMA textura cyberpunk do menu, porém com IDENTIDADE de HOST — graduação QUENTE (âmbar)
	# + anéis de "radar" EXPANDINDO para fora (o servidor TRANSMITE / é a fonte). Contrasta com o
	# cliente (frio + anéis contraindo). mouse_filter IGNORE p/ os cliques chegarem aos botões.
	var bg_tex := TextureRect.new()
	bg_tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_tex.texture = load("res://scenes2D/menu/menu_surreal_training_bg.png")
	bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_tex.modulate = Color(1.0, 0.82, 0.5, 0.98)   # graduação QUENTE (âmbar) = HOST
	bg_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(bg_tex)
	var veil := ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.06, 0.035, 0.012, 0.62)    # véu escuro quente
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(veil)
	_panel.add_child(_make_signal_layer(Color(1.0, 0.62, 0.16, 1.0), 1.0))  # anéis âmbar EXPANDINDO
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
	# Área central: VBox de largura máx. 900, centralizada horizontalmente (as listas ficam aqui).
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


# Camada de "radar/sinal": ColorRect em tela cheia com o shader de anéis concêntricos. `dir` = +1
# expande (host transmite) / -1 contrai (cliente conecta). `aspect` mantém os anéis circulares.
func _make_signal_layer(color: Color, dir: float) -> ColorRect:
	var rect := ColorRect.new()
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


func _make_rooms_list(parent: VBoxContainer, header: String) -> VBoxContainer:
	if header != "":
		var h := Label.new()
		h.text = header
		h.add_theme_font_size_override("font_size", 18)
		parent.add_child(h)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 360)
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	return list


func _make_hint(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	lbl.position.y = 12
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.visible = false
	add_child(lbl)
	return lbl

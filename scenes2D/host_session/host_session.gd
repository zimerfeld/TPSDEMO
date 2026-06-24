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
var _panel: PanelContainer
var _level_picker: OptionButton
var _rooms_list: VBoxContainer
var _hint: Label
var _confirm_dialog: ConfirmationDialog = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	_make_back_button(inner)

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


# Só a sala `id` renderiza (UPDATE_ALWAYS); as demais apenas simulam (otimização de GPU).
func _render_only(id: int) -> void:
	for room in RoomManager.get_rooms():
		var vp: Variant = room["viewport"]
		if vp is SubViewport:
			(vp as SubViewport).render_target_update_mode = (SubViewport.UPDATE_ALWAYS
					if int(room["id"]) == id else SubViewport.UPDATE_DISABLED)


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
	var play_btn := Button.new()
	play_btn.text = "Jogar"
	play_btn.pressed.connect(_on_play_room.bind(id))
	row.add_child(play_btn)
	var observe_btn := Button.new()
	observe_btn.text = "Observando" if id == _observing_id else "Observar"
	observe_btn.disabled = id == _observing_id
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

func _make_panel(title_text: String) -> VBoxContainer:
	_panel = PanelContainer.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_panel.custom_minimum_size = Vector2(540, 0)
	add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	_panel.add_child(margin)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 14)
	margin.add_child(inner)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 28)
	inner.add_child(title)
	return inner


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


func _make_back_button(parent: VBoxContainer) -> void:
	var back_btn := Button.new()
	back_btn.text = "Voltar"
	back_btn.custom_minimum_size = Vector2(0, 44)
	back_btn.pressed.connect(_go_back)
	parent.add_child(back_btn)


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

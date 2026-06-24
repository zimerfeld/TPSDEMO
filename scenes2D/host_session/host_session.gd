extends Control
## Hub de SALAS (servidor multi-level). Dois modos, decididos pelo papel na rede:
##  • SERVIDOR (host): grade de gerência — iniciar/parar/reiniciar e OBSERVAR cada level ativo
##    (cada sala num SubViewport com World3D próprio; só a observada renderiza).
##  • CLIENTE: navegador de salas do servidor — escolhe uma e ENTRA (spawna seu player nela). A
##    sala do cliente é um Node comum (renderiza na janela principal → input/câmera normais).
##
## O peer NÃO é fechado ao navegar aqui; só ao "Voltar ao menu". Ver [[RoomManager]] / [[sistemas/salas]].

signal quit

const LEVELS := [
	{"label": "Level 1", "path": "res://scenes3D/level_1/level_1.tscn"},
	{"label": "Level 2", "path": "res://scenes3D/level_2/level_2.tscn"},
	{"label": "Level Base", "path": "res://scenes3D/level_base/level_base.tscn"},
]

var _server_mode: bool = true
var _joined: bool = false          # cliente: já entrou numa sala (jogando)
var _observing_id: int = -1        # servidor: sala observada (-1 = grade)

var _room_view: TextureRect
var _panel: PanelContainer
var _level_picker: OptionButton
var _rooms_list: VBoxContainer
var _hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A raiz não captura mouse (o painel/botões sim); ao esconder o painel, o jogo recebe o input.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_server_mode = multiplayer.is_server()
	if _server_mode:
		_build_server_ui()
		RoomManager.rooms_changed.connect(_refresh_rooms)
		if PlayerSelection.level_path != "":
			RoomManager.start_room(PlayerSelection.level_path)
		_refresh_rooms()
		_set_observing(-1)
	else:
		_build_client_ui()
		RoomManager.rooms_changed.connect(_refresh_rooms)
		RoomManager.request_room_list.rpc_id(1)  # pede a lista de salas ao servidor
		_refresh_rooms()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


# Encerrar (voltar ao menu) → libera as salas (vivem no autoload persistente).
func _exit_tree() -> void:
	RoomManager.stop_all()


# ───────────────────────────── SERVIDOR (gerência) ─────────────────────────────

func _build_server_ui() -> void:
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

	_hint = _make_hint("Observando — ESC volta à gerência | WASD voa | Espaço+W/S sobe/desce")


func _on_start_pressed() -> void:
	var idx: int = _level_picker.selected
	if idx < 0:
		return
	RoomManager.start_room(String(_level_picker.get_item_metadata(idx)))
	_apply_mouse_mode()


func _set_observing(id: int) -> void:
	_observing_id = id
	for room in RoomManager.get_rooms():
		var vp: Variant = room["viewport"]
		if vp is SubViewport:
			(vp as SubViewport).render_target_update_mode = (SubViewport.UPDATE_ALWAYS
					if int(room["id"]) == id else SubViewport.UPDATE_DISABLED)
	if id >= 0:
		var room := RoomManager.get_room(id)
		if not room.is_empty() and room["viewport"] is SubViewport:
			_room_view.texture = (room["viewport"] as SubViewport).get_texture()
		_room_view.visible = true
		_panel.visible = false
		_hint.visible = true
	else:
		_room_view.visible = false
		_room_view.texture = null
		_panel.visible = true
		_hint.visible = false
	_apply_mouse_mode()
	_refresh_rooms()


func _apply_mouse_mode() -> void:
	Input.set_mouse_mode(
		Input.MOUSE_MODE_CAPTURED if _observing_id >= 0 else Input.MOUSE_MODE_VISIBLE)


# ───────────────────────────── CLIENTE (navegador) ─────────────────────────────

func _build_client_ui() -> void:
	var inner := _make_panel("Salas disponíveis no servidor")
	var info := Label.new()
	info.text = "Escolha uma sala para entrar:"
	info.add_theme_font_size_override("font_size", 18)
	inner.add_child(info)
	_rooms_list = _make_rooms_list(inner, "")
	_make_back_button(inner)


func _on_join_pressed(room_id: int, level_path: String) -> void:
	RoomManager.client_join_room(room_id, level_path, PlayerSelection.variant_id)
	_joined = true
	_panel.visible = false                       # esconde a UI → o jogo (janela principal) aparece
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# ───────────────────────────── lista de salas (ambos os modos) ─────────────────────────────

func _refresh_rooms() -> void:
	if not is_instance_valid(_rooms_list):
		return
	for c in _rooms_list.get_children():
		c.queue_free()
	if _server_mode:
		if _observing_id >= 0 and not RoomManager.has_room(_observing_id):
			_set_observing(-1)
		for room in RoomManager.get_rooms():
			_rooms_list.add_child(_make_server_row(room))
	else:
		for r in RoomManager.server_room_list():
			_rooms_list.add_child(_make_client_row(r))


func _make_server_row(room: Dictionary) -> Control:
	var id: int = int(room["id"])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = "Sala #%d — %s" % [id, RoomManager.level_label(String(room["level_path"]))]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
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


func _make_client_row(r: Dictionary) -> Control:
	var id: int = int(r["id"])
	var path: String = String(r["level_path"])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.text = "Sala #%d — %s  (%d jogador%s)" % [
		id, RoomManager.level_label(path), int(r.get("players", 0)),
		"" if int(r.get("players", 0)) == 1 else "es"]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	var join_btn := Button.new()
	join_btn.text = "Entrar"
	join_btn.pressed.connect(_on_join_pressed.bind(id, path))
	row.add_child(join_btn)
	return row


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
	back_btn.text = "Voltar ao menu"
	back_btn.custom_minimum_size = Vector2(0, 44)
	back_btn.pressed.connect(func() -> void: quit.emit())
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


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"quit"):
		if _server_mode and _observing_id >= 0:
			_set_observing(-1)          # servidor: 1º ESC sai da observação
		else:
			quit.emit()                 # senão encerra (servidor sai; cliente desconecta)
		get_viewport().set_input_as_handled()
		return
	# Servidor observando: empurra o mouse p/ a sala (câmera livre olha em volta).
	if _server_mode and _observing_id >= 0 and event is InputEventMouseMotion:
		var room := RoomManager.get_room(_observing_id)
		if not room.is_empty() and room["viewport"] is SubViewport:
			(room["viewport"] as SubViewport).push_input(event)

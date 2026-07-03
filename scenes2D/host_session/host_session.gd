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
]
const PLAYONLINE_PATH: String = "res://scenes2D/playonline/playonline.tscn"
const CHOOSEPLAYER_PATH: String = "res://scenes2D/chooseplayer/chooseplayer.tscn"
const HOST_SESSION_PATH: String = "res://scenes2D/host_session/host_session.tscn"
const TemplateManagerScene := preload("res://scenes2D/template_manager/template_manager.tscn")

var _observing_id: int = -1        # sala observada (-1 = grade)
var _playing_id: int = -1          # sala em que o host JOGA (-1 = não joga)

var _confirm_dialog: FloatingWindow = null

# Scaffold ESTÁTICO no .tscn (2026-06-30): RoomView/painel/pickers/lista/Voltar/Actions vêm da cena; o
# código só popula os pickers + as linhas de sala (dinâmicas) e religa o foco. Antes a tela inteira era
# montada em runtime.
@onready var _room_view: TextureRect = %RoomView
@onready var _panel: Control = %ManagePanel
@onready var _level_picker: OptionButton = %Levels
@onready var _template_picker: OptionButton = %Templates
@onready var _rooms_list: VBoxContainer = %RoomsList
@onready var _hint: Label = %Hint
@onready var _actions_bar: HBoxContainer = %Actions
@onready var _back_button: Button = %Back
@onready var _manage_templates_button: Button = %ManageTemplates
@onready var _start_button: Button = %Start
@onready var _signal_layer: ColorRect = %SignalLayer


func _ready() -> void:
	# Tema/mouse_filter e todo o scaffold vêm do .tscn. Ajusta só o aspecto dos anéis do shader (depende
	# da viewport); ring_color/dir já estão no material da cena. Depois popula os pickers e conecta tudo.
	var mat := _signal_layer.material as ShaderMaterial
	if mat != null:
		var sz: Vector2 = get_viewport().get_visible_rect().size
		mat.set_shader_parameter("aspect", sz.x / maxf(sz.y, 1.0))
	_populate_level_picker()
	_level_picker.item_selected.connect(func(_idx: int) -> void: _refresh_template_picker())
	_manage_templates_button.pressed.connect(_open_template_dialog_for_selected_level)
	_start_button.pressed.connect(_on_start_pressed)
	_back_button.pressed.connect(_go_back)
	_refresh_template_picker()
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
	# Toggle "Debug 2D" na barra Actions (injetado pelo DebugOverlay como nas demais telas) + sequência
	# de Tab. Re-liga ao injetar o toggle e ao remontar as salas; foco inicial no controle de Tab = 1.
	_actions_bar.child_entered_tree.connect(func(_n: Node) -> void: _rewire_tab.call_deferred())
	_rewire_tab.call_deferred()
	UINav.focus_tab_one.call_deferred(self)


# Popula o seletor de level (estático no .tscn): sentinela "Selecione..." (item 0) + os LEVELS, cada um
# carregando seu caminho na metadata do item.
func _populate_level_picker() -> void:
	_level_picker.clear()
	_level_picker.add_item("Selecione...")  # item 0 = sentinela (sem metadata; convenção do projeto)
	for lv in LEVELS:
		_level_picker.add_item(String(lv["label"]))
		_level_picker.set_item_metadata(_level_picker.item_count - 1, String(lv["path"]))


# (Re)liga a sequência de Tab da grade NUMERANDO em ordem de leitura (lista variável): pickers/botões da
# StartRow (1-4) → botões habilitados de cada linha de sala (Jogar/Observar/Reiniciar/Parar) → Voltar →
# Debug 2D. Botões desabilitados (ex.: "servidor puro") ficam fora. Numerar por código é necessário pois
# o nº de salas varia em runtime. Idempotente: re-chamada quando as salas/visibilidade mudam.
func _rewire_tab() -> void:
	var i := 1
	for c in [_level_picker, _template_picker, _manage_templates_button, _start_button]:
		(c as Control).set_meta(UINav.TAB_ORDER_META, i)
		i += 1
	for row in _rooms_list.get_children():
		for child in row.get_children():
			if child is BaseButton and not (child as BaseButton).disabled:
				(child as Control).set_meta(UINav.TAB_ORDER_META, i)
				i += 1
	_back_button.set_meta(UINav.TAB_ORDER_META, i)
	i += 1
	var dbg := _actions_bar.get_node_or_null("Debug2D")
	if dbg != null:
		(dbg as Control).set_meta(UINav.TAB_ORDER_META, i)
	UINav.wire_tab_ring(self)


func _on_start_pressed() -> void:
	var idx: int = _level_picker.selected
	if idx <= 0:  # item 0 = "Selecione..."
		return
	var level_path := String(_level_picker.get_item_metadata(idx))
	if _template_picker.selected > 0:
		CharacterTemplateManager.set_active(level_path, String(_template_picker.get_item_metadata(_template_picker.selected)))
	else:
		CharacterTemplateManager.set_active(level_path, "")
	RoomManager.start_room(level_path)
	_apply_mouse_mode()


func _refresh_template_picker() -> void:
	if not is_instance_valid(_template_picker):
		return
	_template_picker.clear()
	_template_picker.add_item("Template: padrão do level")
	var idx: int = _level_picker.selected
	if idx <= 0:
		return
	var level_path := String(_level_picker.get_item_metadata(idx))
	var active_id := CharacterTemplateManager.active_id(level_path)
	for t in CharacterTemplateManager.templates_for_level(level_path):
		_template_picker.add_item(String(t.get("name", "Template")))
		_template_picker.set_item_metadata(_template_picker.item_count - 1, String(t.get("id", "")))
		if String(t.get("id", "")) == active_id:
			_template_picker.select(_template_picker.item_count - 1)


func _open_template_dialog_for_selected_level() -> void:
	var idx: int = _level_picker.selected
	if idx <= 0:
		# Antes retornava em SILÊNCIO com o picker no "Selecione..." — parecia botão quebrado.
		# Agora avisa o que falta para abrir o gerenciador.
		FloatingDialog.alert(self, "Gerenciador de Templates",
				"Selecione um level primeiro para gerenciar seus templates.")
		return
	var form := TemplateManagerScene.instantiate() as TemplateFormBase
	form.templates_changed.connect(_refresh_template_picker)
	form.open_over(self, String(_level_picker.get_item_metadata(idx)))


# Botão "Reiniciar" de uma sala: recria o nível do zero (e avisa os clientes dela — ver
# RoomManager.restart_room). O restart é acionado pela GRADE de gerência, então depois dele
# normalizamos para a grade com o MOUSE VISÍVEL (estado idêntico ao de "Iniciar Sala": a sala
# recriada aparece fresquinha na lista, sem capturar o mouse nem deixar a tela num estado morto).
# Robustez: se por algum fluxo o host estivesse observando/jogando ESTA sala, reentra na recriada.
func _on_restart_room(id: int) -> void:
	var was_playing: bool = _playing_id == id
	var was_observing: bool = _observing_id == id
	var new_id: int = RoomManager.restart_room(id)
	if new_id < 0:
		return
	if was_playing:
		RoomManager.host_spawn_in_room(new_id, PlayerSelection.variant_id)
		_set_playing(new_id)
	elif was_observing:
		_set_observing(new_id)
	else:
		_set_observing(-1)


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
	# As linhas de sala mudaram (novos botões Jogar/Observar/Reiniciar/Parar) → re-liga a sequência.
	_rewire_tab.call_deferred()


func _make_server_row(room: Dictionary) -> Control:
	var id: int = int(room["id"])
	var row := HBoxContainer.new()
	row.name = "RoomRow_%d" % id
	row.add_theme_constant_override("separation", 8)
	var lbl := Label.new()
	lbl.name = "RoomInfo_%d" % id
	# Conexões (clientes remotos) ativas nesta sala. Atualiza ao vivo: o RoomManager emite
	# rooms_changed em join_room/leave_room/_on_peer_disconnected → _refresh_rooms remonta as linhas.
	var conns: int = RoomManager.connections_in_room(id)
	lbl.text = "Sala #%d — %s  (%d %s)" % [
		id, RoomManager.level_label(String(room["level_path"])),
		conns, "conexão" if conns == 1 else "conexões"]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	# Modo "servidor puro" (render do host desligado): não há o que ver, então Jogar/Observar ficam
	# desabilitados (o host só gerencia as salas; iniciar/parar/reiniciar seguem funcionando).
	var render_off: bool = not NetConfig.host_render_observed
	var play_btn := Button.new()
	play_btn.name = "Play_%d" % id
	play_btn.text = "Jogar"
	play_btn.disabled = render_off
	if render_off:
		play_btn.tooltip_text = Locale.tr_key("Render do host desativado (servidor puro)")
	play_btn.pressed.connect(_on_play_room.bind(id))
	row.add_child(play_btn)
	var observe_btn := Button.new()
	observe_btn.name = "Observe_%d" % id
	observe_btn.text = "Observando" if id == _observing_id else "Observar"
	observe_btn.disabled = (id == _observing_id) or render_off
	if render_off:
		observe_btn.tooltip_text = Locale.tr_key("Render do host desativado (servidor puro)")
	observe_btn.pressed.connect(_set_observing.bind(id))
	row.add_child(observe_btn)
	var restart_btn := Button.new()
	restart_btn.name = "Restart_%d" % id
	restart_btn.text = "Reiniciar"
	restart_btn.pressed.connect(_on_restart_room.bind(id))
	row.add_child(restart_btn)
	var stop_btn := Button.new()
	stop_btn.name = "Stop_%d" % id
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
	var dlg := FloatingDialog.confirm(self, "Desconectar", "Desconectar e voltar para a gerência de salas ?", "Sim", "Não")
	dlg.confirmed.connect(func() -> void:
		RoomManager.host_leave_room()
		_set_observing(-1))
	dlg.canceled.connect(func() -> void:
		if _playing_id >= 0:  # cancelou: continua jogando (recaptura o mouse)
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED))
	dlg.closed.connect(func() -> void:
		_confirm_dialog = null)
	_confirm_dialog = dlg


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"quit"):
		get_viewport().set_input_as_handled()   # marca antes da ação: _go_back() libera a cena (viewport vira null depois)
		if _playing_id >= 0:
			_confirm_disconnect()       # jogando: confirma desconectar e voltar à gerência
		elif _observing_id >= 0:
			_set_observing(-1)          # observando: 1º ESC sai da observação
		else:
			_go_back()                  # grade: volta ao PlayOnline (derruba o servidor)
		return
	# Observando OU jogando: empurra o mouse p/ a sala (câmera livre ou mira do player). NUNCA
	# encaminhamos teclas — assim o ESC fica nesta sessão e o nível dentro do SubViewport não o vê.
	if (_observing_id >= 0 or _playing_id >= 0) and event is InputEventMouseMotion:
		var rid: int = _observing_id if _observing_id >= 0 else _playing_id
		var room := RoomManager.get_room(rid)
		if not room.is_empty() and room["viewport"] is SubViewport:
			(room["viewport"] as SubViewport).push_input(event)



extends Node

const _BORDER_WIDTH := 2
const _TOOLTIP_GAP := 4.0

# Layer dos canvases do overlay de debug. Fica ACIMA das janelas flutuantes (FloatingDialog usa um
# CanvasLayer em 128), para o overlay de debug ser SEMPRE trazido à frente — inclusive sobre o diálogo
# de confirmação. O canvas do watermark do nome da cena fica logo acima (_OVERLAY_LAYER + 1).
const _OVERLAY_LAYER := 129
# Intensidade do realce da borda do "host" (controle que contém o apontado), relativa ao realce
# pleno (1.0). Bem fraco de propósito: só situa o controle dentro do contêiner sem competir com ele.
const _HOST_GLOW := 0.18

# Empilhamento (z_index) dentro do canvas do overlay. Os TOOLTIPS (texto) ficam SEMPRE acima das
# BORDAS realçadas — inclusive da borda grossa/brilhante do controle apontado — para que o texto do
# pai e do filho permaneça legível mesmo quando o tooltip é projetado para dentro da área do controle.
const _Z_BORDER_HOST := 0
const _Z_BORDER_HOVERED := 1
const _Z_TOOLTIP_HOST := 2
const _Z_TOOLTIP_HOVERED := 3
const _Debug2DToggle := preload("res://controls2D/debug2d_toggle.gd")

# Janelas flutuantes (Dano/IA/Afastamento-Escala etc.) entram neste grupo. Enquanto QUALQUER uma
# está visível, o Debug 2D some na UI que a chamou: só os controles DENTRO da janela flutuante
# mantêm tooltip/borda — evita poluir a tela com informação demais (ver _suppressed_by_floating).
const FLOATING_WINDOW_GROUP := &"debug_floating_window"

const _PALETTE := [
	Color(1.0, 0.25, 0.25),
	Color(0.25, 0.85, 0.25),
	Color(0.3,  0.6,  1.0),
	Color(1.0,  0.75, 0.1),
	Color(1.0,  0.4,  0.0),
	Color(0.8,  0.2,  1.0),
	Color(0.0,  0.9,  0.9),
	Color(1.0,  0.4,  0.8),
	Color(0.5,  1.0,  0.3),
	Color(0.95, 0.9,  0.15),
]

# Cor de cada LINHA do tooltip 2D (Tipo/Nome/Id), iguais às da cena Models
# (_LABEL_LINE_COLORS em models.gd) — manter em sincronia.
const _LINE_COLORS := {
	"type": Color(1.0, 0.45, 0.85),    # rosa (Tipo)
	"name": Color(0.55, 1.0, 0.55),    # verde (Nome)
	"id": Color(1.0, 0.92, 0.42),      # amarelo (Id)
	"tab": Color(1.0, 1.0, 1.0),       # branco (índice de Tab) — pedido do projeto
	"path": Color(0.45, 0.8, 1.0),     # azul claro (caminho na cena) — diferencia mesmo Type/Name
}

var _canvas_layer: CanvasLayer = null
# inst_id → {tooltip: PanelContainer, ctrl_border: Panel, color: Color}
var _overlay_map: Dictionary = {}
var _fps_label: Label = null
# HUD de versão (build_id) no canto inferior direito — texto estático resolvido de RoomManager.game_version().
var _version_label: Label = null
var _palette_index: int = 0
var _last_scene: Node = null

var _persistent_canvas: CanvasLayer = null
var _scene_name_label: Label = null

# Fase do pulso do realce de iluminação da borda sob o mouse (avança com o tempo em _process).
var _glow_phase: float = 0.0

# inst_id → índice de Tab (1-based) na cadeia de foco da tela ativa. Recalculado a cada
# frame só enquanto a linha "Tab" do Debug 2D está visível (ver _process).
var _tab_index_map: Dictionary = {}


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)
	# O watermark do nome da cena é montado ANTES dos overlays, para que _build_overlays já
	# o encontre e possa lhe anexar o tooltip de Debug 2D na primeira construção.
	call_deferred("_setup_scene_name_label")
	if _is_overlay_active():
		call_deferred("_build_overlays")
	if _is_fps_on():
		call_deferred("_update_fps_hud")
	if _is_version_on():
		call_deferred("_update_version_hud")


# 2D (Control) overlays are shown when the "Show Debug 2D" toggle
# (Settings → Debug) is on.
func _is_debug_2d_on() -> bool:
	return Settings.config_file.get_value("game", "debug_2d", false)


# O overlay (canvas/scan) só é necessário com o Debug 2D ligado (o Debug 3D foi para a Models).
func _is_overlay_active() -> bool:
	return _is_debug_2d_on()


func _is_fps_on() -> bool:
	return Settings.config_file.get_value("game", "hud_fps", false)


func _is_version_on() -> bool:
	return Settings.config_file.get_value("game", "hud_version", false)


# 2D tooltip lines (Debug 2D column).
func _is_show_id_on() -> bool:
	return Settings.config_file.get_value("game", "show_id", false)


func _is_show_type_on() -> bool:
	return Settings.config_file.get_value("game", "show_type", false)


func _is_show_name_on() -> bool:
	return Settings.config_file.get_value("game", "show_name", false)


# Linha "Tab" (branca): mostra o índice de Tab/foco de cada controle nas cenas 2D.
func _is_show_tab_on() -> bool:
	return Settings.config_file.get_value("game", "show_tab", false)


# Linha "Path" (azul claro): caminho do controle na árvore da cena ativa.
func _is_show_path_on() -> bool:
	return Settings.config_file.get_value("game", "show_path", false)


func _has_any_2d_line_enabled() -> bool:
	return _is_show_type_on() or _is_show_name_on() or _is_show_id_on() \
		or _is_show_tab_on() or _is_show_path_on()


# Visibility of a 2D tooltip line ("type" / "name" / "id"). A line shows only when
# Debug 2D is on AND that specific line is selected — Debug 2D being active is not
# enough on its own. Its lines are dependent sub-toggles, exactly like the Debug 3D
# column (no implicit default line).
func _line_visible_2d(kind: String) -> bool:
	if not _is_debug_2d_on():
		return false
	match kind:
		"type": return _is_show_type_on()
		"name": return _is_show_name_on()
		"id": return _is_show_id_on()
		"tab": return _is_show_tab_on()
		"path": return _is_show_path_on()
	return false


# Numera os controles na ordem real de navegação por Tab: parte do início da cadeia ativa e segue
# find_next_valid_focus() até fechar o ciclo. Preenche _tab_index_map (inst_id → índice 1-based).
# Controles não focáveis ficam de fora (mostram "TAB: -").
func _compute_tab_indices() -> void:
	_tab_index_map.clear()
	var cur: Control = _tab_chain_start()
	var idx := 1
	var guard := 0
	while cur != null and guard < 4096:
		var cid := cur.get_instance_id()
		if _tab_index_map.has(cid):
			break
		_tab_index_map[cid] = idx
		idx += 1
		guard += 1
		cur = cur.find_next_valid_focus()


# Onde começar a numeração de Tab. Com janela(s) flutuante(s) aberta(s), numera a cadeia DA JANELA (o
# fundo está suprimido): começa no 1º controle DEPOIS do × dela, para o × — que fica por último no anel
# — receber o MAIOR índice. Sem janela, começa no 1º focável da tela ativa (ordem de leitura).
func _tab_chain_start() -> Control:
	var windows := _active_floating_windows()
	if not windows.is_empty():
		var win := windows.back() as Control
		var close_btn := UINav.first_focusable(win)   # ordem de árvore: o botão × vem 1º
		if close_btn == null:
			return null
		var after := close_btn.find_next_valid_focus()
		return after if after != null else close_btn
	var screen := _active_screen_root()
	return UINav.first_focusable(screen) if screen != null else null


# Janelas flutuantes VISÍVEIS agora (nós do FLOATING_WINDOW_GROUP). Nós já liberados/escondidos
# ficam de fora — então abrir/fechar uma janela liga/desliga a supressão sem bookkeeping manual.
func _active_floating_windows() -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group(FLOATING_WINDOW_GROUP):
		if n is Control and (n as Control).is_visible_in_tree():
			out.append(n)
	return out


# True quando há janela(s) flutuante(s) aberta(s) E o controle NÃO está dentro de nenhuma delas —
# i.e., pertence à UI de fundo que a chamou, cujo overlay 2D some. Sem janela aberta: nunca suprime.
func _suppressed_by_floating(ctrl: Control, focus_windows: Array) -> bool:
	if focus_windows.is_empty():
		return false
	for win in focus_windows:
		var w := win as Control
		if w == ctrl or w.is_ancestor_of(ctrl):
			return false
	return true


func refresh() -> void:
	_clear_all()
	if _is_overlay_active():
		_build_overlays()
	_update_fps_hud()
	_update_version_hud()


func _setup_scene_name_label() -> void:
	if not is_instance_valid(_persistent_canvas):
		_persistent_canvas = CanvasLayer.new()
		_persistent_canvas.layer = _OVERLAY_LAYER + 1
		_persistent_canvas.name = "DebugSceneCanvas"
		get_tree().root.add_child(_persistent_canvas)
	_scene_name_label = Label.new()
	_scene_name_label.name = "SceneName"   # nome legível na linha "Name:" do tooltip 2D
	_scene_name_label.add_theme_font_size_override("font_size", 13)
	_scene_name_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.65))
	_scene_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	_scene_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_scene_name_label.add_theme_constant_override("shadow_offset_y", 1)
	_scene_name_label.add_theme_constant_override("shadow_as_outline", 1)
	_scene_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scene_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_scene_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# À DIREITA do título da cena: encostado na borda direita do topo e na mesma faixa
	# vertical do título da cena (offset_top 38 / offset_bottom 96, padrão das telas 2D).
	_scene_name_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_scene_name_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_scene_name_label.offset_left = -320.0
	_scene_name_label.offset_top = 38.0
	_scene_name_label.offset_right = -12.0
	_scene_name_label.offset_bottom = 96.0
	_persistent_canvas.add_child(_scene_name_label)


# main.gd swaps menu/gameplay scenes in as children of the root scene instead of
# using SceneTree.change_scene, so current_scene stays main.tscn. Surface the
# instance (node) name of the screen actually loaded into the runtime — e.g.
# "Menu", "Levels", "Level1" — instead of relying on current_scene.
func _active_screen_root() -> Node:
	var root_scene := get_tree().current_scene
	if root_scene == null:
		return null
	var loaded: Node = null
	for child in root_scene.get_children():
		if child.scene_file_path != "" and child.scene_file_path != root_scene.scene_file_path:
			loaded = child
	return loaded if loaded != null else root_scene


func _active_screen_name() -> String:
	var target := _active_screen_root()
	# String(...) porque Node.name é StringName e o retorno é String (evita warning de ternário).
	return String(target.name) if target != null else ""


# Injeta (uma vez) o toggle de Debug 2D na barra "Actions" da tela ativa. Toda cena 2D com uma
# Actions ganha o controle — exceto a developer, que injeta o SEU próprio (developer.gd) para mantê-lo
# em sincronia com o par Desativado/Ativado da sua coluna Debug 2D.
# Idempotente: não duplica; telas sem Actions (ex.: menu, levels de gameplay) são ignoradas.
func _ensure_debug2d_toggle(screen: Node) -> void:
	# is_instance_valid: a tela pode ter sido liberada entre o call_deferred e esta execução.
	if not is_instance_valid(screen) or screen.scene_file_path.ends_with("developer.tscn"):
		return
	# NUNCA em cena de LEVEL (gameplay 3D): os levels (level_1/level_2) raízam num Node3D e têm uma barra
	# Actions no TitleCanvas — o toggle Debug 2D é de TELAS 2D de UI, não do jogo em si. A tela Models
	# (scenes3D/models) raíza num Node comum, então NÃO cai neste guard e segue recebendo o toggle.
	if screen is Node3D:
		return
	var actions := screen.find_child("Actions", true, false)
	if not (actions is HBoxContainer) or actions.has_node("Debug2D"):
		return
	# O texto é definido ANTES de add_child para o auto-localizador (Locale) capturá-lo como fonte.
	var toggle := _Debug2DToggle.new()
	toggle.name = "Debug2D"
	toggle.text = "Debug 2D"
	# TAB explícito: o toggle é o ÚLTIMO da tela → maior tab_order declarado + 1 (ex.: chooseplayer 7,
	# menu 8). Só quando a tela declara tab_order (max > 0); em telas que numeram por código/ordem de
	# árvore (ex.: client/host_session, que renumeram no seu _rewire_tab) NÃO marcamos aqui — senão o
	# toggle viraria TAB 1 e iria para o início do anel. Ver [[convencoes/navegacao-tab]].
	var max_order := _max_declared_tab_order(screen)
	if max_order > 0:
		toggle.set_meta(UINav.TAB_ORDER_META, max_order + 1)
	actions.add_child(toggle)


# Maior tab_order DECLARADO (metadata/tab_order) entre os Controls da tela, ou 0 se nenhum.
func _max_declared_tab_order(screen: Node) -> int:
	var m := 0
	for n in screen.find_children("*", "Control", true, false):
		var o: int = UINav.tab_order_of(n)
		if o < (1 << 30) and o > m:
			m = o
	return m


func _process(delta: float) -> void:
	_glow_phase += delta
	if is_instance_valid(_fps_label):
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	if is_instance_valid(_scene_name_label):
		_scene_name_label.text = _active_screen_name()

	# Recreate the grid when the loaded screen changes (e.g. entering a level or the
	# Modelos 3D screen). Track the active loaded screen, not current_scene (which is
	# always Main since main.gd swaps screens as its children).
	var current := _active_screen_root()
	if current != _last_scene:
		_last_scene = current
		# Nova tela carregada (level, chooseplayer, etc.): reconstrói TODOS os overlays para
		# que os toggles Debug 2D/3D também valham nela — não só na tela onde foram ligados.
		# (Antes dependia só de _on_node_added, que tinha brechas de timing no carregamento.)
		call_deferred("refresh")
		# Garante o toggle de Debug 2D na barra Actions da tela (menos a developer).
		call_deferred("_ensure_debug2d_toggle", current)

	if _canvas_layer == null:
		return

	# A linha "Tab" mostra a ordem de foco da tela ATIVA, que muda conforme controles
	# aparecem/somem — então recalcula o mapa a cada frame, só quando ela está visível.
	var tab_visible := _line_visible_2d("tab")
	if tab_visible:
		_compute_tab_indices()

	# Janelas flutuantes abertas agora: enquanto houver alguma, o overlay 2D some na UI de fundo
	# que a chamou (só os controles DENTRO da janela mantêm tooltip/borda).
	var focus_windows := _active_floating_windows()

	# O overlay 2D agora é um INSPETOR POR HOVER: a borda + o tooltip aparecem SÓ no controle sob o
	# cursor; todos os demais ficam ocultos. Apontamos o de MENOR área entre os que contêm o mouse
	# (o mais específico/interno). "Elegível" = visível na árvore, com ≥1 linha do Debug 2D ligada e
	# não suprimido por janela flutuante — mesma condição que antes liberava a borda.
	var any_2d_line := _has_any_2d_line_enabled()
	var mouse_pos := get_viewport().get_mouse_position()
	var hov_id: int = 0
	var hov_area: float = INF

	# Passo 1: limpa entradas órfãs, esconde TODO o overlay e acha o controle apontado.
	var to_erase: Array = []
	for inst_id in _overlay_map:
		var obj := instance_from_id(inst_id)
		var entry: Dictionary = _overlay_map[inst_id]
		var tooltip: PanelContainer = entry.tooltip
		var ctrl_border: Panel = entry.ctrl_border
		if not (is_instance_valid(obj) and is_instance_valid(tooltip)):
			if is_instance_valid(tooltip):
				tooltip.queue_free()
			if is_instance_valid(ctrl_border):
				ctrl_border.queue_free()
			to_erase.append(inst_id)
			continue
		var ctrl := obj as Control
		# Com uma janela flutuante aberta, o overlay da UI de fundo que a chamou fica suprimido.
		var eligible := ctrl.is_visible_in_tree() and any_2d_line \
			and not _suppressed_by_floating(ctrl, focus_windows)
		if eligible:
			# Rect em coordenadas de TELA (mapeia controles dentro de SubViewport — ver _screen_rect_of).
			var rect: Rect2 = _screen_rect_of(ctrl)
			if rect.has_point(mouse_pos):
				var area: float = rect.size.x * rect.size.y
				if area < hov_area:
					hov_area = area
					hov_id = inst_id
		# Por padrão tudo fica escondido; o passo 2 reexibe apenas o controle apontado.
		tooltip.visible = false
		if is_instance_valid(ctrl_border):
			ctrl_border.visible = false
	for k in to_erase:
		_overlay_map.erase(k)

	# Passo 2: exibe o overlay (borda + tooltip) do controle apontado e, se ele estiver DENTRO de outro
	# controle, também o do seu "host" (ancestral mais próximo). As linhas são iguais nos dois; o
	# _layout_tooltips depois posiciona primeiro o apontado e depois o host SEM sobrepô-lo (host × filho).
	# O brilho do host sai bem mais fraco (ver _apply_border_glow).
	var host_id: int = 0
	if hov_id != 0:
		_show_overlay_for(hov_id, tab_visible)
		host_id = _host_id_of(instance_from_id(hov_id) as Control)
		if host_id != 0:
			_show_overlay_for(host_id, tab_visible)

	_apply_border_glow(hov_id, host_id)
	# Posiciona PRIMEIRO o tooltip do controle apontado e DEPOIS o do host (sem sobrepô-lo).
	_layout_tooltips(hov_id, host_id)


# Posiciona e exibe o overlay (borda + tooltip, com as linhas Type/Name/Id/Tab escolhidas) de UM
# controle do _overlay_map. Usado tanto para o controle apontado quanto para o seu host.
func _show_overlay_for(inst_id: int, tab_visible: bool) -> void:
	var entry: Dictionary = _overlay_map[inst_id]
	var ctrl := instance_from_id(inst_id) as Control
	if not is_instance_valid(ctrl):
		return
	var tooltip: PanelContainer = entry.tooltip
	var ctrl_border: Panel = entry.ctrl_border
	var rect: Rect2 = _screen_rect_of(ctrl)
	if is_instance_valid(ctrl_border):
		ctrl_border.position = rect.position
		ctrl_border.size = rect.size
		ctrl_border.visible = true
	# A posição final do tooltip é resolvida em _layout_tooltips (regra dos 4 cantos), que posiciona
	# primeiro o controle apontado e depois o host sem sobrepô-lo. Vale para TODO controle, inclusive
	# o título da cena (Title), que segue a mesma regra dos demais.
	entry.type_lbl.visible = _line_visible_2d("type")
	entry.name_lbl.visible = _line_visible_2d("name")
	entry.id_lbl.visible = _line_visible_2d("id")
	entry.tab_lbl.visible = tab_visible
	if tab_visible:
		# Preferimos o valor ESPERADO declarado no .tscn (metadata/tab_order) — assim a linha Tab é
		# previsível e independe da cadeia de foco viva. Sem o metadado, cai no índice CALCULADO pela
		# cadeia real (find_next_valid_focus). Ver UINav.TAB_ORDER_META / [[convencoes/navegacao-tab]].
		var declared := UINav.tab_order_of(ctrl)
		if declared < (1 << 30):
			entry.tab_lbl.text = "TAB: %d" % declared
		else:
			var ti: int = _tab_index_map.get(inst_id, -1)
			entry.tab_lbl.text = "TAB: %d" % ti if ti > 0 else "TAB: -"
	var path_visible := _line_visible_2d("path")
	entry.path_lbl.visible = path_visible
	if path_visible:
		entry.path_lbl.text = "PATH: %s" % _scene_path_of(ctrl)
	tooltip.visible = (
		entry.type_lbl.visible
		or entry.name_lbl.visible
		or entry.id_lbl.visible
		or entry.tab_lbl.visible
		or entry.path_lbl.visible
	)


# Realça a borda do controle sob o cursor com um "efeito de iluminação": borda mais clara e grossa
# + brilho (shadow colorido, sem deslocamento) pulsando suavemente. O `host_id` (controle que CONTÉM
# o apontado) recebe o MESMO efeito, porém com intensidade bem menor (`_HOST_GLOW`), só p/ situar o
# controle no seu contêiner. Os demais voltam ao estado normal UMA vez (flag glow_on) — evita
# reescrever o StyleBox de todos a cada frame. Empilhamento: os TOOLTIPS (texto) ficam SEMPRE acima
# das BORDAS (ver _Z_*), para o texto do pai e do filho seguir legível mesmo projetado sobre o realce.
func _apply_border_glow(hovered_id: int, host_id: int) -> void:
	var pulse: float = 0.5 + 0.5 * sin(fmod(_glow_phase * 5.0, TAU))
	for inst_id in _overlay_map:
		var entry: Dictionary = _overlay_map[inst_id]
		var border: Panel = entry.ctrl_border
		var style: StyleBoxFlat = entry.border_style
		if not is_instance_valid(border) or style == null:
			continue
		if inst_id == hovered_id and border.visible:
			_set_border_lit(style, entry.color, pulse, 1.0)
			border.z_index = _Z_BORDER_HOVERED
			if is_instance_valid(entry.tooltip):
				entry.tooltip.z_index = _Z_TOOLTIP_HOVERED
			entry.glow_on = true
		elif inst_id == host_id and border.visible:
			_set_border_lit(style, entry.color, pulse, _HOST_GLOW)
			border.z_index = _Z_BORDER_HOST
			if is_instance_valid(entry.tooltip):
				entry.tooltip.z_index = _Z_TOOLTIP_HOST
			entry.glow_on = true
		elif entry.get("glow_on", false):
			_set_border_normal(style, entry.color)
			border.z_index = _Z_BORDER_HOST
			if is_instance_valid(entry.tooltip):
				entry.tooltip.z_index = _Z_TOOLTIP_HOST
			entry.glow_on = false


# Caminho do controle na árvore da cena ativa (para a linha PATH). Diferencia controles com o mesmo
# Type/Name. Encurta para os 3 últimos segmentos (prefixados com "…/") quando o caminho é longo — o
# segmento que distingue costuma estar perto do fim. Fora da tela ativa (ex.: o label persistente do
# nome da cena), cai no nome do nó.
func _scene_path_of(ctrl: Control) -> String:
	var root := _active_screen_root()
	if root != null and is_instance_valid(root) and root != ctrl and root.is_ancestor_of(ctrl):
		var segs := String(root.get_path_to(ctrl)).split("/")
		if segs.size() > 3:
			return "…/" + "/".join(segs.slice(segs.size() - 3))
		return "/".join(segs)
	return String(ctrl.name)


# inst_id do ancestral mais próximo que é Control E está rastreado no overlay (o "host" do controle
# apontado), ou 0 se não houver. Como o _tag rotula TODO Control, isso dá o Control-pai imediato.
func _host_id_of(ctrl: Control) -> int:
	var p := ctrl.get_parent()
	while p != null:
		if p is Control:
			var pid := p.get_instance_id()
			if _overlay_map.has(pid):
				return pid
		p = p.get_parent()
	return 0


func _set_border_normal(style: StyleBoxFlat, color: Color) -> void:
	style.border_color = color
	style.set_border_width_all(_BORDER_WIDTH)
	style.shadow_size = 0
	style.shadow_color = Color(0, 0, 0, 0)
	style.shadow_offset = Vector2.ZERO


# intensity: 1.0 = realce pleno (controle apontado); ~_HOST_GLOW = brilho fraco (host/contêiner).
func _set_border_lit(style: StyleBoxFlat, color: Color, pulse: float, intensity: float) -> void:
	style.border_color = color.lightened(0.5 * intensity)
	style.set_border_width_all(_BORDER_WIDTH + int(round(2.0 * intensity)))
	style.shadow_color = Color(color.r, color.g, color.b, 0.55 * intensity)
	style.shadow_size = int(round(lerpf(6.0, 12.0, pulse) * intensity))
	style.shadow_offset = Vector2.ZERO


# Prende uma posição de tooltip à viewport (canto sup-esq dentro da tela).
func _clamp_pos(pos: Vector2, size: Vector2, vp: Vector2) -> Vector2:
	pos.x = clampf(pos.x, 0.0, maxf(0.0, vp.x - size.x))
	pos.y = clampf(pos.y, 0.0, maxf(0.0, vp.y - size.y))
	return pos


# Posiciona os tooltips do controle apontado e do seu host (os únicos visíveis no inspetor por hover).
# Regra (pedido 2026-06-28): posiciona PRIMEIRO o tooltip do controle apontado e DEPOIS o do host —
# este, além de caber na tela, evita SOBREPOR o do apontado (que já ficou fixo). Cada tooltip escolhe
# um dos 4 cantos do controle pela regra de _pick_corner — inclusive o título da cena (Title).
func _layout_tooltips(hov_id: int, host_id: int) -> void:
	var vp := get_viewport().get_visible_rect().size
	var avoid: Array = []   # rects já fixados que o próximo tooltip deve evitar
	var hov_rect := _place_one_tooltip(hov_id, vp, avoid)
	if hov_rect.size.x > 0.0:
		avoid.append(hov_rect)
	if host_id != 0 and host_id != hov_id:
		_place_one_tooltip(host_id, vp, avoid)


# Posiciona o tooltip de UM controle (apontado ou host) e devolve seu Rect2 de tela (size zero se
# não houver tooltip válido). Usa a regra dos 4 cantos (_pick_corner), evitando os rects em `avoid`.
func _place_one_tooltip(inst_id: int, vp: Vector2, avoid: Array) -> Rect2:
	if inst_id == 0 or not _overlay_map.has(inst_id):
		return Rect2()
	var entry: Dictionary = _overlay_map[inst_id]
	var t: PanelContainer = entry.tooltip
	if not (is_instance_valid(t) and t.visible and t.size.x > 0.0 and t.size.y > 0.0):
		return Rect2()
	var ctrl := instance_from_id(inst_id) as Control
	if not is_instance_valid(ctrl):
		return Rect2()
	t.position = _pick_corner(_screen_rect_of(ctrl), t.size, vp, avoid)
	return Rect2(t.position, t.size)


# Escolhe a posição do tooltip entre 4 cantos do controle, NESTA ordem de prioridade:
#   1) à direita do canto superior-direito;
#   2) à esquerda do canto superior-esquerdo;
#   3) à direita do canto inferior-direito;
#   4) à esquerda do canto inferior-esquerdo.
# Retorna o primeiro canto EXTERNO que cabe INTEIRO na tela E não sobrepõe nenhum rect de `avoid`.
# Se nenhum atende aos dois (caso típico do host: contêiner grande cujos 4 cantos externos esbarram
# na tela ou no tooltip do filho já fixado), PROJETA o tooltip PARA DENTRO da área do controle, num
# ponto que caiba na tela e não colida — garantindo a regra de nunca sobrepor pai × filho. Só se nem
# isso couber é que relaxa (aceita o primeiro que ao menos cabe na tela); último recurso: prende o
# canto preferido (1) à viewport.
func _pick_corner(rect: Rect2, size: Vector2, vp: Vector2, avoid: Array) -> Vector2:
	var g := _TOOLTIP_GAP
	var candidates: Array = [
		Vector2(rect.end.x + g, rect.position.y),                    # 1. direita do canto sup-dir
		Vector2(rect.position.x - size.x - g, rect.position.y),      # 2. esquerda do canto sup-esq
		Vector2(rect.end.x + g, rect.end.y - size.y),               # 3. direita do canto inf-dir
		Vector2(rect.position.x - size.x - g, rect.end.y - size.y),  # 4. esquerda do canto inf-esq
	]
	for pos in candidates:
		if _fits_viewport(pos, size, vp) and not _overlaps_any(pos, size, avoid):
			return pos
	# Nenhum canto externo serve sem colisão: reposiciona o tooltip PARA DENTRO da área do controle.
	var inside := _project_into_rect(rect, size, vp, avoid)
	if inside.x >= 0.0:    # x<0 é sentinela de "não há ponto interno livre"
		return inside
	for pos in candidates:
		if _fits_viewport(pos, size, vp):
			return pos
	return _clamp_pos(candidates[0], size, vp)


# Projeta o tooltip PARA DENTRO da área do controle: procura um ponto interno — começando pelos 4
# cantos internos do rect — que caiba INTEIRO na tela E não sobreponha nenhum rect de `avoid`. É o
# recurso para o host (contêiner que envolve o controle apontado) quando os 4 cantos externos não
# servem: como o rect do host é grande, sobra espaço interno longe do tooltip do filho. Devolve o
# ponto, ou Vector2(-1, -1) quando a área interna não comporta o tooltip sem colidir.
func _project_into_rect(rect: Rect2, size: Vector2, vp: Vector2, avoid: Array) -> Vector2:
	var g := _TOOLTIP_GAP
	var inner: Array = [
		Vector2(rect.position.x + g, rect.position.y + g),             # canto interno sup-esq
		Vector2(rect.end.x - size.x - g, rect.position.y + g),         # canto interno sup-dir
		Vector2(rect.position.x + g, rect.end.y - size.y - g),         # canto interno inf-esq
		Vector2(rect.end.x - size.x - g, rect.end.y - size.y - g),     # canto interno inf-dir
	]
	for pos in inner:
		if _fits_viewport(pos, size, vp) and not _overlaps_any(pos, size, avoid):
			return pos
	return Vector2(-1.0, -1.0)


# True se o rect (pos+size) cabe inteiro dentro da viewport (0,0)–(vp).
func _fits_viewport(pos: Vector2, size: Vector2, vp: Vector2) -> bool:
	return pos.x >= 0.0 and pos.y >= 0.0 and pos.x + size.x <= vp.x and pos.y + size.y <= vp.y


# True se o rect (pos+size) intersecta algum dos rects de `avoid`.
func _overlaps_any(pos: Vector2, size: Vector2, avoid: Array) -> bool:
	var r := Rect2(pos, size)
	for other in avoid:
		if r.intersects(other):
			return true
	return false


# Rect do controle em coordenadas de TELA (canvas raiz do overlay). Para controles na viewport
# principal é o próprio get_global_rect(). Para controles DENTRO de um SubViewport (ex.: o preview da
# tela Controles 2D), sobe a cadeia de SubViewports aplicando a posição global e a escala do
# SubViewportContainer (com stretch, escala = tamanho_do_container / tamanho_do_subviewport), senão a
# borda/tooltip ficaria deslocada da posição real do controle na tela.
func _screen_rect_of(ctrl: Control) -> Rect2:
	var rect := ctrl.get_global_rect()
	var vp := ctrl.get_viewport()
	var guard := 0
	while vp is SubViewport and guard < 8:
		guard += 1
		var container := (vp as SubViewport).get_parent() as SubViewportContainer
		if container == null:
			break
		var scale := Vector2.ONE
		var sub_size := Vector2((vp as SubViewport).size)
		if container.stretch and sub_size.x > 0.0 and sub_size.y > 0.0:
			scale = container.size / sub_size
		rect.position = container.get_global_position() + rect.position * scale
		rect.size *= scale
		vp = container.get_viewport()
	return rect


# ── Build / Clear ─────────────────────────────────────────────────────────────

func _build_overlays() -> void:
	_ensure_canvas()
	# Varre a partir da root (não só de current_scene): o HUD 2D e os esqueletos
	# do gameplay (player/enemy) ficam fora de current_scene — o main.gd troca as
	# telas como filhas da root. Assim os overlays 2D e 3D aparecem em qualquer
	# cena, controlados pelos toggles Debug 2D / Debug 3D.
	_scan(get_tree().root)
	# O watermark do nome da cena (canto inferior esquerdo) vive no canvas persistente, que o
	# _scan pula de propósito — então registramos seu tooltip 2D explicitamente quando o
	# Debug 2D está ligado (pedido: o rótulo de nome da cena também deve ter tooltip).
	if _is_debug_2d_on() and is_instance_valid(_scene_name_label):
		_add_2d(_scene_name_label)


func _clear_all() -> void:
	for inst_id in _overlay_map:
		var entry: Dictionary = _overlay_map[inst_id]
		if is_instance_valid(entry.tooltip):
			entry.tooltip.queue_free()
		if is_instance_valid(entry.ctrl_border):
			entry.ctrl_border.queue_free()
	_overlay_map.clear()
	_palette_index = 0

	if is_instance_valid(_canvas_layer):
		_canvas_layer.queue_free()
	_canvas_layer = null
	_fps_label = null
	_version_label = null


func _update_fps_hud() -> void:
	if _is_fps_on():
		_ensure_canvas()
		if not is_instance_valid(_fps_label):
			_fps_label = Label.new()
			_fps_label.add_theme_font_size_override("font_size", 20)
			_fps_label.add_theme_color_override("font_color", Color(0.0, 1.0, 0.0, 0.9))
			_fps_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
			_fps_label.add_theme_constant_override("shadow_offset_x", 1)
			_fps_label.add_theme_constant_override("shadow_offset_y", 1)
			_fps_label.add_theme_constant_override("shadow_as_outline", 1)
			_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_fps_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
			_fps_label.offset_left = -60.0
			_fps_label.offset_top = 8.0
			_fps_label.offset_right = 60.0
			_fps_label.offset_bottom = 36.0
			_canvas_layer.add_child(_fps_label)
	elif is_instance_valid(_fps_label):
		_fps_label.queue_free()
		_fps_label = null


# HUD de versão: rótulo discreto no canto inferior direito com o build_id desta instância — a MESMA
# string que o RoomManager compara no handshake de rede (game_version). No editor mostra "editor-dev";
# no .exe, o build_id carimbado pelo build_windows.ps1. Texto estático (resolvido uma vez).
func _update_version_hud() -> void:
	if _is_version_on():
		_ensure_canvas()
		if not is_instance_valid(_version_label):
			_version_label = Label.new()
			_version_label.add_theme_font_size_override("font_size", 14)
			_version_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.6))
			_version_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
			_version_label.add_theme_constant_override("shadow_offset_x", 1)
			_version_label.add_theme_constant_override("shadow_offset_y", 1)
			_version_label.add_theme_constant_override("shadow_as_outline", 1)
			_version_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_version_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			# Ancorado no canto inferior direito, crescendo para a esquerda/cima (encostado na borda).
			_version_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
			_version_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			_version_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
			_version_label.offset_left = -460.0
			_version_label.offset_top = -34.0
			_version_label.offset_right = -12.0
			_version_label.offset_bottom = -8.0
			_version_label.text = "v " + RoomManager.game_version()
			_canvas_layer.add_child(_version_label)
	elif is_instance_valid(_version_label):
		_version_label.queue_free()
		_version_label = null


func _scan(node: Node) -> void:
	if node == null:
		return
	_tag(node)
	for child in node.get_children():
		_scan(child)


func _tag(node: Node) -> void:
	if not is_instance_valid(node):
		return
	# Não rotula a própria UI de debug (canvas dos overlays 2D e o label de cena).
	if is_instance_valid(_canvas_layer) and _canvas_layer.is_ancestor_of(node):
		return
	if is_instance_valid(_persistent_canvas) and _persistent_canvas.is_ancestor_of(node):
		return
	# Só o Debug 2D (tooltips de controles) é aplicado pelo overlay global, em TODA tela.
	# A inspeção 3D foi movida para a tela Models (overlays próprios sobre o preview).
	if node is Control and not (node is CanvasLayer):
		if _is_debug_2d_on():
			_add_2d(node as Control)


func _add_2d(ctrl: Control) -> void:
	var id := ctrl.get_instance_id()
	if _overlay_map.has(id):
		return
	_ensure_canvas()

	var color := _next_color()
	var rect := _screen_rect_of(ctrl)

	# Colored border around the tracked control
	var ctrl_border := Panel.new()
	var border_style := StyleBoxFlat.new()
	border_style.bg_color = Color(0, 0, 0, 0)
	border_style.border_color = color
	border_style.set_border_width_all(_BORDER_WIDTH)
	ctrl_border.add_theme_stylebox_override("panel", border_style)
	ctrl_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl_border.position = rect.position
	ctrl_border.size = rect.size
	_canvas_layer.add_child(ctrl_border)

	# Tooltip with matching colored border
	var tooltip := PanelContainer.new()
	var tip_style := StyleBoxFlat.new()
	tip_style.bg_color = Color(color.r * 0.1, color.g * 0.1, color.b * 0.1, 0.8)
	tip_style.border_color = color
	tip_style.set_border_width_all(_BORDER_WIDTH)
	tip_style.content_margin_left = 4.0
	tip_style.content_margin_right = 4.0
	tip_style.content_margin_top = 2.0
	tip_style.content_margin_bottom = 2.0
	tooltip.add_theme_stylebox_override("panel", tip_style)
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# One label per line (TYPE / Name / ID, nesta ordem) para que cada uma possa
	# ser ligada/desligada por `visible` conforme show_type/show_name/show_id.
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var type_lbl := _make_overlay_label("TYPE: %s" % ctrl.get_class(), _LINE_COLORS["type"])
	var name_lbl := _make_overlay_label("Name: %s" % ctrl.name, _LINE_COLORS["name"])
	var id_lbl := _make_overlay_label("ID: %d" % id, _LINE_COLORS["id"])
	# Linha branca do índice de Tab; o texto é preenchido a cada frame em _process
	# (o valor depende da ordem de foco viva da tela).
	var tab_lbl := _make_overlay_label("TAB: -", _LINE_COLORS["tab"])
	# Linha azul do caminho na cena; o texto é preenchido a cada frame em _show_overlay_for
	# (o caminho depende da tela ativa e pode mudar se o nó for reparenteado).
	var path_lbl := _make_overlay_label("PATH: -", _LINE_COLORS["path"])
	type_lbl.visible = _line_visible_2d("type")
	name_lbl.visible = _line_visible_2d("name")
	id_lbl.visible = _line_visible_2d("id")
	tab_lbl.visible = _line_visible_2d("tab")
	path_lbl.visible = _line_visible_2d("path")
	# Ordem das linhas = ordem dos toggles na tela developer (Type, Name, Id, Path, Tab).
	vbox.add_child(type_lbl)
	vbox.add_child(name_lbl)
	vbox.add_child(id_lbl)
	vbox.add_child(path_lbl)
	vbox.add_child(tab_lbl)
	tooltip.add_child(vbox)
	tooltip.position = Vector2(rect.position.x + rect.size.x, rect.position.y)
	_canvas_layer.add_child(tooltip)

	_overlay_map[id] = {
		"tooltip": tooltip, "ctrl_border": ctrl_border, "color": color,
		"border_style": border_style, "glow_on": false,
		"type_lbl": type_lbl, "name_lbl": name_lbl, "id_lbl": id_lbl, "tab_lbl": tab_lbl,
		"path_lbl": path_lbl,
	}


func _make_overlay_label(text: String, color: Color = Color(1.0, 1.0, 0.5, 0.95)) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 10)
	# Cor por linha (Tipo/Nome/Id), igual à cena Models (ver _LINE_COLORS).
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.add_theme_constant_override("shadow_as_outline", 1)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return lbl


func _next_color() -> Color:
	var c: Color = _PALETTE[_palette_index % _PALETTE.size()]
	_palette_index += 1
	return c


func _ensure_canvas() -> void:
	if is_instance_valid(_canvas_layer):
		return
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = _OVERLAY_LAYER
	_canvas_layer.name = "DebugOverlayCanvas"
	get_tree().root.add_child(_canvas_layer)


# ── Reactive handlers ─────────────────────────────────────────────────────────

func _on_node_added(node: Node) -> void:
	if not _is_overlay_active():
		return
	call_deferred("_tag", node)


func _on_node_removed(node: Node) -> void:
	var id := node.get_instance_id()
	if _overlay_map.has(id):
		var entry: Dictionary = _overlay_map[id]
		if is_instance_valid(entry.tooltip):
			entry.tooltip.queue_free()
		if is_instance_valid(entry.ctrl_border):
			entry.ctrl_border.queue_free()
		_overlay_map.erase(id)

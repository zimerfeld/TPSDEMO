extends Node

const _BORDER_WIDTH := 2
const _TOOLTIP_GAP := 4.0
const _Debug2DToggle := preload("res://scenes2D/controls2D/debug2d_toggle.gd")

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
}

var _canvas_layer: CanvasLayer = null
# inst_id → {tooltip: PanelContainer, ctrl_border: Panel, color: Color}
var _overlay_map: Dictionary = {}
var _fps_label: Label = null
var _palette_index: int = 0
var _last_scene: Node = null

var _persistent_canvas: CanvasLayer = null
var _scene_name_label: Label = null

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


# 2D (Control) overlays are shown when the "Show Debug 2D" toggle
# (Settings → Debug) is on.
func _is_debug_2d_on() -> bool:
	return Settings.config_file.get_value("game", "debug_2d", false)


# O overlay (canvas/scan) só é necessário com o Debug 2D ligado (o Debug 3D foi para a Models).
func _is_overlay_active() -> bool:
	return _is_debug_2d_on()


func _is_fps_on() -> bool:
	return Settings.config_file.get_value("game", "hud_fps", false)


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


func _has_any_2d_line_enabled() -> bool:
	return _is_show_type_on() or _is_show_name_on() or _is_show_id_on() or _is_show_tab_on()


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
	return false


# Numera os controles na ordem real de navegação por Tab da tela ativa: parte do primeiro
# focável (UINav) e segue find_next_valid_focus() até fechar o ciclo. Preenche _tab_index_map
# (inst_id → índice 1-based). Controles não focáveis ficam de fora (mostram "TAB: -").
func _compute_tab_indices() -> void:
	_tab_index_map.clear()
	var screen := _active_screen_root()
	if screen == null:
		return
	var cur: Control = UINav.first_focusable(screen)
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


func _setup_scene_name_label() -> void:
	if not is_instance_valid(_persistent_canvas):
		_persistent_canvas = CanvasLayer.new()
		_persistent_canvas.layer = 101
		_persistent_canvas.name = "DebugSceneCanvas"
		get_tree().root.add_child(_persistent_canvas)
	_scene_name_label = Label.new()
	_scene_name_label.name = "SceneNameLabel"   # nome legível na linha "Name:" do tooltip 2D
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
	# vertical do TitleLabel (offset_top 38 / offset_bottom 96, padrão das telas 2D).
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
	return target.name if target != null else ""


# Injeta (uma vez) o toggle de Debug 2D na barra "Actions" da tela ativa. Toda cena 2D com uma
# Actions ganha o controle — exceto a developer, que já tem o seu próprio par Desativado/Ativado.
# Idempotente: não duplica; telas sem Actions (ex.: menu, levels de gameplay) são ignoradas.
func _ensure_debug2d_toggle(screen: Node) -> void:
	# is_instance_valid: a tela pode ter sido liberada entre o call_deferred e esta execução.
	if not is_instance_valid(screen) or screen.scene_file_path.ends_with("developer.tscn"):
		return
	var actions := screen.find_child("Actions", true, false)
	if not (actions is HBoxContainer) or actions.has_node("Debug2DToggle"):
		return
	# O texto é definido ANTES de add_child para o auto-localizador (Locale) capturá-lo como fonte.
	var toggle := _Debug2DToggle.new()
	toggle.name = "Debug2DToggle"
	toggle.text = "Debug 2D"
	actions.add_child(toggle)


func _process(_delta: float) -> void:
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

	var to_erase: Array = []
	for inst_id in _overlay_map:
		var obj := instance_from_id(inst_id)
		var entry: Dictionary = _overlay_map[inst_id]
		var tooltip: PanelContainer = entry.tooltip
		var ctrl_border: Panel = entry.ctrl_border
		if is_instance_valid(obj) and is_instance_valid(tooltip):
			var ctrl := obj as Control
			var shown := ctrl.is_visible_in_tree()
			# Rect em coordenadas de TELA: controles dentro de um SubViewport (ex.: o preview da tela
			# Controles 2D) precisam ser mapeados pela posição/escala do SubViewportContainer, senão a
			# borda/tooltip sai deslocada da posição real do controle (ver _screen_rect_of).
			var rect: Rect2 = _screen_rect_of(ctrl)
			# The border is part of the 2D overlay too: hide it unless at least one
			# dependent line (Type/Name/Id) is selected, so Debug 2D alone shows nothing.
			var any_2d_line := _has_any_2d_line_enabled()
			# Com uma janela flutuante aberta, suprime o overlay dos controles da UI que a chamou.
			var suppressed := _suppressed_by_floating(ctrl, focus_windows)
			if is_instance_valid(ctrl_border):
				ctrl_border.position = rect.position
				ctrl_border.size = rect.size
				ctrl_border.visible = shown and any_2d_line and not suppressed
			var vp_size := get_viewport().get_visible_rect().size
			if entry.get("is_title", false):
				# Tooltip do título centralizado horizontalmente, logo ABAIXO do texto.
				var tip_cx: float = rect.position.x + rect.size.x * 0.5 - tooltip.size.x * 0.5
				tooltip.position = Vector2(tip_cx, rect.position.y + rect.size.y + _TOOLTIP_GAP)
			else:
				var tip_x := rect.position.x + rect.size.x
				if tooltip.size.x > 0 and tip_x + tooltip.size.x > vp_size.x:
					tip_x = rect.position.x - tooltip.size.x
				tooltip.position = Vector2(tip_x, rect.position.y)
			entry.type_lbl.visible = _line_visible_2d("type")
			entry.name_lbl.visible = _line_visible_2d("name")
			entry.id_lbl.visible = _line_visible_2d("id")
			entry.tab_lbl.visible = tab_visible
			if tab_visible:
				var ti: int = _tab_index_map.get(inst_id, -1)
				entry.tab_lbl.text = "TAB: %d" % ti if ti > 0 else "TAB: -"
			tooltip.visible = shown and not suppressed and (
				entry.type_lbl.visible
				or entry.name_lbl.visible
				or entry.id_lbl.visible
				or entry.tab_lbl.visible
			)
		else:
			if is_instance_valid(tooltip):
				tooltip.queue_free()
			if is_instance_valid(ctrl_border):
				ctrl_border.queue_free()
			to_erase.append(inst_id)
	for k in to_erase:
		_overlay_map.erase(k)

	_resolve_tooltip_layout()


# Prende uma posição de tooltip à viewport (canto sup-esq dentro da tela).
func _clamp_pos(pos: Vector2, size: Vector2, vp: Vector2) -> Vector2:
	pos.x = clampf(pos.x, 0.0, maxf(0.0, vp.x - size.x))
	pos.y = clampf(pos.y, 0.0, maxf(0.0, vp.y - size.y))
	return pos


# Reposiciona os tooltips visíveis para (a) caberem na tela e (b) NÃO se sobreporem. Cada tooltip já
# entra ancorado ao seu controle (lado direito/esquerdo, ou centralizado p/ o título — feito no
# _process); aqui só resolvemos conflitos: prende à viewport e faz uma **separação iterativa em 2D**
# (empurra cada par sobreposto pelo menor eixo de penetração, metade para cada lado), reprendendo à
# tela a cada passada. Substitui o antigo empurrão SÓ-horizontal, que jogava tooltips p/ fora da tela
# e deixava cruzamentos. A cor da borda de cada tooltip continua igual à do controle (associação
# visual) mesmo quando ele é afastado. Esforço-limitado: com mais tooltips que espaço, minimiza
# sobreposição em vez de garantir zero.
func _resolve_tooltip_layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	var tips: Array = []
	for inst_id in _overlay_map:
		var t: PanelContainer = _overlay_map[inst_id].tooltip
		if is_instance_valid(t) and t.visible and t.size.x > 0.0 and t.size.y > 0.0:
			tips.append(t)
	if tips.size() < 2:
		if tips.size() == 1:
			tips[0].position = _clamp_pos(tips[0].position, tips[0].size, vp)
		return
	for t in tips:
		t.position = _clamp_pos(t.position, t.size, vp)
	# Passadas de separação: para quando ninguém mais se move (ou no teto de iterações).
	for _iter in 16:
		var moved := false
		for a in range(tips.size()):
			for b in range(a + 1, tips.size()):
				var ra := Rect2(tips[a].position, tips[a].size)
				var rb := Rect2(tips[b].position, tips[b].size)
				if not ra.intersects(rb):
					continue
				var overlap_x: float = minf(ra.end.x, rb.end.x) - maxf(ra.position.x, rb.position.x)
				var overlap_y: float = minf(ra.end.y, rb.end.y) - maxf(ra.position.y, rb.position.y)
				var ca := ra.position + ra.size * 0.5
				var cb := rb.position + rb.size * 0.5
				if overlap_x <= overlap_y:
					var sx := overlap_x * 0.5 + _TOOLTIP_GAP * 0.5
					var dx := -1.0 if ca.x <= cb.x else 1.0
					tips[a].position.x += dx * sx
					tips[b].position.x -= dx * sx
				else:
					var sy := overlap_y * 0.5 + _TOOLTIP_GAP * 0.5
					var dy := -1.0 if ca.y <= cb.y else 1.0
					tips[a].position.y += dy * sy
					tips[b].position.y -= dy * sy
				moved = true
		if not moved:
			break
		for t in tips:
			t.position = _clamp_pos(t.position, t.size, vp)


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
	type_lbl.visible = _line_visible_2d("type")
	name_lbl.visible = _line_visible_2d("name")
	id_lbl.visible = _line_visible_2d("id")
	tab_lbl.visible = _line_visible_2d("tab")
	vbox.add_child(type_lbl)
	vbox.add_child(name_lbl)
	vbox.add_child(id_lbl)
	vbox.add_child(tab_lbl)
	tooltip.add_child(vbox)
	tooltip.position = Vector2(rect.position.x + rect.size.x, rect.position.y)
	_canvas_layer.add_child(tooltip)

	_overlay_map[id] = {
		"tooltip": tooltip, "ctrl_border": ctrl_border, "color": color,
		"type_lbl": type_lbl, "name_lbl": name_lbl, "id_lbl": id_lbl, "tab_lbl": tab_lbl,
		# O tooltip do título da cena fica centralizado ABAIXO do texto (não à direita).
		"is_title": ctrl.name == "TitleLabel",
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
	_canvas_layer.layer = 100
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

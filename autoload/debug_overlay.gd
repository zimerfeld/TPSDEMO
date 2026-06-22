extends Node

const _LABEL3D_META := &"_dbg_label3d"
# Marks the 3D geometry gizmos we spawn (skeleton bone lines, mesh AABB boxes) so
# they are skipped by the scan and removed wholesale on refresh.
const _DBG3D_META := &"_dbg_gizmo3d"
const _BORDER_WIDTH := 2
const _TOOLTIP_GAP := 4.0

# Screens that opt out of ALL debug overlays/tooltips — 2D control borders AND 3D
# member labels — regardless of the debug toggles. A screen joins this group and
# its whole subtree is skipped. Used by the menu and the start screen, whose 3D
# robot is purely decorative (no member tooltips wanted, independent of config).
const _NO_OVERLAY_GROUP := &"no_debug_overlay"

# Subtrees whose 3D MEMBER labels are owned elsewhere: the model browser draws its own,
# richer member labels (with head/torso/leg overrides) over its preview, so the global
# overlay must NOT also label that subtree's skeleton — otherwise members get double tags.
# Only the member labels are skipped; the skeleton-line and mesh-box gizmos still apply.
const _NO_MEMBER_LABELS_GROUP := &"no_debug_member_labels"

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

var _canvas_layer: CanvasLayer = null
# inst_id → {tooltip: PanelContainer, ctrl_border: Panel, color: Color}
var _overlay_map: Dictionary = {}
# 3D tooltip line labels: Label3D instance_id → kind ("type"/"name"/"id"). Their
# `visible` is synced every frame with the saved show_type/show_name/show_id.
var _label3d_lines: Dictionary = {}
var _fps_label: Label = null
var _grid_mesh: MeshInstance3D = null
var _palette_index: int = 0
var _last_scene: Node = null

# Skeleton3D instance_id → its bone-line gizmo (MeshInstance3D) instance_id. The
# ImmediateMesh is rebuilt every frame so the lines follow the live pose.
var _skeleton_gizmos: Dictionary = {}

var _persistent_canvas: CanvasLayer = null
var _scene_name_label: Label = null


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
	if _is_show_grid_on():
		call_deferred("_update_grid")


# 2D (Control) overlays are shown when the "Show Debug 2D" toggle
# (Settings → Debug) is on.
func _is_debug_2d_on() -> bool:
	return Settings.config_file.get_value("game", "debug_2d", false)


# 3D (Skeleton3D bone) overlays follow the "Show Debug 3D" toggle.
func _is_debug_3d_on() -> bool:
	return Settings.config_file.get_value("game", "debug_3d", false)


# The per-member body-part labels (CABEÇA/TRONCO/BRAÇO…) ride ON Debug 3D: the
# "Membros" developer toggle only shows/hides them WHILE Debug 3D is enabled (it
# does nothing on its own).
func _is_show_members_on() -> bool:
	return Settings.config_file.get_value("game", "show_members", false)


# The overlay canvas/scan is needed whenever a debug category is enabled. Members
# are gated by Debug 3D, so they don't activate the overlay on their own.
func _is_overlay_active() -> bool:
	return _is_debug_2d_on() or _is_debug_3d_on()


func _is_fps_on() -> bool:
	return Settings.config_file.get_value("game", "hud_fps", false)


# 2D tooltip lines (Debug 2D column).
func _is_show_id_on() -> bool:
	return Settings.config_file.get_value("game", "show_id", false)


func _is_show_type_on() -> bool:
	return Settings.config_file.get_value("game", "show_type", false)


func _is_show_name_on() -> bool:
	return Settings.config_file.get_value("game", "show_name", false)


# 3D label lines (Debug 3D column) — independent from the 2D set above.
func _is_show_id_3d_on() -> bool:
	return Settings.config_file.get_value("game", "show_id_3d", false)


func _is_show_type_3d_on() -> bool:
	return Settings.config_file.get_value("game", "show_type_3d", false)


func _is_show_name_3d_on() -> bool:
	return Settings.config_file.get_value("game", "show_name_3d", false)


# Skeleton bone-line and Mesh AABB visualizers — sub-switches of Debug 3D (they
# only render while Debug 3D is also on).
func _is_show_skeleton3d_on() -> bool:
	return _is_debug_3d_on() and Settings.config_file.get_value("game", "show_skeleton3d", false)


func _is_show_mesh3d_on() -> bool:
	return _is_debug_3d_on() and Settings.config_file.get_value("game", "show_mesh3d", false)


# Visibility of a 3D label line ("type" / "name" / "id" / "member") from the saved
# config. Every 3D line rides on Debug 3D; each kind then has its own sub-toggle in
# the Debug 3D column ("member" is the "Membros" sub-switch).
func _line_visible_3d(kind: String) -> bool:
	if not _is_debug_3d_on():
		return false
	match kind:
		"type": return _is_show_type_3d_on()
		"name": return _is_show_name_3d_on()
		"id": return _is_show_id_3d_on()
		"member": return _is_show_members_on()
	return false


func _has_any_2d_line_enabled() -> bool:
	return _is_show_type_on() or _is_show_name_on() or _is_show_id_on()


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
	return false


func _is_show_grid_on() -> bool:
	return Settings.config_file.get_value("game", "show_grid", false)


func refresh() -> void:
	_clear_all()
	if _is_overlay_active():
		_build_overlays()
	_update_fps_hud()
	_update_grid()


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
	_scene_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_scene_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Canto inferior esquerdo, na mesma faixa vertical dos botões "Voltar"
	# (Actions: offset_top -100 / offset_bottom -50, relativo à borda inferior).
	_scene_name_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_scene_name_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_scene_name_label.offset_left = 8.0
	_scene_name_label.offset_top = -100.0
	_scene_name_label.offset_right = 320.0
	_scene_name_label.offset_bottom = -50.0
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


# True when the screen subtree actually contains 3D content. The loaded screens are
# Node-rooted (main.gd swaps them as children of Main, so current_scene never changes
# type), so we can't gate on the root type — we look for any Node3D descendant.
func _scene_has_3d(node: Node) -> bool:
	if node == null:
		return false
	if node is Node3D:
		return true
	for child in node.get_children():
		if _scene_has_3d(child):
			return true
	return false


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
		if is_instance_valid(_grid_mesh):
			_grid_mesh.queue_free()
			_grid_mesh = null
		if _is_show_grid_on():
			call_deferred("_update_grid")

	# Toggle each 3D tooltip line (TYPE / Name / ID) from the saved config,
	# the same way the 2D overlays react to the saved configuration.
	if not _label3d_lines.is_empty():
		var stale_ids: Array = []
		for lid in _label3d_lines:
			var node := instance_from_id(lid)
			if node is Label3D:
				(node as Label3D).visible = _line_visible_3d(_label3d_lines[lid])
			else:
				stale_ids.append(lid)
		for s in stale_ids:
			_label3d_lines.erase(s)

	# Redraw each skeleton's bone-line gizmo from the live pose so it follows the
	# animation; drop stale entries whose skeleton or gizmo is gone.
	if not _skeleton_gizmos.is_empty():
		var stale_skel: Array = []
		for sid in _skeleton_gizmos:
			var skel := instance_from_id(sid)
			var mi := instance_from_id(_skeleton_gizmos[sid])
			if skel is Skeleton3D and mi is MeshInstance3D:
				_update_skeleton_lines(skel as Skeleton3D, mi as MeshInstance3D)
			else:
				stale_skel.append(sid)
		for s in stale_skel:
			_skeleton_gizmos.erase(s)

	if _canvas_layer == null:
		return

	var to_erase: Array = []
	for inst_id in _overlay_map:
		var obj := instance_from_id(inst_id)
		var entry: Dictionary = _overlay_map[inst_id]
		var tooltip: PanelContainer = entry.tooltip
		var ctrl_border: Panel = entry.ctrl_border
		if is_instance_valid(obj) and is_instance_valid(tooltip):
			var ctrl := obj as Control
			var shown := ctrl.is_visible_in_tree()
			var rect: Rect2 = ctrl.get_global_rect()
			# The border is part of the 2D overlay too: hide it unless at least one
			# dependent line (Type/Name/Id) is selected, so Debug 2D alone shows nothing.
			var any_2d_line := _has_any_2d_line_enabled()
			if is_instance_valid(ctrl_border):
				ctrl_border.position = rect.position
				ctrl_border.size = rect.size
				ctrl_border.visible = shown and any_2d_line
			var vp_size := get_viewport().get_visible_rect().size
			var tip_x := rect.position.x + rect.size.x
			if tooltip.size.x > 0 and tip_x + tooltip.size.x > vp_size.x:
				tip_x = rect.position.x - tooltip.size.x
			tooltip.position = Vector2(tip_x, rect.position.y)
			entry.type_lbl.visible = _line_visible_2d("type")
			entry.name_lbl.visible = _line_visible_2d("name")
			entry.id_lbl.visible = _line_visible_2d("id")
			tooltip.visible = shown and (
				entry.type_lbl.visible
				or entry.name_lbl.visible
				or entry.id_lbl.visible
			)
		else:
			if is_instance_valid(tooltip):
				tooltip.queue_free()
			if is_instance_valid(ctrl_border):
				ctrl_border.queue_free()
			to_erase.append(inst_id)
	for k in to_erase:
		_overlay_map.erase(k)

	_resolve_overlaps()
	_clamp_tooltips_to_viewport()


func _clamp_tooltips_to_viewport() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	for inst_id in _overlay_map:
		var tooltip: PanelContainer = _overlay_map[inst_id].tooltip
		if not is_instance_valid(tooltip) or not tooltip.visible or tooltip.size.x <= 0:
			continue
		var pos := tooltip.position
		pos.x = clamp(pos.x, 0.0, vp_size.x - tooltip.size.x)
		pos.y = clamp(pos.y, 0.0, vp_size.y - tooltip.size.y)
		tooltip.position = pos


func _resolve_overlaps() -> void:
	var tooltips: Array = []
	for inst_id in _overlay_map:
		var tooltip: PanelContainer = _overlay_map[inst_id].tooltip
		if is_instance_valid(tooltip) and tooltip.size.x > 0:
			tooltips.append(tooltip)
	if tooltips.size() < 2:
		return
	# Sort right-to-left: fix rightmost tooltips first, push overlaps to the left
	tooltips.sort_custom(func(a, b): return a.position.x > b.position.x)
	for i in range(1, tooltips.size()):
		var pos_i: Vector2 = tooltips[i].position
		var size_i: Vector2 = tooltips[i].size
		for j in range(i):
			if Rect2(pos_i, size_i).intersects(Rect2(tooltips[j].position, tooltips[j].size)):
				pos_i.x = tooltips[j].position.x - size_i.x - _TOOLTIP_GAP
		tooltips[i].position = pos_i


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

	# Varre a partir da root: player/enemy ficam fora de current_scene (o main.gd
	# troca telas como filhas da root), então remover só de current_scene deixaria
	# os labels órfãos e visíveis ao desligar o Debug 3D.
	_remove_3d_labels(get_tree().root)
	_label3d_lines.clear()

	# Same reasoning for the 3D geometry gizmos (skeleton lines / mesh boxes).
	_remove_3d_gizmos(get_tree().root)
	_skeleton_gizmos.clear()

	if is_instance_valid(_canvas_layer):
		_canvas_layer.queue_free()
	_canvas_layer = null
	_fps_label = null

	if is_instance_valid(_grid_mesh):
		_grid_mesh.queue_free()
	_grid_mesh = null


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


# "Malha no Solo": a 100 m × 100 m wireframe floor grid drawn at the origin, to gauge
# scale/position in 3D screens (Modelos 3D, levels). Added to the active loaded screen
# whenever it has 3D content; absent on the pure-2D screens (menu/settings/developer).
func _update_grid() -> void:
	if _is_show_grid_on():
		if not is_instance_valid(_grid_mesh):
			var target := _active_screen_root()
			if _scene_has_3d(target):
				_grid_mesh = _build_grid_mesh()
				target.add_child(_grid_mesh)
	else:
		if is_instance_valid(_grid_mesh):
			_grid_mesh.queue_free()
			_grid_mesh = null


func _build_grid_mesh() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_LINES)
	# 100m × 100m grid centered at origin, 10m cell spacing
	for i in range(11):
		var t := -50.0 + i * 10.0
		st.add_vertex(Vector3(t, 0.05, -50.0))
		st.add_vertex(Vector3(t, 0.05,  50.0))
		st.add_vertex(Vector3(-50.0, 0.05, t))
		st.add_vertex(Vector3( 50.0, 0.05, t))
	var arr_mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.WHITE
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = false
	arr_mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.name = "DebugGrid"
	mi.mesh = arr_mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


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
	if node.has_meta(_LABEL3D_META) or node.has_meta(_DBG3D_META):
		return
	if node is Control and not (node is CanvasLayer):
		# Os tooltips de Debug 2D aparecem em TODA tela, SEM exceção — inclusive nas que
		# saem do overlay 3D (grupo no_debug_overlay), como Models e o editor de Dano. Por
		# isso o 2D NÃO checa _is_overlay_exempt (diferente dos overlays 3D abaixo).
		if _is_debug_2d_on():
			_add_2d(node as Control)
	elif node is Skeleton3D:
		# Overlays 3D continuam respeitando no_debug_overlay (ex.: robô decorativo do menu,
		# preview da Models que desenha seus próprios rótulos).
		if _is_overlay_exempt(node):
			return
		var skel := node as Skeleton3D
		# Members ride on Debug 3D: only scan skeletons when it's on (the per-bone
		# member labels are then shown/hidden by the "Membros" sub-toggle).
		if _is_debug_3d_on():
			_add_3d_skeleton(skel)
		# Skeleton bone-line visualizer ("Show Skeleton3D" sub-toggle).
		if _is_show_skeleton3d_on() and not _skeleton_gizmos.has(skel.get_instance_id()):
			_add_skeleton_lines(skel)
	elif node is MeshInstance3D:
		if _is_overlay_exempt(node):
			return
		# Mesh AABB wireframe box ("Show Mesh3D" sub-toggle).
		if node != _grid_mesh and _is_show_mesh3d_on():
			_add_mesh_box(node as MeshInstance3D)


func _add_2d(ctrl: Control) -> void:
	var id := ctrl.get_instance_id()
	if _overlay_map.has(id):
		return
	_ensure_canvas()

	var color := _next_color()
	var rect := ctrl.get_global_rect()

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
	var type_lbl := _make_overlay_label("TYPE: %s" % ctrl.get_class())
	var name_lbl := _make_overlay_label("Name: %s" % ctrl.name)
	var id_lbl := _make_overlay_label("ID: %d" % id)
	type_lbl.visible = _line_visible_2d("type")
	name_lbl.visible = _line_visible_2d("name")
	id_lbl.visible = _line_visible_2d("id")
	vbox.add_child(type_lbl)
	vbox.add_child(name_lbl)
	vbox.add_child(id_lbl)
	tooltip.add_child(vbox)
	tooltip.position = Vector2(rect.position.x + rect.size.x, rect.position.y)
	_canvas_layer.add_child(tooltip)

	_overlay_map[id] = {
		"tooltip": tooltip, "ctrl_border": ctrl_border, "color": color,
		"type_lbl": type_lbl, "name_lbl": name_lbl, "id_lbl": id_lbl,
	}


func _make_overlay_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 10)
	# Light yellow — the Debug 2D column color (3D labels use light cyan).
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5, 0.95))
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


# True when `node` is inside a screen that opted out of all debug overlays (it or
# any ancestor is in `_NO_OVERLAY_GROUP`).
func _is_overlay_exempt(node: Node) -> bool:
	return _in_group_or_ancestor(node, _NO_OVERLAY_GROUP)


# True when `node` or any of its ancestors is in `group`.
func _in_group_or_ancestor(node: Node, group: StringName) -> bool:
	var n: Node = node
	while n != null:
		if n.is_in_group(group):
			return true
		n = n.get_parent()
	return false


# Public: mark a subtree whose 3D MEMBER labels are drawn elsewhere (the model browser
# preview), so the global overlay skips ONLY its member labels for that subtree. The
# skeleton-line / mesh-box gizmos (their own sub-toggles) still apply.
func exempt_member_labels(node: Node) -> void:
	if is_instance_valid(node):
		node.add_to_group(_NO_MEMBER_LABELS_GROUP)


# Rotula apenas os BONES que pertencem a um MEMBRO (CABEÇA/TRONCO/BRAÇO/PERNA);
# ossos de controle/IK não recebem label. Cada osso rotulado recebe um
# BoneAttachment3D (segue a pose/animação) com 1 linha Label3D:
#   Membro: <CABEÇA…>
# Visível/invisível conforme o toggle "Show Debug 3D". Usa o mesmo classificador
# das hitboxes (BodyParts).
func _bone_depth(skel: Skeleton3D, b: int) -> int:
	var d := 0
	var p := skel.get_bone_parent(b)
	while p != -1:
		d += 1
		p = skel.get_bone_parent(p)
	return d


func _add_3d_skeleton(skel: Skeleton3D) -> void:
	if skel.has_meta(_LABEL3D_META):
		return
	# Skip skeletons whose member labels are owned elsewhere (the model browser preview).
	if _in_group_or_ancestor(skel, _NO_MEMBER_LABELS_GROUP):
		return
	# One label per MEMBER, not per bone: a limb spans several bones (shoulder,
	# arm, hand) that all map to the same group, so anchor the single "Membro: …"
	# tag to the shallowest bone of each group to avoid a cluttered pile of labels.
	# Classificador por instância (BodyParts não é polimórfico via estático). O overlay
	# roda sobre esqueletos quaisquer de fase e não sabe o body_type, então usa o plano
	# default (bípede) — rótulos são só debug.
	var classifier := BodyPlans.default()
	var rep_bone := {}      # group → bone index (shallowest)
	var rep_depth := {}
	for i in skel.get_bone_count():
		var g := classifier.group_of(skel.get_bone_name(i))
		if g == "":
			continue
		var d := _bone_depth(skel, i)
		if not rep_bone.has(g) or d < rep_depth[g]:
			rep_bone[g] = i
			rep_depth[g] = d

	for g in rep_bone:
		var i: int = rep_bone[g]
		var member := classifier.label_of(g)

		var att := BoneAttachment3D.new()
		att.name = "DebugBoneLabel_%d" % i
		att.set_meta(_LABEL3D_META, true)
		skel.add_child(att)
		att.bone_name = skel.get_bone_name(i)

		# One Label3D per line. TYPE / Name / ID describe the owning Skeleton3D node
		# (parallel to the 2D tooltips); "Membro" names the body part. Each line is
		# shown/hidden by its own Debug 3D sub-toggle. Stacked top-down, so higher
		# lines sit above the member tag.
		var lines := [
			{"kind": "type", "text": "TYPE: %s" % skel.get_class(), "y": 0.18},
			{"kind": "name", "text": "Name: %s" % skel.name, "y": 0.12},
			{"kind": "id", "text": "ID: %d" % skel.get_instance_id(), "y": 0.06},
			{"kind": "member", "text": "Membro: %s" % member, "y": 0.0},
		]
		for line in lines:
			var lbl := Label3D.new()
			lbl.name = "DebugBoneLine_" + str(line["kind"])
			lbl.text = str(line["text"])
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.no_depth_test = true
			lbl.pixel_size = 0.003
			lbl.font_size = 14
			# Light cyan — the Debug 3D column color, distinct from the light-yellow
			# 2D tooltips.
			lbl.modulate = Color(0.6, 1.0, 1.0)
			lbl.outline_size = 4
			lbl.outline_modulate = Color(0, 0, 0, 0.8)
			lbl.position = Vector3(0.0, line["y"], 0.0)
			lbl.visible = _line_visible_3d(line["kind"])
			lbl.set_meta(_LABEL3D_META, true)
			att.add_child(lbl)
			_label3d_lines[lbl.get_instance_id()] = line["kind"]

	skel.set_meta(_LABEL3D_META, true)


# Unshaded, depth-test-off line material so a gizmo is visible through the mesh.
func _gizmo_line_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = color
	return mat


# "Show Skeleton3D": attach a line gizmo to the skeleton that draws a segment from
# each bone to its parent. The ImmediateMesh is rebuilt every frame (in _process)
# from the live global poses, so the lines track the animation.
func _add_skeleton_lines(skel: Skeleton3D) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "DebugSkeletonLines"
	mi.set_meta(_DBG3D_META, true)
	mi.mesh = ImmediateMesh.new()
	mi.material_override = _gizmo_line_material(Color(1.0, 1.0, 1.0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	skel.add_child(mi)
	_skeleton_gizmos[skel.get_instance_id()] = mi.get_instance_id()
	_update_skeleton_lines(skel, mi)


# Rebuild one skeleton's bone-line mesh from the current pose (skeleton-local space,
# which is the gizmo's own space since it is a child of the skeleton).
func _update_skeleton_lines(skel: Skeleton3D, mi: MeshInstance3D) -> void:
	var im := mi.mesh as ImmediateMesh
	im.clear_surfaces()
	if skel.get_bone_count() == 0:
		return
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for b in skel.get_bone_count():
		var parent := skel.get_bone_parent(b)
		if parent == -1:
			continue
		im.surface_add_vertex(skel.get_bone_global_pose(b).origin)
		im.surface_add_vertex(skel.get_bone_global_pose(parent).origin)
	im.surface_end()


# "Show Mesh3D": draw the 12 edges of a MeshInstance3D's local AABB as a wireframe
# box, parented to the mesh so it follows its transform. (Per the chosen option,
# the AABB box stands in for a full wireframe — cheap and pose-stable.)
func _add_mesh_box(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null or mesh_instance.has_node(NodePath("DebugMeshBox")):
		return
	var aabb := mesh_instance.get_aabb()
	if aabb.size == Vector3.ZERO:
		return
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var o := aabb.position
	var s := aabb.size
	# 8 corners, then the 12 edges connecting them.
	var c := [
		o, o + Vector3(s.x, 0, 0), o + Vector3(s.x, 0, s.z), o + Vector3(0, 0, s.z),
		o + Vector3(0, s.y, 0), o + Vector3(s.x, s.y, 0), o + Vector3(s.x, s.y, s.z), o + Vector3(0, s.y, s.z),
	]
	var edges := [0, 1, 1, 2, 2, 3, 3, 0, 4, 5, 5, 6, 6, 7, 7, 4, 0, 4, 1, 5, 2, 6, 3, 7]
	for e in edges:
		im.surface_add_vertex(c[e])
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.name = "DebugMeshBox"
	mi.set_meta(_DBG3D_META, true)
	mi.mesh = im
	mi.material_override = _gizmo_line_material(Color(0.2, 1.0, 0.9))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_instance.add_child(mi)


# Free every 3D geometry gizmo (skeleton lines, mesh boxes) under `node`. Uses an
# IMMEDIATE free (not queue_free) so a refresh that rebuilds in the same frame finds
# a clean tree — otherwise the still-pending old gizmo collides by name with the new
# one (renaming the skeleton lines) or trips the mesh-box `has_node` guard.
func _remove_3d_gizmos(node: Node) -> void:
	for child in node.get_children():
		if child.has_meta(_DBG3D_META):
			child.free()
		else:
			_remove_3d_gizmos(child)


func _remove_3d_labels(node: Node) -> void:
	for child in node.get_children():
		# Os labels de bone ficam sob um BoneAttachment3D criado por nós; remover o
		# wrapper já leva junto as linhas Label3D filhas.
		if (child is BoneAttachment3D or child is Label3D) and child.has_meta(_LABEL3D_META):
			child.queue_free()
		else:
			_remove_3d_labels(child)
	if node.has_meta(_LABEL3D_META):
		node.remove_meta(_LABEL3D_META)


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

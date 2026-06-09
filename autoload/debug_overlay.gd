extends Node

const _LABEL3D_META := &"_dbg_label3d"
const _BORDER_WIDTH := 2
const _TOOLTIP_GAP := 4.0

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

var _persistent_canvas: CanvasLayer = null
var _scene_name_label: Label = null


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)
	if _is_overlay_active():
		call_deferred("_build_overlays")
	if _is_fps_on():
		call_deferred("_update_fps_hud")
	if _is_show_grid_on():
		call_deferred("_update_grid")
	call_deferred("_setup_scene_name_label")


# 2D (Control) overlays are shown when the "Show Debug 2D" toggle
# (Settings → Debug) is on.
func _is_debug_2d_on() -> bool:
	return Settings.config_file.get_value("game", "debug_2d", false)


# 3D (Skeleton3D bone) overlays follow the "Show Debug 3D" toggle.
func _is_debug_3d_on() -> bool:
	return Settings.config_file.get_value("game", "debug_3d", false)


# The overlay canvas/scan is needed whenever either category is enabled.
func _is_overlay_active() -> bool:
	return _is_debug_2d_on() or _is_debug_3d_on()


func _is_fps_on() -> bool:
	return Settings.config_file.get_value("game", "hud_fps", false)


func _is_show_id_on() -> bool:
	return Settings.config_file.get_value("game", "show_id", false)


func _is_show_type_on() -> bool:
	return Settings.config_file.get_value("game", "show_type", false)


func _is_show_name_on() -> bool:
	return Settings.config_file.get_value("game", "show_name", false)


# Visibility of a tooltip line ("type" / "name" / "member" / "id") from the saved
# config. The body-part line ("member") rides along with the Name toggle.
func _line_visible(kind: String) -> bool:
	match kind:
		"type": return _is_show_type_on()
		"name": return _is_show_name_on()
		"member": return _is_show_name_on()
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
func _active_screen_name() -> String:
	var root_scene := get_tree().current_scene
	if root_scene == null:
		return ""
	var loaded: Node = null
	for child in root_scene.get_children():
		if child.scene_file_path != "" and child.scene_file_path != root_scene.scene_file_path:
			loaded = child
	var target := loaded if loaded != null else root_scene
	return target.name


func _process(_delta: float) -> void:
	if is_instance_valid(_fps_label):
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	if is_instance_valid(_scene_name_label):
		_scene_name_label.text = _active_screen_name()

	# Recreate grid when scene changes (e.g. entering a level)
	var current := get_tree().current_scene
	if current != _last_scene:
		_last_scene = current
		if is_instance_valid(_grid_mesh):
			_grid_mesh.queue_free()
			_grid_mesh = null
		if current is Node3D and _is_show_grid_on():
			call_deferred("_update_grid")

	# Toggle each 3D tooltip line (TYPE / Name / ID) from the saved config,
	# the same way the 2D overlays react to the saved configuration.
	if not _label3d_lines.is_empty():
		var stale_ids: Array = []
		for lid in _label3d_lines:
			var node := instance_from_id(lid)
			if node is Label3D:
				(node as Label3D).visible = _line_visible(_label3d_lines[lid])
			else:
				stale_ids.append(lid)
		for s in stale_ids:
			_label3d_lines.erase(s)

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
			if is_instance_valid(ctrl_border):
				ctrl_border.position = rect.position
				ctrl_border.size = rect.size
				ctrl_border.visible = shown
			var vp_size := get_viewport().get_visible_rect().size
			var tip_x := rect.position.x + rect.size.x
			if tooltip.size.x > 0 and tip_x + tooltip.size.x > vp_size.x:
				tip_x = rect.position.x - tooltip.size.x
			tooltip.position = Vector2(tip_x, rect.position.y)
			tooltip.visible = shown
			entry.type_lbl.visible = _is_show_type_on()
			entry.name_lbl.visible = _is_show_name_on()
			entry.id_lbl.visible = _is_show_id_on()
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
	_scan(get_tree().current_scene)


func _clear_all() -> void:
	for inst_id in _overlay_map:
		var entry: Dictionary = _overlay_map[inst_id]
		if is_instance_valid(entry.tooltip):
			entry.tooltip.queue_free()
		if is_instance_valid(entry.ctrl_border):
			entry.ctrl_border.queue_free()
	_overlay_map.clear()
	_palette_index = 0

	if get_tree().current_scene != null:
		_remove_3d_labels(get_tree().current_scene)
	_label3d_lines.clear()

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


func _update_grid() -> void:
	if _is_show_grid_on():
		if not is_instance_valid(_grid_mesh):
			var scene := get_tree().current_scene
			if scene is Node3D:
				_grid_mesh = _build_grid_mesh()
				scene.add_child(_grid_mesh)
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
	if is_instance_valid(_canvas_layer) and _canvas_layer.is_ancestor_of(node):
		return
	if node.has_meta(_LABEL3D_META):
		return
	if node is Control and not (node is CanvasLayer):
		if _is_debug_2d_on():
			_add_2d(node as Control)
	elif node is Skeleton3D:
		if _is_debug_3d_on():
			_add_3d_skeleton(node as Skeleton3D)


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
	type_lbl.visible = _is_show_type_on()
	name_lbl.visible = _is_show_name_on()
	id_lbl.visible = _is_show_id_on()
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
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0, 0.92))
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


# Rotula apenas os BONES que pertencem a um MEMBRO (CABEÇA/TRONCO/BRAÇO/PERNA);
# ossos de controle/IK não recebem label. Cada osso rotulado recebe um
# BoneAttachment3D (segue a pose/animação) com 1 linha Label3D:
#   Membro: <CABEÇA…>
# ligada/desligada pelo toggle "Show Name". Usa o mesmo classificador das
# hitboxes (BodyParts).
func _add_3d_skeleton(skel: Skeleton3D) -> void:
	if skel.has_meta(_LABEL3D_META):
		return
	for i in skel.get_bone_count():
		var member := BodyParts.label_of(BodyParts.group_of(skel.get_bone_name(i)))
		if member == "":
			continue

		var att := BoneAttachment3D.new()
		att.name = "DebugBoneLabel_%d" % i
		att.set_meta(_LABEL3D_META, true)
		skel.add_child(att)
		att.bone_name = skel.get_bone_name(i)

		var lines := [
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
			lbl.modulate = Color(1.0, 0.8, 0.2) if line["kind"] == "member" else Color(0.3, 0.9, 1.0)
			lbl.outline_size = 4
			lbl.outline_modulate = Color(0, 0, 0, 0.8)
			lbl.position = Vector3(0.0, line["y"], 0.0)
			lbl.visible = _line_visible(line["kind"])
			lbl.set_meta(_LABEL3D_META, true)
			att.add_child(lbl)
			_label3d_lines[lbl.get_instance_id()] = line["kind"]

	skel.set_meta(_LABEL3D_META, true)


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

extends Node

const _LABEL3D_META := &"_dbg_label3d"

var _canvas_layer: CanvasLayer = null
var _label_map: Dictionary = {}  # int (instance_id) → Label


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)
	# If debug was saved as ON, rebuild when the first scene finishes loading.
	if _is_debug_on():
		call_deferred("_build_overlays")


func _is_debug_on() -> bool:
	return Settings.config_file.get_value("game", "debug_mode", false)


func refresh() -> void:
	_clear_all()
	if _is_debug_on():
		_build_overlays()


func _process(_delta: float) -> void:
	if _canvas_layer == null:
		return
	var to_erase: Array = []
	for inst_id in _label_map:
		var obj := instance_from_id(inst_id)
		var lbl: Label = _label_map[inst_id]
		if is_instance_valid(obj) and is_instance_valid(lbl):
			lbl.position = (obj as Control).get_global_rect().position + Vector2(2.0, 2.0)
		else:
			if is_instance_valid(lbl):
				lbl.queue_free()
			to_erase.append(inst_id)
	for k in to_erase:
		_label_map.erase(k)


# ── Build / Clear ─────────────────────────────────────────────────────────────

func _build_overlays() -> void:
	_ensure_canvas()
	_scan(get_tree().current_scene)


func _clear_all() -> void:
	for inst_id in _label_map:
		var lbl: Label = _label_map[inst_id]
		if is_instance_valid(lbl):
			lbl.queue_free()
	_label_map.clear()

	if get_tree().current_scene != null:
		_remove_3d_labels(get_tree().current_scene)

	if is_instance_valid(_canvas_layer):
		_canvas_layer.queue_free()
	_canvas_layer = null


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
		_add_2d(node as Control)
	elif node is MeshInstance3D:
		_add_3d(node as MeshInstance3D)


func _add_2d(ctrl: Control) -> void:
	var id := ctrl.get_instance_id()
	if _label_map.has(id):
		return
	_ensure_canvas()
	var lbl := Label.new()
	lbl.text = "TYPE: %s\nID: %d\nName: %s" % [ctrl.get_class(), id, ctrl.name]
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0, 0.92))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1.0))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.add_theme_constant_override("shadow_as_outline", 1)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.position = ctrl.get_global_rect().position + Vector2(2.0, 2.0)
	_canvas_layer.add_child(lbl)
	_label_map[id] = lbl


func _add_3d(mesh: MeshInstance3D) -> void:
	if mesh.has_meta(_LABEL3D_META):
		return
	var lbl := Label3D.new()
	lbl.name = "DebugLabel3D"
	lbl.text = "TYPE: %s\nID: %d\nName: %s" % [mesh.get_class(), mesh.get_instance_id(), mesh.name]
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.pixel_size = 0.005
	lbl.font_size = 14
	lbl.modulate = Color.YELLOW
	lbl.outline_size = 4
	lbl.outline_modulate = Color(0, 0, 0, 0.8)
	lbl.position = Vector3(0.0, 0.5, 0.0)
	lbl.set_meta(_LABEL3D_META, true)
	mesh.set_meta(_LABEL3D_META, true)
	mesh.add_child(lbl)


func _remove_3d_labels(node: Node) -> void:
	for child in node.get_children():
		if child is Label3D and child.has_meta(_LABEL3D_META):
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
	if not _is_debug_on():
		return
	call_deferred("_tag", node)


func _on_node_removed(node: Node) -> void:
	var id := node.get_instance_id()
	if _label_map.has(id):
		var lbl: Label = _label_map[id]
		if is_instance_valid(lbl):
			lbl.queue_free()
		_label_map.erase(id)

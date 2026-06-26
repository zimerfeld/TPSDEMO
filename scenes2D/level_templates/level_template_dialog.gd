class_name LevelTemplateDialog
extends Window

signal templates_changed

const LEVELS := [
	{"label": "Level 1", "path": "res://scenes3D/level_1/level_1.tscn"},
	{"label": "Level 2", "path": "res://scenes3D/level_2/level_2.tscn"},
	{"label": "Level Base", "path": "res://scenes3D/level_base/level_base.tscn"},
]

var _level_path := ""
var _template: Dictionary = {}
var _entry_index := -1
var _model_options: Array[Dictionary] = []

var _template_picker: OptionButton
var _name_edit: LineEdit
var _entry_picker: OptionButton
var _kind_picker: OptionButton
var _model_picker: OptionButton
var _faction_picker: OptionButton
var _count_spin: SpinBox
var _placement_picker: OptionButton
var _positions_edit: LineEdit
var _random_center_edit: LineEdit
var _random_size_edit: LineEdit
var _formation_picker: OptionButton
var _formation_origin_edit: LineEdit
var _spacing_spin: SpinBox
var _rotation_spin: SpinBox


func _ready() -> void:
	title = "Templates de Level"
	# Larga o suficiente para os rótulos da coluna 1, os campos da coluna 2 e as linhas de botões
	# caberem inteiros — sem cortar controles nem exibir só parte deles.
	size = Vector2i(1200, 720)
	min_size = Vector2i(1040, 600)
	close_requested.connect(hide)
	_build_ui()


func popup_for_level(level_path: String) -> void:
	_level_path = level_path
	if _template.is_empty():
		_load_active_or_first()
	_refresh_template_picker()
	_refresh_template_fields()
	popup_centered()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)
	_template_picker = OptionButton.new()
	_template_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_template_picker.item_selected.connect(_on_template_selected)
	top.add_child(_template_picker)
	_add_button(top, "Novo", _new_template)
	_add_button(top, "Duplicar", _duplicate_template)
	_add_button(top, "Remover", _remove_template)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Nome do template"
	root.add_child(_labeled("Nome", _name_edit))

	root.add_child(HSeparator.new())
	var entry_row := HBoxContainer.new()
	entry_row.add_theme_constant_override("separation", 8)
	root.add_child(entry_row)
	_entry_picker = OptionButton.new()
	_entry_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entry_picker.item_selected.connect(_on_entry_selected)
	entry_row.add_child(_entry_picker)
	_add_button(entry_row, "+ Personagem", func() -> void: _add_entry("character"))
	_add_button(entry_row, "+ Estrutura", func() -> void: _add_entry("structure"))
	_add_button(entry_row, "Remover Entrada", _remove_entry)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	root.add_child(grid)

	_kind_picker = _picker(["character", "structure"])
	_kind_picker.item_selected.connect(func(_idx: int) -> void:
		_save_entry_fields()
		_refresh_model_picker())
	_model_picker = OptionButton.new()
	_faction_picker = _picker(["friendly", "enemy", "neutral"])
	_count_spin = _spin(1, 64, 1, 1)
	_placement_picker = _picker(["random", "coordinates", "formation"])
	_positions_edit = _line("x,y,z; x,y,z")
	_random_center_edit = _line("0,1,0")
	_random_size_edit = _line("34,0,34")
	_formation_picker = _picker(["line", "circle", "wedge", "grid"])
	_formation_origin_edit = _line("0,1,0")
	_spacing_spin = _spin(0.5, 50, 0.5, 4)
	_rotation_spin = _spin(-360, 360, 5, 0)
	_add_grid_row(grid, "Tipo", _kind_picker)
	_add_grid_row(grid, "Modelo", _model_picker)
	_add_grid_row(grid, "Facção", _faction_picker)
	_add_grid_row(grid, "Quantidade", _count_spin)
	_add_grid_row(grid, "Posicionamento", _placement_picker)
	_add_grid_row(grid, "Coordenadas", _positions_edit)
	_add_grid_row(grid, "Centro aleatório", _random_center_edit)
	_add_grid_row(grid, "Tamanho aleatório", _random_size_edit)
	_add_grid_row(grid, "Formação", _formation_picker)
	_add_grid_row(grid, "Origem formação", _formation_origin_edit)
	_add_grid_row(grid, "Espaçamento", _spacing_spin)
	_add_grid_row(grid, "Rotação Y", _rotation_spin)

	root.add_child(HSeparator.new())
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	root.add_child(actions)
	_add_button(actions, "Salvar", _save_template)
	_add_button(actions, "Salvar e Usar Neste Level", _save_and_use)
	_add_button(actions, "Fechar", hide)


func _load_active_or_first() -> void:
	var active := LevelTemplateManager.active_template(_level_path)
	if not active.is_empty():
		_template = active
		return
	var options := LevelTemplateManager.templates_for_level(_level_path)
	_template = options[0] if not options.is_empty() else _default_template()


func _refresh_template_picker() -> void:
	_template_picker.clear()
	var templates := LevelTemplateManager.templates_for_level(_level_path)
	for t in templates:
		_template_picker.add_item(String(t.get("name", "Template")))
		_template_picker.set_item_metadata(_template_picker.item_count - 1, String(t.get("id", "")))
	for i in _template_picker.item_count:
		if String(_template_picker.get_item_metadata(i)) == String(_template.get("id", "")):
			_template_picker.select(i)
			return


func _refresh_template_fields() -> void:
	_name_edit.text = String(_template.get("name", "Template"))
	_refresh_entry_picker()
	_entry_index = clampi(_entry_index, 0, max(0, _entries().size() - 1))
	_refresh_entry_fields()


func _refresh_entry_picker() -> void:
	_entry_picker.clear()
	for i in _entries().size():
		var e := _entries()[i] as Dictionary
		_entry_picker.add_item("%d. %s %s x%d" % [
			i + 1,
			String(e.get("faction", "neutral")),
			String(e.get("model_key", "")),
			int(e.get("count", 1)),
		])
	if _entry_picker.item_count > 0:
		_entry_picker.select(clampi(_entry_index, 0, _entry_picker.item_count - 1))


func _refresh_entry_fields() -> void:
	var has_entry := _entry_index >= 0 and _entry_index < _entries().size()
	for control in [_kind_picker, _model_picker, _faction_picker, _count_spin, _placement_picker,
			_positions_edit, _random_center_edit, _random_size_edit, _formation_picker,
			_formation_origin_edit, _spacing_spin, _rotation_spin]:
		if control is LineEdit or control is SpinBox:
			control.editable = has_entry
		elif control is OptionButton:
			control.disabled = not has_entry
	if not has_entry:
		return
	var e := _entries()[_entry_index] as Dictionary
	_select_text(_kind_picker, String(e.get("kind", "character")))
	_refresh_model_picker()
	_select_model(String(e.get("scene_path", "")))
	_select_text(_faction_picker, String(e.get("faction", "enemy")))
	_count_spin.value = int(e.get("count", 1))
	_select_text(_placement_picker, String(e.get("placement", "random")))
	_positions_edit.text = _positions_to_text(e.get("positions", []))
	_random_center_edit.text = _vec_to_text(e.get("random_center", [0, 1, 0]))
	_random_size_edit.text = _vec_to_text(e.get("random_size", [34, 0, 34]))
	_select_text(_formation_picker, String(e.get("formation", "line")))
	_formation_origin_edit.text = _vec_to_text(e.get("formation_origin", [0, 1, 0]))
	_spacing_spin.value = float(e.get("spacing", 4.0))
	_rotation_spin.value = float(e.get("rotation_y", 0.0))


func _save_template() -> void:
	_save_entry_fields()
	_template["name"] = _name_edit.text.strip_edges()
	_template["level_path"] = _level_path
	LevelTemplateManager.upsert_template(_template)
	templates_changed.emit()
	_refresh_template_picker()


func _save_and_use() -> void:
	_save_template()
	LevelTemplateManager.set_active_template(_level_path, String(_template.get("id", "")))
	templates_changed.emit()


func _new_template() -> void:
	_template = _default_template()
	_entry_index = 0
	_refresh_template_fields()


func _duplicate_template() -> void:
	_save_entry_fields()
	_template = _template.duplicate(true)
	_template["id"] = ""
	_template["name"] = "%s cópia" % String(_template.get("name", "Template"))
	_save_template()


func _remove_template() -> void:
	var id := String(_template.get("id", ""))
	if id != "":
		LevelTemplateManager.remove_template(id)
	_template = _default_template()
	_entry_index = 0
	templates_changed.emit()
	_refresh_template_picker()
	_refresh_template_fields()


func _add_entry(kind: String) -> void:
	_save_entry_fields()
	var options := LevelTemplateManager.model_options(kind)
	var first := options[0] if not options.is_empty() else {}
	_entries().append({
		"kind": kind,
		"faction": "friendly" if kind == "character" else "neutral",
		"model_key": String(first.get("key", kind)),
		"scene_path": String(first.get("path", "")),
		"placement": "random",
		"count": 1,
		"positions": [[0, 1, 0]],
		"random_center": [0, 1, 0],
		"random_size": [34, 0, 34],
		"formation": "line",
		"formation_origin": [0, 1, 0],
		"spacing": 4.0,
		"rotation_y": 0.0,
	})
	_entry_index = _entries().size() - 1
	_refresh_template_fields()


func _remove_entry() -> void:
	if _entry_index < 0 or _entry_index >= _entries().size():
		return
	_entries().remove_at(_entry_index)
	_entry_index = mini(_entry_index, _entries().size() - 1)
	_refresh_template_fields()


func _on_template_selected(index: int) -> void:
	var id := String(_template_picker.get_item_metadata(index))
	for t in LevelTemplateManager.templates_for_level(_level_path):
		if String(t.get("id", "")) == id:
			_template = t
			_entry_index = 0
			_refresh_template_fields()
			return


func _on_entry_selected(index: int) -> void:
	_save_entry_fields()
	_entry_index = index
	_refresh_entry_fields()


func _save_entry_fields() -> void:
	if _entry_index < 0 or _entry_index >= _entries().size():
		return
	var e := _entries()[_entry_index] as Dictionary
	e["kind"] = _kind_picker.get_item_text(_kind_picker.selected)
	e["faction"] = _faction_picker.get_item_text(_faction_picker.selected)
	if _model_picker.selected >= 0:
		var meta: Dictionary = _model_picker.get_item_metadata(_model_picker.selected)
		e["model_key"] = String(meta.get("key", ""))
		e["scene_path"] = String(meta.get("path", ""))
	e["count"] = int(_count_spin.value)
	e["placement"] = _placement_picker.get_item_text(_placement_picker.selected)
	e["positions"] = _parse_positions(_positions_edit.text)
	e["random_center"] = _parse_vector_text(_random_center_edit.text)
	e["random_size"] = _parse_vector_text(_random_size_edit.text)
	e["formation"] = _formation_picker.get_item_text(_formation_picker.selected)
	e["formation_origin"] = _parse_vector_text(_formation_origin_edit.text)
	e["spacing"] = float(_spacing_spin.value)
	e["rotation_y"] = float(_rotation_spin.value)


func _refresh_model_picker() -> void:
	_model_picker.clear()
	var kind := _kind_picker.get_item_text(_kind_picker.selected) if _kind_picker.selected >= 0 else "character"
	_model_options = LevelTemplateManager.model_options(kind)
	for opt in _model_options:
		_model_picker.add_item("%s (%s)" % [String(opt.get("label", "")), String(opt.get("kind", ""))])
		_model_picker.set_item_metadata(_model_picker.item_count - 1, opt)


func _entries() -> Array:
	if not _template.has("entries") or not _template["entries"] is Array:
		_template["entries"] = []
	return _template["entries"]


func _default_template() -> Dictionary:
	return {
		"id": "",
		"name": "Novo template",
		"level_path": _level_path,
		"entries": [],
	}


func _picker(values: Array[String]) -> OptionButton:
	var p := OptionButton.new()
	for v in values:
		p.add_item(v)
	return p


func _spin(min_value: float, max_value: float, step: float, value: float) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_value
	s.max_value = max_value
	s.step = step
	s.value = value
	return s


func _line(placeholder: String) -> LineEdit:
	var l := LineEdit.new()
	l.placeholder_text = placeholder
	return l


func _labeled(label_text: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 120
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _add_grid_row(grid: GridContainer, label_text: String, control: Control) -> void:
	var label := Label.new()
	label.text = label_text
	grid.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(control)


func _add_button(parent: Control, text: String, callable: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(callable)
	parent.add_child(b)
	return b


func _select_text(picker: OptionButton, value: String) -> void:
	for i in picker.item_count:
		if picker.get_item_text(i) == value:
			picker.select(i)
			return


func _select_model(scene_path: String) -> void:
	for i in _model_picker.item_count:
		var meta: Dictionary = _model_picker.get_item_metadata(i)
		if String(meta.get("path", "")) == scene_path:
			_model_picker.select(i)
			return
	if _model_picker.item_count > 0:
		_model_picker.select(0)


func _parse_positions(text: String) -> Array:
	var out: Array = []
	for chunk in text.split(";", false):
		out.append(_parse_vector_text(chunk))
	return out


func _parse_vector_text(text: String) -> Array:
	var parts := text.strip_edges().split(",", false)
	while parts.size() < 3:
		parts.append("0")
	return [float(parts[0]), float(parts[1]), float(parts[2])]


func _positions_to_text(positions: Variant) -> String:
	if not positions is Array:
		return ""
	var chunks: Array[String] = []
	for p in positions:
		chunks.append(_vec_to_text(p))
	return "; ".join(chunks)


func _vec_to_text(value: Variant) -> String:
	if value is Array and (value as Array).size() >= 3:
		return "%s,%s,%s" % [str(value[0]), str(value[1]), str(value[2])]
	if value is Vector3:
		return "%s,%s,%s" % [str(value.x), str(value.y), str(value.z)]
	return "0,0,0"

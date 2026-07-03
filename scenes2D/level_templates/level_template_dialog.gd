class_name LevelTemplateDialog
extends Node

## Controlador do "Gerenciador de Templates" (personagens) E do "Gerenciador de Cenários" (objetos
## de cenário) de cada level — mesma janela/formulário, mudando a CATEGORIA (`configure`): monta o
## formulário DENTRO da janela flutuante reutilizável (FloatingWindow), num CanvasLayer no topo.
## Assim os controles herdam o tema 2D do projeto e o Debug 2D funciona sobre a janela.
##
## O MODELO da entrada é escolhido por NAVEGAÇÃO EM CASCATA de OptionButtons: um dropdown por
## nível de pasta a partir da raiz da categoria (characters/ ou sceneries/), descendo pelas
## subpastas até uma pasta-modelo (cena com o nome da pasta) — que preenche os campos referentes
## (model_key + scene_path) da entrada.

signal templates_changed

const FLOATING_SCENE := preload("res://scenes2D/controls2D/floating_window/floating_window.tscn")

var _level_path := ""
var _template: Dictionary = {}
var _entry_index := -1
## Categoria dos templates geridos por ESTA instância: "spawn" (personagens) ou "scenery".
var _category := "spawn"

var _win: FloatingWindow = null
var _template_picker: OptionButton
var _name_edit: LineEdit
var _entry_name_edit: LineEdit
var _entry_picker: OptionButton
var _cascade_row: HFlowContainer
var _cascade_pickers: Array[OptionButton] = []
var _cascade_dirs: Array[String] = []
var _model_value_label: Label
var _sel_model_key := ""
var _sel_scene_path := ""
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


# Define a categoria ANTES do primeiro popup: "spawn" (Gerenciador de Templates, navega
# library3D/characters) ou "scenery" (Gerenciador de Cenários, navega library3D/sceneries).
func configure(category: String) -> void:
	_category = category


func popup_for_level(level_path: String) -> void:
	_level_path = level_path
	if _template.is_empty():
		_load_active_or_first()
	_open_window()
	_refresh_template_picker()
	_refresh_template_fields()


func _window_title() -> String:
	return "Gerenciador de Cenários" if _category == "scenery" else "Gerenciador de Templates"


func _root_dir() -> String:
	return LevelTemplateManager.SCENERIES_ROOT if _category == "scenery" \
			else LevelTemplateManager.CHARACTERS_ROOT


func _entry_kind() -> String:
	return "scenery" if _category == "scenery" else "character"


# Monta a janela flutuante (num CanvasLayer no topo), constrói o formulário no seu conteúdo e os
# botões de ação no rodapé, e a centraliza. O CanvasLayer é liberado junto quando a janela fecha.
# Larga o suficiente para os rótulos da coluna 1, os campos da coluna 2 e as linhas de botões caberem.
func _open_window() -> void:
	if is_instance_valid(_win):
		_win.close()
	var layer := CanvasLayer.new()
	layer.layer = 128
	_win = FLOATING_SCENE.instantiate()
	_win.min_window_size = Vector2(1040, 640)
	layer.add_child(_win)
	add_child(layer)
	_win.set_title(_window_title())
	_win.closed.connect(layer.queue_free)
	_build_ui(_win.get_content())
	_win.popup_centered()


func _build_ui(content: VBoxContainer) -> void:
	var root := content
	root.add_theme_constant_override("separation", 10)

	var top := HBoxContainer.new()
	top.name = "TopRow"
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)
	_template_picker = OptionButton.new()
	_template_picker.name = "TemplatePicker"
	_template_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_template_picker.item_selected.connect(_on_template_selected)
	top.add_child(_template_picker)
	_add_button(top, "Novo", _new_template)
	_add_button(top, "Duplicar", _duplicate_template)
	_add_button(top, "Remover", _remove_template)

	_name_edit = LineEdit.new()
	_name_edit.name = "NameField"
	_name_edit.placeholder_text = "Nome do template"
	_name_edit.text_changed.connect(_on_template_name_changed)
	root.add_child(_labeled("Nome", _name_edit))

	var entry_separator := HSeparator.new()
	entry_separator.name = "EntrySeparator"
	root.add_child(entry_separator)
	# Campo "Nome da entrada": renomeia o texto exibido no EntryPicker abaixo dele. Vazio → o dropdown
	# cai no rótulo automático ("N. facção modelo xN"). A digitação atualiza o item na hora (sem rebuild).
	_entry_name_edit = LineEdit.new()
	_entry_name_edit.name = "EntryNameField"
	_entry_name_edit.placeholder_text = "Nome da entrada"
	_entry_name_edit.text_changed.connect(_on_entry_name_changed)
	root.add_child(_labeled("Nome da entrada", _entry_name_edit))
	var entry_row := HBoxContainer.new()
	entry_row.name = "EntryRow"
	entry_row.add_theme_constant_override("separation", 8)
	root.add_child(entry_row)
	_entry_picker = OptionButton.new()
	_entry_picker.name = "EntryPicker"
	_entry_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entry_picker.item_selected.connect(_on_entry_selected)
	entry_row.add_child(_entry_picker)
	_add_button(entry_row, "Adicionar Entrada", func() -> void: _add_entry(_entry_kind()))
	_add_button(entry_row, "Remover Entrada", _remove_entry)

	var grid := GridContainer.new()
	grid.name = "FieldsGrid"
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	root.add_child(grid)

	# Navegação em CASCATA do modelo: um OptionButton por nível de pasta (raiz da categoria →
	# subpastas → pasta-modelo). O rótulo abaixo mostra o modelo selecionado (campos referentes).
	var model_box := VBoxContainer.new()
	model_box.name = "ModelBox"
	model_box.add_theme_constant_override("separation", 4)
	_cascade_row = HFlowContainer.new()
	_cascade_row.name = "CascadeRow"
	_cascade_row.add_theme_constant_override("h_separation", 8)
	model_box.add_child(_cascade_row)
	_model_value_label = Label.new()
	_model_value_label.name = "ModelValueLabel"
	model_box.add_child(_model_value_label)
	if _category != "scenery":
		_faction_picker = _picker(["friendly", "enemy", "neutral"])
		_faction_picker.name = "FactionPickers"
	_count_spin = _spin(1, 64, 1, 1)
	_count_spin.name = "CountSpin"
	_placement_picker = _picker(["random", "coordinates", "formation"])
	_placement_picker.name = "PlacementPicker"
	_positions_edit = _line("x,y,z; x,y,z")
	_positions_edit.name = "PositionsField"
	_random_center_edit = _line("0,1,0")
	_random_center_edit.name = "RandomCenterField"
	_random_size_edit = _line("34,0,34")
	_random_size_edit.name = "RandomSizeField"
	_formation_picker = _picker(["line", "circle", "wedge", "grid"])
	_formation_picker.name = "FormationPicker"
	_formation_origin_edit = _line("0,1,0")
	_formation_origin_edit.name = "FormationOriginField"
	_spacing_spin = _spin(0.5, 50, 0.5, 4)
	_spacing_spin.name = "SpacingSpin"
	_rotation_spin = _spin(-360, 360, 5, 0)
	_rotation_spin.name = "RotationSpin"
	_add_grid_row(grid, "Modelo", model_box)
	# Cenários não têm facção (são objetos neutros do palco) — a linha só existe p/ personagens.
	if _faction_picker != null:
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

	# Ações no RODAPÉ da janela flutuante (largura uniforme, traduzidas — igual às demais janelas).
	_win.add_footer_button("Salvar").pressed.connect(_save_template)
	_win.add_footer_button("Salvar e Usar Neste Level").pressed.connect(_save_and_use)
	_win.add_footer_button("Fechar").pressed.connect(_win.close)


func _load_active_or_first() -> void:
	var active := LevelTemplateManager.active_scenery(_level_path) if _category == "scenery" \
			else LevelTemplateManager.active_template(_level_path)
	if not active.is_empty():
		_template = active
		return
	var options := LevelTemplateManager.templates_for_level(_level_path, _category)
	_template = options[0] if not options.is_empty() else _default_template()


func _refresh_template_picker() -> void:
	_template_picker.clear()
	var templates := LevelTemplateManager.templates_for_level(_level_path, _category)
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
		_entry_picker.add_item(_entry_display_text(i))
	if _entry_picker.item_count > 0:
		_entry_picker.select(clampi(_entry_index, 0, _entry_picker.item_count - 1))


# Texto exibido no EntryPicker para a entrada `i`: o NOME custom (se houver), senão o rótulo
# automático ("N. facção modelo xN"). O prefixo "N." mantém a ordem/identificação na lista.
func _entry_display_text(i: int) -> String:
	var e := _entries()[i] as Dictionary
	var custom := String(e.get("name", "")).strip_edges()
	if custom != "":
		return "%d. %s" % [i + 1, custom]
	return "%d. %s %s x%d" % [
		i + 1,
		String(e.get("faction", "neutral")),
		String(e.get("model_key", "")),
		int(e.get("count", 1)),
	]


# Digitou no campo "Nome" do template: grava direto no template em edição, para o valor
# sobreviver aos refreshes do formulário (ex.: Adicionar/Remover Entrada re-lê o dicionário).
func _on_template_name_changed(new_text: String) -> void:
	_template["name"] = new_text


# Digitou no campo "Nome da entrada": grava na entrada selecionada e atualiza SÓ o item do dropdown
# (sem repovoar tudo → o campo não perde o foco). Vazio volta ao rótulo automático.
func _on_entry_name_changed(new_text: String) -> void:
	if _entry_index < 0 or _entry_index >= _entries().size():
		return
	(_entries()[_entry_index] as Dictionary)["name"] = new_text
	_entry_picker.set_item_text(_entry_index, _entry_display_text(_entry_index))


func _refresh_entry_fields() -> void:
	var has_entry := _entry_index >= 0 and _entry_index < _entries().size()
	var controls: Array = [_entry_name_edit, _count_spin,
			_placement_picker, _positions_edit, _random_center_edit, _random_size_edit,
			_formation_picker, _formation_origin_edit, _spacing_spin, _rotation_spin]
	if _faction_picker != null:
		controls.append(_faction_picker)
	for control in controls:
		if control is LineEdit or control is SpinBox:
			control.editable = has_entry
		elif control is OptionButton:
			control.disabled = not has_entry
	for picker in _cascade_pickers:
		picker.disabled = not has_entry
	# Re-liga o anel de Tab agora que os campos do grid mudaram de habilitado/desabilitado: assim a
	# sequência (topo → nome → entrada → grid → rodapé → ×) inclui TODOS os controles focáveis atuais,
	# de cima p/ baixo e da esquerda p/ a direita, com o × por ÚLTIMO. call_deferred: o estado assentou.
	if is_instance_valid(_win):
		_win.wire_focus_ring.call_deferred()
	if not has_entry:
		_rebuild_cascade("")
		return
	var e := _entries()[_entry_index] as Dictionary
	_entry_name_edit.text = String(e.get("name", ""))
	_rebuild_cascade(String(e.get("scene_path", "")))
	if _faction_picker != null:
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
	_template["category"] = _category
	# Guarda o id devolvido: num template NOVO o upsert gera o id numa CÓPIA normalizada,
	# então sem esta atribuição o _template local ficaria com id "" — o "Salvar e Usar
	# Neste Level" ativaria id vazio (nada) e cada Save criaria um template duplicado.
	_template["id"] = LevelTemplateManager.upsert_template(_template)
	templates_changed.emit()
	_refresh_template_picker()


func _save_and_use() -> void:
	_save_template()
	if _category == "scenery":
		LevelTemplateManager.set_active_scenery(_level_path, String(_template.get("id", "")))
	else:
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
	_entries().append({
		"kind": kind,
		"faction": "friendly" if kind == "character" else "neutral",
		"model_key": "",
		"scene_path": "",
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
	for t in LevelTemplateManager.templates_for_level(_level_path, _category):
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
	e["name"] = _entry_name_edit.text.strip_edges()
	e["kind"] = _entry_kind()
	if _faction_picker != null and _faction_picker.selected >= 0:
		e["faction"] = _faction_picker.get_item_text(_faction_picker.selected)
	# A cascata só sobrescreve o modelo quando uma pasta-modelo foi de fato alcançada — navegar
	# pelas pastas sem concluir não apaga o modelo já salvo da entrada.
	if _sel_scene_path != "":
		e["model_key"] = _sel_model_key
		e["scene_path"] = _sel_scene_path
	e["count"] = int(_count_spin.value)
	e["placement"] = _placement_picker.get_item_text(_placement_picker.selected)
	e["positions"] = _parse_positions(_positions_edit.text)
	e["random_center"] = _parse_vector_text(_random_center_edit.text)
	e["random_size"] = _parse_vector_text(_random_size_edit.text)
	e["formation"] = _formation_picker.get_item_text(_formation_picker.selected)
	e["formation_origin"] = _parse_vector_text(_formation_origin_edit.text)
	e["spacing"] = float(_spacing_spin.value)
	e["rotation_y"] = float(_rotation_spin.value)


# ---- Cascata de pastas do Modelo -----------------------------------------------------------

# (Re)monta a cadeia de OptionButtons a partir da raiz da categoria e, se a entrada já tem um
# modelo salvo (scene_path sob a raiz), re-seleciona a cadeia de pastas até ele.
func _rebuild_cascade(scene_path: String) -> void:
	for picker in _cascade_pickers:
		picker.queue_free()
	_cascade_pickers.clear()
	_cascade_dirs.clear()
	_sel_model_key = ""
	_sel_scene_path = ""
	var root := _root_dir()
	_append_cascade_picker(root)
	if scene_path.begins_with(root + "/"):
		var rel_dir := scene_path.substr(root.length() + 1).get_base_dir()
		for folder in rel_dir.split("/", false):
			var depth := _cascade_pickers.size() - 1
			if depth < 0:
				break
			var picker := _cascade_pickers[depth]
			var idx := _find_item(picker, String(folder))
			if idx < 0:
				break
			picker.select(idx)  # select() por código não emite item_selected → desce manualmente
			_descend(depth, String(folder))
	_update_model_label()
	if is_instance_valid(_win):
		_win.wire_focus_ring.call_deferred()


# Acrescenta o dropdown do PRÓXIMO nível listando as subpastas navegáveis de `dir_path`
# (só pastas que contêm um modelo em alguma profundidade; vazio → cascata termina aqui).
func _append_cascade_picker(dir_path: String) -> void:
	var info: Dictionary = LevelTemplateManager.browse_dir(dir_path)
	var folders: Array = info.get("folders", [])
	if folders.is_empty():
		return
	var picker := OptionButton.new()
	picker.name = "FolderPickers%d" % (_cascade_pickers.size() + 1)
	picker.add_item("Selecione...")
	for folder in folders:
		picker.add_item(String(folder))
	var depth := _cascade_pickers.size()
	picker.item_selected.connect(func(idx: int) -> void: _on_cascade_selected(depth, idx))
	_cascade_row.add_child(picker)
	_cascade_pickers.append(picker)
	_cascade_dirs.append(dir_path)


func _on_cascade_selected(depth: int, idx: int) -> void:
	# Escolher num nível corta todos os níveis mais fundos (a navegação recomeça dali).
	while _cascade_pickers.size() > depth + 1:
		(_cascade_pickers.pop_back() as OptionButton).queue_free()
		_cascade_dirs.pop_back()
	if idx <= 0:
		_sel_model_key = ""
		_sel_scene_path = ""
	else:
		_descend(depth, _cascade_pickers[depth].get_item_text(idx))
	_update_model_label()
	if is_instance_valid(_win):
		_win.wire_focus_ring.call_deferred()


# Entra na pasta escolhida: se ela é uma pasta-MODELO, mapeia os campos referentes da entrada
# (model_key + scene_path); havendo subpastas navegáveis, oferece o próximo nível da cascata.
func _descend(depth: int, folder: String) -> void:
	var dir := "%s/%s" % [_cascade_dirs[depth], folder]
	var info: Dictionary = LevelTemplateManager.browse_dir(dir)
	var model: Dictionary = info.get("model", {})
	_sel_model_key = String(model.get("key", ""))
	_sel_scene_path = String(model.get("path", ""))
	if not (info.get("folders", []) as Array).is_empty():
		_append_cascade_picker(dir)


func _update_model_label() -> void:
	if _sel_scene_path != "":
		_model_value_label.text = "Modelo: %s (%s)" % [
			_sel_model_key.replace("_", " ").capitalize(), _sel_scene_path.get_file()]
	else:
		_model_value_label.text = "Navegue pelas pastas até um modelo"


func _find_item(picker: OptionButton, text: String) -> int:
	for i in picker.item_count:
		if picker.get_item_text(i) == text:
			return i
	return -1


func _entries() -> Array:
	if not _template.has("entries") or not _template["entries"] is Array:
		_template["entries"] = []
	return _template["entries"]


func _default_template() -> Dictionary:
	return {
		"id": "",
		"name": "Novo cenário" if _category == "scenery" else "Novo template",
		"level_path": _level_path,
		"category": _category,
		"entries": [],
	}


func _picker(values: Array[String]) -> OptionButton:
	var p := OptionButton.new()
	for v in values:
		p.add_item(v)
	return p


func _spin(min_value: float, max_value: float, step: float, value: float) -> SpinBox:
	var s := SpinBox.new()
	s.focus_mode = Control.FOCUS_ALL   # SpinBox não é FOCUS_ALL por padrão → entraria no anel de Tab como "TAB: -"
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
	row.name = "LabeledRow_%s" % label_text
	row.add_theme_constant_override("separation", 8)
	var label := Label.new()
	label.name = "FieldLabel_%s" % label_text
	label.text = label_text
	label.custom_minimum_size.x = 120
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _add_grid_row(grid: GridContainer, label_text: String, control: Control) -> void:
	var label := Label.new()
	label.name = "GridLabel_%s" % label_text
	label.text = label_text
	grid.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(control)


func _add_button(parent: Control, text: String, callable: Callable) -> Button:
	var b := Button.new()
	b.name = "ActionButton_%s" % text
	b.text = text
	b.pressed.connect(callable)
	parent.add_child(b)
	return b


func _select_text(picker: OptionButton, value: String) -> void:
	for i in picker.item_count:
		if picker.get_item_text(i) == value:
			picker.select(i)
			return


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

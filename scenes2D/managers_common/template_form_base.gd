class_name TemplateFormBase
extends ScrollContainer
## Base do formulário dos gerenciadores (Templates de personagens / Cenários). É a RAIZ de cada
## cena `.tscn` (um ScrollContainer, para rolar verticalmente quando os campos não couberem) e é
## inserida no conteúdo de uma FloatingWindow (CanvasLayer no topo), herdando o tema 2D e o Debug 2D.
##
## Cada SUBCLASSE só define o manager de dados, o título e o nome padrão; a cena `.tscn` define quais
## campos existem (ex.: a linha "Facção" só existe na cena de personagens — detectada por presença
## do nó `%Factions`). O MODELO da entrada é escolhido por NAVEGAÇÃO EM CASCATA de OptionButtons
## (um por nível de pasta a partir da raiz da categoria), até uma pasta-modelo.

signal templates_changed

const FLOATING_SCENE := preload("res://controls2D/floating_window/floating_window.tscn")

var _level_path := ""
var _template: Dictionary = {}
var _entry_index := -1
var _win: FloatingWindow = null
var _cascade_pickers: Array[OptionButton] = []
var _cascade_dirs: Array[String] = []
var _sel_model_key := ""
var _sel_scene_path := ""

@onready var _templates_picker: OptionButton = %Templates
@onready var _name_edit: LineEdit = %NameField
@onready var _entry_name_edit: LineEdit = %EntryNameField
@onready var _entries_picker: OptionButton = %Entries
# CascadeRow agora é um VBoxContainer (empilha os dropdowns "Folders" verticalmente, cada um ocupando
# a largura toda da linha — o cross-axis do VBox estica os filhos). Ver _append_cascade_picker.
@onready var _cascade_row: VBoxContainer = %CascadeRow
@onready var _factions_picker: OptionButton = get_node_or_null("%Factions")
# Dropdown de ARMA (só na cena de personagens — nó %Weapons). Habilitado só depois que um
# personagem (pasta-modelo) é escolhido na cascata; opções vindas de library3D/weapons.
@onready var _weapons_picker: OptionButton = get_node_or_null("%Weapons")
@onready var _count_spin: SpinBox = %Count
@onready var _placements_picker: OptionButton = %Placements
# Painel que agrupa os campos condicionais ao Posicionamento (some quando não há entrada).
@onready var _placement_group: PanelContainer = %PlacementGroup
# Rótulos + campos específicos de cada modo de Posicionamento (mostrados/ocultados por
# _apply_placement_visibility conforme o valor de %Placements).
@onready var _positions_label: Label = %PositionsLabel
@onready var _positions_edit: LineEdit = %PositionsField
@onready var _random_center_label: Label = %RandomCenterLabel
@onready var _random_center_edit: LineEdit = %RandomCenterField
@onready var _random_size_label: Label = %RandomSizeLabel
@onready var _random_size_edit: LineEdit = %RandomSizeField
@onready var _formation_label: Label = %FormationLabel
@onready var _formations_picker: OptionButton = %Formations
@onready var _formation_origin_label: Label = %FormationOriginLabel
@onready var _formation_origin_edit: LineEdit = %FormationOriginField
@onready var _spacing_label: Label = %SpacingLabel
@onready var _spacing_spin: SpinBox = %Spacing
@onready var _rotation_spin: SpinBox = %Rotation


# ---- Ganchos virtuais (cada subclasse define) ---------------------------------------------

# Autoload de dados desta categoria (CharacterTemplateManager / SceneryTemplateManager).
func _manager() -> TemplateManagerBase:
	return null


func _window_title() -> String:
	return "Gerenciador"


func _default_name() -> String:
	return "Novo template"


func _entry_kind() -> String:
	return "character"


# ---- Ciclo de vida ------------------------------------------------------------------------

func _ready() -> void:
	_setup_picker_items()
	_templates_picker.item_selected.connect(_on_template_selected)
	_name_edit.text_changed.connect(_on_template_name_changed)
	_entry_name_edit.text_changed.connect(_on_entry_name_changed)
	_entries_picker.item_selected.connect(_on_entry_selected)
	_placements_picker.item_selected.connect(_on_placement_selected)
	(%Novo as Button).pressed.connect(_new_template)
	(%Duplicar as Button).pressed.connect(_duplicate_template)
	(%Remover as Button).pressed.connect(_remove_template)
	(%AddEntry as Button).pressed.connect(_add_entry)
	(%RemoveEntry as Button).pressed.connect(_remove_entry)


# Popula os OptionButton de enum (valores internos — NÃO traduzidos, são chaves de dados).
func _setup_picker_items() -> void:
	for v in ["random", "coordinates", "formation"]:
		_placements_picker.add_item(v)
	for v in ["line", "circle", "wedge", "grid"]:
		_formations_picker.add_item(v)
	if _factions_picker != null:
		for v in ["friendly", "enemy", "neutral"]:
			_factions_picker.add_item(v)
	if _weapons_picker != null:
		_populate_weapons()


# Abre a janela flutuante (num CanvasLayer no topo, sob `host`), insere ESTE formulário no seu
# conteúdo e monta os botões de ação no rodapé. Ao fechar, o CanvasLayer (janela + formulário) é
# liberado — a instância não é reaproveitada (o chamador cria uma nova a cada abertura).
func open_over(host: Node, level_path: String) -> void:
	_level_path = level_path
	var layer := CanvasLayer.new()
	layer.layer = 128
	_win = FLOATING_SCENE.instantiate()
	_win.min_window_size = Vector2(700, 620)
	layer.add_child(_win)
	# Encosta a barra de rolagem vertical mais à direita: reduz a margem direita do corpo da janela
	# só nesta janela (override de instância), aproximando o ScrollContainer da borda direita.
	var body := _win.get_node_or_null("Window/Main/Body") as MarginContainer
	if body != null:
		body.add_theme_constant_override("margin_right", 4)
	host.add_child(layer)
	_win.set_title(_window_title())
	_win.closed.connect(layer.queue_free)
	_win.get_content().add_child(self)  # entra na árvore → dispara _ready()
	# Ações no RODAPÉ da janela (largura uniforme, traduzidas — igual às demais janelas).
	_win.add_footer_button("Salvar").pressed.connect(_save_template)
	# add_footer_button nomeia o nó "Footer_<texto>"; renomeamos p/ "Footer_SalvarAplicar" (sem espaços).
	var save_apply := _win.add_footer_button("Salvar e Aplicar")
	save_apply.name = "Footer_SalvarAplicar"
	save_apply.pressed.connect(_save_and_use)
	_win.add_footer_button("Fechar").pressed.connect(_win.close)
	_load_active_or_first()
	_refresh_template_picker()
	_refresh_template_fields()
	_win.popup_centered()


func _load_active_or_first() -> void:
	var active := _manager().active(_level_path)
	if not active.is_empty():
		_template = active
		return
	var options := _manager().templates_for_level(_level_path)
	_template = options[0] if not options.is_empty() else _default_template()


func _refresh_template_picker() -> void:
	_templates_picker.clear()
	for t in _manager().templates_for_level(_level_path):
		_templates_picker.add_item(String(t.get("name", "Template")))
		_templates_picker.set_item_metadata(_templates_picker.item_count - 1, String(t.get("id", "")))
	for i in _templates_picker.item_count:
		if String(_templates_picker.get_item_metadata(i)) == String(_template.get("id", "")):
			_templates_picker.select(i)
			return


func _refresh_template_fields() -> void:
	_name_edit.text = String(_template.get("name", "Template"))
	_refresh_entry_picker()
	_entry_index = clampi(_entry_index, 0, max(0, _entries().size() - 1))
	_refresh_entry_fields()


func _refresh_entry_picker() -> void:
	_entries_picker.clear()
	for i in _entries().size():
		_entries_picker.add_item(_entry_display_text(i))
	if _entries_picker.item_count > 0:
		_entries_picker.select(clampi(_entry_index, 0, _entries_picker.item_count - 1))


# Texto do dropdown Entries para a entrada `i`: o índice "N." + o corpo (_entry_body_text).
func _entry_display_text(i: int) -> String:
	return "%d. %s" % [i + 1, _entry_body_text(i)]


# Corpo do rótulo da entrada `i` (SEM o prefixo "N."): o NOME custom, se houver, senão o rótulo
# automático. É o que auto-preenche o campo "Nome da entrada".
func _entry_body_text(i: int) -> String:
	var e := _entries()[i] as Dictionary
	var custom := String(e.get("name", "")).strip_edges()
	return custom if custom != "" else _entry_auto_label(e)


# Rótulo AUTOMÁTICO da entrada ("facção modelo xN" / "modelo xN"), ignorando qualquer nome custom.
func _entry_auto_label(e: Dictionary) -> String:
	if _factions_picker != null:
		return "%s %s x%d" % [String(e.get("faction", "neutral")),
			String(e.get("model_key", "")), int(e.get("count", 1))]
	return "%s x%d" % [String(e.get("model_key", "")), int(e.get("count", 1))]


func _on_template_name_changed(new_text: String) -> void:
	_template["name"] = new_text


func _on_entry_name_changed(new_text: String) -> void:
	if _entry_index < 0 or _entry_index >= _entries().size():
		return
	(_entries()[_entry_index] as Dictionary)["name"] = new_text
	_entries_picker.set_item_text(_entry_index, _entry_display_text(_entry_index))


func _refresh_entry_fields() -> void:
	var has_entry := _entry_index >= 0 and _entry_index < _entries().size()
	var controls: Array = [_entry_name_edit, _count_spin,
			_placements_picker, _positions_edit, _random_center_edit, _random_size_edit,
			_formations_picker, _formation_origin_edit, _spacing_spin, _rotation_spin]
	if _factions_picker != null:
		controls.append(_factions_picker)
	for control in controls:
		if control is LineEdit or control is SpinBox:
			control.editable = has_entry
		elif control is OptionButton:
			control.disabled = not has_entry
	for picker in _cascade_pickers:
		picker.disabled = not has_entry
	if not has_entry:
		# Sem entrada: oculta todos os campos de posicionamento e religa o anel de Tab (× por último).
		_apply_placement_visibility()
		if is_instance_valid(_win):
			_win.wire_focus_ring.call_deferred()
		_rebuild_cascade("")
		return
	var e := _entries()[_entry_index] as Dictionary
	# Auto-preenche o campo "Nome da entrada" com o texto exibido no dropdown Entries (corpo, sem o
	# "N."): o nome custom, se houver, senão o rótulo automático — o campo nunca fica vazio.
	_entry_name_edit.text = _entry_body_text(_entry_index)
	_rebuild_cascade(String(e.get("scene_path", "")))
	if _factions_picker != null:
		_select_text(_factions_picker, String(e.get("faction", "enemy")))
	if _weapons_picker != null:
		_select_weapon(String(e.get("weapon_path", "")))
	_count_spin.value = int(e.get("count", 1))
	_select_text(_placements_picker, String(e.get("placement", "random")))
	_positions_edit.text = _positions_to_text(e.get("positions", []))
	_random_center_edit.text = _vec_to_text(e.get("random_center", [0, 1, 0]))
	_random_size_edit.text = _vec_to_text(e.get("random_size", [34, 0, 34]))
	_select_text(_formations_picker, String(e.get("formation", "line")))
	_formation_origin_edit.text = _vec_to_text(e.get("formation_origin", [0, 1, 0]))
	_spacing_spin.value = float(e.get("spacing", 4.0))
	_rotation_spin.value = float(e.get("rotation_y", 0.0))
	# Agora que %Placements reflete o modo salvo, aplica a visibilidade e religa o anel de Tab.
	_apply_placement_visibility()
	if is_instance_valid(_win):
		_win.wire_focus_ring.call_deferred()


# Mostra apenas os campos do modo de Posicionamento atualmente selecionado, ocultando os demais
# (label + campo juntos, para o GridContainer manter o pareamento das colunas). Sem entrada, oculta
# tudo. "coordinates" → Coordenadas; "random" → Centro/Tamanho aleatório; "formation" → Formação,
# Origem e Espaçamento. Rotação Y é geral (sempre visível). O anel de Tab ignora ocultos (UINav).
func _apply_placement_visibility() -> void:
	var has_entry := _entry_index >= 0 and _entry_index < _entries().size()
	# O grupo inteiro só aparece com uma entrada selecionada (cada modo mostra ao menos um campo).
	_placement_group.visible = has_entry
	var placement := ""
	if has_entry and _placements_picker.selected >= 0:
		placement = _placements_picker.get_item_text(_placements_picker.selected)
	var coord := placement == "coordinates"
	var rand := placement == "random"
	var form := placement == "formation"
	_positions_label.visible = coord
	_positions_edit.visible = coord
	_random_center_label.visible = rand
	_random_center_edit.visible = rand
	_random_size_label.visible = rand
	_random_size_edit.visible = rand
	_formation_label.visible = form
	_formations_picker.visible = form
	_formation_origin_label.visible = form
	_formation_origin_edit.visible = form
	_spacing_label.visible = form
	_spacing_spin.visible = form


# Trocar o Posicionamento no dropdown reflete na hora quais campos aparecem e religa o anel de Tab.
func _on_placement_selected(_index: int) -> void:
	_apply_placement_visibility()
	if is_instance_valid(_win):
		_win.wire_focus_ring.call_deferred()


func _save_template() -> void:
	_save_entry_fields()
	_template["name"] = _name_edit.text.strip_edges()
	_template["level_path"] = _level_path
	# Guarda o id devolvido: num template NOVO o upsert gera o id numa CÓPIA normalizada, então sem
	# esta atribuição o _template local ficaria com id "" (Save duplicaria; "Usar" ativaria vazio).
	_template["id"] = _manager().upsert_template(_template)
	templates_changed.emit()
	_refresh_template_picker()


func _save_and_use() -> void:
	_save_template()
	_manager().set_active(_level_path, String(_template.get("id", "")))
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
		_manager().remove_template(id)
	_template = _default_template()
	_entry_index = 0
	templates_changed.emit()
	_refresh_template_picker()
	_refresh_template_fields()


func _add_entry() -> void:
	_save_entry_fields()
	_entries().append({
		"kind": _entry_kind(),
		"faction": "friendly" if _factions_picker != null else "neutral",
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
		"weapon_key": "",
		"weapon_path": "",
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
	var id := String(_templates_picker.get_item_metadata(index))
	for t in _manager().templates_for_level(_level_path):
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
	e["kind"] = _entry_kind()
	if _factions_picker != null and _factions_picker.selected >= 0:
		e["faction"] = _factions_picker.get_item_text(_factions_picker.selected)
	# Arma escolhida (só personagens): guarda o caminho da cena e a chave (nome da pasta). "Selecione..."
	# (índice 0) ou dropdown desabilitado (sem personagem) → sem arma.
	if _weapons_picker != null:
		var wsel := _weapons_picker.selected
		var wpath := "" if wsel <= 0 else String(_weapons_picker.get_item_metadata(wsel))
		e["weapon_path"] = wpath
		e["weapon_key"] = "" if wpath == "" else wpath.get_file().get_basename()
	# A cascata só sobrescreve o modelo quando uma pasta-modelo foi de fato alcançada.
	if _sel_scene_path != "":
		e["model_key"] = _sel_model_key
		e["scene_path"] = _sel_scene_path
	e["count"] = int(_count_spin.value)
	e["placement"] = _placements_picker.get_item_text(_placements_picker.selected)
	e["positions"] = _parse_positions(_positions_edit.text)
	e["random_center"] = _parse_vector_text(_random_center_edit.text)
	e["random_size"] = _parse_vector_text(_random_size_edit.text)
	e["formation"] = _formations_picker.get_item_text(_formations_picker.selected)
	e["formation_origin"] = _parse_vector_text(_formation_origin_edit.text)
	e["spacing"] = float(_spacing_spin.value)
	e["rotation_y"] = float(_rotation_spin.value)
	# Nome da entrada por ÚLTIMO (após facção/modelo/quantidade acima): o campo é AUTO-PREENCHIDO com o
	# rótulo automático, então só grava como NOME CUSTOM se o usuário o alterou; se ainda for o rótulo
	# automático (calculado com os valores recém-salvos), mantém "" para o rótulo seguir dinâmico.
	var typed := _entry_name_edit.text.strip_edges()
	e["name"] = "" if typed == _entry_auto_label(e) else typed


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
	var root := _manager().root_dir()
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
	_refresh_weapon_enabled()
	if is_instance_valid(_win):
		_win.wire_focus_ring.call_deferred()


# Acrescenta o dropdown do PRÓXIMO nível listando as subpastas navegáveis de `dir_path`
# (só pastas que contêm um modelo em alguma profundidade; vazio → cascata termina aqui).
func _append_cascade_picker(dir_path: String) -> void:
	var info: Dictionary = _manager().browse_dir(dir_path)
	var folders: Array = info.get("folders", [])
	if folders.is_empty():
		return
	var picker := OptionButton.new()
	picker.name = "Folders%d" % (_cascade_pickers.size() + 1)
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
	_refresh_weapon_enabled()
	if is_instance_valid(_win):
		_win.wire_focus_ring.call_deferred()


# Entra na pasta escolhida: se ela é uma pasta-MODELO, mapeia os campos referentes da entrada
# (model_key + scene_path); havendo subpastas navegáveis, oferece o próximo nível da cascata.
func _descend(depth: int, folder: String) -> void:
	var dir := "%s/%s" % [_cascade_dirs[depth], folder]
	var info: Dictionary = _manager().browse_dir(dir)
	var model: Dictionary = info.get("model", {})
	_sel_model_key = String(model.get("key", ""))
	_sel_scene_path = String(model.get("path", ""))
	# Ao alcançar uma pasta-MODELO a cascata PARA: não desce para subpastas de suporte (laser/, parts/…)
	# — era o que gerava o "Folders2" poluído com efeitos/projéteis. Só oferece o próximo nível quando a
	# pasta é apenas um AGRUPADOR intermediário (não tem cena homônima).
	if _sel_scene_path == "" and not (info.get("folders", []) as Array).is_empty():
		_append_cascade_picker(dir)


func _find_item(picker: OptionButton, text: String) -> int:
	for i in picker.item_count:
		if picker.get_item_text(i) == text:
			return i
	return -1


# ---- Arma (só personagens) ----------------------------------------------------------------

# Preenche o dropdown de arma a partir de library3D/weapons (via TemplateManagerBase.list_weapons):
# "Selecione..." (metadata "") + uma opção por arma, com o caminho da cena na metadata.
func _populate_weapons() -> void:
	_weapons_picker.clear()
	_weapons_picker.add_item("Selecione...")
	_weapons_picker.set_item_metadata(0, "")
	for w in _manager().list_weapons():
		_weapons_picker.add_item(String(w["label"]))
		_weapons_picker.set_item_metadata(_weapons_picker.item_count - 1, String(w["path"]))


# Seleciona a arma cujo caminho de cena bate com `path`; "" (ou não encontrada) → "Selecione...".
func _select_weapon(path: String) -> void:
	if _weapons_picker == null:
		return
	for i in _weapons_picker.item_count:
		if String(_weapons_picker.get_item_metadata(i)) == path:
			_weapons_picker.select(i)
			return
	_weapons_picker.select(0)


# A arma só fica habilitada DEPOIS que um personagem (pasta-modelo) foi escolhido na cascata
# (_sel_scene_path preenchido) e há uma entrada selecionada.
func _refresh_weapon_enabled() -> void:
	if _weapons_picker == null:
		return
	var has_entry := _entry_index >= 0 and _entry_index < _entries().size()
	_weapons_picker.disabled = not (has_entry and _sel_scene_path != "")


# ---- Helpers -------------------------------------------------------------------------------

func _entries() -> Array:
	if not _template.has("entries") or not _template["entries"] is Array:
		_template["entries"] = []
	return _template["entries"]


func _default_template() -> Dictionary:
	return {
		"id": "",
		"name": _default_name(),
		"level_path": _level_path,
		"entries": [],
	}


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

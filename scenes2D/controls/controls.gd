extends Node

## Visualizador dos controles 2D — equivalente 2D da tela Models (scenes3D/models).
## Um dropdown lista cada controle em res://scenes2D/controls2D/ e o selecionado é
## instanciado num SubViewport de preview. Soltar uma nova pasta de controle lá
## faz ela aparecer aqui automaticamente (sem mudar código).

signal replace_main_scene(resource: PackedScene)

const DEVELOPER_PATH: String = "res://scenes2D/developer/developer.tscn"

# Placeholder shown as the first, default-selected option of the dropdown. Picking
# it means "nothing chosen yet": the preview is cleared.
const SELECT_LABEL: String = "Selecione..."

# Raiz da biblioteca de controles 2D. Cada subpasta <nome>/ com um <nome>.tscn é
# um controle previewável (espelha o scanner da tela Models para a library3D).
const CONTROLS_ROOT: String = "res://scenes2D/controls2D"

# Construído em _ready varrendo CONTROLS_ROOT. Cada entrada: {"name", "path"}.
var _controls: Array = []

@onready var cbo_control: OptionButton = $UI/Selectors/ControlRow/cboControl
@onready var status_label: Label = $UI/Selectors/StatusLabel
@onready var preview: SubViewport = $UI/PreviewContainer/SubViewport
@onready var portuguese_button: Button = $UI/LangBar/PortugueseButton
@onready var english_button: Button = $UI/LangBar/EnglishButton

# The status line is driven dynamically, so it opts out of the automatic localizer
# (Locale.SKIP_GROUP) and re-translates itself from the stored template on a language
# change. Empty template means "blank".
var _status_template: String = ""
var _status_args: Array = []


func _ready() -> void:
	_controls = _scan_controls()

	cbo_control.clear()
	cbo_control.add_item(Locale.tr_key(SELECT_LABEL))
	for entry in _controls:
		cbo_control.add_item(entry["name"])
	cbo_control.item_selected.connect(_on_control_selected)

	# The status text is code-driven: skip the auto-localizer and re-apply on language
	# change so it always matches the active language.
	status_label.add_to_group(Locale.SKIP_GROUP)
	Locale.language_changed.connect(_on_language_changed)
	_update_language_buttons()

	# Start blank: the dropdown shows "Selecione..." and nothing is previewed until
	# the user picks a control.
	cbo_control.select(0)
	_on_control_selected(0)
	if _controls.is_empty():
		_set_status("Nenhum controle em %s.", [CONTROLS_ROOT])


# Store a (translatable) template + args and render it in the active language.
func _set_status(template: String, args: Array = []) -> void:
	_status_template = template
	_status_args = args
	_apply_status()


func _apply_status() -> void:
	if _status_template == "":
		status_label.text = ""
		return
	var text := Locale.tr_key(_status_template)
	status_label.text = (text % _status_args) if not _status_args.is_empty() else text


func _on_language_changed(_lang: String) -> void:
	cbo_control.set_item_text(0, Locale.tr_key(SELECT_LABEL))
	_apply_status()
	_update_language_buttons()


func _update_language_buttons() -> void:
	var lang := Locale.get_language()
	portuguese_button.disabled = lang == "pt"
	english_button.disabled = lang == "en"


func _on_portuguese_pressed() -> void:
	Locale.set_language("pt")
	_update_language_buttons()


func _on_english_pressed() -> void:
	Locale.set_language("en")
	_update_language_buttons()


# Lista as subpastas de CONTROLS_ROOT que têm um <pasta>.tscn (a cena do controle),
# uma entrada por controle, ordenadas por nome.
func _scan_controls() -> Array:
	var result: Array = []
	var access := DirAccess.open(CONTROLS_ROOT)
	if access == null:
		return result
	for folder in access.get_directories():
		var scene_path := CONTROLS_ROOT.path_join(folder).path_join(folder + ".tscn")
		if ResourceLoader.exists(scene_path):
			result.append({"name": _prettify(folder), "path": scene_path})
	result.sort_custom(func(a, b): return a["name"] < b["name"])
	return result


# Mostra o controle selecionado: limpa o preview e instancia a cena no SubViewport.
# Índice 0 é o placeholder "Selecione..." (nada previsualizado); controles reais
# começam no índice 1 (mapeando para _controls[index - 1]).
func _on_control_selected(index: int) -> void:
	for child in preview.get_children():
		child.queue_free()
	if index <= 0:
		_set_status("Selecione um controle.")
		return
	var control_index := index - 1
	if control_index >= _controls.size():
		return
	var entry: Dictionary = _controls[control_index]
	var scene: PackedScene = load(entry["path"])
	if scene == null:
		_set_status("Falha ao carregar: %s", [entry["name"]])
		return
	var instance := scene.instantiate()
	preview.add_child(instance)
	# The control name is a proper noun: store it as-is (tr_key passes unknown keys through).
	_set_status(entry["name"])
	_center_preview(instance)


# Centraliza o controle previsualizado no SubViewport, horizontal e verticalmente,
# "sempre que possível": só recentra o eixo em que o controle é MENOR que o viewport
# (controles que já preenchem a área toda — scanlines, hud, pause_menu — ficam onde
# estão). Espera um frame para o layout assentar antes de medir o tamanho real.
func _center_preview(node: Node) -> void:
	var control := node as Control
	if control == null:
		return
	await get_tree().process_frame
	if not is_instance_valid(control):
		return
	var viewport_size := Vector2(preview.size)
	var control_size := control.size
	var pos := control.position
	if control_size.x < viewport_size.x:
		pos.x = (viewport_size.x - control_size.x) * 0.5
	if control_size.y < viewport_size.y:
		pos.y = (viewport_size.y - control_size.y) * 0.5
	control.position = pos


# "ability_bar" -> "Ability Bar", "cyberpunk_hud" -> "Cyberpunk Hud".
func _prettify(raw_name: String) -> String:
	var words := raw_name.replace("_", " ").replace("-", " ").split(" ", false)
	var out: Array[String] = []
	for word in words:
		out.append(word.capitalize())
	return " ".join(out)


func _on_back_pressed() -> void:
	emit_signal("replace_main_scene", load(DEVELOPER_PATH))


func _input(input_event: InputEvent) -> void:
	if input_event.is_action_pressed(&"quit"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()

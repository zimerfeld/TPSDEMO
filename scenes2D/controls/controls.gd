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


func _ready() -> void:
	_controls = _scan_controls()

	cbo_control.clear()
	cbo_control.add_item(SELECT_LABEL)
	for entry in _controls:
		cbo_control.add_item(entry["name"])
	cbo_control.item_selected.connect(_on_control_selected)

	# Start blank: the dropdown shows "Selecione..." and nothing is previewed until
	# the user picks a control.
	cbo_control.select(0)
	_on_control_selected(0)
	if _controls.is_empty():
		status_label.text = "Nenhum controle em %s." % CONTROLS_ROOT


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
		status_label.text = "Selecione um controle."
		return
	var control_index := index - 1
	if control_index >= _controls.size():
		return
	var entry: Dictionary = _controls[control_index]
	var scene: PackedScene = load(entry["path"])
	if scene == null:
		status_label.text = "Falha ao carregar: %s" % entry["name"]
		return
	preview.add_child(scene.instantiate())
	status_label.text = entry["name"]


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

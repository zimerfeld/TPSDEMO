extends Node

## Visualizador dos controles 2D — equivalente 2D da tela Models (scenes3D/models).
## Um dropdown lista cada controle em res://controls2D/ e o selecionado é
## instanciado num SubViewport de preview. Soltar uma nova pasta de controle lá
## faz ela aparecer aqui automaticamente (sem mudar código).

signal replace_main_scene(resource: PackedScene)

const DEVELOPER_PATH: String = "res://scenes2D/developer/developer.tscn"

# Placeholder shown as the first, default-selected option of the dropdown. Picking
# it means "nothing chosen yet": the preview is cleared.
const SELECT_LABEL: String = "Selecione..."

# Raiz da biblioteca de controles 2D. Cada subpasta <nome>/ com um <nome>.tscn é
# um controle previewável (espelha o scanner da tela Models para a library3D).
const CONTROLS_ROOT: String = "res://controls2D"

# Construído em _ready varrendo CONTROLS_ROOT. Cada entrada: {"name", "path"}.
var _controls: Array = []

@onready var cbo_control: OptionButton = %Controls
@onready var preview: SubViewport = %SubViewport
@onready var portuguese_button: Button = $UI/Actions/LangBar/Portuguese
@onready var english_button: Button = $UI/Actions/LangBar/English
@onready var spanish_button: Button = $UI/Actions/LangBar/Spanish


func _ready() -> void:
	_controls = _scan_controls()

	cbo_control.clear()
	cbo_control.add_item(Locale.tr_key(SELECT_LABEL))
	for entry in _controls:
		cbo_control.add_item(entry["name"])
	cbo_control.item_selected.connect(_on_control_selected)

	Locale.language_changed.connect(_on_language_changed)
	_update_language_buttons()

	# Start blank: the dropdown shows "Selecione..." and nothing is previewed until
	# the user picks a control.
	cbo_control.select(0)
	_on_control_selected(0)

	# Foco inicial no Tab = 1 + anel de Tab na ordem de leitura. Re-liga quando o DebugOverlay injeta
	# o toggle "Debug 2D" na barra Actions (entra DEPOIS do _ready).
	UINav.focus_tab_one.call_deferred(self)
	_wire_tab_order.call_deferred()
	($UI/Actions as HBoxContainer).child_entered_tree.connect(
		func(_n: Node) -> void: _wire_tab_order.call_deferred())


# (Re)liga o anel de Tab da tela na ordem de leitura. Idempotente — re-chamável quando o conjunto
# de focáveis muda (toggle injetado, botão de idioma habilitando/desabilitando).
func _wire_tab_order() -> void:
	UINav.wire_tab_ring(self)


func _on_language_changed(_lang: String) -> void:
	cbo_control.set_item_text(0, Locale.tr_key(SELECT_LABEL))
	_update_language_buttons()


func _update_language_buttons() -> void:
	var lang := Locale.get_language()
	portuguese_button.disabled = lang == "pt"
	english_button.disabled = lang == "en"
	spanish_button.disabled = lang == "es"
	# O idioma ativo fica desabilitado (fora do Tab) — re-liga o anel p/ a sequência fechar sem ele.
	if is_node_ready():
		_wire_tab_order.call_deferred()


func _on_portuguese_pressed() -> void:
	Locale.set_language("pt")
	_update_language_buttons()


func _on_english_pressed() -> void:
	Locale.set_language("en")
	_update_language_buttons()


func _on_spanish_pressed() -> void:
	Locale.set_language("es")
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
		return
	var control_index := index - 1
	if control_index >= _controls.size():
		return
	var entry: Dictionary = _controls[control_index]
	var scene: PackedScene = load(entry["path"])
	if scene == null:
		return
	var instance := scene.instantiate()
	preview.add_child(instance)
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
		# ESC encerra primeiro um campo em edição; só o 2º ESC volta à tela developer.
		if UINav.cancel_active_edit(get_viewport()):
			get_viewport().set_input_as_handled()
			return
		get_viewport().set_input_as_handled()
		_on_back_pressed()

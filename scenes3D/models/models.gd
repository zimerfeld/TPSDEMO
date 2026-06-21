extends Node

signal replace_main_scene(resource: PackedScene)

const DEVELOPER_PATH: String = "res://scenes2D/developer/developer.tscn"

# Placeholder shown as the first, default-selected option of every dropdown.
# Picking it means "nothing chosen yet": dependent dropdowns reset to this same
# placeholder and the preview is cleared. In the prefix dropdown it doubles as
# "no filter" (it replaced the old "Todos"), so it lists every model.
const SELECT_LABEL: String = "Selecione..."

# Selectable option in the part dropdown (right below "Selecione...") that previews
# the whole assembled model. Picking a real part below it isolates one distinct mesh.
const WHOLE_MODEL_LABEL: String = "Modelo completo"

# Option listed right below "Selecione..." in the Efeitos Especiais dropdown, meaning
# "show every effect". Added only when the model actually exposes at least one effect.
# ALL_VALUE is the stable sentinel persisted for it (its visible label is translated, so
# restore keys off the sentinel, not the text).
const ALL_EFFECTS_LABEL: String = "Todos"
const ALL_VALUE: String = "__all__"

# Stable identifier persisted for the "Modelo completo" part selection. Its visible label
# is translated, so the restore code keys off this sentinel instead of the on-screen text.
const WHOLE_MODEL_VALUE: String = "__whole_model__"

# Root of the 3D model library. Models live in res://library3D/<tipo>/<modelo>/
# (e.g. characters/red_robot, props/forklift, structures/core). The selection
# dropdowns below are built by scanning this folder, so dropping a new model
# folder in here makes it show up automatically — no code change needed.
const LIBRARY_ROOT: String = "res://library3D"

# Model categories shown in the dropdown, in display order. Only these
# subfolders of LIBRARY_ROOT are scanned — support folders that also live under
# library/ (e.g. geometry/, textures/) are intentionally ignored here.
const CATEGORIES: Array[Dictionary] = [
	{"key": "characters", "label": "Personagens"},
	{"key": "propulsores", "label": "Propulsores"},
	{"key": "structures", "label": "Estruturas"},
	{"key": "weapons", "label": "Armas"},
]

# Models follow the Godot/Blender convention (front = -Z), but the preview camera
# sits on +Z looking toward -Z, so it would face the model's BACK. Rotate the holder
# 180° by default so the model's FRONT faces the user; the user's ±90° yaw drag then
# swings around the front.
const DEFAULT_FRONT_YAW: float = PI

# How fast the dragged model rotates, in radians per pixel of mouse motion.
const DRAG_SENSITIVITY: float = 0.01

# Auto-rotation speed in radians per second when the toggle is on.
const AUTO_ROTATE_SPEED: float = 0.6

# Mouse-wheel zoom: the camera slides along its view axis toward/away from the
# model. ZOOM_STEP is how much one wheel notch changes the target distance;
# ZOOM_MIN/MAX clamp it; ZOOM_SMOOTH is the per-second approach rate that makes
# the move glide instead of snapping.
const ZOOM_STEP: float = 0.6
const ZOOM_MIN: float = 1.2
const ZOOM_MAX: float = 12.0
const ZOOM_SMOOTH: float = 10.0

# Built at _ready by scanning LIBRARY_ROOT. Each entry:
#   {"key": String, "label": String, "models": Array[{"name", "path"}]}
var _categories: Array = []

# Currently selected model scene and its de-duplicated mesh catalog. A big level
# model bundles hundreds of placed MeshInstance3D, but they share a small palette
# of unique meshes — the catalog lists each distinct mesh once (the reusable
# asset), not every placement. Each entry:
#   {"label", "mesh": Mesh, "name": String, "count": int, "has_collision": bool, "skinned": bool}
# _model_scene is the mesh source used to build the catalog (the raw .glb when
# present). _display_scene is what the "Modelo completo" view instantiates: the
# authored .tscn (materials, effects, the intended visible variant) when one
# exists, otherwise the same scene as _model_scene.
var _model_scene: PackedScene = null
var _display_scene: PackedScene = null
var _mesh_catalog: Array = []
# Resource path of the currently previewed model, used to look up per-character
# data such as the head bone(s) that BodyParts can't infer from the name alone.
var _current_model_path: String = ""

# The models of the current category that pass the active prefix filter, in the
# same order as the Model dropdown — so the dropdown index maps straight back to
# an entry. Rebuilt whenever the category or prefix changes.
var _filtered_models: Array = []
# Active prefix filter ("" = ALL_PREFIXES_LABEL, i.e. no filtering).
var _prefix_filter: String = ""

# Rotation state. The holder either spins on its own (auto) or follows the mouse
# while the left button is held; dragging temporarily overrides auto-rotation.
# Yaw and pitch are tracked separately and rebuilt as an Euler rotation with no
# roll, so mouse motion only ever turns the model about the two orthogonal axes
# (horizontal -> yaw on Y, vertical -> pitch on X).
var _auto_rotate: bool = false
var _dragging: bool = false
var _yaw: float = 0.0
var _pitch: float = 0.0

# Whole-model preview toggles. Colliders draws wireframe gizmos for the
# (otherwise invisible) CollisionShape3D volumes; animation plays the model's
# AnimationPlayer; audio plays ALL of its sound emitters (movement, motor, shots,
# explosions, voices...). Effects ("Efeitos especiais") shows everything else linked
# to the model that no other toggle covers — particles, lights and bone-mounted
# laser/muzzle meshes (see _collect_effect_nodes). All start off so a freshly-picked
# model previews static, silent and clean.
var _show_colliders: bool = false
var _play_animation: bool = false
var _play_audio: bool = false
var _show_effects: bool = false
# Rótulos "Membro: CABEÇA" sobre cada collider — toggle PRÓPRIO do browser, totalmente
# independente da tela de Debug 3D (que agora só afeta os levels do jogo).
var _show_member_labels: bool = false
# Linhas extras do tooltip de membro (TYPE/Name/ID do Skeleton3D), cada uma com seu
# checkbox dedicado na cena Models — não dependem mais do Debug 3D global.
var _show_type: bool = false
var _show_name: bool = false
var _show_id: bool = false
# Editor de dano por membro (painel com um input de bônus % por membro). Só faz sentido
# para personagens em "Modelo completo"; não é persistido (abre fechado a cada visita).
var _show_damage_panel: bool = false

# Dropdowns Membro/Sub-membro (só "Modelo completo", personagens/armas): isolam o collider
# de um membro e, opcionalmente, de um de seus sub-membros, na visualização. Cada array
# guarda as entradas {group,label} na MESMA ordem dos itens do combo (item index - 1).
var _member_entries: Array = []      # membros grandes (HEAD/TORSO/ARM…), exceto PART_*
var _sub_member_entries: Array = []  # sub-membros (PART_*) do membro atualmente escolhido

# AnimationPlayers of the current whole-model preview, used by the "Animação"
# dropdown to list and play the model's clips.
var _preview_anim_players: Array = []
# The model's MAIN AnimationPlayer (the one its AnimationTree drives, or the richest one
# when there is no tree). When no specific clip is chosen, ONLY this player auto-plays a
# default/idle clip; the other players (one-shot effect/death clips like kaboom/blast/shoot)
# stay stopped so they don't overlay extra debris meshes on the model.
var _main_anim_player: AnimationPlayer = null
# The live body subtree (the main player's model root). Hidden while a death/explosion clip
# plays — those clips reveal the model's debris (e.g. red_robot's kaboom shows the Death
# parts) WITHOUT hiding the body, so without this the intact body and the debris overlap as
# "two models". Hiding it leaves only the explosion.
var _main_body_root: Node3D = null

# Special-effect nodes of the current whole-model preview, used by the "Efeitos
# Especiais" dropdown to list and isolate them. Each entry: {"label", "node"}.
var _preview_effect_nodes: Array = []

# The live preview instance currently under ModelHolder (whole model or single
# mesh). Toggles act on THIS node in place instead of rebuilding it, so flipping
# any toggle never reloads the model nor disturbs the camera/rotation.
var _preview_instance: Node = null
# Captured at build so the in-place audio applier can restore state: each emitter's
# authored volume_db, so a muted-by-toggle emitter can be un-muted without a rebuild.
var _preview_audio_players: Array = []
var _preview_audio_volumes: Dictionary = {}
# Whether the per-member colliders were already built for the current preview, so
# turning the Colliders toggle on later builds them once instead of every time.
var _member_colliders_built: bool = false
# Índice das pilhas de rótulos de membro vivas no preview, consumido a cada frame por
# _layout_member_labels para o anti-colisão (empurrar pilhas que se sobreponham na tela).
# Cada entrada: {"pivot": Node3D (move a pilha junta), "body": StaticBody3D (âncora animada),
# "base": Vector3 (posição local sem empurrão), "H": float, "halfW": float} — H/halfW são o
# tamanho aproximado do bloco em metros, usados para projetar seu retângulo de tela.
var _member_label_pivots: Array = []

@onready var model_holder: Node3D = $ModelHolder
@onready var camera: Camera3D = $Camera3D

# Mouse-wheel zoom state: the camera's distance from the model along its local Z.
# _zoom_target is nudged by the wheel; _zoom eases toward it every frame.
var _zoom: float = 0.0
var _zoom_target: float = 0.0
@onready var cbo_category: OptionButton = $UI/Selectors/CategoryRow/cboCategory
@onready var cbo_prefix: OptionButton = $UI/Selectors/PrefixRow/cboPrefix
@onready var cbo_models: OptionButton = $UI/Selectors/ModelRow/cboModels
@onready var cbo_meshes: OptionButton = $UI/Selectors/MeshRow/cboMeshes
@onready var animation_row: HBoxContainer = $UI/Selectors/AnimationRow
@onready var cbo_animations: OptionButton = $UI/Selectors/AnimationRow/cboAnimations
@onready var effects_row: HBoxContainer = $UI/Selectors/EffectsRow
@onready var cbo_effects: OptionButton = $UI/Selectors/EffectsRow/cboEffects
@onready var member_row: HBoxContainer = $UI/Selectors/MemberRow
@onready var cbo_members: OptionButton = $UI/Selectors/MemberRow/cboMembers
@onready var sub_member_row: HBoxContainer = $UI/Selectors/SubMemberRow
@onready var cbo_sub_members: OptionButton = $UI/Selectors/SubMemberRow/cboSubMembers
@onready var rotate_toggle: CheckButton = $UI/Toggles/RotateToggle
@onready var animation_toggle: CheckButton = $UI/Toggles/AnimationToggle
@onready var audio_toggle: CheckButton = $UI/Toggles/AudioToggle
@onready var colliders_toggle: CheckButton = $UI/Toggles/CollidersToggle
@onready var labels_toggle: CheckButton = $UI/Toggles/LabelsToggle
@onready var type_check: CheckButton = $UI/Toggles/LabelLinesRow/TypeCheck
@onready var name_check: CheckButton = $UI/Toggles/LabelLinesRow/NameCheck
@onready var id_check: CheckButton = $UI/Toggles/LabelLinesRow/IdCheck
@onready var damage_toggle: CheckButton = $UI/Toggles/DamageToggle
@onready var effects_toggle: CheckButton = $UI/Toggles/EffectsToggle
@onready var damage_panel: PanelContainer = $UI/DamagePanel
@onready var damage_rows: VBoxContainer = $UI/DamagePanel/Margin/Scroll/VBox/Rows
@onready var portuguese_button: Button = $UI/LangBar/PortugueseButton
@onready var english_button: Button = $UI/LangBar/EnglishButton
# Watermark do nome da cena no canto inferior esquerdo (mesma faixa do botão "Voltar"),
# espelhando o do debug_overlay.gd. A cena Models está no grupo no_debug_overlay (isenta
# do overlay global), então ela mostra o PRÓPRIO rótulo, sempre visível e sem depender de
# nenhum toggle de Debug.
@onready var scene_name_label: Label = $UI/SceneNameLabel


func _ready() -> void:
	_zoom = camera.position.z
	_zoom_target = _zoom
	# Nome da cena (nó raiz) no watermark inferior esquerdo, como nas demais telas.
	scene_name_label.text = name
	_categories = _scan_library()

	cbo_category.clear()
	cbo_category.add_item(Locale.tr_key(SELECT_LABEL))
	for category in _categories:
		cbo_category.add_item(Locale.tr_key(category["label"]))
	cbo_category.item_selected.connect(_on_category_selected)
	cbo_prefix.item_selected.connect(_on_prefix_selected)
	cbo_models.item_selected.connect(_on_model_selected)
	cbo_meshes.item_selected.connect(_on_mesh_selected)
	cbo_animations.item_selected.connect(_on_animation_selected)
	cbo_effects.item_selected.connect(_on_effect_selected)
	cbo_members.item_selected.connect(_on_member_selected)
	cbo_sub_members.item_selected.connect(_on_sub_member_selected)
	_reset_animations()
	_reset_effects()
	_reset_members()

	# Restore the toggle states saved on a previous visit, so the browser reopens
	# exactly as the user left it (see _save_toggle / _on_*_toggled). Defaults match
	# the field initializers above (everything off) for a first run.
	_auto_rotate = Settings.config_file.get_value("models", "auto_rotate", _auto_rotate)
	_play_animation = Settings.config_file.get_value("models", "play_animation", _play_animation)
	_play_audio = Settings.config_file.get_value("models", "play_audio", _play_audio)
	_show_colliders = Settings.config_file.get_value("models", "show_colliders", _show_colliders)
	_show_member_labels = Settings.config_file.get_value("models", "show_member_labels", _show_member_labels)
	_show_type = Settings.config_file.get_value("models", "show_type", _show_type)
	_show_name = Settings.config_file.get_value("models", "show_name", _show_name)
	_show_id = Settings.config_file.get_value("models", "show_id", _show_id)
	_show_effects = Settings.config_file.get_value("models", "show_effects", _show_effects)

	rotate_toggle.button_pressed = _auto_rotate
	rotate_toggle.toggled.connect(_on_rotate_toggled)
	animation_toggle.button_pressed = _play_animation
	animation_toggle.toggled.connect(_on_animation_toggled)
	audio_toggle.button_pressed = _play_audio
	audio_toggle.toggled.connect(_on_audio_toggled)
	colliders_toggle.button_pressed = _show_colliders
	colliders_toggle.toggled.connect(_on_colliders_toggled)
	labels_toggle.button_pressed = _show_member_labels
	labels_toggle.toggled.connect(_on_labels_toggled)
	type_check.button_pressed = _show_type
	type_check.toggled.connect(_on_type_toggled)
	name_check.button_pressed = _show_name
	name_check.toggled.connect(_on_name_toggled)
	id_check.button_pressed = _show_id
	id_check.toggled.connect(_on_id_toggled)
	damage_toggle.button_pressed = _show_damage_panel
	damage_toggle.toggled.connect(_on_damage_toggled)
	effects_toggle.button_pressed = _show_effects
	effects_toggle.toggled.connect(_on_effects_toggled)

	# Pinta o texto de cada toggle de linha com a mesma cor do rótulo 3D que ele controla.
	_apply_label_line_colors()

	Locale.language_changed.connect(_on_language_changed)
	_update_language_buttons()

	# Reopen exactly where the user left off: replay the persisted selection chain
	# (Categoria -> Prefixo -> Modelo -> Parte -> Animação/Efeitos). With nothing saved
	# every dropdown shows "Selecione..." and nothing is previewed — identical to a first
	# visit, and no real item is ever auto-selected.
	_restore_selection_chain()


func _on_language_changed(_lang: String) -> void:
	# Relabel the placeholders/category names already in the dropdowns (kept in place so
	# the current selection survives), then re-apply the lang buttons.
	if cbo_category.item_count > 0:
		cbo_category.set_item_text(0, Locale.tr_key(SELECT_LABEL))
	for i in range(_categories.size()):
		if i + 1 < cbo_category.item_count:
			cbo_category.set_item_text(i + 1, Locale.tr_key(_categories[i]["label"]))
	for combo in [cbo_prefix, cbo_models, cbo_meshes, cbo_animations, cbo_effects, cbo_members, cbo_sub_members]:
		if combo.item_count > 0:
			combo.set_item_text(0, Locale.tr_key(SELECT_LABEL))
	if cbo_meshes.item_count > 1:
		cbo_meshes.set_item_text(1, Locale.tr_key(WHOLE_MODEL_LABEL))
	# The "Todos" entry (when present) sits at index 1 of the Efeitos dropdown.
	if not _preview_effect_nodes.is_empty() and cbo_effects.item_count > 1:
		cbo_effects.set_item_text(1, Locale.tr_key(ALL_EFFECTS_LABEL))
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


func _process(delta: float) -> void:
	# Slowly spin the previewed mesh, like the character on the choose-player
	# screen — but pause while the user is hand-rotating it with the mouse.
	if _auto_rotate and not _dragging:
		_yaw += delta * AUTO_ROTATE_SPEED
	# Rebuild rotation from yaw/pitch with roll fixed at 0 (orthogonal axes only).
	# The default 180° yaw turns the model's front toward the camera.
	model_holder.rotation = Vector3(_pitch, DEFAULT_FRONT_YAW + _yaw, 0.0)
	# Glide the camera toward the wheel-set zoom distance instead of snapping.
	if not is_equal_approx(_zoom, _zoom_target):
		_zoom = lerpf(_zoom, _zoom_target, minf(ZOOM_SMOOTH * delta, 1.0))
		camera.position.z = _zoom
	# Reflui as pilhas de rótulos de membro para que conjuntos de membros diferentes não se
	# sobreponham na tela (o modelo gira, então a checagem é por frame). Sem pilhas, é no-op.
	if not _member_label_pivots.is_empty():
		_layout_member_labels()


# Sequential gating: each dropdown below Categoria stays DISABLED until the one
# directly above it holds a real (non-"Selecione...") choice. So the user is forced
# down the chain Categoria -> Prefixo -> Modelo -> Parte. Category index 0 is the
# "Selecione..." placeholder (real categories start at index 1). Selecting it blanks
# and disables the whole chain below and clears the preview.
func _on_category_selected(index: int) -> void:
	_save_selection("sel_category", _category_value(index))
	if index <= 0:
		_reset_prefixes()
		_reset_models()
		return
	_populate_prefixes(index - 1)
	# Prefix is now enabled but still on its placeholder, so Modelo/Parte stay locked.
	_reset_models()


# Build the prefix dropdown for a category: "Selecione..." (placeholder) plus each
# distinct model prefix (the first underscore-separated token, e.g. "robot" for
# robot_01 / robot_02). Enables the dropdown; the placeholder carries empty metadata.
func _populate_prefixes(category_index: int) -> void:
	var models: Array = _categories[category_index]["models"]
	var seen: Dictionary = {}
	var prefixes: Array = []
	for entry in models:
		var prefix: String = entry.get("prefix", "")
		if prefix != "" and not seen.has(prefix):
			seen[prefix] = true
			prefixes.append(prefix)
	prefixes.sort()

	cbo_prefix.clear()
	cbo_prefix.add_item(Locale.tr_key(SELECT_LABEL))
	cbo_prefix.set_item_metadata(0, "")
	for prefix in prefixes:
		cbo_prefix.add_item(_prettify(prefix))
		cbo_prefix.set_item_metadata(cbo_prefix.item_count - 1, prefix)
	cbo_prefix.select(0)
	cbo_prefix.disabled = false
	_prefix_filter = ""


# Reset the prefix dropdown to just the "Selecione..." placeholder and DISABLE it
# (no category chosen, so there is nothing to filter yet).
func _reset_prefixes() -> void:
	cbo_prefix.clear()
	cbo_prefix.add_item(Locale.tr_key(SELECT_LABEL))
	cbo_prefix.set_item_metadata(0, "")
	cbo_prefix.select(0)
	cbo_prefix.disabled = true
	_prefix_filter = ""


func _on_prefix_selected(index: int) -> void:
	_prefix_filter = cbo_prefix.get_item_metadata(index)
	_save_selection("sel_prefix", _prefix_filter)
	if _prefix_filter == "":
		# Back to the placeholder: re-lock Modelo and Parte.
		_reset_models()
	else:
		_populate_models()


# Fill the Model dropdown with "Selecione..." plus the current category's models
# that match the chosen prefix, and ENABLE it. The placeholder stays selected, so no
# model is previewed until the user picks one — and the Part dropdown stays locked.
func _populate_models() -> void:
	cbo_models.clear()
	cbo_models.add_item(Locale.tr_key(SELECT_LABEL))
	_filtered_models = []
	var cat_index := cbo_category.selected - 1
	if cat_index < 0:
		_reset_models()
		return

	var models: Array = _categories[cat_index]["models"]
	for entry in models:
		if entry.get("prefix", "") != _prefix_filter:
			continue
		_filtered_models.append(entry)
		cbo_models.add_item(entry["name"])

	cbo_models.select(0)
	cbo_models.disabled = false
	_reset_meshes_and_preview()


# Reset the Model dropdown to just the "Selecione..." placeholder, DISABLE it, and
# clear the parts dropdown and preview below it.
func _reset_models() -> void:
	cbo_models.clear()
	cbo_models.add_item(Locale.tr_key(SELECT_LABEL))
	cbo_models.select(0)
	cbo_models.disabled = true
	_filtered_models = []
	_reset_meshes_and_preview()


# Reset the Part dropdown to just the "Selecione..." placeholder, DISABLE it, and
# clear the previewed mesh/model and its cached scenes. Also resets the dropdowns
# below Part (Animação, Efeitos, Membro, Sub-membro) so changing any upper dropdown
# cascades a "Selecione..." reset all the way down.
func _reset_meshes_and_preview() -> void:
	_model_scene = null
	_display_scene = null
	_mesh_catalog = []
	cbo_meshes.clear()
	cbo_meshes.add_item(Locale.tr_key(SELECT_LABEL))
	cbo_meshes.select(0)
	cbo_meshes.disabled = true
	_reset_animations()
	_reset_effects()
	_reset_members()
	_clear_preview()


# Model dropdown index 0 is the "Selecione..." placeholder; real models start at
# index 1 (mapping to _filtered_models[index - 1]). Selecting a real model rebuilds
# the Part dropdown ("Selecione...", then "Modelo completo", then each distinct
# mesh) but leaves the placeholder selected, so nothing previews until a part is
# picked. Selecting the placeholder blanks the part dropdown and the preview.
func _on_model_selected(index: int) -> void:
	if index <= 0:
		_save_selection("sel_model", "")
		_reset_meshes_and_preview()
		return

	var model: Dictionary = _filtered_models[index - 1]
	_save_selection("sel_model", model["name"])
	_current_model_path = model["path"]
	_model_scene = load(model["path"])
	_display_scene = load(model.get("display_path", model["path"]))
	_mesh_catalog = _build_mesh_catalog(_model_scene)

	cbo_meshes.clear()
	cbo_meshes.add_item(Locale.tr_key(SELECT_LABEL))
	cbo_meshes.add_item(Locale.tr_key(WHOLE_MODEL_LABEL))
	for entry in _mesh_catalog:
		cbo_meshes.add_item(entry["label"])
	cbo_meshes.select(0)
	cbo_meshes.disabled = false
	# Part is back on its placeholder, so the dropdowns below it reset/hide too
	# (Animação, Efeitos, Membro, Sub-membro) — cascade the "Selecione..." reset down.
	_reset_animations()
	_reset_effects()
	_reset_members()
	_clear_preview()


# Part dropdown index 0 is the "Selecione..." placeholder (nothing previewed),
# index 1 is the assembled "Modelo completo", and indices 2.. map to the distinct
# meshes in _mesh_catalog (shifted by the two leading entries).
func _on_mesh_selected(index: int) -> void:
	_save_selection("sel_part", _part_value(index))
	if index <= 0:
		_clear_preview()
		_reset_animations()
		_reset_effects()
		_reset_members()
	elif index == 1:
		_preview_whole_model()
		# The animation/effects/member dropdowns only apply to "Modelo completo".
		_populate_animations()
		_populate_effects()
		_populate_members()
	else:
		# A single isolated part has no animation/effects/member combos below it.
		_preview_mesh(index - 2)
		_reset_animations()
		_reset_effects()
		_reset_members()


# Fill the "Animação" dropdown with "Selecione..." plus every clip the previewed
# model exposes; enable it only when there is at least one. Selecting a clip plays
# it on the preview (see _on_animation_selected). The whole row is shown ONLY for the
# assembled "Modelo completo" view (see _on_mesh_selected) — single parts and the
# placeholder hide it via _reset_animations.
func _populate_animations() -> void:
	animation_row.visible = true
	# Preserve the current pick across preview rebuilds (toggling colliders/audio
	# re-runs the preview), so a chosen clip keeps playing.
	var prev := "" if cbo_animations.selected <= 0 else cbo_animations.get_item_text(cbo_animations.selected)
	cbo_animations.clear()
	cbo_animations.add_item(Locale.tr_key(SELECT_LABEL))
	var seen: Dictionary = {}
	for ap: AnimationPlayer in _preview_anim_players:
		for clip in ap.get_animation_list():
			if not seen.has(clip):
				seen[clip] = true
				cbo_animations.add_item(clip)
	var restore := 0
	for i in range(1, cbo_animations.item_count):
		if cbo_animations.get_item_text(i) == prev:
			restore = i
			break
	cbo_animations.select(restore)
	cbo_animations.disabled = cbo_animations.item_count <= 1


# Reset the "Animação" dropdown to just the placeholder, disable it and HIDE the whole
# row — the combo is only shown for the assembled "Modelo completo" view.
func _reset_animations() -> void:
	cbo_animations.clear()
	cbo_animations.add_item(Locale.tr_key(SELECT_LABEL))
	cbo_animations.select(0)
	cbo_animations.disabled = true
	animation_row.visible = false


# Item 0 is "Selecione..." (stop / static rest); items 1.. are clip names. Plays the
# chosen clip (looping via the player) on every AnimationPlayer that has it — but only
# while the Animação toggle is on: with it off, picking a clip just updates the pending
# selection and plays nothing (it starts when the toggle is turned on, via _refresh_preview).
func _on_animation_selected(index: int) -> void:
	_save_selection("sel_animation", "" if index <= 0 else cbo_animations.get_item_text(index))
	if not _play_animation:
		return
	# Play the newly chosen clip in place (the appliers read cbo_animations).
	_apply_animation_state()


# Fill the "Efeitos Especiais" dropdown with "Selecione..." plus one entry per special
# effect of the previewed model (particles, lights, bone-mounted laser/muzzle meshes —
# see _collect_effect_nodes). Shown ONLY for the assembled "Modelo completo" view, like
# the animation dropdown. Preserves the current pick across preview rebuilds.
func _populate_effects() -> void:
	effects_row.visible = true
	var prev_value := _effect_value(cbo_effects.selected)
	cbo_effects.clear()
	cbo_effects.add_item(Locale.tr_key(SELECT_LABEL))
	# Only offer "Todos" (and the per-effect entries) when the model actually exposes
	# effects, so an effect-less model just shows the placeholder and stays disabled.
	if not _preview_effect_nodes.is_empty():
		cbo_effects.add_item(Locale.tr_key(ALL_EFFECTS_LABEL))
		for entry in _preview_effect_nodes:
			cbo_effects.add_item(entry["label"])
	cbo_effects.select(maxi(_effect_index_for_value(prev_value), 0))
	cbo_effects.disabled = cbo_effects.item_count <= 1
	_apply_effects_visibility()


# Reset the "Efeitos Especiais" dropdown to just the placeholder, disable it and HIDE
# the whole row — the combo is only shown for the assembled "Modelo completo" view.
func _reset_effects() -> void:
	cbo_effects.clear()
	cbo_effects.add_item(Locale.tr_key(SELECT_LABEL))
	cbo_effects.select(0)
	cbo_effects.disabled = true
	effects_row.visible = false


# Item 0 is "Selecione...", item 1 is "Todos" (show every effect), items 2.. are effect
# names. Picking a name isolates it (only that effect renders); see _apply_effects_visibility.
func _on_effect_selected(index: int) -> void:
	_save_selection("sel_effect", _effect_value(index))
	_apply_effects_visibility()


# Stable persisted value for an Efeitos index: "" (placeholder), the ALL_VALUE sentinel
# ("Todos", index 1) or the effect label (indices 2..).
func _effect_value(index: int) -> String:
	if index <= 0:
		return ""
	if index == 1:
		return ALL_VALUE
	return cbo_effects.get_item_text(index)


# Inverse of _effect_value: the Efeitos index for a saved value (0 when empty or stale).
func _effect_index_for_value(value: String) -> int:
	if value == "":
		return 0
	if value == ALL_VALUE:
		return 1 if cbo_effects.item_count > 1 else 0
	for i in range(2, cbo_effects.item_count):
		if cbo_effects.get_item_text(i) == value:
			return i
	return 0


# Show/hide the preview's special-effect nodes: nothing while the "Efeitos especiais"
# toggle is off; with it on, every effect on "Selecione..."/"Todos", or only the chosen
# one when a specific effect is picked.
func _apply_effects_visibility() -> void:
	var sel := cbo_effects.selected
	var chosen := "" if sel <= 1 else cbo_effects.get_item_text(sel)
	for entry in _preview_effect_nodes:
		var node: Node3D = entry["node"]
		if not is_instance_valid(node):
			continue
		node.visible = _show_effects and (chosen == "" or entry["label"] == chosen)


# --- Dropdowns Membro / Sub-membro (isolamento de membro no preview) ---------
#
# Só aparecem na visão "Modelo completo" de Personagens/Armas (mesma porta dos tooltips de
# membro). "Membro" lista os membros grandes (HEAD/TORSO/ARM…) lidos dos próprios colliders
# do preview; escolher um ISOLA o seu collider (mostra só ele, mesmo com o toggle Colisores
# desligado — o dropdown é seu próprio "inspecionar"). "Sub-membro" depende do membro
# escolhido e lista os PART_* daquele membro (mapeados pelo OSSO-PAI, subindo na hierarquia
# do esqueleto até o classificador devolver um membro); escolher um estreita o foco para
# membro + aquele sub-membro. O placeholder "Selecione..." em cada um = sem isolamento /
# membro inteiro. Tudo espelha o padrão de _populate_effects / _apply_effects_visibility.

# StaticBody3D de membro do preview (carimbados com a meta "group" por _add_member_colliders).
func _member_bodies() -> Array:
	var out: Array = []
	if _preview_instance == null:
		return out
	for node in _preview_instance.find_children("*", "StaticBody3D", true, false):
		if (node as StaticBody3D).has_meta("group"):
			out.append(node)
	return out


# Entradas {group,label} dos membros, na MESMA fonte usada pelo combo Membro e pelo painel Dano.
# PERSONAGENS: TODOS os membros do PLANO corporal (mesmo sem geometria no preview), na ordem do
# plano e com o rótulo do plano (CABEÇA/TRONCO/BRAÇO E-D/PERNA E-D…) — assim a lista reflete o
# corpo inteiro, não só os que têm collider. ARMAS (sem plano corporal): os grupos dos colliders
# do preview (WeaponParts), exceto os sub-membros PART_*, ordenados por rótulo.
func _plan_member_entries() -> Array:
	var out: Array = []
	if _current_category_key() == "characters":
		var c := _current_classifier()
		for g in c.members():
			out.append({"group": g, "label": c.label_of(g)})
		return out
	for body in _member_bodies():
		var g := str((body as StaticBody3D).get_meta("group"))
		if g.begins_with("PART_"):
			continue
		var lab := str((body as StaticBody3D).get_meta("member_label")) \
			if (body as StaticBody3D).has_meta("member_label") else g
		out.append({"group": g, "label": lab})
	out.sort_custom(func(a, b): return a["label"] < b["label"])
	return out


# Preenche o dropdown "Membro". Personagens: todos os membros do plano (ver _plan_member_entries);
# armas: os membros com collider. Só para Personagens/Armas em "Modelo completo"; senão esconde as
# duas rows. Preserva a escolha atual entre rebuilds (como _populate_effects).
func _populate_members() -> void:
	if not (_current_category_key() in ["characters", "weapons"]):
		_reset_members()
		return
	_ensure_member_colliders()
	member_row.visible = true
	var prev := _member_value(cbo_members.selected)
	_member_entries = _plan_member_entries()
	cbo_members.clear()
	cbo_members.add_item(Locale.tr_key(SELECT_LABEL))
	for e in _member_entries:
		cbo_members.add_item(str(e["label"]))
	cbo_members.select(maxi(_member_index_for_value(prev), 0))
	cbo_members.disabled = _member_entries.is_empty()
	_populate_sub_members()
	_refresh_member_overlays()


# Reseta o dropdown "Membro" ao placeholder, desabilita e esconde a row (e a de sub-membro).
func _reset_members() -> void:
	cbo_members.clear()
	cbo_members.add_item(Locale.tr_key(SELECT_LABEL))
	cbo_members.select(0)
	cbo_members.disabled = true
	member_row.visible = false
	_member_entries = []
	_reset_sub_members()


# Preenche o dropdown "Sub-membro" com os PART_* do membro escolhido (ou esconde a row se não
# houver membro específico escolhido ou ele não tiver sub-membros). Depende de cbo_members.
func _populate_sub_members() -> void:
	var prev := _sub_member_value(cbo_sub_members.selected)
	_sub_member_entries = []
	cbo_sub_members.clear()
	cbo_sub_members.add_item(Locale.tr_key(SELECT_LABEL))
	var msel := cbo_members.selected
	if not member_row.visible or msel <= 0:
		cbo_sub_members.select(0)
		cbo_sub_members.disabled = true
		sub_member_row.visible = false
		return
	var mgroup := str(_member_entries[msel - 1]["group"])
	var owners := _sub_member_owner_map()
	for body in _member_bodies():
		var g := str((body as StaticBody3D).get_meta("group"))
		if not g.begins_with("PART_"):
			continue
		if str(owners.get(g, "")) != mgroup:
			continue
		var lab := str((body as StaticBody3D).get_meta("member_label")) \
			if (body as StaticBody3D).has_meta("member_label") else g.substr(len("PART_"))
		_sub_member_entries.append({"group": g, "label": lab})
	_sub_member_entries.sort_custom(func(a, b): return a["label"] < b["label"])
	if _sub_member_entries.is_empty():
		cbo_sub_members.select(0)
		cbo_sub_members.disabled = true
		sub_member_row.visible = false
		return
	for e in _sub_member_entries:
		cbo_sub_members.add_item(str(e["label"]))
	sub_member_row.visible = true
	cbo_sub_members.select(maxi(_sub_member_index_for_value(prev), 0))
	cbo_sub_members.disabled = false


func _reset_sub_members() -> void:
	cbo_sub_members.clear()
	cbo_sub_members.add_item(Locale.tr_key(SELECT_LABEL))
	cbo_sub_members.select(0)
	cbo_sub_members.disabled = true
	sub_member_row.visible = false
	_sub_member_entries = []


# Escolher um membro: persiste, repopula os sub-membros daquele membro e reaplica o isolamento.
func _on_member_selected(index: int) -> void:
	_save_selection("sel_member", _member_value(index))
	_populate_sub_members()
	_refresh_member_overlays()


# Escolher um sub-membro: persiste e reaplica o isolamento (membro + aquele sub-membro).
func _on_sub_member_selected(index: int) -> void:
	_save_selection("sel_submember", _sub_member_value(index))
	_refresh_member_overlays()


# Valor estável persistido de um índice de "Membro": "" (placeholder) ou o group do membro.
func _member_value(index: int) -> String:
	if index <= 0 or index - 1 >= _member_entries.size():
		return ""
	return str(_member_entries[index - 1]["group"])


# Inverso de _member_value: o índice do combo para um group salvo (0 quando vazio/inexistente).
func _member_index_for_value(value: String) -> int:
	if value == "":
		return 0
	for i in _member_entries.size():
		if str(_member_entries[i]["group"]) == value:
			return i + 1
	return 0


func _sub_member_value(index: int) -> String:
	if index <= 0 or index - 1 >= _sub_member_entries.size():
		return ""
	return str(_sub_member_entries[index - 1]["group"])


func _sub_member_index_for_value(value: String) -> int:
	if value == "":
		return 0
	for i in _sub_member_entries.size():
		if str(_sub_member_entries[i]["group"]) == value:
			return i + 1
	return 0


# Mapa PART_<osso> → group do membro DONO. Dois critérios, nesta ordem:
#   1) NOME da peça (classifier.owner_hint): uma placa costuma dizer no nome a que membro
#      pertence ("shoulderpad.L" → BRAÇO E), mesmo pendurada noutro osso. Resolve casos como
#      a ombreira do player, filha do "chest" (a hierarquia a colocaria no TRONCO).
#   2) HIERARQUIA: sobe do osso da peça na cadeia de pais até o classificador devolver um
#      membro — esse é o dono (caso o nome não decida; ex.: placas penduradas no membro certo).
# Vazio para rigs sem esqueleto (não têm PART_*).
func _sub_member_owner_map() -> Dictionary:
	var out: Dictionary = {}
	if _preview_instance == null:
		return out
	var skels: Array = _preview_instance.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return out
	var skel := skels[0] as Skeleton3D
	var classifier := _current_classifier()
	var head := _head_bones_for_current()
	var torso := _torso_bones_for_current()
	# Resolvedor compartilhado com o rótulo (LimbColliders._part_label): nome da peça → owner_hint
	# subindo na hierarquia (pega escudos presos a ossos AUX/IK, ex.: L-Shield → L-ARMIK → BRAÇO).
	for body in _member_bodies():
		var g := str((body as StaticBody3D).get_meta("group"))
		if not g.begins_with("PART_"):
			continue
		var bone_name := g.substr(len("PART_"))
		out[g] = LimbColliders.resolve_sub_member_owner(skel, bone_name, classifier, head, torso, [])
	return out


# Conjunto de groups em FOCO conforme os dropdowns, ou null quando não há isolamento
# (row escondida ou "Membro" no placeholder). SEM sub-membro escolhido → foca SÓ o collider do
# MEMBRO (não inclui os sub-membros). COM um sub-membro escolhido → foca SÓ aquele sub-membro
# (não inclui o membro). Assim o isolamento mostra exatamente uma peça por vez.
func _current_focus_groups():
	if not member_row.visible:
		return null
	var msel := cbo_members.selected
	if msel <= 0 or msel - 1 >= _member_entries.size():
		return null
	var ssel := cbo_sub_members.selected
	if sub_member_row.visible and ssel >= 1 and ssel - 1 < _sub_member_entries.size():
		return {str(_sub_member_entries[ssel - 1]["group"]): true}
	return {str(_member_entries[msel - 1]["group"]): true}


# Reaplica os overlays de membro (gizmos de collider + pilhas de label) respeitando o foco
# dos dropdowns. SEM foco: estado normal dos toggles (Colisores/Rótulos). COM foco: garante
# que os gizmos existam (mesmo com Colisores off — o dropdown é seu próprio "inspecionar") e
# esconde tudo que não está no foco. O ramo de foco NUNCA remove gizmos (só adiciona/esconde),
# evitando corrida com o queue_free do _apply_colliders_visibility.
func _refresh_member_overlays() -> void:
	if _preview_instance == null:
		return
	var focus = _current_focus_groups()
	if focus == null:
		_apply_colliders_visibility()
		_apply_member_labels_visibility()
		return
	_ensure_member_colliders()
	_apply_member_labels_visibility()        # (re)cria as pilhas conforme os toggles
	_add_collider_gizmos(_preview_instance)  # idempotente: garante gizmo no membro em foco
	for body in _member_bodies():
		var vis: bool = focus.has(str((body as StaticBody3D).get_meta("group")))
		for giz in body.find_children(_GIZMO_NAME, "MeshInstance3D", true, false):
			(giz as MeshInstance3D).visible = vis
		# Esconde a pilha inteira de quem está fora de foco (o pivô agrupa as 4 linhas);
		# em foco, o pivô fica visível e cada linha mantém o próprio toggle.
		for piv in body.find_children(_LABEL_PREFIX + "Pivot", "Node3D", true, false):
			(piv as Node3D).visible = vis


func _on_rotate_toggled(pressed: bool) -> void:
	_auto_rotate = pressed
	_save_toggle("auto_rotate", pressed)


# Every toggle below acts on the EXISTING preview in place (play/stop, mute, show/
# hide) — never a rebuild — so the model is not reloaded and the camera/rotation
# stay exactly as the user left them.
func _on_animation_toggled(pressed: bool) -> void:
	_play_animation = pressed
	_save_toggle("play_animation", pressed)
	_apply_animation_state()


func _on_audio_toggled(pressed: bool) -> void:
	_play_audio = pressed
	_save_toggle("play_audio", pressed)
	_apply_audio_state()


func _on_colliders_toggled(pressed: bool) -> void:
	_show_colliders = pressed
	_save_toggle("show_colliders", pressed)
	# Via _refresh_member_overlays (não direto _apply_colliders_visibility) para o
	# isolamento Membro/Sub-membro, se ativo, continuar valendo após mexer no toggle.
	_refresh_member_overlays()


# Toggle PRÓPRIO dos rótulos de membro do browser: liga/desliga os Label3D "Membro: …"
# sobre os colliders, sem depender da tela de Debug 3D.
func _on_labels_toggled(pressed: bool) -> void:
	_show_member_labels = pressed
	_save_toggle("show_member_labels", pressed)
	_refresh_member_overlays()


# Checkboxes dedicados das linhas extras do tooltip (Skeleton3D): Tipo/Nome/ID. Cada um
# liga/desliga sua linha, independente do Debug 3D global (que só vale nos levels).
func _on_type_toggled(pressed: bool) -> void:
	_show_type = pressed
	_save_toggle("show_type", pressed)
	_refresh_member_overlays()


func _on_name_toggled(pressed: bool) -> void:
	_show_name = pressed
	_save_toggle("show_name", pressed)
	_refresh_member_overlays()


func _on_id_toggled(pressed: bool) -> void:
	_show_id = pressed
	_save_toggle("show_id", pressed)
	_refresh_member_overlays()


# True quando QUALQUER linha de rótulo de membro está ligada (Membro/Tipo/Nome/ID) — decide
# construir colliders/labels do preview, já sem ler nada do Debug 3D global.
func _any_member_label() -> bool:
	return _show_member_labels or _show_type or _show_name or _show_id


# Abre/fecha o painel de edição de dano por membro (só popula para personagem em
# "Modelo completo"; _refresh_damage_panel decide a visibilidade real).
func _on_damage_toggled(pressed: bool) -> void:
	_show_damage_panel = pressed
	_refresh_damage_panel()


# The special-effect nodes already live in the preview (collected on build), so toggling
# just flips their visibility — no rebuild needed (cheaper, no flicker).
func _on_effects_toggled(pressed: bool) -> void:
	_show_effects = pressed
	_save_toggle("show_effects", pressed)
	_apply_effects_visibility()


# Persist one preview toggle so the model browser reopens with the same options.
func _save_toggle(key: String, value: bool) -> void:
	Settings.config_file.set_value("models", key, value)
	Settings.save_settings()


# --- Selection persistence + restore ----------------------------------------

# Persist one dropdown selection so the browser reopens on the same chain. Stored by a
# STABLE value (category key / prefix token / model name / clip / effect label, or the
# WHOLE_MODEL_VALUE sentinel for "Modelo completo") rather than by index, so it survives
# the library being re-scanned in a different order. "" means the placeholder.
func _save_selection(key: String, value: String) -> void:
	Settings.config_file.set_value("models", key, value)
	Settings.save_settings()


# Stable value for a Categoria index: the category key (index 0 / out of range -> "").
func _category_value(index: int) -> String:
	var i := index - 1
	return String(_categories[i]["key"]) if i >= 0 and i < _categories.size() else ""


# Stable value for a Parte index: "" (placeholder), the WHOLE_MODEL_VALUE sentinel
# ("Modelo completo", index 1) or the mesh label (indices 2..).
func _part_value(index: int) -> String:
	if index <= 0:
		return ""
	if index == 1:
		return WHOLE_MODEL_VALUE
	return cbo_meshes.get_item_text(index)


# Replay the persisted Categoria -> Prefixo -> Modelo -> Parte chain (and, for "Modelo
# completo", the parallel Animação/Efeitos leaves) so the browser reopens exactly where
# the user left it. select() does not emit item_selected, so each step also calls its
# handler explicitly — populating the next dropdown just like a real click would.
#
# Per saved value at each level:
#   * empty -> the user simply stopped here: leave this dropdown enabled on its
#     placeholder, ready to continue. With everything empty this reproduces the blank
#     first-run start (every combo "Selecione...", nothing previewed).
#   * stale -> the saved choice no longer exists in the library, so there is "no more
#     data" for it: DISABLE this dropdown, and since its handler never runs the rest of
#     the chain below stays disabled too.
func _restore_selection_chain() -> void:
	var cfg := Settings.config_file
	var v_cat: String = cfg.get_value("models", "sel_category", "")
	var v_pre: String = cfg.get_value("models", "sel_prefix", "")
	var v_mod: String = cfg.get_value("models", "sel_model", "")
	var v_part: String = cfg.get_value("models", "sel_part", "")
	var v_anim: String = cfg.get_value("models", "sel_animation", "")
	var v_eff: String = cfg.get_value("models", "sel_effect", "")
	var v_member: String = cfg.get_value("models", "sel_member", "")
	var v_submember: String = cfg.get_value("models", "sel_submember", "")

	# Categoria — the root dropdown is always enabled. A missing/stale value falls back to
	# the placeholder, which resets and disables the whole chain below it.
	var ci := _find_category_index(v_cat)
	if ci <= 0:
		cbo_category.select(0)
		_on_category_selected(0)
		return
	cbo_category.select(ci)
	_on_category_selected(ci)

	# Prefixo
	if v_pre == "":
		return
	var pi := _find_prefix_index(v_pre)
	if pi <= 0:
		cbo_prefix.disabled = true
		return
	cbo_prefix.select(pi)
	_on_prefix_selected(pi)

	# Modelo
	if v_mod == "":
		return
	var mi := _find_model_index(v_mod)
	if mi <= 0:
		cbo_models.disabled = true
		return
	cbo_models.select(mi)
	_on_model_selected(mi)

	# Parte
	if v_part == "":
		return
	var qi := _find_part_index(v_part)
	if qi <= 0:
		cbo_meshes.disabled = true
		return
	cbo_meshes.select(qi)
	_on_mesh_selected(qi)
	# A single isolated mesh exposes no Animação/Efeitos combos below it.
	if qi != 1:
		return

	# Animação and Efeitos are parallel leaves of "Modelo completo": restore each on its own.
	# A stale saved value disables that one combo; an empty one leaves it enabled on its
	# placeholder (nothing further down depends on either).
	var ai := _find_combo_text_index(cbo_animations, v_anim)
	if ai > 0:
		cbo_animations.select(ai)
		_on_animation_selected(ai)
	elif v_anim != "":
		cbo_animations.disabled = true
	var ei := _effect_index_for_value(v_eff)
	if ei > 0:
		cbo_effects.select(ei)
		_on_effect_selected(ei)
	elif v_eff != "":
		cbo_effects.disabled = true

	# Membro/Sub-membro: também leaves de "Modelo completo" (só Personagens/Armas). _populate_members
	# já rodou em _on_mesh_selected(1), então os entries existem. Restaura o membro e, se válido, o
	# sub-membro (que só existe depois do membro repopular sua lista de PART_*).
	var mem_i := _member_index_for_value(v_member)
	if mem_i > 0:
		cbo_members.select(mem_i)
		_on_member_selected(mem_i)
		var sub_i := _sub_member_index_for_value(v_submember)
		if sub_i > 0:
			cbo_sub_members.select(sub_i)
			_on_sub_member_selected(sub_i)


# Index of the Categoria item with the given category key, or -1 if none/empty.
func _find_category_index(value: String) -> int:
	if value == "":
		return -1
	for i in range(_categories.size()):
		if String(_categories[i]["key"]) == value:
			return i + 1
	return -1


# Index of the Prefixo item whose metadata equals the saved prefix token, or -1.
func _find_prefix_index(value: String) -> int:
	if value == "":
		return -1
	for i in range(1, cbo_prefix.item_count):
		if String(cbo_prefix.get_item_metadata(i)) == value:
			return i
	return -1


# Index of the Modelo item with the given (displayed) model name, or -1.
func _find_model_index(value: String) -> int:
	if value == "":
		return -1
	for i in range(1, cbo_models.item_count):
		if cbo_models.get_item_text(i) == value:
			return i
	return -1


# Index of the Parte item for a saved part value: WHOLE_MODEL_VALUE -> the "Modelo
# completo" entry at index 1; otherwise the mesh whose label matches. -1 if none/empty.
func _find_part_index(value: String) -> int:
	if value == "":
		return -1
	if value == WHOLE_MODEL_VALUE:
		return 1 if cbo_meshes.item_count > 1 else -1
	for i in range(2, cbo_meshes.item_count):
		if cbo_meshes.get_item_text(i) == value:
			return i
	return -1


# Index of the first real (index >= 1) item of `combo` whose text equals `value`, or -1.
func _find_combo_text_index(combo: OptionButton, value: String) -> int:
	if value == "":
		return -1
	for i in range(1, combo.item_count):
		if combo.get_item_text(i) == value:
			return i
	return -1


# --- Library scanning -------------------------------------------------------

# For each category in CATEGORIES, scan LIBRARY_ROOT/<categoria>/<modelo>/ and
# collect one entry per model folder. Categories with no models are dropped.
func _scan_library() -> Array:
	var result: Array = []
	for category in CATEGORIES:
		var type_path := LIBRARY_ROOT.path_join(category["key"])
		var type_access := DirAccess.open(type_path)
		if type_access == null:
			continue

		var models: Array = []
		for model_dir in type_access.get_directories():
			var model_path := type_path.path_join(model_dir)
			var file_path := _find_model_file(model_path)
			if file_path != "":
				models.append({
					"name": _prettify(model_dir),
					"path": file_path,
					"display_path": _find_display_file(model_path),
					"prefix": _prefix_of(model_dir),
				})

		if not models.is_empty():
			models.sort_custom(func(a, b): return a["name"] < b["name"])
			result.append({
				"key": category["key"],
				"label": category["label"],
				"models": models,
			})

	return result


# Em builds EXPORTADOS, os arquivos-fonte não vão crus no PCK: o modelo importado vira
# "<nome>.glb.import" e as cenas viram "<nome>.tscn.remap" (ambos apontam para o recurso importado).
# No EDITOR os arquivos crus existem (com um ".import" ao lado). Normaliza tirando o sufixo
# ".import"/".remap" → devolve o caminho lógico ("red_robot.glb.import" → "red_robot.glb",
# "red_robot.tscn.remap" → "red_robot.tscn"), que load() resolve nos dois contextos. Sem isso o
# scanner não acha modelo nenhum no .exe e o menu Categoria fica vazio.
func _logical_name(file_name: String) -> String:
	var ext := file_name.get_extension().to_lower()
	if ext == "remap" or ext == "import":
		return file_name.get_basename()
	return file_name


# Pick the previewable resource in a model folder: the raw imported model
# (.glb / .gltf) if present — so we show the mesh without running any gameplay
# script — otherwise an assembled scene (.tscn). Only files directly in the
# folder are considered (subfolders like audio/ or bullet/ are ignored).
# A folder may hold more than one scene (e.g. criatura_alada/ also ships
# bomb.tscn, the projectile it drops); the file whose basename matches the
# folder name is the model itself, so it wins over any sibling scene.
func _find_model_file(folder: String) -> String:
	var access := DirAccess.open(folder)
	if access == null:
		return ""
	var model_name := folder.get_file()
	var mesh_path: String = ""
	var mesh_named: String = ""
	var scene_path: String = ""
	var scene_named: String = ""
	for raw_name in access.get_files():
		var file_name := _logical_name(raw_name)
		var is_named := file_name.get_basename() == model_name
		match file_name.get_extension().to_lower():
			"glb", "gltf":
				if mesh_path == "":
					mesh_path = folder.path_join(file_name)
				if is_named and mesh_named == "":
					mesh_named = folder.path_join(file_name)
			"tscn":
				if scene_path == "":
					scene_path = folder.path_join(file_name)
				if is_named and scene_named == "":
					scene_named = folder.path_join(file_name)
	if mesh_named != "":
		return mesh_named
	if mesh_path != "":
		return mesh_path
	if scene_named != "":
		return scene_named
	return scene_path


# Pick the resource for the assembled "Modelo completo" view: the authored scene
# (.tscn) when present — it carries the materials, effects and the intended
# visible setup the raw mesh lacks — falling back to whatever _find_model_file
# resolves (the .glb) when there is no scene.
func _find_display_file(folder: String) -> String:
	var access := DirAccess.open(folder)
	if access == null:
		return ""
	var model_name := folder.get_file()
	var scene_path: String = ""
	for raw_name in access.get_files():
		var file_name := _logical_name(raw_name)
		if file_name.get_extension().to_lower() == "tscn":
			# The scene named after the folder is the model; a sibling scene
			# (e.g. bomb.tscn next to criatura_alada.tscn) must not shadow it.
			if file_name.get_basename() == model_name:
				return folder.path_join(file_name)
			if scene_path == "":
				scene_path = folder.path_join(file_name)
	if scene_path != "":
		return scene_path
	return _find_model_file(folder)


# --- Mesh catalog (de-duplicated reusable assets) ---------------------------

# Walk every MeshInstance3D in the model and group them by their shared Mesh
# resource, so each distinct mesh shows up once. Entries are sorted by how many
# times the mesh is placed (most-used first), which surfaces the "main" pieces.
func _build_mesh_catalog(scene: PackedScene) -> Array:
	var result: Array = []
	if scene == null:
		return result

	var instance := scene.instantiate()
	var nodes: Array = instance.find_children("*", "MeshInstance3D", true, false)
	if instance is MeshInstance3D:
		nodes.append(instance)

	var by_mesh: Dictionary = {}
	var entries: Array = []
	for node in nodes:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var id := mesh_instance.mesh.get_instance_id()
		if not by_mesh.has(id):
			var has_collision := not mesh_instance.find_children(
				"*", "CollisionShape3D", true, false
			).is_empty()
			# Capture the instance's materials so a single-part preview keeps its
			# look. Some models (criatura_alada) paint their meshes via
			# material_override / per-surface overrides on the INSTANCE rather than
			# baking them into the Mesh surfaces — without this the isolated part
			# would render untextured.
			var surface_overrides: Array = []
			for s in mesh_instance.mesh.get_surface_count():
				surface_overrides.append(mesh_instance.get_surface_override_material(s))
			by_mesh[id] = entries.size()
			entries.append({
				"mesh": mesh_instance.mesh,
				"name": _group_key(mesh_instance.name),
				"count": 0,
				"has_collision": has_collision,
				"skinned": mesh_instance.skin != null,
				"material_override": mesh_instance.material_override,
				"surface_overrides": surface_overrides,
			})
		entries[by_mesh[id]]["count"] += 1
	instance.free()

	entries.sort_custom(func(a, b):
		if a["count"] != b["count"]:
			return a["count"] > b["count"]
		return a["name"] < b["name"])

	for entry in entries:
		var label: String = _prettify(entry["name"])
		if entry["count"] > 1:
			label += " (×%d)" % entry["count"]
		if entry["skinned"]:
			label += " [skin]"
		elif entry["has_collision"]:
			label += " [+col]"
		entry["label"] = label
		result.append(entry)
	return result


# Grouping prefix of a model folder: the first underscore-separated token.
# "core_out_light" -> "core", "red_robot" -> "red", "forklift" -> "forklift".
func _prefix_of(folder_name: String) -> String:
	var parts := folder_name.split("_", false)
	return parts[0] if not parts.is_empty() else folder_name


# "prop_cargobox5b_022" -> "prop_cargobox5b", "Spot_010" -> "Spot".
# Strips trailing _<number> groups without eating mid-name digits.
func _group_key(node_name: String) -> String:
	var regex := RegEx.new()
	regex.compile("_[0-9]+$")
	var result := node_name
	while true:
		var match_result := regex.search(result)
		if match_result == null:
			break
		var stripped := result.substr(0, match_result.get_start())
		if stripped == "":
			break
		result = stripped
	return result


# --- Preview ----------------------------------------------------------------

func _clear_preview() -> void:
	for child in model_holder.get_children():
		child.queue_free()
	_preview_instance = null
	_preview_anim_players = []
	_main_anim_player = null
	_main_body_root = null
	_preview_audio_players = []
	_preview_audio_volumes = {}
	_member_colliders_built = false
	_preview_effect_nodes = []
	_member_label_pivots = []
	_yaw = 0.0
	_pitch = 0.0
	model_holder.rotation = Vector3.ZERO
	# Rede de segurança do editor de dano: qualquer teardown de preview (trocar/desmarcar
	# modelo, ir para mesh isolada) oculta o painel; o build do "Modelo completo" o reexibe.
	if _show_damage_panel and is_instance_valid(damage_panel):
		_refresh_damage_panel()


# Show a single instance of the selected distinct mesh, centered and fit to view.
func _preview_mesh(index: int) -> void:
	_clear_preview()
	if index < 0 or index >= _mesh_catalog.size():
		return
	var mesh_instance := MeshInstance3D.new()
	var entry: Dictionary = _mesh_catalog[index]
	mesh_instance.mesh = entry["mesh"]
	# Re-apply the materials captured from the source instance so painted-by-
	# override models (e.g. criatura_alada) keep their texture in the part view.
	mesh_instance.material_override = entry.get("material_override", null)
	var surface_overrides: Array = entry.get("surface_overrides", [])
	for s in surface_overrides.size():
		mesh_instance.set_surface_override_material(s, surface_overrides[s])
	model_holder.add_child(mesh_instance)
	_preview_instance = mesh_instance
	_fit_to_view(mesh_instance)


# Show the whole model with every object in place (the default view when a model
# is picked), centered and fit to view. Uses the assembled scene (_display_scene)
# so materials and effects show, and strips its scripts first so gameplay logic
# never runs — the preview stays static and the scene's saved visibility decides
# what shows (e.g. the forklift's one clean colour variant, not a random pick).
func _preview_whole_model() -> void:
	_clear_preview()
	if _display_scene == null:
		return
	var instance := _display_scene.instantiate()
	# Level the model: disregard any baked angular tilt the .glb root carries so it
	# previews upright. The user's drag then rotates it on orthogonal axes only.
	if instance is Node3D:
		(instance as Node3D).rotation = Vector3.ZERO
	_strip_scripts(instance)
	# Catalog the special-effect nodes (particles, lights, bone-mounted laser/muzzle
	# meshes). Their visibility is decided by the "Efeitos especiais" toggle + dropdown
	# via _apply_effects_visibility (called from _populate_effects after this returns);
	# _fit_to_view ignores them, so framing is unaffected either way.
	_preview_effect_nodes = _collect_effect_nodes(instance)
	# Capture autoplay/volumes and DISABLE any AnimationTree BEFORE the subtree
	# enters the tree, so nothing autostarts and the tree never fights the clip we
	# drive directly (that double-drive is what made red_robot look like two
	# overlapping models). Playback is then started below per the active toggles.
	_capture_av(instance)
	# The model browser draws its OWN richer member labels (head/torso overrides) over the
	# preview, so tell the global Debug 3D overlay not to ALSO label this subtree's skeleton
	# (its skeleton-line/mesh-box gizmos still apply). Avoids double member labels.
	DebugOverlay.exempt_member_labels(instance)
	model_holder.add_child(instance)
	_preview_instance = instance
	_apply_animation_state()
	_apply_audio_state()
	# Detect members for characters and weapons either way: their colliders feed the
	# always-on member tooltips; for other categories we only build them to draw the
	# collider gizmos when the toggle is on.
	var show_members := _current_category_key() in ["characters", "weapons"]
	_member_colliders_built = false
	if _show_colliders or _any_member_label() or show_members:
		# Build the per-member colliders (best-fit sphere/box/capsule) — the preview
		# strips the gameplay script that normally builds them, so we do it here.
		_add_member_colliders(instance)
		_member_colliders_built = true
	if instance is Node3D:
		# Frame from the POSED body (the member colliders) when we have them: a
		# skinned mesh's get_aabb() is the bind pose, which for red_robot sits ~1.4 m
		# off the idle pose in Z — using it would anchor the pivot behind the body so
		# it swings away when rotated. The collider bounds track the real pose.
		var posed := _posed_member_bounds(instance) if _member_colliders_built else AABB()
		if posed.size != Vector3.ZERO:
			_fit_to_view(instance as Node3D, 2.0, posed)
		else:
			_fit_to_view(instance as Node3D)
	if _show_colliders:
		_add_collider_gizmos(instance)
	# Rótulos de membro (TYPE/Name/ID/Membro): cada linha segue seu PRÓPRIO toggle da cena
	# Models (Rótulos/Tipo/Nome/ID), totalmente desacoplado do Debug 3D global.
	if _member_colliders_built and _any_member_label():
		_add_member_labels(instance)
	# Editor de dano por membro: repopula se o painel estiver aberto (só personagem completo).
	if _show_damage_panel:
		_refresh_damage_panel()


# Capture the preview's animation/audio state into fields and neutralise anything
# that would start on its own, BEFORE the subtree enters the tree (autoplay fires on
# tree entry). Clears every AnimationPlayer's autoplay and records each emitter's
# authored volume so the in-place appliers can later (re)start or mute/un-mute them
# without rebuilding. Also disables every AnimationTree so it never poses the
# skeleton in parallel with the clip we drive directly.
func _capture_av(instance: Node) -> void:
	_preview_anim_players = []
	_main_anim_player = null
	for node in instance.find_children("*", "AnimationPlayer", true, false):
		var ap := node as AnimationPlayer
		# Clear authored autoplay so no clip starts on tree entry — playback is driven
		# explicitly by the Animação toggle + combo via _apply_animation_state.
		ap.autoplay = ""
		_preview_anim_players.append(ap)
	for node in instance.find_children("*", "AnimationTree", true, false):
		var tree := node as AnimationTree
		# The clips carry their root motion on a bone (e.g. Skeleton3D:MASTER) that the
		# tree extracted (and the gameplay script applied to the body). Driving a clip
		# straight from the AnimationPlayer would instead APPLY that bone, translating the
		# whole skeleton — which made red_robot drift ~1.6 m and look like a second model
		# behind the first. Copy the tree's root_motion_track onto the player it drives so
		# the clip plays IN PLACE (the root motion is extracted, and we simply discard it).
		var ap := tree.get_node_or_null(tree.anim_player) as AnimationPlayer
		if ap != null:
			if not tree.root_motion_track.is_empty():
				ap.root_motion_track = tree.root_motion_track
			_main_anim_player = ap
		tree.active = false
	# With no AnimationTree, treat the richest player as the main one (the others are
	# usually one-shot effect/death clips that must not auto-play over the model).
	if _main_anim_player == null:
		for ap: AnimationPlayer in _preview_anim_players:
			if _main_anim_player == null or ap.get_animation_list().size() > _main_anim_player.get_animation_list().size():
				_main_anim_player = ap
	# The body subtree is the main player's model root (e.g. RedRobotModel), a sibling of
	# the debris/death node — so hiding it doesn't hide the explosion.
	_main_body_root = _main_anim_player.get_parent() as Node3D if _main_anim_player != null else null

	_preview_audio_players = []
	_preview_audio_volumes = {}
	for cls in ["AudioStreamPlayer", "AudioStreamPlayer3D", "AudioStreamPlayer2D"]:
		for node in instance.find_children("*", cls, true, false):
			_preview_audio_players.append(node)
			_preview_audio_volumes[node] = node.get("volume_db")
			node.set("autoplay", false)


# Apply the Animação toggle to the live preview: with it off, stop every player;
# with it on, play the "Animação" dropdown's clip (falling back to the model's
# autoplay clip, then its first clip) on each player that has it. Re-applies the
# audio state afterwards so animation-driven sound respects the Audio/Falas toggles.
func _apply_animation_state() -> void:
	var chosen := "" if cbo_animations.selected <= 0 else cbo_animations.get_item_text(cbo_animations.selected)
	# An animation plays ONLY when BOTH the Animação toggle is on AND a clip is explicitly
	# chosen in the combo. With the toggle off, or while the combo still sits on
	# "Selecione...", nothing plays — there is no default/idle auto-play.
	var should_play := _play_animation and chosen != ""
	# A death/explosion clip reveals the model's debris; hide the live body so the preview
	# shows ONLY the explosion (otherwise the intact body and the debris overlap).
	if is_instance_valid(_main_body_root):
		_main_body_root.visible = not (should_play and _is_death_clip(chosen))
	for ap: AnimationPlayer in _preview_anim_players:
		if not is_instance_valid(ap):
			continue
		# Play the chosen clip on whichever player owns it; stop every other player (and all
		# of them when nothing should play).
		if should_play and ap.has_animation(chosen):
			ap.play(chosen)
		else:
			ap.stop()
	_apply_audio_state()


# A death/explosion clip (by common naming) that reveals the model's debris instead of
# animating the body — the live body is hidden while one of these plays.
func _is_death_clip(clip: String) -> bool:
	var c := clip.to_lower()
	return c.contains("kaboom") or c.contains("explo") or c.contains("death") or c.contains("die") or c.contains("destr")


# Apply the Audio toggle to the live preview's emitters in place: each emitter is muted
# (volume_db -80) when the toggle is off and restored to its authored volume when on;
# standalone emitters are (re)started when on, the rest stopped. Muting the volume is what
# also gates sound triggered from animation tracks. Covers every emitter — movement, motor,
# shots, explosions and voices alike (there is no separate speech toggle anymore).
func _apply_audio_state() -> void:
	for node in _preview_audio_players:
		if not is_instance_valid(node):
			continue
		var wanted := _play_audio
		var authored: float = _preview_audio_volumes.get(node, 0.0)
		node.set("volume_db", authored if wanted else -80.0)
		if node.get("stream") == null:
			continue
		if wanted:
			if not node.get("playing"):
				node.play()
		else:
			node.stop()


# Recursively detach every script in the instanced subtree before it enters the
# tree, so no _ready / gameplay code runs during the static preview.
func _strip_scripts(node: Node) -> void:
	node.set_script(null)
	for child in node.get_children():
		_strip_scripts(child)


# Effect node classes surfaced by the "Efeitos Especiais" dropdown — every kind of
# special effect a model may carry: lights (luminosity/shadows — Light3D covers Omni/
# Spot/Directional), particle systems (smoke, sparks, thrust — GPU/CPU), and the other
# visual-effect volumes (decals, fog, particle attractors/colliders). is_class() matches
# subclasses too, so listing the base class is enough.
const _EFFECT_CLASSES: Array[String] = [
	"GPUParticles3D", "CPUParticles3D", "Light3D",
	"Decal", "FogVolume", "GPUParticlesAttractor3D", "GPUParticlesCollision3D",
]


# Collect the model's gameplay-only flourishes — particles (smoke/thrust), lights
# (luminosity/shadows), decals/fog/other effect volumes, and meshes pinned to a bone
# (muzzle/laser) — the "remaining" elements no other toggle covers. Returned as
# [{"label", "node"}] for the "Efeitos Especiais" dropdown; the caller decides their
# visibility via _apply_effects_visibility.
func _collect_effect_nodes(instance: Node) -> Array:
	var out: Array = []
	for node in instance.find_children("*", "Node3D", true, false):
		var is_effect := false
		for cls in _EFFECT_CLASSES:
			if node.is_class(cls):
				is_effect = true
				break
		if not is_effect and node is MeshInstance3D and _under_bone_attachment(node, instance):
			is_effect = true
		if is_effect:
			out.append({"label": _prettify(String(node.name)), "node": node})
	return out


# Name carried by every collider wireframe gizmo, so the Colliders toggle can add
# them once and strip them back out in place without touching anything else.
const _GIZMO_NAME := "_ColliderGizmo"

# Prefixo dos nós de tooltip de membro (Tipo/Nome/ID/Membro): o pivô da pilha é
# "_MdlLbl_Pivot" e cada linha "_MdlLbl_<Id>", para os toggles da cena Models acharem e
# recriarem tudo in-place sem tocar no resto.
const _LABEL_PREFIX := "_MdlLbl_"

# Cor distinta por LINHA do tooltip de membro. A MESMA cor é aplicada ao texto do toggle que
# controla a linha (Membro→Rótulos, Tipo→Tipo, Nome→Nome, ID→ID), para o usuário associar de
# relance o controle ao seu rótulo 3D. As chaves casam com o "id" das linhas em _add_member_labels.
const _LABEL_LINE_COLORS := {
	"Member": Color(0.45, 0.85, 1.0),   # azul-ciano (membro)
	"Type": Color(1.0, 0.66, 0.32),     # laranja (tipo)
	"Name": Color(0.55, 1.0, 0.55),     # verde (nome)
	"Id": Color(1.0, 0.92, 0.42),       # amarelo (id)
}

# Tamanho dos Label3D de membro (compartilhado entre a construção e o anti-colisão por tela,
# que projeta o bloco usando estes números). _LBL_LINE_STEP é o passo em Y entre linhas.
const _LBL_PIXEL_SIZE := 0.003
const _LBL_FONT_SIZE := 14
const _LBL_LINE_STEP := 0.06


# Apply the Colliders toggle to the live preview in place: build the member colliders
# on first use, then add or remove the wireframe gizmos — no rebuild, so the camera
# and rotation are untouched.
func _apply_colliders_visibility() -> void:
	if _preview_instance == null:
		return
	if _show_colliders:
		_ensure_member_colliders()
		_add_collider_gizmos(_preview_instance)
	else:
		for gizmo in _preview_instance.find_children(_GIZMO_NAME, "MeshInstance3D", true, false):
			gizmo.queue_free()


# Build the per-member colliders once for the current preview (idempotent), so the
# Colliders toggle can draw gizmos for categories whose colliders were not built at
# preview time (characters/weapons already build them for the member tooltips).
func _ensure_member_colliders() -> void:
	if _member_colliders_built or _preview_instance == null:
		return
	_add_member_colliders(_preview_instance)
	_member_colliders_built = true


# Aplica os toggles de rótulo (Rótulos/Tipo/Nome/ID) no preview ao vivo, in-place: remove a
# pilha de labels atual e a recria com a visibilidade certa por linha. Sem rebuild do modelo
# → câmera/rotação intactas. Nada é lido do Debug 3D global.
func _apply_member_labels_visibility() -> void:
	if _preview_instance == null:
		return
	# Remove as pilhas atuais (cada pivô leva junto suas linhas) e zera o índice do anti-colisão.
	for pivot in _preview_instance.find_children(_LABEL_PREFIX + "Pivot", "Node3D", true, false):
		(pivot as Node3D).free()
	_member_label_pivots = []
	if not _any_member_label():
		return
	_ensure_member_colliders()
	_add_member_labels(_preview_instance)


# --- Editor de dano por membro ----------------------------------------------

# Chave do modelo atual = nome da pasta que contém o .tscn (ex.: "red_robot", "player").
# É a MESMA chave que o gameplay define em LimbColliders.model_key, então o que o editor
# grava em LimbConfig é exatamente o que player.gd/red_robot.gd leem em partida.
func _current_model_key() -> String:
	if _current_model_path == "":
		return ""
	return _current_model_path.get_base_dir().get_file()


# Plano corporal do modelo atual (espelha o @export body_type do gameplay, que o preview
# não enxerga porque os scripts são removidos). Default bípede.
func _body_type_for_current() -> String:
	return _MODEL_BODY_TYPE.get(_current_model_key(), "biped")


# Instância do classificador do modelo atual (para dano default e labels).
func _current_classifier() -> BodyParts:
	return BodyPlans.for_type(_body_type_for_current())


# True quando o preview é um PERSONAGEM em "Modelo completo" — a única situação em que o
# editor de dano por membro faz sentido (precisa do dono e dos membros completos).
func _preview_is_whole_character() -> bool:
	return _current_category_key() == "characters" \
		and _part_value(cbo_meshes.selected) == WHOLE_MODEL_VALUE


# (Re)constrói o painel: uma linha por membro (rótulo + SpinBox de bônus %), lendo o valor
# salvo em LimbConfig. Oculta o painel quando o toggle está off ou o preview não é um
# personagem completo. Idempotente — limpa as linhas antigas antes de repopular.
func _refresh_damage_panel() -> void:
	for child in damage_rows.get_children():
		child.queue_free()
	if not _show_damage_panel or not _preview_is_whole_character() or _preview_instance == null:
		damage_panel.visible = false
		return
	_ensure_member_colliders()
	var model_key := _current_model_key()
	# Membros do plano (todos), na MESMA ordem/fonte do combo Membro. Cada membro vira uma linha
	# e, INDENTADOS logo abaixo dele, seus sub-membros (PART_*) — agrupados pelo mesmo owner_hint
	# usado nos combos, para painel e dropdowns concordarem sobre quem é dono de cada placa.
	var members := _plan_member_entries()
	var member_groups := {}
	for m in members:
		member_groups[m["group"]] = true
	var subs_by_owner := _sub_members_by_owner()
	for m in members:
		damage_rows.add_child(_make_damage_row(model_key, m["group"], m["label"]))
		for s in subs_by_owner.get(str(m["group"]), []):
			damage_rows.add_child(_make_damage_row(model_key, s["group"], s["label"], s["bone"], true))
	# Sub-membros cujo dono não está na lista (owner_hint "" ou grupo ausente): seção "Outros".
	var orphans: Array = []
	for owner_group in subs_by_owner:
		if not member_groups.has(owner_group):
			for s in subs_by_owner[owner_group]:
				orphans.append(s)
	if not orphans.is_empty():
		damage_rows.add_child(HSeparator.new())
		var lbl := Label.new()
		lbl.text = "Outros sub-membros"   # Label: auto-localizado pelo Locale via a chave no JSON
		damage_rows.add_child(lbl)
		for s in orphans:
			damage_rows.add_child(_make_damage_row(model_key, s["group"], s["label"], s["bone"], true))
	_add_sub_member_add_row(model_key)
	damage_panel.visible = true


# Mapa owner_group → [{group, label, bone}] dos sub-membros (PART_*) do preview, agrupados pelo
# mesmo dono dos combos (_sub_member_owner_map). Usado para aninhar no painel Dano.
func _sub_members_by_owner() -> Dictionary:
	var out: Dictionary = {}
	if _preview_instance == null:
		return out
	var owners := _sub_member_owner_map()
	for node in _preview_instance.find_children("*", "StaticBody3D", true, false):
		var body := node as StaticBody3D
		if not body.has_meta("group"):
			continue
		var grp := str(body.get_meta("group"))
		if not grp.begins_with("PART_"):
			continue
		var bone := grp.substr(len("PART_"))
		var label := str(body.get_meta("member_label")) if body.has_meta("member_label") else bone
		var owner_group := str(owners.get(grp, ""))
		if not out.has(owner_group):
			out[owner_group] = []
		out[owner_group].append({"group": grp, "label": label, "bone": bone})
	return out


# Uma linha do editor: rótulo do membro + SpinBox em bônus % (passo 5, faixa -100..+500),
# pré-preenchido com (multiplicador salvo - 1) * 100. Mudar o valor grava em LimbConfig.
# `remove_bone` != "" adiciona um botão × que remove o sub-membro (linhas PART_). `indent` recua
# a linha (margem + prefixo ↳) para os sub-membros aninhados sob o membro dono.
func _make_damage_row(model_key: String, group: String, label: String, remove_bone: String = "", indent: bool = false) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var name_lbl := Label.new()
	name_lbl.text = ("↳ " + label) if indent else label
	name_lbl.custom_minimum_size = Vector2(110, 0)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)
	var spin := SpinBox.new()
	spin.min_value = -100.0
	spin.max_value = 500.0
	spin.step = 5.0
	spin.suffix = "%"
	spin.value = (LimbConfig.get_multiplier(model_key, group, _current_classifier()) - 1.0) * 100.0
	spin.value_changed.connect(_on_member_damage_changed.bind(model_key, group))
	row.add_child(spin)
	if remove_bone != "":
		var del := Button.new()
		del.text = "×"
		del.tooltip_text = Locale.tr_key("Remover sub-membro")
		del.pressed.connect(_on_sub_member_removed.bind(model_key, remove_bone))
		row.add_child(del)
	if not indent:
		return row
	# Recuo dos sub-membros aninhados.
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_child(row)
	return margin


# Grava o novo multiplicador (1 + bônus%/100) em LimbConfig e atualiza a meta do collider
# de preview vivo, para que o valor mostrado e o salvo fiquem coerentes na mesma sessão.
func _on_member_damage_changed(pct: float, model_key: String, group: String) -> void:
	var mult := 1.0 + pct / 100.0
	LimbConfig.set_multiplier(model_key, group, mult)
	if _preview_instance == null:
		return
	for node in _preview_instance.find_children("*", "StaticBody3D", true, false):
		var body := node as StaticBody3D
		if body.has_meta("group") and str(body.get_meta("group")) == group:
			body.set_meta("damage_multiplier", mult)


# Linha "Adicionar sub-membro": separador + título + dropdown dos ossos auxiliares (group_of == "")
# + botão Adicionar. As linhas dos sub-membros EXISTENTES agora são aninhadas sob cada membro em
# _refresh_damage_panel; aqui fica só a promoção de um novo osso a sub-membro.
func _add_sub_member_add_row(model_key: String) -> void:
	damage_rows.add_child(HSeparator.new())
	var title := Label.new()
	title.text = "Adicionar sub-membro"   # Label: auto-localizado pelo Locale via a chave no JSON
	damage_rows.add_child(title)
	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 10)
	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var candidates := _aux_bone_candidates()
	if candidates.is_empty():
		picker.add_item(Locale.tr_key("(sem ossos auxiliares)"))
		picker.disabled = true
	else:
		for b in candidates:
			picker.add_item(b)
	add_row.add_child(picker)
	var add_btn := Button.new()
	add_btn.text = "Adicionar"   # Button: auto-localizado pelo Locale via a chave no JSON
	add_btn.disabled = candidates.is_empty()
	add_btn.pressed.connect(func(): _on_sub_member_added(model_key, picker))
	add_row.add_child(add_btn)
	damage_rows.add_child(add_row)


# Ossos do esqueleto do preview que o classificador descarta (group_of == "") e ainda NÃO
# são sub-membros — candidatos a promoção. Vazio se o preview não tem Skeleton3D.
func _aux_bone_candidates() -> Array[String]:
	var out: Array[String] = []
	if _preview_instance == null:
		return out
	var skels: Array = _preview_instance.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return out
	var skel := skels[0] as Skeleton3D
	var classifier := _current_classifier()
	var existing := LimbConfig.sub_members(_current_model_key())
	for b in skel.get_bone_count():
		var bn := skel.get_bone_name(b)
		if classifier.group_of(bn) == "" and not existing.has(bn):
			out.append(bn)
	return out


# Promove o osso escolhido a sub-membro, reconstrói os colliders do preview e repopula.
func _on_sub_member_added(model_key: String, picker: OptionButton) -> void:
	if picker.disabled or picker.selected < 0:
		return
	LimbConfig.add_sub_member(model_key, picker.get_item_text(picker.selected))
	_rebuild_member_colliders()


# Remove o sub-membro, reconstrói os colliders do preview e repopula.
func _on_sub_member_removed(model_key: String, bone: String) -> void:
	LimbConfig.remove_sub_member(model_key, bone)
	_rebuild_member_colliders()


# Refaz os colliders de membro do preview (após mudar a lista de sub-membros), repondo
# gizmos/rótulos conforme os toggles, e repopula o painel.
func _rebuild_member_colliders() -> void:
	if _preview_instance == null:
		return
	_clear_member_colliders()
	_ensure_member_colliders()
	if _show_colliders:
		_add_collider_gizmos(_preview_instance)
	if _member_colliders_built and _any_member_label():
		_add_member_labels(_preview_instance)
	_refresh_damage_panel()


# Remove os colliders de membro atuais do preview: o nó LimbColliders (caminho com
# esqueleto) e os wrappers que carregam cada corpo — BoneAttachment3D "Hitbox_*" (esqueleto)
# ou o próprio StaticBody3D (caminho sem esqueleto). free() imediato (a lista é um snapshot),
# para o rebuild seguinte não enxergar duplicatas.
func _clear_member_colliders() -> void:
	if _preview_instance == null:
		return
	var to_free: Array[Node] = []
	for lc in _preview_instance.find_children("*", "LimbColliders", true, false):
		to_free.append(lc)
	for body in _preview_instance.find_children("*", "StaticBody3D", true, false):
		if (body as Node).has_meta("member_label"):
			var p := body.get_parent()
			to_free.append(p if p is BoneAttachment3D else body)
	for n in to_free:
		if is_instance_valid(n):
			n.free()
	_member_colliders_built = false


# Draw a wireframe gizmo for every CollisionShape3D so the otherwise-invisible
# collision volumes can be inspected. Each gizmo is parented under its shape so
# it inherits the shape transform and the root's fit-to-view scale. Idempotent: a
# shape that already carries its gizmo is skipped (the toggle may re-run this).
#
# For Personagens/Armas we build per-MEMBER colliders and those are what's interesting to
# inspect; the model's own authored body collider (e.g. red_robot's big body sphere) and
# its detection/death volumes would just be noise wrapping everything, so they are skipped
# — only the per-member colliders get a gizmo. Other categories draw all their shapes.
func _add_collider_gizmos(instance: Node) -> void:
	var members_only := _current_category_key() in ["characters", "weapons"]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.2, 1.0, 0.4, 0.28)
	for node in instance.find_children("*", "CollisionShape3D", true, false):
		var shape_node := node as CollisionShape3D
		if shape_node.shape == null or shape_node.has_node(NodePath(_GIZMO_NAME)):
			continue
		if members_only and not _is_member_collider(shape_node):
			continue
		var gizmo := MeshInstance3D.new()
		gizmo.name = _GIZMO_NAME
		gizmo.mesh = shape_node.shape.get_debug_mesh()
		gizmo.material_override = mat
		shape_node.add_child(gizmo)


# True when a CollisionShape3D belongs to one of the per-member colliders we built (its
# owning StaticBody3D carries the "member_label" meta), as opposed to the model's own
# authored body/detection/death colliders.
func _is_member_collider(shape_node: CollisionShape3D) -> bool:
	var parent := shape_node.get_parent()
	return parent is StaticBody3D and parent.has_meta("member_label")


# Draws the member tooltip STACK (TYPE / Name / ID / Membro) over each member collider, com o
# mesmo conteúdo/cor (ciano) do debug_overlay.gd, mas cada linha gated pelo SEU toggle da cena
# Models (Rótulos/Tipo/Nome/ID) — não há mais leitura do Debug 3D global. O preview é exempt do
# overlay global (exempt_member_labels), então o browser é dono desses tooltips aqui — onde tem
# os overrides por personagem (cabeça/tronco) que o classificador global não tem. Cada label é
# filho do corpo do collider (ancorado ao osso/pivô animado), então acompanha o membro.
func _add_member_labels(instance: Node) -> void:
	# Idempotente: remove pilhas anteriores (cada pivô leva junto suas linhas) e zera o índice
	# do anti-colisão antes de recriar, para chamadas repetidas não acumularem duplicatas.
	for old in instance.find_children(_LABEL_PREFIX + "Pivot", "Node3D", true, false):
		(old as Node3D).free()
	_member_label_pivots = []
	# TYPE/Name/ID describe the owning Skeleton3D (like the global overlay); fall back to the
	# preview root for rigs without a skeleton (criatura).
	var owner_node: Node = instance
	var skels: Array = instance.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		owner_node = skels[0]
	for node in instance.find_children("*", "StaticBody3D", true, false):
		var body := node as StaticBody3D
		if not body.has_meta("member_label"):
			continue
		var text: String = str(body.get_meta("member_label"))
		if text == "":
			continue
		var shapes: Array = body.find_children("*", "CollisionShape3D", true, false)
		if shapes.is_empty():
			continue
		# Member centre in the body's local space (the shape carries the offset).
		var center: Vector3 = (shapes[0] as CollisionShape3D).position
		# Cada linha: id (p/ recriar in-place + cor), visibilidade pelo toggle local, e offset Y.
		var lines := [
			{"id": "Type", "on": _show_type, "text": "TYPE: %s" % owner_node.get_class(), "y": 0.18},
			{"id": "Name", "on": _show_name, "text": "Name: %s" % owner_node.name, "y": 0.12},
			{"id": "Id", "on": _show_id, "text": "ID: %d" % owner_node.get_instance_id(), "y": 0.06},
			{"id": "Member", "on": _show_member_labels, "text": "Membro: %s" % text, "y": 0.0},
		]
		# Um pivô por membro agrupa as 4 linhas, de modo que o anti-colisão desloque a pilha
		# inteira de uma vez (sem desalinhar as linhas entre si). Posicionado no topo do bloco.
		var base: Vector3 = center + Vector3(0.0, 0.12, 0.0)
		var pivot := Node3D.new()
		pivot.name = _LABEL_PREFIX + "Pivot"
		body.add_child(pivot)
		pivot.position = base
		var visible_count := 0
		var max_y := 0.0
		var max_len := 0
		for line in lines:
			var lbl := Label3D.new()
			lbl.name = _LABEL_PREFIX + str(line["id"])
			lbl.text = str(line["text"])
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.no_depth_test = true
			# Always draw on TOP of the translucent green collider gizmos and of each other,
			# so a member's tag is never swallowed by a neighbouring collider/label.
			lbl.render_priority = 4
			lbl.outline_render_priority = 3
			lbl.pixel_size = _LBL_PIXEL_SIZE
			lbl.font_size = _LBL_FONT_SIZE
			# Cor própria da linha (Membro/Tipo/Nome/ID) — a mesma usada no toggle que a controla.
			lbl.modulate = _LABEL_LINE_COLORS.get(str(line["id"]), Color(0.6, 1.0, 1.0))
			lbl.outline_size = 4
			lbl.outline_modulate = Color(0, 0, 0, 0.8)
			lbl.visible = bool(line["on"])
			pivot.add_child(lbl)
			# Relativo ao pivô: o "Membro" (y=0) fica na base, as demais linhas acima dele.
			lbl.position = Vector3(0.0, float(line["y"]), 0.0)
			if bool(line["on"]):
				visible_count += 1
				max_y = maxf(max_y, float(line["y"]))
				max_len = maxi(max_len, str(line["text"]).length())
		# Sem nenhuma linha visível, nada a posicionar: descarta o pivô e não o indexa.
		if visible_count == 0:
			pivot.free()
			continue
		# Tamanho aproximado do bloco em METROS, para o anti-colisão projetar seu retângulo:
		# altura = topo da pilha + uma linha; meia-largura ≈ metade do texto mais longo (Label3D
		# centraliza no eixo X). Largura por caractere ≈ font*pixel_size*0.5.
		var block_h: float = max_y + _LBL_LINE_STEP
		var half_w: float = max_len * (_LBL_FONT_SIZE * _LBL_PIXEL_SIZE * 0.5) * 0.5
		_member_label_pivots.append({
			"pivot": pivot, "body": body, "base": base, "H": block_h, "halfW": half_w,
		})


# Pinta o texto de cada toggle de linha com a cor do rótulo 3D que ele controla, para o
# usuário ligar de relance o controle ao seu rótulo. Cobre os estados do CheckButton (normal/
# hover/pressed/focus) para a cor não "sumir" ao passar o mouse ou marcar.
func _apply_label_line_colors() -> void:
	var toggles := {
		"Member": labels_toggle, "Type": type_check, "Name": name_check, "Id": id_check,
	}
	for id in toggles:
		var btn: CheckButton = toggles[id]
		var col: Color = _LABEL_LINE_COLORS[id]
		for key in [
			"font_color", "font_hover_color", "font_pressed_color",
			"font_hover_pressed_color", "font_focus_color",
		]:
			btn.add_theme_color_override(key, col)


# Anti-colisão das pilhas de rótulos de membro (chamado por frame enquanto houver pilhas). O
# modelo gira, então conjuntos de membros distintos podem se sobrepor na tela a qualquer
# momento; aqui projetamos cada pilha para um retângulo de tela e, processando de cima para
# baixo, empurramos para BAIXO quem colidir com uma pilha já posicionada — mantendo cada
# conjunto inteiro e legível "um abaixo do outro". O empurrão é convertido de pixels de tela
# para metros e aplicado movendo o pivô da pilha no espaço-mundo (para baixo = -câmera_up).
func _layout_member_labels() -> void:
	if camera == null:
		return
	var up_world := camera.global_transform.basis.y
	var right_world := camera.global_transform.basis.x
	# 1) Mede o retângulo de tela de cada pilha SEM empurrão (pivô reposto na base). As medidas
	# saem de posições de MUNDO reais (pivot.to_global), então já embutem o escalonamento do
	# fit-to-view; o fator px/metro vem da câmera na profundidade da âncora (corrige o zoom).
	var rects: Array = []
	for i in _member_label_pivots.size():
		var e: Dictionary = _member_label_pivots[i]
		var pivot: Node3D = e["pivot"]
		var body: Node3D = e["body"]
		if not is_instance_valid(pivot) or not is_instance_valid(body):
			continue
		pivot.position = e["base"]
		# Âncora = base da pilha (linha "Membro"); topo = base + H ao longo do eixo da pilha.
		var anchor: Vector3 = pivot.to_global(Vector3.ZERO)
		if camera.is_position_behind(anchor):
			continue
		var a_px := camera.unproject_position(anchor)
		var top_px := camera.unproject_position(pivot.to_global(Vector3(0.0, float(e["H"]), 0.0)))
		# Pixels por metro de mundo nesta profundidade (1 m na horizontal de tela → px).
		var px_per_m := absf(camera.unproject_position(anchor + right_world).x - a_px.x)
		if px_per_m < 0.001:
			continue
		var scale_x: float = body.global_transform.basis.get_scale().x
		var height_px := absf(a_px.y - top_px.y)
		var halfw_px := maxf(float(e["halfW"]) * scale_x * px_per_m, 16.0)
		# A pilha cresce para CIMA a partir da âncora (linha "Membro" embaixo).
		rects.append({
			"idx": i, "x": a_px.x, "bottom": a_px.y, "top": a_px.y - height_px,
			"halfw": halfw_px, "mpp": 1.0 / px_per_m,
		})
	# 2) De-overlap guloso: de cima para baixo, empurra cada pilha abaixo das já posicionadas.
	rects.sort_custom(func(a, b): return a["top"] < b["top"])
	var placed: Array = []
	for r in rects:
		var push := 0.0
		var changed := true
		while changed:
			changed = false
			for p in placed:
				if absf(r["x"] - p["x"]) >= (r["halfw"] + p["halfw"]):
					continue   # sem sobreposição horizontal
				var r_top: float = r["top"] + push
				var r_bot: float = r["bottom"] + push
				if r_bot <= p["top"] or r_top >= p["bottom"]:
					continue   # sem sobreposição vertical
				# Colide: desce r até passar do fundo da pilha já posicionada (+ folga).
				push += (p["bottom"] - r_top) + 4.0
				changed = true
		placed.append({
			"x": r["x"], "halfw": r["halfw"], "top": r["top"] + push, "bottom": r["bottom"] + push,
		})
		# Aplica o empurrão no pivô: para baixo na tela = mundo -up (convertido p/ o espaço local
		# do corpo, que gira com o modelo). push==0 deixa o pivô exatamente na base.
		var e: Dictionary = _member_label_pivots[r["idx"]]
		var body: Node3D = e["body"]
		if push > 0.0 and r["mpp"] > 0.0 and is_instance_valid(body):
			var down_local: Vector3 = body.global_transform.basis.inverse() * (-up_world * (push * float(r["mpp"])))
			(e["pivot"] as Node3D).position = (e["base"] as Vector3) + down_local


# Per-character: head bone(s) BodyParts can't infer from the name (it excludes
# "eye"/"mouth"), so the model browser names them explicitly for the preview.
const _MODEL_HEAD_BONES := {
	# Face panel ("mouth_eyes") + eyes ("L-EYE"/"R-EYE"). The eyes are excluded by the
	# "eye" keyword, so without forcing them the head would wrap only the ~42-vertex panel
	# and read as a tiny sphere. Mirrors red_robot.gd's gameplay head hitbox.
	"red_robot": ["mouth_eyes", "L-EYE", "R-EYE"],
}

# Per-character TORSO bone(s) the classifier can't infer from a generic name — same
# role as _MODEL_HEAD_BONES but for the trunk (red_robot's body is "Bone.001").
const _MODEL_TORSO_BONES := {
	"red_robot": ["Bone.001"],
}

# Per-character body PLAN (mirrors the @export body_type the gameplay sets, which the
# stripped preview can't read). Drives the member classifier. Default "biped".
const _MODEL_BODY_TYPE := {
	"red_robot": "biped",
	"player": "biped",
}

# Per-character HEAD collider shape (mirrors LimbColliders.head_shape the gameplay sets).
# Default "sphere"; the player uses a "capsule" (same orientation as the head bone).
const _MODEL_HEAD_SHAPE := {
	"player": "capsule",
}

# Sub-membros (placas salientes etc.) NÃO ficam mais numa tabela aqui: vêm de LimbConfig
# (res://data/limb_config.json, por model_key), editáveis na tela — o preview os recebe ao
# setar lc.model_key. Ver _add_member_colliders.


# Build best-fit colliders that wrap each body MEMBER (sphere/capsule head, box torso,
# capsule limbs) so they render green via the gizmos above. The gameplay script
# that normally builds these is stripped from the preview, so we build them here.
# Skeleton characters reuse the shared LimbColliders builder; the criatura (no
# skeleton) is grouped by mesh-node name instead.
func _add_member_colliders(instance: Node) -> void:
	var skels: Array = instance.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		var lc := LimbColliders.new()
		lc.body_type = _body_type_for_current()   # plano corporal → classificador
		lc.model_key = _current_model_key()        # sub-membros + dano de LimbConfig
		lc.head_shape = _MODEL_HEAD_SHAPE.get(_current_model_key(), "sphere")  # cabeça: esfera/cápsula
		lc.hitbox_layer = 64        # own layer — does not touch damage layers (16/32)
		lc.padding = 0.04           # tight gap around the mesh (hugs the body)
		lc.head_bone_names = _head_bones_for_current()
		lc.torso_bone_names = _torso_bones_for_current()
		instance.add_child(lc)
		lc.build_for(skels[0] as Skeleton3D)
		return
	_add_mesh_member_colliders(instance)


func _head_bones_for_current() -> Array[String]:
	return _model_bones_for_current(_MODEL_HEAD_BONES)


func _torso_bones_for_current() -> Array[String]:
	return _model_bones_for_current(_MODEL_TORSO_BONES)


func _model_bones_for_current(table: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for key in table:
		if _current_model_path.contains(key):
			for b in table[key]:
				out.append(b)
			break
	return out


# Key ("characters"/"weapons"/…) of the category currently selected, or "" if on
# the "Selecione..." placeholder. Drives weapon-vs-character member detection.
func _current_category_key() -> String:
	var idx := cbo_category.selected - 1
	if idx < 0 or idx >= _categories.size():
		return ""
	return _categories[idx]["key"]


# Member colliders for a rig that has no Skeleton3D, grouping the visible mesh nodes
# by member name. Characters use BodyParts (head/torso/arms/legs → criatura_alada,
# mecha07); weapons use WeaponParts (cano/corpo/cabo/… → pistola etc.). Each collider
# is parented to the lowest common ancestor of its member's meshes — that ancestor is
# the node the animation drives (the limb pivot / recoiling receiver), so the collider
# (and its tooltip) MOVES WITH THE ANIMATION instead of staying behind.
func _add_mesh_member_colliders(instance: Node) -> void:
	var is_weapon := _current_category_key() == "weapons"
	# Personagens usam o classificador do plano (instância — BodyParts não é polimórfico
	# via estático); armas seguem o WeaponParts estático.
	var classifier := _current_classifier()
	var members: Dictionary = {}   # group -> {"label": String, "nodes": Array}
	for node in instance.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var g := WeaponParts.group_of(mi.name) if is_weapon else classifier.group_of(mi.name)
		if g == "":
			continue
		if not members.has(g):
			var lab: String = WeaponParts.label_of(g) if is_weapon else classifier.label_of(g)
			members[g] = {"label": lab, "nodes": []}
		members[g]["nodes"].append(mi)

	for g in members:
		var nodes: Array = members[g]["nodes"]
		var anchor := _lca(nodes, instance)
		if anchor == null:
			anchor = instance
		# AABB in the anchor's local space: the meshes are rigid under their animated
		# pivot, so this is pose-independent and stays glued to the moving member.
		var inv := (anchor as Node3D).global_transform.affine_inverse()
		var aabb := AABB()
		var first := true
		for n in nodes:
			var mi := n as MeshInstance3D
			var box := (inv * mi.global_transform) * mi.get_aabb()
			aabb = box if first else aabb.merge(box)
			first = false
		aabb = aabb.grow(0.04)

		var body := StaticBody3D.new()
		body.name = "Collider_%s" % g
		body.collision_layer = 64
		body.collision_mask = 0
		# "group" espelha o que LimbColliders carimba no caminho com esqueleto, para o
		# editor de dano por membro também listar rigs sem Skeleton3D (criatura).
		body.set_meta("group", g)
		body.set_meta("member_label", members[g]["label"])
		if is_weapon:
			# Barrel → capsule along its length; receiver/grip/stock/mag → box.
			var kind := "capsule" if g == WeaponParts.BARREL else "box"
			body.add_child(LimbColliders.make_shape(kind, aabb))
		else:
			body.add_child(LimbColliders.make_member_shape(g, aabb))
		anchor.add_child(body)


# Lowest common ancestor of `nodes` within `root` (inclusive). For a single node it
# is the node itself; used to anchor a member's collider to the node the animation
# actually moves.
func _lca(nodes: Array, root: Node) -> Node:
	if nodes.is_empty():
		return root
	var common: Array = _ancestor_chain(nodes[0], root)
	for i in range(1, nodes.size()):
		var chain: Array = _ancestor_chain(nodes[i], root)
		var k := 0
		while k < common.size() and k < chain.size() and common[k] == chain[k]:
			k += 1
		common = common.slice(0, k)
	return common[-1] if not common.is_empty() else root


# Chain of nodes from `root` down to `node` (inclusive), root first.
func _ancestor_chain(node: Node, root: Node) -> Array:
	var chain: Array = []
	var n: Node = node
	while n != null:
		chain.push_front(n)
		if n == root:
			break
		n = n.get_parent()
	return chain


# Center and scale a model so it fits nicely in front of the camera, regardless
# of its original size. target_size is the largest dimension after scaling. Only
# mesh geometry is measured — lights and particle systems carry huge bounds (the
# forklift spotlight reaches 50 m) that would otherwise shrink the model to a dot.
# `precomputed` (an AABB in `model`'s local space) overrides the mesh measurement:
# used for skinned characters, whose mesh get_aabb() is the bind pose and can sit
# well off the posed body (see _posed_member_bounds).
func _fit_to_view(model: Node3D, target_size: float = 2.0, precomputed = null) -> void:
	var bounds := AABB()
	if precomputed is AABB:
		bounds = precomputed
	else:
		var visuals: Array = model.find_children("*", "MeshInstance3D", true, false)
		if model is MeshInstance3D:
			visuals.append(model)
		var first := true
		for node in visuals:
			var vi := node as MeshInstance3D
			# Frame only the body: skip hidden meshes (the forklift's unused colour
			# variants, a character's death debris) and meshes bolted to a bone
			# (muzzle/laser effects whose long beams would otherwise shrink the body
			# to a dot).
			if not vi.is_visible_in_tree():
				continue
			if _under_bone_attachment(vi, model):
				continue
			var rel := model.global_transform.affine_inverse() * vi.global_transform
			var box := rel * vi.get_aabb()
			if first:
				bounds = box
				first = false
			else:
				bounds = bounds.merge(box)
		if first:
			return

	var max_dim: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if max_dim <= 0.0:
		return
	var scale_factor := target_size / max_dim
	model.scale = Vector3.ONE * scale_factor
	model.position = -bounds.get_center() * scale_factor


# Bounds of the POSED body, measured from the per-member colliders (which wrap the
# skinned vertices in the live pose), in `model`'s local space. Used to frame and
# CENTER skinned characters correctly — their mesh get_aabb() is the bind pose and
# for red_robot sits ~1.4 m off in Z, which would put the rotation pivot behind the
# body. Returns an empty AABB (size 0) when there are no member colliders.
func _posed_member_bounds(model: Node3D) -> AABB:
	var inv := model.global_transform.affine_inverse()
	var bounds := AABB()
	var first := true
	for node in model.find_children("*", "StaticBody3D", true, false):
		var body := node as StaticBody3D
		if not body.has_meta("member_label"):
			continue
		for cs in body.find_children("*", "CollisionShape3D", true, false):
			var shape: Shape3D = (cs as CollisionShape3D).shape
			if shape == null:
				continue
			var box := (inv * (cs as CollisionShape3D).global_transform) * shape.get_debug_mesh().get_aabb()
			if first:
				bounds = box
				first = false
			else:
				bounds = bounds.merge(box)
	return bounds


# True when `node` hangs under a BoneAttachment3D somewhere below `root` — i.e.
# it is a prop pinned to a skeleton bone (weapon, muzzle/laser effect) rather
# than part of the model's body.
func _under_bone_attachment(node: Node, root: Node) -> bool:
	var parent := node.get_parent()
	while parent != null and parent != root:
		if parent is BoneAttachment3D:
			return true
		parent = parent.get_parent()
	return false


# --- Misc -------------------------------------------------------------------

# "red_robot" -> "Red Robot", "core_out_light" -> "Core Out Light".
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


# Hold the left mouse button over the render area and drag to hand-rotate the
# mesh on the two orthogonal axes (horizontal -> yaw, vertical -> pitch). Clicks
# that land on a dropdown or button are consumed by those controls first, so only
# drags over the empty 3D view reach here.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseButton and event.pressed and \
			event.button_index == MOUSE_BUTTON_WHEEL_UP:
		# Wheel forward -> approach the model (smaller distance).
		_zoom_target = clampf(_zoom_target - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
	elif event is InputEventMouseButton and event.pressed and \
			event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		# Wheel backward -> pull away from the model (larger distance).
		_zoom_target = clampf(_zoom_target + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		# Both axes swing up to 180 degrees each side: yaw (left/right) turns the model
		# all the way around to its back, and pitch (up/down) tilts it all the way over.
		_yaw = clampf(_yaw + motion.relative.x * DRAG_SENSITIVITY, -PI, PI)
		_pitch = clampf(_pitch + motion.relative.y * DRAG_SENSITIVITY, -PI, PI)

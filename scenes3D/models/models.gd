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

@onready var model_holder: Node3D = $ModelHolder
@onready var camera: Camera3D = $Camera3D

# Mouse-wheel zoom state: the camera's distance from the model along its local Z.
# _zoom_target is nudged by the wheel; _zoom eases toward it every frame.
var _zoom: float = 0.0
var _zoom_target: float = 0.0
@onready var selectors_box: VBoxContainer = $UI/Selectors
@onready var category_row: HBoxContainer = $UI/Selectors/CategoryRow
@onready var cbo_category: OptionButton = $UI/Selectors/CategoryRow/cboCategory
@onready var prefix_row: HBoxContainer = $UI/Selectors/PrefixRow
@onready var cbo_prefix: OptionButton = $UI/Selectors/PrefixRow/cboPrefix
@onready var model_row: HBoxContainer = $UI/Selectors/ModelRow
@onready var cbo_models: OptionButton = $UI/Selectors/ModelRow/cboModels
@onready var mesh_row: HBoxContainer = $UI/Selectors/MeshRow
@onready var cbo_meshes: OptionButton = $UI/Selectors/MeshRow/cboMeshes
@onready var animation_row: HBoxContainer = $UI/Selectors/AnimationRow
@onready var cbo_animations: OptionButton = $UI/Selectors/AnimationRow/cboAnimations
@onready var effects_row: HBoxContainer = $UI/Selectors/EffectsRow
@onready var cbo_effects: OptionButton = $UI/Selectors/EffectsRow/cboEffects
@onready var status_label: Label = $UI/Selectors/StatusLabel
@onready var rotate_toggle: CheckButton = $UI/Toggles/RotateToggle
@onready var animation_toggle: CheckButton = $UI/Toggles/AnimationToggle
@onready var audio_toggle: CheckButton = $UI/Toggles/AudioToggle
@onready var colliders_toggle: CheckButton = $UI/Toggles/CollidersToggle
@onready var effects_toggle: CheckButton = $UI/Toggles/EffectsToggle
@onready var portuguese_button: Button = $UI/LangBar/PortugueseButton
@onready var english_button: Button = $UI/LangBar/EnglishButton

# Dynamic status line state: the (translatable) template, its format args, and the row
# the message refers to (so the label can be re-placed below the matching combo and
# re-translated on a language change). The status label opts out of the auto-localizer.
var _status_template: String = ""
var _status_args: Array = []
var _status_row: Control = null


func _ready() -> void:
	_zoom = camera.position.z
	_zoom_target = _zoom
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
	_reset_animations()
	_reset_effects()

	# Restore the toggle states saved on a previous visit, so the browser reopens
	# exactly as the user left it (see _save_toggle / _on_*_toggled). Defaults match
	# the field initializers above (everything off) for a first run.
	_auto_rotate = Settings.config_file.get_value("models", "auto_rotate", _auto_rotate)
	_play_animation = Settings.config_file.get_value("models", "play_animation", _play_animation)
	_play_audio = Settings.config_file.get_value("models", "play_audio", _play_audio)
	_show_colliders = Settings.config_file.get_value("models", "show_colliders", _show_colliders)
	_show_effects = Settings.config_file.get_value("models", "show_effects", _show_effects)

	rotate_toggle.button_pressed = _auto_rotate
	rotate_toggle.toggled.connect(_on_rotate_toggled)
	animation_toggle.button_pressed = _play_animation
	animation_toggle.toggled.connect(_on_animation_toggled)
	audio_toggle.button_pressed = _play_audio
	audio_toggle.toggled.connect(_on_audio_toggled)
	colliders_toggle.button_pressed = _show_colliders
	colliders_toggle.toggled.connect(_on_colliders_toggled)
	effects_toggle.button_pressed = _show_effects
	effects_toggle.toggled.connect(_on_effects_toggled)

	# The status line is code-driven (dynamic placement + text): opt it out of the
	# auto-localizer and re-apply it on every language change.
	status_label.add_to_group(Locale.SKIP_GROUP)
	Locale.language_changed.connect(_on_language_changed)
	_update_language_buttons()

	# Start blank: every dropdown shows "Selecione..." and nothing is previewed
	# until the user drills down Categoria -> Prefixo -> Modelo -> Parte.
	cbo_category.select(0)
	_on_category_selected(0)


# Store a (translatable) status template, its format args and the combo row it refers to,
# render it in the active language and move the red status label directly below that row.
func _set_status(template: String, row: Control, args: Array = []) -> void:
	_status_template = template
	_status_args = args
	_status_row = row
	_apply_status()


func _apply_status() -> void:
	if _status_template == "":
		status_label.text = ""
		return
	var text := Locale.tr_key(_status_template)
	status_label.text = (text % _status_args) if not _status_args.is_empty() else text
	# Reposition the label directly ABOVE the row whose combo the message is about.
	# move_child places the node at the given FINAL index; when the label currently sits
	# above the target row, removing it shifts the row up by one, so compensate.
	if _status_row != null and is_instance_valid(_status_row):
		var row_index := _status_row.get_index()
		var target := maxi(0, row_index - 1) if status_label.get_index() < row_index else row_index
		selectors_box.move_child(status_label, target)


func _on_language_changed(_lang: String) -> void:
	# Relabel the placeholders/category names already in the dropdowns (kept in place so
	# the current selection survives), then re-apply the status line and the lang buttons.
	if cbo_category.item_count > 0:
		cbo_category.set_item_text(0, Locale.tr_key(SELECT_LABEL))
	for i in range(_categories.size()):
		if i + 1 < cbo_category.item_count:
			cbo_category.set_item_text(i + 1, Locale.tr_key(_categories[i]["label"]))
	for combo in [cbo_prefix, cbo_models, cbo_meshes, cbo_animations, cbo_effects]:
		if combo.item_count > 0:
			combo.set_item_text(0, Locale.tr_key(SELECT_LABEL))
	if cbo_meshes.item_count > 1:
		cbo_meshes.set_item_text(1, Locale.tr_key(WHOLE_MODEL_LABEL))
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


# Sequential gating: each dropdown below Categoria stays DISABLED until the one
# directly above it holds a real (non-"Selecione...") choice. So the user is forced
# down the chain Categoria -> Prefixo -> Modelo -> Parte. Category index 0 is the
# "Selecione..." placeholder (real categories start at index 1). Selecting it blanks
# and disables the whole chain below and clears the preview.
func _on_category_selected(index: int) -> void:
	if index <= 0:
		_reset_prefixes()
		_reset_models()
		_set_status("Selecione uma categoria.", category_row)
		return
	_populate_prefixes(index - 1)
	# Prefix is now enabled but still on its placeholder, so Modelo/Parte stay locked.
	_reset_models()
	_set_status("Selecione um prefixo.", prefix_row)


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
	if _prefix_filter == "":
		# Back to the placeholder: re-lock Modelo and Parte.
		_reset_models()
		_set_status("Selecione um prefixo.", prefix_row)
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
		_set_status("Selecione uma categoria.", category_row)
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
	if _filtered_models.is_empty():
		_set_status("Nenhum modelo neste grupo.", model_row)
	else:
		_set_status("Selecione um modelo.", model_row)


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
# clear the previewed mesh/model and its cached scenes. Also resets the two dropdowns
# below Part (Animação, Efeitos Especiais) so changing any upper dropdown cascades all
# the way down.
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
	_clear_preview()


# Model dropdown index 0 is the "Selecione..." placeholder; real models start at
# index 1 (mapping to _filtered_models[index - 1]). Selecting a real model rebuilds
# the Part dropdown ("Selecione...", then "Modelo completo", then each distinct
# mesh) but leaves the placeholder selected, so nothing previews until a part is
# picked. Selecting the placeholder blanks the part dropdown and the preview.
func _on_model_selected(index: int) -> void:
	if index <= 0:
		_reset_meshes_and_preview()
		_set_status("Selecione um modelo.", model_row)
		return

	var model: Dictionary = _filtered_models[index - 1]
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
	# Part is back on its placeholder, so the dropdowns below it reset/hide too.
	_reset_animations()
	_reset_effects()
	_clear_preview()
	_set_status("Selecione uma parte.", mesh_row)


# Part dropdown index 0 is the "Selecione..." placeholder (nothing previewed),
# index 1 is the assembled "Modelo completo", and indices 2.. map to the distinct
# meshes in _mesh_catalog (shifted by the two leading entries).
func _on_mesh_selected(index: int) -> void:
	if index <= 0:
		_clear_preview()
		_reset_animations()
		_reset_effects()
		_set_status("Selecione uma parte.", mesh_row)
	elif index == 1:
		_preview_whole_model()
		# The animation and special-effects dropdowns only apply to "Modelo completo".
		_populate_animations()
		_populate_effects()
		# No quantity message: the status now only guides the animation/effects combos
		# (when they have options), sitting just above whichever ones showed up.
		_update_whole_model_status()
	else:
		# A single isolated part has no animation/effects combos below it, so it carries
		# no status line at all.
		_preview_mesh(index - 2)
		_reset_animations()
		_reset_effects()
		_clear_status()


# Status line for the assembled "Modelo completo" view: it appears ONLY when at least one
# of the two combos below it actually has options, and sits directly above the topmost one
# that does, carrying that combo's "pick something" prompt (both → a combined prompt). When
# the model exposes neither animations nor effects, no status shows.
func _update_whole_model_status() -> void:
	var has_anim := not cbo_animations.disabled and cbo_animations.item_count > 1
	var has_effects := not cbo_effects.disabled and cbo_effects.item_count > 1
	if has_anim and has_effects:
		_set_status("Selecione uma animação e/ou um efeito.", animation_row)
	elif has_anim:
		_set_status("Selecione uma animação.", animation_row)
	elif has_effects:
		_set_status("Selecione um efeito.", effects_row)
	else:
		_clear_status()


# Blank the status line (no template, no row): the label renders empty and stays put.
func _clear_status() -> void:
	_set_status("", null)


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
func _on_animation_selected(_index: int) -> void:
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
	var prev := "" if cbo_effects.selected <= 0 else cbo_effects.get_item_text(cbo_effects.selected)
	cbo_effects.clear()
	cbo_effects.add_item(Locale.tr_key(SELECT_LABEL))
	for entry in _preview_effect_nodes:
		cbo_effects.add_item(entry["label"])
	var restore := 0
	for i in range(1, cbo_effects.item_count):
		if cbo_effects.get_item_text(i) == prev:
			restore = i
			break
	cbo_effects.select(restore)
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


# Item 0 is "Selecione..." (show every effect, per the toggle); items 1.. are effect
# names. Picking one isolates it (only that effect renders); see _apply_effects_visibility.
func _on_effect_selected(_index: int) -> void:
	_apply_effects_visibility()


# Show/hide the preview's special-effect nodes: nothing while the "Efeitos especiais"
# toggle is off; with it on, every effect when the dropdown is on "Selecione...", or
# only the chosen one when a specific effect is picked.
func _apply_effects_visibility() -> void:
	var chosen := "" if cbo_effects.selected <= 0 else cbo_effects.get_item_text(cbo_effects.selected)
	for entry in _preview_effect_nodes:
		var node: Node3D = entry["node"]
		if not is_instance_valid(node):
			continue
		node.visible = _show_effects and (chosen == "" or entry["label"] == chosen)


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
	_apply_colliders_visibility()


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
	for file_name in access.get_files():
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
	for file_name in access.get_files():
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
	_yaw = 0.0
	_pitch = 0.0
	model_holder.rotation = Vector3.ZERO


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
	if _show_colliders or show_members:
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
	# Debug 3D tooltips (TYPE/Name/ID/Membro) over the members: shown when "Debug 3D" is on AND
	# any of its sub-toggles (Tipo/Nome/ID/Membros) is on — mirroring debug_overlay.gd. Each
	# line then follows its own sub-toggle. Needs the member colliders as the anchor.
	if _member_colliders_built and _debug3d_tooltips_enabled():
		_add_member_labels(instance)


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


# Collect the model's gameplay-only flourishes — particle systems (smoke, thrust),
# lights, and meshes pinned to a bone (muzzle/laser) — the "remaining" elements no
# other toggle covers. Returned as [{"label", "node"}] for the "Efeitos Especiais"
# dropdown; the caller decides their visibility via _apply_effects_visibility.
func _collect_effect_nodes(instance: Node) -> Array:
	var out: Array = []
	for node in instance.find_children("*", "Node3D", true, false):
		var is_effect := node is GPUParticles3D or node is CPUParticles3D or node is Light3D
		if not is_effect and node is MeshInstance3D and _under_bone_attachment(node, instance):
			is_effect = true
		if is_effect:
			out.append({"label": _prettify(String(node.name)), "node": node})
	return out


# Name carried by every collider wireframe gizmo, so the Colliders toggle can add
# them once and strip them back out in place without touching anything else.
const _GIZMO_NAME := "_ColliderGizmo"


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


# The Debug 3D tooltips obey the developer's toggles exactly like debug_overlay.gd: "Debug 3D"
# must be on, plus at least one sub-toggle (Tipo/Nome/ID/Membros). Read straight from the saved
# config (these toggles live on the developer screen, so they don't change while the browser is
# open — reading at preview-build time is enough).
func _debug3d_tooltips_enabled() -> bool:
	var cfg := Settings.config_file
	if not cfg.get_value("game", "debug_3d", false):
		return false
	return cfg.get_value("game", "show_type_3d", false) \
		or cfg.get_value("game", "show_name_3d", false) \
		or cfg.get_value("game", "show_id_3d", false) \
		or cfg.get_value("game", "show_members", false)


# Draws the Debug 3D tooltip STACK (TYPE / Name / ID / Membro) over each member collider —
# the SAME content, cyan color and per-sub-toggle gating as debug_overlay.gd's
# _add_3d_skeleton. The preview is exempt from the global overlay (exempt_member_labels), so
# the browser owns these tooltips here — where it has the per-character bone overrides
# (head/torso/leg-guard plates) the global classifier lacks, so members are labeled right.
# Each label is parented to the collider body (anchored to the animated bone/pivot), so it
# travels WITH the member during animation. Each line follows its own sub-toggle.
func _add_member_labels(instance: Node) -> void:
	# TYPE/Name/ID describe the owning Skeleton3D (like the global overlay); fall back to the
	# preview root for rigs without a skeleton (criatura).
	var owner_node: Node = instance
	var skels: Array = instance.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		owner_node = skels[0]
	var cfg := Settings.config_file
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
		# Same lines/order/offsets as the global overlay; each gated by its sub-toggle.
		var lines := [
			{"cfg": "show_type_3d", "text": "TYPE: %s" % owner_node.get_class(), "y": 0.18},
			{"cfg": "show_name_3d", "text": "Name: %s" % owner_node.name, "y": 0.12},
			{"cfg": "show_id_3d", "text": "ID: %d" % owner_node.get_instance_id(), "y": 0.06},
			{"cfg": "show_members", "text": "Membro: %s" % text, "y": 0.0},
		]
		for line in lines:
			var lbl := Label3D.new()
			lbl.text = str(line["text"])
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.no_depth_test = true
			lbl.pixel_size = 0.003
			lbl.font_size = 14
			# Light cyan — the Debug 3D column color (matches debug_overlay.gd).
			lbl.modulate = Color(0.6, 1.0, 1.0)
			lbl.outline_size = 4
			lbl.outline_modulate = Color(0, 0, 0, 0.8)
			lbl.visible = cfg.get_value("game", str(line["cfg"]), false)
			body.add_child(lbl)
			lbl.position = center + Vector3(0.0, 0.12 + float(line["y"]), 0.0)


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

# Per-character STANDALONE part bone(s): protruding plates that get their OWN box collider
# (the limb capsule wouldn't wrap them) instead of being merged into a member. Mirrors
# red_robot.gd — its rear leg guard plates ("...RearLegGuard").
const _MODEL_STANDALONE_BONES := {
	"red_robot": ["L-RearLegGuard", "R-RearLegGuard"],
}


# Build best-fit colliders that wrap each body MEMBER (sphere head, box torso,
# capsule limbs) so they render green via the gizmos above. The gameplay script
# that normally builds these is stripped from the preview, so we build them here.
# Skeleton characters reuse the shared LimbColliders builder; the criatura (no
# skeleton) is grouped by mesh-node name instead.
func _add_member_colliders(instance: Node) -> void:
	var skels: Array = instance.find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		var lc := LimbColliders.new()
		lc.hitbox_layer = 64        # own layer — does not touch damage layers (16/32)
		lc.padding = 0.04           # tight gap around the mesh (hugs the body)
		lc.head_bone_names = _head_bones_for_current()
		lc.torso_bone_names = _torso_bones_for_current()
		lc.standalone_part_bones = _standalone_bones_for_current()
		instance.add_child(lc)
		lc.build_for(skels[0] as Skeleton3D)
		return
	_add_mesh_member_colliders(instance)


func _head_bones_for_current() -> Array[String]:
	return _model_bones_for_current(_MODEL_HEAD_BONES)


func _torso_bones_for_current() -> Array[String]:
	return _model_bones_for_current(_MODEL_TORSO_BONES)


func _standalone_bones_for_current() -> Array[String]:
	return _model_bones_for_current(_MODEL_STANDALONE_BONES)


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
	var members: Dictionary = {}   # group -> {"label": String, "nodes": Array}
	for node in instance.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var g := WeaponParts.group_of(mi.name) if is_weapon else BodyParts.group_of(mi.name)
		if g == "":
			continue
		if not members.has(g):
			var lab: String = WeaponParts.label_of(g) if is_weapon else BodyParts.label_of(g)
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

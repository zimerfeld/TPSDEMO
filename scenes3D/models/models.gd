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
# (otherwise invisible) CollisionShape3D volumes; effects shows the model's
# gameplay flourishes (particles, lights, bone-mounted laser/muzzle meshes);
# animation plays the model's AnimationPlayer; audio plays its sound emitters.
# All start off so a freshly-picked model previews static and silent.
var _show_colliders: bool = false
var _show_effects: bool = false
var _play_animation: bool = false
var _play_audio: bool = false

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
@onready var status_label: Label = $UI/Selectors/StatusLabel
@onready var rotate_toggle: CheckButton = $UI/Toggles/RotateToggle
@onready var animation_toggle: CheckButton = $UI/Toggles/AnimationToggle
@onready var audio_toggle: CheckButton = $UI/Toggles/AudioToggle
@onready var colliders_toggle: CheckButton = $UI/Toggles/CollidersToggle
@onready var effects_toggle: CheckButton = $UI/Toggles/EffectsToggle


func _ready() -> void:
	_zoom = camera.position.z
	_zoom_target = _zoom
	_categories = _scan_library()

	cbo_category.clear()
	cbo_category.add_item(SELECT_LABEL)
	for category in _categories:
		cbo_category.add_item(category["label"])
	cbo_category.item_selected.connect(_on_category_selected)
	cbo_prefix.item_selected.connect(_on_prefix_selected)
	cbo_models.item_selected.connect(_on_model_selected)
	cbo_meshes.item_selected.connect(_on_mesh_selected)

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

	# Start blank: every dropdown shows "Selecione..." and nothing is previewed
	# until the user drills down Categoria -> Prefixo -> Modelo -> Parte.
	cbo_category.select(0)
	_on_category_selected(0)


func _process(delta: float) -> void:
	# Slowly spin the previewed mesh, like the character on the choose-player
	# screen — but pause while the user is hand-rotating it with the mouse.
	if _auto_rotate and not _dragging:
		_yaw += delta * AUTO_ROTATE_SPEED
	# Rebuild rotation from yaw/pitch with roll fixed at 0 (orthogonal axes only).
	model_holder.rotation = Vector3(_pitch, _yaw, 0.0)
	# Glide the camera toward the wheel-set zoom distance instead of snapping.
	if not is_equal_approx(_zoom, _zoom_target):
		_zoom = lerpf(_zoom, _zoom_target, minf(ZOOM_SMOOTH * delta, 1.0))
		camera.position.z = _zoom


# Category dropdown index 0 is the "Selecione..." placeholder; real categories
# start at index 1 (mapping to _categories[index - 1]). Selecting the placeholder
# blanks the whole dependent chain (prefix, model, part) and clears the preview.
func _on_category_selected(index: int) -> void:
	if index <= 0:
		_reset_prefixes()
		_reset_models()
		status_label.text = "Selecione uma categoria."
		return
	_populate_prefixes(index - 1)
	_populate_models()


# Build the prefix dropdown for a category: "Selecione..." (no filter, every model
# in the category) plus each distinct model prefix (the first underscore-separated
# token, e.g. "core" for core / core_out_light). Selecting resets the filter to
# none. The placeholder carries an empty metadata string so it means "no filter".
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
	cbo_prefix.add_item(SELECT_LABEL)
	cbo_prefix.set_item_metadata(0, "")
	for prefix in prefixes:
		cbo_prefix.add_item(_prettify(prefix))
		cbo_prefix.set_item_metadata(cbo_prefix.item_count - 1, prefix)
	cbo_prefix.select(0)
	_prefix_filter = ""


# Reset the prefix dropdown to just the "Selecione..." placeholder (no category
# chosen, so there is nothing to filter).
func _reset_prefixes() -> void:
	cbo_prefix.clear()
	cbo_prefix.add_item(SELECT_LABEL)
	cbo_prefix.set_item_metadata(0, "")
	cbo_prefix.select(0)
	_prefix_filter = ""


func _on_prefix_selected(index: int) -> void:
	_prefix_filter = cbo_prefix.get_item_metadata(index)
	_populate_models()


# Fill the Model dropdown with "Selecione..." plus the current category's models
# that match the active prefix filter. The placeholder stays selected, so no model
# is previewed until the user picks one — and the Part dropdown is reset to blank.
func _populate_models() -> void:
	cbo_models.clear()
	cbo_models.add_item(SELECT_LABEL)
	_filtered_models = []
	var cat_index := cbo_category.selected - 1
	if cat_index < 0:
		cbo_models.select(0)
		_reset_meshes_and_preview()
		status_label.text = "Selecione uma categoria."
		return

	var models: Array = _categories[cat_index]["models"]
	for entry in models:
		if _prefix_filter != "" and entry.get("prefix", "") != _prefix_filter:
			continue
		_filtered_models.append(entry)
		cbo_models.add_item(entry["name"])

	cbo_models.select(0)
	_reset_meshes_and_preview()
	if _filtered_models.is_empty():
		status_label.text = "Nenhum modelo neste grupo."
	else:
		status_label.text = "Selecione um modelo."


# Reset the Model dropdown to just the "Selecione..." placeholder and clear the
# parts dropdown and preview below it.
func _reset_models() -> void:
	cbo_models.clear()
	cbo_models.add_item(SELECT_LABEL)
	cbo_models.select(0)
	_filtered_models = []
	_reset_meshes_and_preview()


# Reset the Part dropdown to just the "Selecione..." placeholder and clear the
# previewed mesh/model and its cached scenes.
func _reset_meshes_and_preview() -> void:
	_model_scene = null
	_display_scene = null
	_mesh_catalog = []
	cbo_meshes.clear()
	cbo_meshes.add_item(SELECT_LABEL)
	cbo_meshes.select(0)
	_clear_preview()


# Model dropdown index 0 is the "Selecione..." placeholder; real models start at
# index 1 (mapping to _filtered_models[index - 1]). Selecting a real model rebuilds
# the Part dropdown ("Selecione...", then "Modelo completo", then each distinct
# mesh) but leaves the placeholder selected, so nothing previews until a part is
# picked. Selecting the placeholder blanks the part dropdown and the preview.
func _on_model_selected(index: int) -> void:
	if index <= 0:
		_reset_meshes_and_preview()
		status_label.text = "Selecione um modelo."
		return

	var model: Dictionary = _filtered_models[index - 1]
	_current_model_path = model["path"]
	_model_scene = load(model["path"])
	_display_scene = load(model.get("display_path", model["path"]))
	_mesh_catalog = _build_mesh_catalog(_model_scene)

	cbo_meshes.clear()
	cbo_meshes.add_item(SELECT_LABEL)
	cbo_meshes.add_item(WHOLE_MODEL_LABEL)
	for entry in _mesh_catalog:
		cbo_meshes.add_item(entry["label"])
	cbo_meshes.select(0)
	_clear_preview()
	status_label.text = "Selecione uma parte."


# Part dropdown index 0 is the "Selecione..." placeholder (nothing previewed),
# index 1 is the assembled "Modelo completo", and indices 2.. map to the distinct
# meshes in _mesh_catalog (shifted by the two leading entries).
func _on_mesh_selected(index: int) -> void:
	if index <= 0:
		_clear_preview()
		status_label.text = "Selecione uma parte."
	elif index == 1:
		_preview_whole_model()
		status_label.text = "Modelo completo — %d parte(s)" % _mesh_catalog.size()
	else:
		_preview_mesh(index - 2)
		status_label.text = "Parte: %s" % _mesh_catalog[index - 2]["label"]


func _on_rotate_toggled(pressed: bool) -> void:
	_auto_rotate = pressed


func _on_animation_toggled(pressed: bool) -> void:
	_play_animation = pressed
	_refresh_preview()


func _on_audio_toggled(pressed: bool) -> void:
	_play_audio = pressed
	_refresh_preview()


func _on_colliders_toggled(pressed: bool) -> void:
	_show_colliders = pressed
	_refresh_preview()


func _on_effects_toggled(pressed: bool) -> void:
	_show_effects = pressed
	_refresh_preview()


# Re-render the current Part selection so toggle changes take effect.
func _refresh_preview() -> void:
	if cbo_meshes.item_count > 0:
		_on_mesh_selected(cbo_meshes.selected)


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
	_strip_scripts(instance)
	if not _show_effects:
		_hide_gameplay_effects(instance)
	# Suppress autoplay BEFORE the subtree enters the tree (autoplay fires on
	# tree entry), then kick off playback below only for the toggles that are on.
	var av_state := _suppress_autoplay(instance)
	model_holder.add_child(instance)
	_apply_av_playback(av_state)
	if _show_colliders:
		# Build the per-member colliders (best-fit sphere/box/capsule) so they show
		# up green — the preview strips the gameplay script that normally builds
		# them, so we construct them here just for display.
		_add_member_colliders(instance)
	if instance is Node3D:
		_fit_to_view(instance as Node3D)
	if _show_colliders:
		_add_collider_gizmos(instance)


# Clear the autoplay on every AnimationPlayer and audio emitter so nothing starts
# the instant the subtree enters the tree. Returns the captured state so playback
# can be (re)started afterwards from inside the tree, per the Animation/Som toggles.
func _suppress_autoplay(instance: Node) -> Dictionary:
	var anim_autoplay: Dictionary = {}
	for node in instance.find_children("*", "AnimationPlayer", true, false):
		var ap := node as AnimationPlayer
		anim_autoplay[ap] = ap.autoplay
		ap.autoplay = ""

	var audio_players: Array = []
	for cls in ["AudioStreamPlayer", "AudioStreamPlayer3D", "AudioStreamPlayer2D"]:
		audio_players.append_array(instance.find_children("*", cls, true, false))
	for node in audio_players:
		node.set("autoplay", false)

	return {"anim": anim_autoplay, "audio": audio_players}


# Start the model's animation and/or sound depending on the toggles. Animation
# uses the original autoplay clip (falling back to the first available); audio
# plays every emitter that has a stream. Off toggles leave it static and silent.
func _apply_av_playback(state: Dictionary) -> void:
	if _play_animation:
		for ap: AnimationPlayer in state["anim"]:
			var clip: String = state["anim"][ap]
			if clip == "" and not ap.get_animation_list().is_empty():
				clip = ap.get_animation_list()[0]
			if clip != "" and ap.has_animation(clip):
				ap.play(clip)
	if _play_audio:
		for node in state["audio"]:
			if node.get("stream") != null:
				node.play()


# Recursively detach every script in the instanced subtree before it enters the
# tree, so no _ready / gameplay code runs during the static preview.
func _strip_scripts(node: Node) -> void:
	node.set_script(null)
	for child in node.get_children():
		_strip_scripts(child)


# Hide the model's gameplay-only flourishes — particle systems (smoke, thrust),
# lights, and meshes pinned to a bone (muzzle/laser) — leaving just the body.
func _hide_gameplay_effects(instance: Node) -> void:
	for node in instance.find_children("*", "Node3D", true, false):
		var node3d := node as Node3D
		if node is GPUParticles3D or node is CPUParticles3D or node is Light3D:
			node3d.visible = false
		elif node is MeshInstance3D and _under_bone_attachment(node, instance):
			node3d.visible = false


# Draw a wireframe gizmo for every CollisionShape3D so the otherwise-invisible
# collision volumes can be inspected. Each gizmo is parented under its shape so
# it inherits the shape transform and the root's fit-to-view scale.
func _add_collider_gizmos(instance: Node) -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.2, 1.0, 0.4, 0.28)
	for node in instance.find_children("*", "CollisionShape3D", true, false):
		var shape_node := node as CollisionShape3D
		if shape_node.shape == null:
			continue
		var gizmo := MeshInstance3D.new()
		gizmo.mesh = shape_node.shape.get_debug_mesh()
		gizmo.material_override = mat
		shape_node.add_child(gizmo)


# Per-character: head bone(s) BodyParts can't infer from the name (it excludes
# "eye"/"mouth"), so the model browser names them explicitly for the preview.
const _MODEL_HEAD_BONES := {
	"red_robot": ["mouth_eyes"],
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
		lc.padding = 0.1            # small gap around the mesh (~the "10px" margin)
		lc.head_bone_names = _head_bones_for_current()
		instance.add_child(lc)
		lc.build_for(skels[0] as Skeleton3D)
		return
	_add_mesh_member_colliders(instance)


func _head_bones_for_current() -> Array[String]:
	var out: Array[String] = []
	for key in _MODEL_HEAD_BONES:
		if _current_model_path.contains(key):
			for b in _MODEL_HEAD_BONES[key]:
				out.append(b)
			break
	return out


# Member colliders for a rig that has no Skeleton3D (criatura_alada): group the
# visible mesh nodes by BodyParts (head/torso/legs from their names) and wrap each
# group with the same best-fit geometry, in the instance's local space.
func _add_mesh_member_colliders(instance: Node) -> void:
	var groups: Dictionary = {}   # group -> AABB (instance-local)
	var inv := (instance as Node3D).global_transform.affine_inverse()
	for node in instance.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var g := BodyParts.group_of(mi.name)
		if g == "":
			continue
		var box := (inv * mi.global_transform) * mi.get_aabb()
		groups[g] = box if not groups.has(g) else (groups[g] as AABB).merge(box)

	var holder := Node3D.new()
	holder.name = "MemberColliders"
	instance.add_child(holder)
	for g in groups:
		var aabb: AABB = (groups[g] as AABB).grow(0.1)
		var body := StaticBody3D.new()
		body.name = "Collider_%s" % g
		body.collision_layer = 64
		body.collision_mask = 0
		body.set_meta("member_label", BodyParts.label_of(g))
		body.add_child(LimbColliders.make_member_shape(g, aabb))
		holder.add_child(body)


# Center and scale a model so it fits nicely in front of the camera, regardless
# of its original size. target_size is the largest dimension after scaling. Only
# mesh geometry is measured — lights and particle systems carry huge bounds (the
# forklift spotlight reaches 50 m) that would otherwise shrink the model to a dot.
func _fit_to_view(model: Node3D, target_size: float = 2.0) -> void:
	var visuals: Array = model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		visuals.append(model)

	var bounds := AABB()
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
		_yaw += motion.relative.x * DRAG_SENSITIVITY
		# Pitch is clamped to ±90° so the model can't roll past vertical and flip.
		_pitch = clampf(_pitch + motion.relative.y * DRAG_SENSITIVITY, -PI * 0.5, PI * 0.5)

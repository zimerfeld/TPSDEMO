extends Node

## UI language switcher. Each scene ships its OWN pair of flat JSON dictionaries inside
## a "Resources/" folder next to its scene file (e.g.
## res://scenes2D/menu/Resources/menu.pt.json + menu.en.json). Every dictionary maps the
## canonical (authored) text of a Button/Label/CheckButton — or any string a screen passes
## to tr_key — to that language's text. At boot Locale scans SCAN_ROOTS, finds every
## "*.pt.json" / "*.en.json" and merges them into one lookup table per language, so a new
## screen is covered just by dropping its Resources/ dictionaries in — no autoload edit.
##
## The chosen language is persisted in Settings ("game/language") and applied at startup;
## switching re-localizes the live tree and emits `language_changed`.
##
## Localization is automatic: every Button/Label that enters the tree has its `text`
## translated. Nodes whose text a script drives dynamically (status lines, dropdown items)
## opt OUT by joining the SKIP_GROUP group and re-translate themselves on `language_changed`
## via tr_key (so the auto-localizer never fights the script over the same label).

signal language_changed(lang: String)

const DEFAULT_LANG := "pt"
# Folders scanned (recursively) for per-scene "*.<lang>.json" dictionaries.
const SCAN_ROOTS: Array[String] = ["res://scenes2D", "res://scenes3D"]
# Meta key holding a node's canonical source text, so it can be re-translated when the
# language changes without losing the original.
const _SRC_META := &"_loc_src"
# Nodes in this group are skipped by the automatic Button/Label localizer: a script owns
# their text and re-applies tr_key itself on `language_changed`.
const SKIP_GROUP := &"loc_manual"

var _lang: String = DEFAULT_LANG
var _table: Dictionary = {}


func _ready() -> void:
	_lang = Settings.config_file.get_value("game", "language", DEFAULT_LANG)
	if _lang != "pt" and _lang != "en":
		_lang = DEFAULT_LANG
	_load_table()
	# Localize nodes as they enter the tree (covers every screen main.gd swaps in).
	get_tree().node_added.connect(_localize_node)
	# Localize whatever already exists at boot.
	call_deferred("_localize_tree", get_tree().root)


func get_language() -> String:
	return _lang


# Switch language, persist it and re-localize the live tree. No-op for an unknown or
# already-active language.
func set_language(lang: String) -> void:
	if lang == _lang or (lang != "pt" and lang != "en"):
		return
	_lang = lang
	Settings.config_file.set_value("game", "language", lang)
	Settings.save_settings()
	_load_table()
	_localize_tree(get_tree().root)
	language_changed.emit(lang)


# Translate a canonical (source) string into the active language; unknown keys pass
# through unchanged.
func tr_key(src: String) -> String:
	return _table.get(src, src)


func _load_table() -> void:
	_table = {}
	for root in SCAN_ROOTS:
		_scan_dir(root)


# Recursively walk `path`, merging every "*.<lang>.json" dictionary found into _table.
func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if not entry.begins_with("."):
				_scan_dir(path.path_join(entry))
		elif entry.ends_with("." + _lang + ".json"):
			_merge_json(path.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()


func _merge_json(file_path: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		_table.merge(data, true)
	else:
		push_warning("Locale: '%s' is not a JSON object" % file_path)


func _localize_tree(node: Node) -> void:
	if node == null:
		return
	_localize_node(node)
	for child in node.get_children():
		_localize_tree(child)


# Localize one node's `text` if it is a Button or Label. OptionButton/MenuButton are
# excluded (their `text` is the live selection, managed in code), and nodes in SKIP_GROUP
# opt out so a script can own their text. The first time a node is seen its current text is
# captured as the canonical source (meta); later language changes translate from that
# stored source rather than from the already-translated text.
func _localize_node(node: Node) -> void:
	if node is OptionButton or node is MenuButton:
		return
	if not (node is Button or node is Label):
		return
	if node.is_in_group(SKIP_GROUP):
		return
	var src: String
	if node.has_meta(_SRC_META):
		src = node.get_meta(_SRC_META)
	else:
		src = node.text
		node.set_meta(_SRC_META, src)
	node.text = tr_key(src)

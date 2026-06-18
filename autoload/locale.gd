extends Node

## UI language switcher. Each language is a flat JSON dictionary in the project root
## (res://pt.json, res://en.json) mapping the canonical (Portuguese-build) text of a
## Button/Label to that language's text. The chosen language is persisted in Settings
## ("game/language") and applied at startup; switching re-localizes the live tree.
##
## Localization is automatic: every Button/Label that enters the tree has its `text`
## translated, so new screens are covered without per-scene code — extending coverage
## just means adding keys to the two JSON files.

signal language_changed(lang: String)

const FILES := {
	"pt": "res://pt.json",
	"en": "res://en.json",
}
const DEFAULT_LANG := "pt"
# Meta key holding a node's canonical source text, so it can be re-translated when the
# language changes without losing the original.
const _SRC_META := &"_loc_src"

var _lang: String = DEFAULT_LANG
var _table: Dictionary = {}


func _ready() -> void:
	_lang = Settings.config_file.get_value("game", "language", DEFAULT_LANG)
	if not FILES.has(_lang):
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
	if lang == _lang or not FILES.has(lang):
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
	_table = _read_json(FILES.get(_lang, FILES[DEFAULT_LANG]))


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_warning("Locale: missing dictionary '%s'" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var data: Variant = JSON.parse_string(file.get_as_text())
	return data if data is Dictionary else {}


func _localize_tree(node: Node) -> void:
	if node == null:
		return
	_localize_node(node)
	for child in node.get_children():
		_localize_tree(child)


# Localize one node's `text` if it is a Button or Label. The first time a node is seen
# its current text is captured as the canonical source (meta); later language changes
# translate from that stored source rather than from the already-translated text.
func _localize_node(node: Node) -> void:
	if not (node is Button or node is Label):
		return
	var src: String
	if node.has_meta(_SRC_META):
		src = node.get_meta(_SRC_META)
	else:
		src = node.text
		node.set_meta(_SRC_META, src)
	node.text = tr_key(src)

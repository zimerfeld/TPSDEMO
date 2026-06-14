extends HBoxContainer

## Ability bar — N ability slots, each with a cooldown ring gauge.
##
## Drive via set_cooldown(index, remaining, max) + trigger(index), or
## auto-bind to /root/GameState (ability_cooldown_changed signal and the
## ability_1/2/3 input actions, if they exist) when bind_game_state is true.
##
## Each slot is a VBoxContainer named Ability1..N containing:
##   IconWrap (PanelContainer) > GaugeRing (cooldown_gauge.gd), CD (Label),
##   State (Label).

@export var bind_game_state: bool = true

const _ACCENT: Array[Color] = [
	Color(0.0, 0.918, 1.0, 1.0),
	Color(1.0, 0.176, 0.584, 1.0),
	Color(1.0, 0.306, 0.306, 1.0),
]
const _DIM := Color(0.227, 0.251, 0.333, 1.0)
const _KEYS: Array[String] = ["Q", "E", "R"]

var _slots: Array[Control] = []
var _gauges: Array = []
var _cd_labels: Array = []
var _state_labels: Array = []
var _game_state: Node = null

func _ready() -> void:
	for child in get_children():
		var slot := child as VBoxContainer
		if slot == null:
			continue
		_slots.append(slot)
		_gauges.append(slot.get_node_or_null("IconWrap/GaugeRing"))
		_cd_labels.append(slot.get_node_or_null("CD"))
		_state_labels.append(slot.get_node_or_null("State"))
	if not bind_game_state:
		return
	_game_state = get_node_or_null("/root/GameState")
	if _game_state != null and _game_state.has_signal("ability_cooldown_changed"):
		_game_state.ability_cooldown_changed.connect(_on_cooldown_changed)

func _unhandled_input(event: InputEvent) -> void:
	if _game_state == null:
		return
	for i in range(_slots.size()):
		var action := "ability_%d" % (i + 1)
		if InputMap.has_action(action) and event.is_action_pressed(action):
			if _game_state.has_method("use_ability"):
				_game_state.use_ability(i)
			trigger(i)
			get_viewport().set_input_as_handled()

## Update slot `index`: fill its gauge and refresh the CD / state labels.
func set_cooldown(index: int, remaining: float, max_cd: float) -> void:
	if index < 0 or index >= _slots.size():
		return
	var gauge = _gauges[index]
	if gauge != null and gauge.has_method("set_remaining"):
		gauge.set_remaining(remaining, max_cd)
	var cd: Label = _cd_labels[index]
	var st: Label = _state_labels[index]
	if cd == null or st == null:
		return
	if remaining > 0.0:
		cd.text = "%.1f" % remaining
		st.text = "COOLDOWN"
		st.add_theme_color_override("font_color", _DIM)
	else:
		cd.text = _KEYS[index] if index < _KEYS.size() else str(index + 1)
		st.text = "ARMED"
		st.add_theme_color_override("font_color", _accent(index))

## Pop/bounce animation on a slot — call when its ability fires.
func trigger(index: int) -> void:
	if index < 0 or index >= _slots.size():
		return
	var node := _slots[index]
	node.pivot_offset = node.size * 0.5
	var t := create_tween()
	t.tween_property(node, "scale", Vector2(1.18, 1.18), 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "scale", Vector2.ONE, 0.42) \
		.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func _on_cooldown_changed(index: int, remaining: float) -> void:
	var max_cd := 1.0
	if _game_state != null and "cooldown_max" in _game_state \
			and index < _game_state.cooldown_max.size():
		max_cd = _game_state.cooldown_max[index]
	set_cooldown(index, remaining, max_cd)

func _accent(index: int) -> Color:
	return _ACCENT[index] if index < _ACCENT.size() else _ACCENT[0]

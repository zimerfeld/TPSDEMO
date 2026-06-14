extends PanelContainer

## Credits / balance readout with an animated ticker and spend/gain flash.
##
## Drive via set_credits(value), or auto-bind to /root/GameState
## (credits_changed signal) when bind_game_state is true.

@export var bind_game_state: bool = true

const _SPEND := Color(1.0, 0.42, 0.18, 1.0)  # orange flash on debit
const _GAIN := Color(0.22, 1.0, 0.08, 1.0)   # green flash on top-up

@onready var _count: Label = $AmmoContent/AmmoCount

var _game_state: Node = null
var _displayed: float = 0.0
var _tick_tween: Tween = null

func _ready() -> void:
	if not bind_game_state:
		return
	_game_state = get_node_or_null("/root/GameState")
	if _game_state == null:
		return
	if _game_state.has_signal("credits_changed"):
		_game_state.credits_changed.connect(_on_credits_changed)
	if "credits" in _game_state:
		set_credits(_game_state.credits)

## Snap the displayed balance to `value` (no ticker animation).
func set_credits(value: int) -> void:
	if _tick_tween != null and _tick_tween.is_running():
		_tick_tween.kill()
	_displayed = float(value)
	_count.text = _format(value)

func _on_credits_changed(value: int, delta: int) -> void:
	var flash := _SPEND if delta < 0 else _GAIN
	_count.modulate = flash
	create_tween().tween_property(_count, "modulate", Color.WHITE, 0.35)
	if delta >= 0:
		# Gains snap; the ticker is reserved for spends so it reads as draining.
		set_credits(value)
		return
	if _tick_tween != null and _tick_tween.is_running():
		_tick_tween.kill()
	var duration := clampf(float(absi(delta)) / 700.0, 0.18, 0.45)
	_tick_tween = create_tween()
	_tick_tween.tween_method(_set_displayed, _displayed, float(value), duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _set_displayed(v: float) -> void:
	_displayed = v
	_count.text = _format(int(round(v)))

func _format(value: int) -> String:
	# Thousands separator (Godot has no built-in int locale formatter).
	var s := str(value)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count == 3 and i > 0:
			out = "," + out
			count = 0
	return out

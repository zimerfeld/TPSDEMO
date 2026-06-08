extends VBoxContainer

## Scrolling system-log feed. Push lines via push_message(text), or
## auto-bind to /root/GameState (log_message signal) when bind_game_state
## is true. A child Messages container (log_pulse.gd) holds Log1..N labels
## plus a Cursor label.

@export var bind_game_state: bool = true
@export var timestamp: bool = true

var _logs: Array[Label] = []
var _cursor: Label = null
var _game_state: Node = null

func _ready() -> void:
	var messages := $LogPanel/Messages
	for child in messages.get_children():
		if child is Label and String(child.name).begins_with("Log"):
			_logs.append(child)
	_cursor = messages.get_node_or_null("Cursor")
	_blink_cursor()
	if not bind_game_state:
		return
	_game_state = get_node_or_null("/root/GameState")
	if _game_state != null and _game_state.has_signal("log_message"):
		_game_state.log_message.connect(push_message)

## Append a line, scrolling older entries up one row.
func push_message(text: String) -> void:
	if _logs.is_empty():
		return
	for i in range(_logs.size() - 1):
		_logs[i].text = _logs[i + 1].text
	if timestamp:
		var stamp := Time.get_time_string_from_system()
		_logs[_logs.size() - 1].text = "[%s] %s" % [stamp, text]
	else:
		_logs[_logs.size() - 1].text = text

func _blink_cursor() -> void:
	if _cursor == null:
		return
	var t := create_tween().set_loops()
	t.tween_property(_cursor, "modulate:a", 0.2, 0.5)
	t.tween_property(_cursor, "modulate:a", 1.0, 0.5)

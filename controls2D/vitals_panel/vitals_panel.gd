extends PanelContainer

## Vitals readout (HP + Shield) — reusable HUD widget.
##
## Drive it via set_health()/set_shield(), or let it auto-bind to a
## /root/GameState autoload exposing health_changed/shield_changed (and an
## optional hp_direct_hit) signals when bind_game_state is true.

@export var bind_game_state: bool = true
@export var max_health: float = 100.0
@export var max_shield: float = 100.0

@onready var _health_bar: ProgressBar = $Content/HealthBar
@onready var _health_val: Label = $Content/HpHeader/HealthVal
@onready var _shield_bar: ProgressBar = $Content/ShieldBar
@onready var _shield_val: Label = $Content/ShHeader/ShieldVal

var _game_state: Node = null

func _ready() -> void:
	_start_hp_breathe()
	if not bind_game_state:
		return
	_game_state = get_node_or_null("/root/GameState")
	if _game_state == null:
		return
	if _game_state.has_signal("health_changed"):
		_game_state.health_changed.connect(_on_health_changed)
	if _game_state.has_signal("shield_changed"):
		_game_state.shield_changed.connect(_on_shield_changed)
	if _game_state.has_signal("hp_direct_hit"):
		_game_state.hp_direct_hit.connect(func(_a: float) -> void: flash_damage())
	if "health" in _game_state:
		set_health(_game_state.health)
	if "shield" in _game_state:
		set_shield(_game_state.shield)

## Update HP. Pass max_value > 0 to also change the bar's maximum.
func set_health(value: float, max_value: float = -1.0) -> void:
	if max_value > 0.0:
		max_health = max_value
	_health_bar.max_value = max_health
	_health_bar.value = value
	_health_val.text = str(int(round(value)))

## Update shield. Pass max_value > 0 to also change the bar's maximum.
func set_shield(value: float, max_value: float = -1.0) -> void:
	if max_value > 0.0:
		max_shield = max_value
	_shield_bar.max_value = max_shield
	_shield_bar.value = value
	_shield_val.text = str(int(round(value)))

func _on_health_changed(value: float, max_value: float) -> void:
	set_health(value, max_value)

func _on_shield_changed(value: float, max_value: float) -> void:
	set_shield(value, max_value)

func _start_hp_breathe() -> void:
	var breathe := create_tween().set_loops()
	breathe.set_trans(Tween.TRANS_SINE)
	breathe.tween_property(_health_bar, "modulate:a", 0.85, 1.25)
	breathe.tween_property(_health_bar, "modulate:a", 1.0, 1.25)

## Brief red flash on the HP bar fill — call it when the player takes a hit.
func flash_damage() -> void:
	var style := _health_bar.get_theme_stylebox("fill")
	if style is StyleBoxFlat:
		var dup := style.duplicate() as StyleBoxFlat
		_health_bar.add_theme_stylebox_override("fill", dup)
		var original := dup.bg_color
		dup.bg_color = Color(1.0, 0.1, 0.1, 1.0)
		var t := create_tween()
		t.tween_interval(0.15)
		t.tween_property(dup, "bg_color", original, 0.9)

extends Control

## Ring gauge around an ability icon. The fill arc represents cooldown
## progress (0 = just used, 1 = ready). A subtle comet-tail sweep orbits
## the ring for constant motion life.
##
## Reusable: works with no data source (idle ring + sweep only). Drive it
## either by calling set_progress()/set_remaining() from a parent widget,
## or — if a GameState autoload with cooldowns[]/cooldown_max[] exists and
## bind_game_state is true — it auto-reads GameState.cooldowns[ability_index].

@export var ability_index: int = 0
@export var color: Color = Color(0.0, 0.918, 1.0, 1.0)
@export var ring_radius: float = 30.0
@export var ring_width: float = 3.0
## When true, auto-read cooldown from a /root/GameState autoload if present.
@export var bind_game_state: bool = true

@export_group("Idle sweep")
@export var sweep_period: float = 3.2  # seconds per full revolution
@export var sweep_arc: float = 0.9      # comet-tail length in radians
@export var sweep_segments: int = 14
@export var sweep_intensity: float = 0.9  # peak alpha at head
@export var sweep_width_boost: float = 1.5  # extra width on top of ring_width

var _game_state: Node = null
var _phase: float = 0.0
var _progress: float = 1.0  # 0 = just used, 1 = ready

func _ready() -> void:
	if bind_game_state:
		_game_state = get_node_or_null("/root/GameState")
	_phase = randf() * TAU  # stagger rings on first frame

## Set the fill fraction directly (0 = empty/just used, 1 = full/ready).
func set_progress(value: float) -> void:
	_progress = clampf(value, 0.0, 1.0)
	queue_redraw()

## Set fill from a remaining/max cooldown pair (remaining 0 => ready).
func set_remaining(remaining: float, max_cd: float) -> void:
	if max_cd > 0.0:
		_progress = clampf(1.0 - remaining / max_cd, 0.0, 1.0)
	else:
		_progress = 1.0
	queue_redraw()

func _process(delta: float) -> void:
	if sweep_period > 0.0:
		_phase = fposmod(_phase + TAU * delta / sweep_period, TAU)
	queue_redraw()

func _draw() -> void:
	var progress := _progress
	if _game_state != null \
			and "cooldowns" in _game_state and "cooldown_max" in _game_state \
			and ability_index < _game_state.cooldowns.size():
		var remaining: float = _game_state.cooldowns[ability_index]
		var max_cd: float = _game_state.cooldown_max[ability_index]
		progress = 1.0
		if max_cd > 0.0:
			progress = clampf(1.0 - remaining / max_cd, 0.0, 1.0)
	var center := size * 0.5
	var dim := Color(color.r, color.g, color.b, 0.25)
	draw_arc(center, ring_radius, 0.0, TAU, 48, dim, ring_width)
	if progress > 0.0:
		var start_a := -PI / 2
		var end_a := start_a + TAU * progress
		draw_arc(center, ring_radius, start_a, end_a, 48, color, ring_width)
	_draw_sweep(center)

func _draw_sweep(center: Vector2) -> void:
	if sweep_segments < 2 or sweep_arc <= 0.0:
		return
	var seg := sweep_arc / float(sweep_segments)
	var w := ring_width + sweep_width_boost
	for i in sweep_segments:
		# t=1 at the head, t=0 at the tail — quadratic falloff for a bright tip
		# and a soft wake.
		var t := float(i + 1) / float(sweep_segments)
		var a1 := _phase - (1.0 - t) * sweep_arc
		var a0 := a1 - seg
		var alpha := pow(t, 2.2) * sweep_intensity
		var c := Color(color.r, color.g, color.b, alpha)
		draw_arc(center, ring_radius, a0, a1, 4, c, w)

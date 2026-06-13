extends Control

## Pulsing white-to-transparent gradient overlay, intended to sit inside a
## ProgressBar (anchors_preset=15, mouse_filter=ignore). The bright side
## rides the "filled" end of the bar and breathes in alpha over a sine loop;
## the far end stays clear so the bar's native color dominates there.
##
## Clips the gradient width to the current fill width via `track_progress`,
## so at low shield values the glow shrinks instead of spilling into the
## unfilled region. Leave `track_progress` empty to span the whole rect.

@export var peak_alpha: float = 0.45
@export var min_alpha: float = 0.05
@export var period: float = 3.2
@export var gradient_fraction: float = 0.55  # portion of the fill that gets lit
@export var bright_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var track_progress: NodePath

var _phase: float = 0.0
var _bar: ProgressBar = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if track_progress != NodePath(""):
		_bar = get_node_or_null(track_progress) as ProgressBar

func _process(delta: float) -> void:
	if period <= 0.0:
		return
	_phase = fposmod(_phase + delta / period, 1.0)
	queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var fill_w := size.x
	if _bar != null and _bar.max_value > 0.0:
		fill_w = size.x * clampf(_bar.value / _bar.max_value, 0.0, 1.0)
	if fill_w <= 0.0:
		return
	var gw := minf(fill_w, size.x * gradient_fraction)
	if gw <= 0.0:
		return
	# Sine-eased 0..1 over `period`.
	var t := 0.5 - 0.5 * cos(_phase * TAU)
	var a := lerpf(min_alpha, peak_alpha, t)
	var bright := Color(bright_color.r, bright_color.g, bright_color.b, a)
	var clear := Color(bright_color.r, bright_color.g, bright_color.b, 0.0)
	var pts := PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(gw, 0.0),
		Vector2(gw, size.y),
		Vector2(0.0, size.y),
	])
	var cols := PackedColorArray([bright, clear, clear, bright])
	draw_polygon(pts, cols)

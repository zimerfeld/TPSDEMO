extends Control

## Data-packet dot that orbits the perimeter of a PanelContainer.
##
## Place as a child of a PanelContainer — it fills the content rect and
## traverses the panel's outer perimeter (offset inward by `edge_inset`)
## at a constant speed. A short fading trail behind the dot implies motion.

@export var color: Color = Color(1.0, 0.42, 0.18, 0.55)
@export var dot_radius: float = 1.8
@export var trail_segments: int = 5
@export var trail_spacing: float = 0.014  # phase units between trail samples
@export var period: float = 5.5  # seconds per orbit
@export var edge_inset: float = 6.0  # how far inside the outer edge to travel
@export var start_phase: float = 0.0

var _phase: float = 0.0
var _ml: float = 0.0
var _mt: float = 0.0
var _mr: float = 0.0
var _mb: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase = fposmod(start_phase, 1.0)
	_cache_parent_margins()
	resized.connect(queue_redraw)

func _cache_parent_margins() -> void:
	var parent := get_parent() as Control
	if parent == null:
		return
	var sb := parent.get_theme_stylebox("panel")
	if sb == null:
		return
	_ml = sb.get_margin(SIDE_LEFT)
	_mt = sb.get_margin(SIDE_TOP)
	_mr = sb.get_margin(SIDE_RIGHT)
	_mb = sb.get_margin(SIDE_BOTTOM)

func _process(delta: float) -> void:
	if period <= 0.0:
		return
	_phase = fposmod(_phase + delta / period, 1.0)
	queue_redraw()

func _perimeter_point(t: float) -> Vector2:
	# Outer rect in local coords, inset so the dot rides just inside the frame.
	var x0 := -_ml + edge_inset
	var y0 := -_mt + edge_inset
	var x1 := size.x + _mr - edge_inset
	var y1 := size.y + _mb - edge_inset
	var w := maxf(x1 - x0, 1.0)
	var h := maxf(y1 - y0, 1.0)
	var perim := 2.0 * (w + h)
	var d := fposmod(t, 1.0) * perim
	if d < w:
		return Vector2(x0 + d, y0)
	d -= w
	if d < h:
		return Vector2(x1, y0 + d)
	d -= h
	if d < w:
		return Vector2(x1 - d, y1)
	d -= w
	return Vector2(x0, y1 - d)

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	# Trailing samples behind the head, each dimmer + smaller than the one ahead.
	for i in range(trail_segments, 0, -1):
		var t := _phase - float(i) * trail_spacing
		var pt := _perimeter_point(t)
		var falloff := 1.0 - float(i) / float(trail_segments + 1)
		var tc := Color(color.r, color.g, color.b, color.a * falloff * 0.55)
		draw_circle(pt, dot_radius * (0.4 + 0.55 * falloff), tc)
	# Head dot with a faint bloom halo.
	var head := _perimeter_point(_phase)
	var halo := Color(color.r, color.g, color.b, color.a * 0.35)
	draw_circle(head, dot_radius * 1.9, halo)
	draw_circle(head, dot_radius, color)

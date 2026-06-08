extends Control

## Scrolling waveform trace — sine + higher-frequency noise.
## Purely decorative: approximates an audio/comms signal line.

@export var color: Color = Color(0.22, 1.0, 0.08, 0.8)
@export var amplitude: float = 10.0
@export var base_freq: float = 0.15
@export var scroll_speed: float = 3.0
@export var point_count: int = 64

var _phase: float = 0.0

func _process(delta: float) -> void:
	_phase += scroll_speed * delta
	queue_redraw()

func _draw() -> void:
	if point_count < 2 or size.x <= 0.0:
		return
	var mid_y := size.y * 0.5
	var step := size.x / float(point_count - 1)
	var points := PackedVector2Array()
	points.resize(point_count)
	for i in range(point_count):
		var x := i * step
		var s := sin(_phase + i * base_freq) + sin(_phase * 0.7 + i * 0.42) * 0.35
		var y := mid_y + s * amplitude
		points[i] = Vector2(x, y)
	draw_polyline(points, color, 1.5, true)
	# Thin midline under the trace
	var mid := Color(color.r, color.g, color.b, 0.15)
	draw_line(Vector2(0.0, mid_y), Vector2(size.x, mid_y), mid, 1.0)
